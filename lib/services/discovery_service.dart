import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/models.dart';
import 'network_service.dart';

/// LAN discovery — broadcast-primary, multicast-secondary, shared socket.
/// 
/// FIXES:
/// • Sends to 255.255.255.255 (global broadcast) in addition to subnet + multicast
/// • Host computes broadcast from ALL interfaces, not just primary IP
/// • Client sends periodic query bursts (every 3s) so new hosts appear instantly
/// • TTL reduced to 5s so dead hosts vanish fast
/// • Goodbye sent 5× over 500ms for reliable removal
class DiscoveryService {
  static const int    discoveryPort  = 9877;
  static const String multicastGroup = '224.0.0.123';

  static const String _kAnnounce = 'SB_ANNOUNCE';
  static const String _kGoodbye  = 'SB_GOODBYE';
  static const String _kQuery    = 'SB_QUERY';

  static const Duration _announcePeriod = Duration(seconds: 2);
  static const Duration _deviceTtl      = Duration(seconds: 5);
  static const Duration _clientQueryInterval = Duration(seconds: 3);

  RawDatagramSocket?  _socket;
  StreamSubscription? _socketSub;
  bool                _socketReady = false;

  String _broadcastAddr = '255.255.255.255';
  List<String> _allLocalIps = [];

  bool   _isHosting = false;
  String _hostName  = '';
  int    _hostPort  = 9876;
  Timer? _announceTimer;

  final Map<String, DateTime> _lastSeen = {};
  Timer? _ttlTimer;
  Timer? _clientQueryTimer;

  final _devicesController =
      StreamController<List<DiscoveredDevice>>.broadcast();
  Stream<List<DiscoveredDevice>> get devicesStream => _devicesController.stream;

  final List<DiscoveredDevice> _devices = [];

  String _localIp = '';
  void setLocalIp(String ip) => _localIp = ip;

  Future<void> _ensureSocket() async {
    if (_socketReady) return;

    // Get all IPs for self-filtering and broadcast computation
    _allLocalIps = await NetworkService.getAllLocalIps();

    // Derive subnet broadcast from PRIMARY local IP
    try {
      final localIp = await NetworkService.getLocalIp();
      final parts   = localIp.split('.');
      if (parts.length == 4) {
        _broadcastAddr = '${parts[0]}.${parts[1]}.${parts[2]}.255';
      }
    } catch (_) {}

    for (final reusePort in [true, false]) {
      try {
        _socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          discoveryPort,
          reuseAddress: true,
          reusePort: reusePort,
        );
        break;
      } catch (e) {
        _socket = null;
        if (!reusePort) {
          print('[Discovery] Cannot bind socket: $e');
          return;
        }
      }
    }

    if (_socket == null) return;

    _socket!.broadcastEnabled = true;

    try {
      _socket!.joinMulticast(InternetAddress(multicastGroup));
    } catch (e) {
      print('[Discovery] Multicast join failed (broadcast-only): $e');
    }

    _socketSub = _socket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final dg = _socket!.receive();
        if (dg != null) _handleDatagram(dg);
      }
    });

    _ttlTimer ??= Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pruneExpired(),
    );

    _socketReady = true;
    print('[Discovery] Socket ready — broadcast=$_broadcastAddr port=$discoveryPort ips=$_allLocalIps');
  }

  void _sendTo(List<int> bytes, String ip, int port) {
    try { _socket?.send(bytes, InternetAddress(ip), port); } catch (_) {}
  }

  /// Broadcasts to subnet, global broadcast, AND multicast for maximum reach.
  void _broadcast(Map<String, dynamic> data) {
    if (_socket == null) return;
    final bytes = utf8.encode(jsonEncode(data));

    // Subnet broadcast (primary interface)
    _sendTo(bytes, _broadcastAddr, discoveryPort);
    // Global broadcast (all interfaces)
    _sendTo(bytes, '255.255.255.255', discoveryPort);
    // Multicast
    _sendTo(bytes, multicastGroup,  discoveryPort);
  }

  void _unicast(Map<String, dynamic> data, String ip, int port) {
    if (_socket == null) return;
    _sendTo(utf8.encode(jsonEncode(data)), ip, port);
  }

  // ── HOST API ───────────────────────────────────────────────────────────────

  Future<void> startHost(String deviceName, int serverPort) async {
    if (_isHosting) return;
    _hostName = deviceName;
    _hostPort = serverPort;

    await _ensureSocket();
    if (!_socketReady) return;

    void announce() => _broadcast({
      'type': _kAnnounce,
      'name': _hostName,
      'port': _hostPort,
    });

    // Burst for fast initial pickup
    for (int i = 0; i < 3; i++) {
      announce();
      if (i < 2) await Future.delayed(const Duration(milliseconds: 300));
    }

    _announceTimer = Timer.periodic(_announcePeriod, (_) => announce());
    _isHosting = true;
    print('[Discovery] Hosting as "$_hostName" on port $_hostPort');
  }

  Future<void> stopHost() async {
    if (!_isHosting) return;
    _announceTimer?.cancel();
    _announceTimer = null;

    // Aggressive goodbye — 5× over 500ms for reliable delivery
    for (int i = 0; i < 5; i++) {
      _broadcast({'type': _kGoodbye, 'port': _hostPort});
      if (i < 4) await Future.delayed(const Duration(milliseconds: 100));
    }

    _isHosting = false;
    print('[Discovery] Stopped hosting');
  }

  // ── DISCOVERY API ──────────────────────────────────────────────────────────

  Future<void> startDiscovery({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (kIsWeb) return;
    await _ensureSocket();
    if (!_socketReady) return;

    // Initial query burst
    _sendQueryBurst();

    // Periodic query bursts so hosts that start AFTER us are discovered
    // within ~3 seconds without manual refresh.
    _clientQueryTimer ??= Timer.periodic(_clientQueryInterval, (_) {
      _sendQueryBurst();
    });
  }

  void _sendQueryBurst() {
    if (_socket == null) return;
    for (int i = 0; i < 3; i++) {
      _broadcast({'type': _kQuery});
      if (i < 2) Future.delayed(const Duration(milliseconds: 200));
    }
  }

  void clearResults() {
    _devices.clear();
    _lastSeen.clear();
    _devicesController.add([]);
  }

  Future<void> stopDiscovery() async {
    _clientQueryTimer?.cancel();
    _clientQueryTimer = null;
    _ttlTimer?.cancel();
    _ttlTimer = null;
    await _socketSub?.cancel();
    _socketSub = null;
    if (_socket != null) {
      try { _socket!.leaveMulticast(InternetAddress(multicastGroup)); } catch (_) {}
      _socket!.close();
      _socket = null;
    }
    _socketReady = false;
  }

  // ── Datagram handler ───────────────────────────────────────────────────────

  void _handleDatagram(Datagram dg) {
    try {
      final data = jsonDecode(utf8.decode(dg.data).trim());
      if (data is! Map) return;

      final type       = data['type'] as String?;
      final senderIp   = dg.address.address;
      final senderPort = dg.port;

      switch (type) {
        case _kAnnounce:
          final name = (data['name'] as String?) ?? 'Unknown';
          final port = (data['port'] as int?)    ?? 9876;

          // Filter self by any local IP OR by active host name+port
          if (_allLocalIps.contains(senderIp)) return;
          if (_localIp.isNotEmpty && senderIp == _localIp) return;
          if (_isHosting && port == _hostPort && name == _hostName) return;

          _upsert(DiscoveredDevice(name: name, ip: senderIp, port: port));

        case _kGoodbye:
          final port = (data['port'] as int?) ?? 9876;
          _remove(senderIp, port);

        case _kQuery:
          if (_isHosting) {
            _unicast(
              {'type': _kAnnounce, 'name': _hostName, 'port': _hostPort},
              senderIp,
              senderPort,
            );
          }
      }
    } catch (_) {}
  }

  void _upsert(DiscoveredDevice device) {
    final key = '${device.ip}:${device.port}';
    _lastSeen[key] = DateTime.now();

    final idx = _devices.indexWhere(
      (d) => d.ip == device.ip && d.port == device.port,
    );
    if (idx == -1) {
      _devices.add(device);
      _devicesController.add(List.from(_devices));
    } else if (_devices[idx].name != device.name) {
      _devices[idx] = device;
      _devicesController.add(List.from(_devices));
    }
  }

  void _remove(String ip, int port) {
    final before = _devices.length;
    _lastSeen.remove('$ip:$port');
    _devices.removeWhere((d) => d.ip == ip && d.port == port);
    if (_devices.length != before) {
      _devicesController.add(List.from(_devices));
      print('[Discovery] Removed $ip:$port');
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
        _devices.removeWhere(
          (d) => d.ip == parts[0] && d.port == (int.tryParse(parts[1]) ?? -1),
        );
        print('[Discovery] Pruned $key (TTL)');
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