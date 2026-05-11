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

  RawDatagramSocket? _hostSocket;     // for responding as host
  RawDatagramSocket? _scanSocket;     // for scanning as client
  StreamSubscription? _hostSubscription;
  StreamSubscription? _scanSubscription;
  Timer? _scanTimer;
  Timer? _queryTimer;

  final _devicesController =
      StreamController<List<DiscoveredDevice>>.broadcast();
  Stream<List<DiscoveredDevice>> get devicesStream =>
      _devicesController.stream;

  final List<DiscoveredDevice> _discoveredDevices = [];

  bool _isHosting = false;
  String _hostName = '';
  int _hostServerPort = 9876;

  /// Start hosting – open a UDP socket, join multicast group, and listen for queries.
  Future<void> startHost(String deviceName, int serverPort) async {
    if (_isHosting) return;
    _hostName = deviceName;
    _hostServerPort = serverPort;

    try {
      _hostSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
      );
      _hostSocket!.joinMulticast(InternetAddress(multicastAddress));
      _hostSubscription = _hostSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _hostSocket!.receive();
          if (datagram == null) return;
          final message = String.fromCharCodes(datagram.data).trim();
          if (message == magicQuery) {
            final reply = jsonEncode({
              'name': _hostName,
              'port': _hostServerPort,
            });
            _hostSocket!.send(
              reply.codeUnits,
              datagram.address,
              datagram.port,
            );
          }
        }
      });
      _isHosting = true;
    } catch (e) {
      print('[DiscoveryService] Failed to start host UDP: $e');
      await stopHost();
    }
  }

  /// Stop hosting.
  Future<void> stopHost() async {
    if (!_isHosting) return;

    // Broadcast goodbye so clients can remove us instantly
    if (_hostSocket != null) {
      try {
        final goodbye = jsonEncode({
          'type': magicGoodbye,
          'ip': InternetAddress.anyIPv4.address, // Placeholder, client uses sender IP
          'port': _hostServerPort,
        });
        _hostSocket!.send(
          goodbye.codeUnits,
          InternetAddress(multicastAddress),
          discoveryPort,
        );
      } catch (_) {}
    }

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

  /// Clears discovered devices list (e.g. when the user stops hosting).
  void clearResults() {
    _discoveredDevices.clear();
    _devicesController.add([]);
  }

  /// Scan for hosts by sending a multicast query and listening for replies.
  /// Sends queries every 2 seconds so hosts that start mid-scan are found.
  Future<void> startDiscovery({Duration timeout = const Duration(seconds: 10)}) async {
    await stopDiscovery();

    if (kIsWeb) return;

    // Clear previous results at the START of a new scan
    _discoveredDevices.clear();
    _devicesController.add([]);

    try {
      _scanSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0, // OS picks free port
      );
      _scanSocket!.broadcastEnabled = true;

      final completer = Completer<void>();
      _scanTimer = Timer(timeout, () {
        completer.complete();
      });

      _scanSubscription = _scanSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _scanSocket!.receive();
          if (datagram == null) return;
          try {
            final data = jsonDecode(String.fromCharCodes(datagram.data));
            final ip = datagram.address.address;

            // Handle Goodbye
            if (data is Map && data['type'] == magicGoodbye) {
              final port = data['port'] as int? ?? 9876;
              _discoveredDevices.removeWhere((d) => d.ip == ip && d.port == port);
              _devicesController.add(List<DiscoveredDevice>.from(_discoveredDevices));
              return;
            }

            // Handle Discovery Response
            final name = data['name'] as String? ?? 'Unknown';
            final port = data['port'] as int? ?? 9876;

            _discoveredDevices.removeWhere(
              (d) => d.ip == ip && d.port == port,
            );
            _discoveredDevices.add(DiscoveredDevice(name: name, ip: ip, port: port));
            _devicesController.add(List<DiscoveredDevice>.from(_discoveredDevices));
          } catch (_) {}
        }
      });

      // Send query immediately, then repeat every 2 seconds
      final queryBytes = utf8.encode(magicQuery);
      void sendQuery() {
        _scanSocket?.send(
          queryBytes,
          InternetAddress(multicastAddress),
          discoveryPort,
        );
      }

      sendQuery();
      _queryTimer = Timer.periodic(const Duration(seconds: 2), (_) => sendQuery());

      await completer.future;
    } catch (e) {
      print('[DiscoveryService] Scan error: $e');
    } finally {
      await stopDiscovery();
    }
  }

  /// Stops the scan but keeps discovered results visible.
  Future<void> stopDiscovery() async {
    _scanTimer?.cancel();
    _scanTimer = null;
    _queryTimer?.cancel();
    _queryTimer = null;
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    _scanSocket?.close();
    _scanSocket = null;
    // Results are intentionally kept — cleared at the start of the next scan.
  }

  void dispose() {
    stopHost();
    stopDiscovery();
    _devicesController.close();
  }
}