import 'dart:io' as io;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:shelf_router/shelf_router.dart';

import '../services/discovery_service.dart';
import '../services/host_service.dart';
import '../services/client_service.dart';
import '../services/file_transfer_service.dart';
import '../services/network_service.dart';
import 'models.dart';

class AppState extends ChangeNotifier {
  final DiscoveryService _discoveryService = DiscoveryService();
  final HostService _hostService = HostService();
  final ClientService _clientService = ClientService();
  final FileTransferService _fileTransferService = FileTransferService();
  final Uuid _uuid = const Uuid();

  String _deviceName = '';
  int hostPort = 9876;
  bool isScanning = false;

  set setHostPort(int port) {
    if (port > 0 && port <= 65535) {
      hostPort = port;
      notifyListeners();
    }
  }

  bool isHosting = false;
  bool isConnectedToHost = false;
  bool isBusy = false;

  String localIp = '127.0.0.1';
  String connectionStatus = '';
  Timer? _statusTimer;
  List<DiscoveredDevice> discoveredHosts = [];
  List<SharePayload> history = [];
  Map<String, double> downloadsProgress = {};
  List<String> participants = [];       // includes host + clients, with "(You)" markers

  String get deviceName => _deviceName.isEmpty
      ? (kIsWeb ? 'Web User' : io.Platform.localHostname)
      : _deviceName;

  set deviceName(String name) {
    _deviceName = name.trim();
    notifyListeners();
  }

  AppState() {
    _initNetwork();
    
    // Discovery
    _discoveryService.devicesStream.listen((devices) {
      discoveredHosts = devices;
      notifyListeners();
    });

    // Hosting Streams
    _hostService.payloadStream.listen(_handleIncomingPayload);
    _hostService.clientListStream.listen(_handleClientListUpdate);
    _hostService.statusStream.listen((status) => _setStatus(status));

    // Client Streams
    _clientService.payloadStream.listen(_handleIncomingPayload);
    _clientService.clientListStream.listen(_handleClientListUpdate);
    _clientService.statusStream.listen((status) => _setStatus(status));

    // When the host drops the connection, reset the client state
    _clientService.disconnectedStream.listen((_) {
      isConnectedToHost = false;
      participants.clear();
      discoveredHosts.clear();
      _discoveryService.clearResults();
      _setStatus('The host has stopped the server. You have been disconnected.');
    });

    // Progress
    _fileTransferService.progressStream.listen((progressMap) {
      downloadsProgress.addAll(progressMap);
      notifyListeners();
    });
  }

  /// Sets a status message. Transient messages auto-clear after 3 seconds.
  /// Persistent statuses (server running, connected) stay until manually cleared.
  void _setStatus(String status, {bool persistent = false}) {
    _statusTimer?.cancel();
    connectionStatus = status;
    notifyListeners();

    if (!persistent && status.isNotEmpty) {
      _statusTimer = Timer(const Duration(seconds: 3), () {
        connectionStatus = '';
        notifyListeners();
      });
    }
  }

  /// Called by the UI close button to dismiss the status banner.
  void clearStatus() {
    _statusTimer?.cancel();
    connectionStatus = '';
    notifyListeners();
  }

  void _handleIncomingPayload(SharePayload payload) {
    if (!history.any((item) => item.id == payload.id)) {
      history.add(payload);
      notifyListeners();
    }
  }

  void _handleClientListUpdate(List<String> rawList) {
    final myName = deviceName;
    participants = rawList.map((name) {
      // Check if this entry is us as host
      if (name == '$myName (Host)') {
        return '$myName (Host, You)';
      }
      // Check if this entry is us as client
      if (name == myName) {
        return '$myName (You)';
      }
      return name;
    }).toList();
    notifyListeners();
  }

  Future<void> _initNetwork() async {
    localIp = await NetworkService.getLocalIp();
    notifyListeners();
  }

  Future<void> startHosting() async {
    if (isBusy || isHosting) return;
    isBusy = true;
    notifyListeners();

    if (kIsWeb) {
      _setStatus('Hosting not supported on Web.');
      isBusy = false;
      return;
    }

    try {
      _setStatus('Starting server on port $hostPort...', persistent: true);

      final router = Router();
      _fileTransferService.setupRoutes(router);
      await _hostService.startServer(hostPort, deviceName, router);

      try {
        await _discoveryService.startHost(deviceName, hostPort);
      } catch (e) {
        print('[AppState] mDNS advertising failed: $e');
      }

      isHosting = true;
      _setStatus('Server running on $localIp:$hostPort', persistent: true);
    } on io.SocketException catch (e) {
      if (e.osError?.errorCode == 98 || e.message.contains('Address already in use')) {
        _setStatus('Port $hostPort is already in use. Please choose a different port.');
      } else {
        _setStatus('Could not start server: ${e.message}');
      }
      isHosting = false;
    } catch (e) {
      _setStatus('Could not start server: $e');
      isHosting = false;
    }

    isBusy = false;
    notifyListeners();
  }

  Future<void> stopHosting() async {
    if (isBusy) return;
    isBusy = true;
    notifyListeners();

    if (!kIsWeb) {
      // Each step is wrapped individually so one failure doesn't skip the rest.
      try { await _discoveryService.stopHost(); } catch (_) {}
      try { await _discoveryService.stopDiscovery(); } catch (_) {}
      try { _discoveryService.clearResults(); } catch (_) {}
      try { await _hostService.stopServer(); } catch (_) {}
      try { _fileTransferService.clearHostedFiles(); } catch (_) {}
    }

    discoveredHosts.clear();
    isHosting = false;
    connectionStatus = '';
    isBusy = false;
    notifyListeners();
  }

  Future<void> toggleHosting(bool enable) async {
    if (enable) {
      await startHosting();
    } else {
      await stopHosting();
    }
  }

  Future<void> refreshDiscovery() async {
    if (kIsWeb || isScanning) return;
    isScanning = true;
    notifyListeners();
    try {
      await _discoveryService.startDiscovery(timeout: const Duration(seconds: 10));
    } catch (e) {
      print('Discovery error: $e');
    }
    isScanning = false;
    notifyListeners();
  }

  Future<void> connectTo(String ip, int port) async {
    if (isBusy) return;
    isBusy = true;
    _setStatus('Connecting to $ip:$port...', persistent: true);

    try {
      final success = await _clientService.connect(ip, port);
      isConnectedToHost = success;
      if (success) {
        _clientService.sendHandshake(deviceName);
        _setStatus('Connected to $ip:$port', persistent: true);
      } else {
        _setStatus('The host at $ip:$port is not available. It may have been stopped or is unreachable.');
        // Remove the stale entry from discovered list
        discoveredHosts.removeWhere((d) => d.ip == ip && d.port == port);
      }
    } on io.SocketException catch (_) {
      _setStatus('The host at $ip:$port is not available. It may have been stopped or is unreachable.');
      discoveredHosts.removeWhere((d) => d.ip == ip && d.port == port);
    } catch (_) {
      _setStatus('Could not connect. Please check the address and try again.');
    }

    isBusy = false;
    notifyListeners();
  }

  Future<void> disconnectFromHost() async {
    if (!kIsWeb) {
      _clientService.disconnect();
    }
    isConnectedToHost = false;
    connectionStatus = '';
    notifyListeners();
  }

  Future<void> shareText(String text) async {
    if (text.isEmpty) return;

    final payload = SharePayload(
      id: _uuid.v4(),
      type: FileTransferType.text,
      fileName: 'Text Message',
      size: text.length,
      data: text,
      senderName: deviceName,
    );

    history.add(payload);
    notifyListeners();

    if (isHosting) {
      _hostService.sendPayload(payload);
    } else if (isConnectedToHost) {
      _clientService.sendPayload(payload);
    }
  }

  Future<void> shareFile(io.File file) async {
    if (kIsWeb) {
      _setStatus('File sharing not supported on Web Client');
      return;
    }

    final stat = await file.stat();
    final payload = SharePayload(
      id: _uuid.v4(),
      type: FileTransferType.file,
      fileName: file.path.split(io.Platform.pathSeparator).last,
      size: stat.size,
      senderName: deviceName,
    );

    history.add(payload);
    notifyListeners();

    _fileTransferService.hostFile(payload.id, file);

    if (isHosting) {
      _hostService.sendPayload(payload);
    } else if (isConnectedToHost) {
      _clientService.sendPayload(payload);
    }
  }

  Future<void> downloadLargeFile(
      String ip, int port, String id, String fileName) async {
    if (kIsWeb) {
      _setStatus('File download not supported on Web Client');
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final downloadedFile = await _fileTransferService.downloadFile(
      ip: ip,
      port: port,
      id: id,
      fileName: fileName,
      saveDirectory: dir.path,
    );
    
    if (downloadedFile != null) {
      _setStatus('File downloaded: ${downloadedFile.path}');
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _discoveryService.dispose();
    _hostService.dispose();
    _clientService.dispose();
    _fileTransferService.dispose();
    super.dispose();
  }
}