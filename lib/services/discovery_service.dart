import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/models.dart';

/// Push-based LAN discovery.
///
/// HOST side:
///   • Broadcasts a JSON announce packet to the multicast group every [_announcePeriod].
///   • Sends a goodbye packet (3×) on stop so clients remove it immediately.
///
/// CLIENT side:
///   • Keeps ONE persistent UDP socket bound to [discoveryPort] that has
///     joined the multicast group — it therefore receives every announce/goodbye
///     the host emits, regardless of when the client opened the app.
///   • A TTL timer removes devices that haven't been heard from in [_deviceTtl],
///     which handles hard crashes / network drops gracefully.
class DiscoveryService {
  // ── Constants ──────────────────────────────────────────────────────────────
  static const int discoveryPort = 9877;
  static const String multicastAddress = '224.0.0.123';

  static const String _typeAnnounce = 'SB_ANNOUNCE';
  static const String _typeGoodbye  = 'SB_GOODBYE';

  static const Duration _announcePeriod = Duration(seconds: 2);
  static const Duration _deviceTtl      = Duration(seconds: 7); // ≥ 3 missed announces

  // ── Host-side state ────────────────────────────────────────────────────────
  RawDatagramSocket? _hostSocket;
  Timer?             _announceTimer;
  bool               _isHosting = false;
  String             _hostName  = '';
  int                _hostPort  = 9876;

  // ── Listener-side state ────────────────────────────────────────────────────
  RawDatagramSocket?  _listenerSocket;
  StreamSubscription? _listenerSub;
  bool                _isListening = false;
  Timer?              _ttlTimer;

  // "ip:port" → time of last announce
  final Map<String, DateTime> _lastSeen = {};

  // ── Public stream ──────────────────────────────────────────────────────────
  final _devicesController =
      StreamController<List<DiscoveredDevice>>.broadcast();
  Stream<List<DiscoveredDevice>> get devicesStream => _devicesController.stream;

  final List<DiscoveredDevice> _devices = [];

  // ────────────────────────────────────────────────────────────────────────────
  // HOST API
  // ────────────────────────────────────────────────────────────────────────────

  /// Opens a send-only UDP socket and begins broadcasting presence.
  Future<void> startHost(String deviceName, int serverPort) async {
    if (_isHosting) return;
    _hostName = deviceName;
    _hostPort = serverPort;

    try {
      // Ephemeral port — we only send, never receive on this socket.
      _hostSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

      void announce() {
        if (_hostSocket == null) return;
        final bytes = utf8.encode(jsonEncode({
          'type': _typeAnnounce,
          'name': _hostName,
          'port': _hostPort,
        }));
        try {
          _hostSocket!.send(bytes, InternetAddress(multicastAddress), discoveryPort);
        } catch (_) {}
      }

      announce(); // immediate
      _announceTimer = Timer.periodic(_announcePeriod, (_) => announce());
      _isHosting = true;
      print('[Discovery] Host broadcasting as "$_hostName" on port $_hostPort');
    } catch (e) {
      print('[Discovery] startHost failed: $e');
      await stopHost();
    }
  }

  /// Sends goodbye 3× and tears down the broadcast socket.
  Future<void> stopHost() async {
    _announceTimer?.cancel();
    _announceTimer = null;

    if (_hostSocket != null) {
      final bytes = utf8.encode(jsonEncode({
        'type': _typeGoodbye,
        'port': _hostPort,
      }));
      // Send 3 times to improve reliability over lossy Wi-Fi.
      for (int i = 0; i < 3; i++) {
        try {
          _hostSocket!.send(bytes, InternetAddress(multicastAddress), discoveryPort);
        } catch (_) {}
      }
      _hostSocket!.close();
      _hostSocket = null;
    }
    _isHosting = false;
    print('[Discovery] Host stopped broadcasting');
  }

  // ────────────────────────────────────────────────────────────────────────────
  // CLIENT / LISTENER API
  // ────────────────────────────────────────────────────────────────────────────

  /// Starts the persistent multicast listener (idempotent).
  ///
  /// [timeout] is accepted for API compatibility but ignored — the listener
  /// stays open until [stopDiscovery] or [dispose] is called.
  Future<void> startDiscovery({Duration timeout = const Duration(seconds: 10)}) async {
    if (kIsWeb || _isListening) return;

    try {
      _listenerSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
        reuseAddress: true,
        reusePort: true, // needed on some platforms to share the port with the host socket
      );
      _listenerSocket!.joinMulticast(InternetAddress(multicastAddress));

      _listenerSub = _listenerSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = _listenerSocket!.receive();
          if (dg != null) _handleDatagram(dg);
        }
      });

      // TTL cleanup: runs every 2 s, removes devices silent for >7 s.
      _ttlTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pruneExpired());

      _isListening = true;
      print('[Discovery] Listener active on port $discoveryPort (multicast $multicastAddress)');
    } catch (e) {
      print('[Discovery] startDiscovery failed: $e');
      _isListening = false;
    }
  }

  /// Stops the listener and TTL timer. Discovered results are kept.
  Future<void> stopDiscovery() async {
    _ttlTimer?.cancel();
    _ttlTimer = null;

    await _listenerSub?.cancel();
    _listenerSub = null;

    if (_listenerSocket != null) {
      try { _listenerSocket!.leaveMulticast(InternetAddress(multicastAddress)); } catch (_) {}
      _listenerSocket!.close();
      _listenerSocket = null;
    }
    _isListening = false;
  }

  /// Clears the discovered-device list and stream.
  void clearResults() {
    _devices.clear();
    _lastSeen.clear();
    _devicesController.add([]);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // INTERNAL
  // ────────────────────────────────────────────────────────────────────────────

  void _handleDatagram(Datagram dg) {
    try {
      final raw  = utf8.decode(dg.data).trim();
      final data = jsonDecode(raw);
      if (data is! Map) return;

      final type = data['type'] as String?;
      final ip   = dg.address.address;

      if (type == _typeGoodbye) {
        final port = data['port'] as int? ?? 9876;
        _remove(ip, port);
        return;
      }

      if (type == _typeAnnounce) {
        final name = (data['name'] as String?) ?? 'Unknown';
        final port = (data['port'] as int?) ?? 9876;
        _upsert(DiscoveredDevice(name: name, ip: ip, port: port));
        return;
      }
    } catch (_) {}
  }

  void _upsert(DiscoveredDevice device) {
    final key = '${device.ip}:${device.port}';
    _lastSeen[key] = DateTime.now();

    final idx = _devices.indexWhere((d) => d.ip == device.ip && d.port == device.port);
    if (idx == -1) {
      _devices.add(device);
      _devicesController.add(List.from(_devices));
    } else if (_devices[idx].name != device.name) {
      // Name changed (e.g. device renamed)
      _devices[idx] = device;
      _devicesController.add(List.from(_devices));
    }
    // Seen same device again — no change needed, just updated _lastSeen.
  }

  void _remove(String ip, int port) {
    final key = '$ip:$port';
    _lastSeen.remove(key);
    final before = _devices.length;
    _devices.removeWhere((d) => d.ip == ip && d.port == port);
    if (_devices.length != before) {
      _devicesController.add(List.from(_devices));
      print('[Discovery] Removed $ip:$port (goodbye)');
    }
  }

  void _pruneExpired() {
    final now     = DateTime.now();
    final expired = _lastSeen.entries
        .where((e) => now.difference(e.value) > _deviceTtl)
        .map((e) => e.key)
        .toList();

    if (expired.isEmpty) return;

    for (final key in expired) {
      _lastSeen.remove(key);
      final parts = key.split(':');
      if (parts.length == 2) {
        final ip   = parts[0];
        final port = int.tryParse(parts[1]) ?? 9876;
        _devices.removeWhere((d) => d.ip == ip && d.port == port);
        print('[Discovery] Pruned $ip:$port (TTL expired)');
      }
    }
    _devicesController.add(List.from(_devices));
  }

  void dispose() {
    stopHost();
    stopDiscovery();
    _devicesController.close();
  }
}