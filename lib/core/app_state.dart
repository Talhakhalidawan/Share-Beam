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
    _hostService.statusStream.listen((status) {
      connectionStatus = status;
      notifyListeners();
    });

    // Client Streams
    _clientService.payloadStream.listen(_handleIncomingPayload);
    _clientService.clientListStream.listen(_handleClientListUpdate);
    _clientService.statusStream.listen((status) {
      connectionStatus = status;
      notifyListeners();
    });

    // Progress
    _fileTransferService.progressStream.listen((progressMap) {
      downloadsProgress.addAll(progressMap);
      notifyListeners();
    });
  }

  void _handleIncomingPayload(SharePayload payload) {
    if (!history.any((item) => item.id == payload.id)) {
      history.add(payload);
      notifyListeners();
    }
  }

  void _handleClientListUpdate(List<String> rawList) {
    participants = rawList.map((name) {
      if (name == '$_deviceName (Host)') {
        return '$deviceName (Host, You)';
      } else if (name == deviceName) {
        return '$deviceName (You)';
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
      connectionStatus = 'Hosting not supported on Web.';
      isBusy = false;
      notifyListeners();
      return;
    }

    try {
      connectionStatus = 'Starting server on port $hostPort...';
      notifyListeners();

      final router = Router();
      _fileTransferService.setupRoutes(router);
      await _hostService.startServer(hostPort, deviceName, router);

      try {
        await _discoveryService.startHost(deviceName, hostPort);
      } catch (e) {
        print('[AppState] mDNS advertising failed: $e');
      }

      isHosting = true;
      connectionStatus = 'Server running on $localIp:$hostPort';
    } catch (e) {
      connectionStatus = 'Failed to start server: $e';
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
      try {
        await _discoveryService.stopHost();
        await _discoveryService.stopDiscovery();
        await _hostService.stopServer();
        _fileTransferService.clearHostedFiles();
      } catch (e) {
        print('Error stopping server: $e');
      }
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
    connectionStatus = 'Connecting to $ip:$port...';
    notifyListeners();

    final success = await _clientService.connect(ip, port);
    isConnectedToHost = success;
    if (success) {
      _clientService.sendHandshake(deviceName);
      connectionStatus = 'Connected to $ip:$port';
    } else {
      connectionStatus = 'Failed to connect to $ip:$port';
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
      connectionStatus = 'File sharing not supported on Web Client';
      notifyListeners();
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
      connectionStatus = 'File download not supported on Web Client';
      notifyListeners();
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
      connectionStatus = 'File downloaded: ${downloadedFile.path}';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _discoveryService.dispose();
    _hostService.dispose();
    _clientService.dispose();
    _fileTransferService.dispose();
    super.dispose();
  }
}