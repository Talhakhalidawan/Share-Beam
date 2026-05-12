import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/models.dart';

class DiscoveryService {
  static const int discoveryPort = 9877;
  static const String multicastAddress = '224.0.0.123';
  static const String magicQuery = 'SHAREBEAM_DISCOVER';
  static const String magicGoodbye = 'SHAREBEAM_GOODBYE';
  static const String magicHeartbeat = 'SHAREBEAM_HEARTBEAT';

  static const Duration staleTimeout = Duration(seconds: 15);
  static const Duration queryInterval = Duration(seconds: 3);
  static const Duration heartbeatInterval = Duration(seconds: 3);
  static const Duration cleanupInterval = Duration(seconds: 5);

  RawDatagramSocket? _hostSocket;
  RawDatagramSocket? _scanSocket;
  StreamSubscription? _hostSubscription;
  StreamSubscription? _scanSubscription;
  Timer? _heartbeatTimer;
  Timer? _queryTimer;
  Timer? _cleanupTimer;

  final _devicesController =
      StreamController<List<DiscoveredDevice>>.broadcast();
  Stream<List<DiscoveredDevice>> get devicesStream => _devicesController.stream;

  final List<DiscoveredDevice> _discoveredDevices = [];

  bool _isHosting = false;
  String _hostName = '';
  int _hostServerPort = 9876;
  bool _isDiscovering = false;

  /// Start advertising this device as a host.
  /// Binds to the shared discovery port so other devices can reach us,
  /// and broadcasts a heartbeat every 3 seconds so new clients find us instantly.
  Future<void> startHost(String deviceName, int serverPort) async {
    if (_isHosting) return;
    _hostName = deviceName;
    _hostServerPort = serverPort;

    try {
      _hostSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
        reuseAddress: true,
        reusePort: true,
      );
      _hostSocket!.joinMulticast(InternetAddress(multicastAddress));

      _hostSubscription = _hostSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _hostSocket!.receive();
          if (datagram == null) return;
          final message = String.fromCharCodes(datagram.data).trim();
          if (message == magicQuery) {
            _sendReply(datagram.address, datagram.port);
          }
        }
      });

      // Immediate heartbeat + periodic
      _sendHeartbeat();
      _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) => _sendHeartbeat());

      _isHosting = true;
    } catch (e) {
      print('[DiscoveryService] Failed to start host UDP: $e');
      await stopHost();
    }
  }

  void _sendReply(InternetAddress address, int port) {
    if (_hostSocket == null) return;
    final reply = jsonEncode({'name': _hostName, 'port': _hostServerPort});
    try {
      _hostSocket!.send(reply.codeUnits, address, port);
    } catch (_) {}
  }

  void _sendHeartbeat() {
    if (_hostSocket == null) return;
    final heartbeat = jsonEncode({
      'type': magicHeartbeat,
      'name': _hostName,
      'port': _hostServerPort,
    });
    try {
      _hostSocket!.send(
        heartbeat.codeUnits,
        InternetAddress(multicastAddress),
        discoveryPort,
      );
    } catch (_) {}
  }

  /// Stop advertising. Sends a multicast goodbye so clients remove us instantly.
  Future<void> stopHost() async {
    if (!_isHosting) return;

    if (_hostSocket != null) {
      try {
        final goodbye = jsonEncode({
          'type': magicGoodbye,
          'port': _hostServerPort,
        });
        _hostSocket!.send(
          goodbye.codeUnits,
          InternetAddress(multicastAddress),
          discoveryPort,
        );
      } catch (_) {}
    }

    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _hostSubscription?.cancel();
    _hostSubscription = null;

    if (_hostSocket != null) {
      try {
        _hostSocket!.leaveMulticast(InternetAddress(multicastAddress));
      } catch (_) {}
      _hostSocket?.close();
      _hostSocket = null;
    }
    _isHosting = false;
  }

  /// Start continuous background discovery.
  /// Listens on the shared discovery port so it catches heartbeats, replies,
  /// and goodbyes in real time. Sends a query burst every 3 seconds.
  Future<void> startDiscovery() async {
    if (_isDiscovering) return;
    _isDiscovering = true;

    if (kIsWeb) return;

    try {
      _scanSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
        reuseAddress: true,
        reusePort: true,
      );
      _scanSocket!.broadcastEnabled = true;
      _scanSocket!.joinMulticast(InternetAddress(multicastAddress));

      _scanSubscription = _scanSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _scanSocket!.receive();
          if (datagram == null) return;
          _handleDiscoveryDatagram(datagram);
        }
      });

      // Immediate query + periodic re-query
      _sendDiscoveryQuery();
      _queryTimer = Timer.periodic(queryInterval, (_) => _sendDiscoveryQuery());

      // Remove crashed / silent hosts
      _cleanupTimer = Timer.periodic(cleanupInterval, (_) => _removeStaleDevices());
    } catch (e) {
      print('[DiscoveryService] Discovery start error: $e');
      _isDiscovering = false;
    }
  }

  /// Triggers an extra discovery query immediately (for manual refresh).
  void sendImmediateQuery() => _sendDiscoveryQuery();

  void _sendDiscoveryQuery() {
    if (_scanSocket == null) return;
    try {
      _scanSocket!.send(
        utf8.encode(magicQuery),
        InternetAddress(multicastAddress),
        discoveryPort,
      );
    } catch (_) {}
  }

  void _handleDiscoveryDatagram(Datagram datagram) {
    try {
      final data = jsonDecode(String.fromCharCodes(datagram.data));
      final ip = datagram.address.address;
      if (data is! Map) return;

      final type = data['type'] as String?;

      // Goodbye → remove immediately
      if (type == magicGoodbye) {
        final port = (data['port'] as num?)?.toInt() ?? 9876;
        _removeDevice(ip, port);
        return;
      }

      // Heartbeat or unicast reply
      final String name;
      final int port;
      if (type == magicHeartbeat) {
        name = data['name'] as String? ?? 'Unknown';
        port = (data['port'] as num?)?.toInt() ?? 9876;
      } else {
        // Legacy unicast response (no type field)
        name = data['name'] as String? ?? 'Unknown';
        port = (data['port'] as num?)?.toInt() ?? 9876;
      }

      _updateOrAddDevice(name, ip, port);
    } catch (_) {
      // Malformed packet — ignore
    }
  }

  void _updateOrAddDevice(String name, String ip, int port) {
    _discoveredDevices.removeWhere((d) => d.ip == ip && d.port == port);
    _discoveredDevices.add(DiscoveredDevice(
      name: name,
      ip: ip,
      port: port,
      lastSeen: DateTime.now(),
    ));
    _devicesController.add(List<DiscoveredDevice>.from(_discoveredDevices));
  }

  void _removeDevice(String ip, int port) {
    final before = _discoveredDevices.length;
    _discoveredDevices.removeWhere((d) => d.ip == ip && d.port == port);
    if (_discoveredDevices.length != before) {
      _devicesController.add(List<DiscoveredDevice>.from(_discoveredDevices));
    }
  }

  void _removeStaleDevices() {
    final now = DateTime.now();
    final before = _discoveredDevices.length;
    _discoveredDevices.removeWhere(
      (d) => now.difference(d.lastSeen) > staleTimeout,
    );
    if (_discoveredDevices.length != before) {
      _devicesController.add(List<DiscoveredDevice>.from(_discoveredDevices));
    }
  }

  /// Stops the background listener. Discovered results are kept.
  Future<void> stopDiscovery() async {
    _isDiscovering = false;
    _queryTimer?.cancel();
    _queryTimer = null;
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    _scanSocket?.close();
    _scanSocket = null;
  }

  void clearResults() {
    _discoveredDevices.clear();
    _devicesController.add([]);
  }

  void dispose() {
    stopHost();
    stopDiscovery();
    _devicesController.close();
  }
}