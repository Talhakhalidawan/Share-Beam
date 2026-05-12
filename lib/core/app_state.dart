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
  final DiscoveryService    _discoveryService    = DiscoveryService();
  final HostService         _hostService         = HostService();
  final ClientService       _clientService       = ClientService();
  final FileTransferService _fileTransferService = FileTransferService();
  final Uuid _uuid = const Uuid();

  String _deviceName = '';
  int    hostPort    = 9876;

  bool isScanning = false;

  set setHostPort(int port) {
    if (port > 0 && port <= 65535) {
      hostPort = port;
      notifyListeners();
    }
  }

  bool isHosting         = false;
  bool isConnectedToHost = false;
  bool isBusy            = false;

  String  localIp         = '127.0.0.1';
  String? connectedHostIp;
  int     connectedHostPort = 9876;

  String connectionStatus = '';
  Timer? _statusTimer;

  List<DiscoveredDevice> discoveredHosts   = [];
  List<SharePayload>     history           = [];
  Map<String, double>    downloadsProgress = {};
  List<String>           participants      = [];

  String get deviceName => _deviceName.isEmpty
      ? (kIsWeb ? 'Web User' : io.Platform.localHostname)
      : _deviceName;

  set deviceName(String name) {
    _deviceName = name.trim();
    notifyListeners();
  }

  AppState() {
    _initNetwork();

    _discoveryService.devicesStream.listen((devices) {
      discoveredHosts = devices;
      notifyListeners();
    });

    _hostService.payloadStream.listen(_handleIncomingPayload);
    _hostService.clientListStream.listen(_handleClientListUpdate);
    _hostService.statusStream.listen(_setStatus);

    _clientService.payloadStream.listen(_handleIncomingPayload);
    _clientService.clientListStream.listen(_handleClientListUpdate);
    _clientService.statusStream.listen(_setStatus);

    _clientService.disconnectedStream.listen((_) {
      isConnectedToHost = false;
      connectedHostIp   = null;
      participants.clear();
      _setStatus('The host has stopped the server. You have been disconnected.');
      notifyListeners();
    });

    _fileTransferService.progressStream.listen((map) {
      downloadsProgress.addAll(map);
      notifyListeners();
    });
  }

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
      if (name == '$myName (Host)') return '$myName (Host, You)';
      if (name == myName)            return '$myName (You)';
      return name;
    }).toList();
    notifyListeners();
  }

  Future<void> _initNetwork() async {
    localIp = await NetworkService.getLocalIp();
    _discoveryService.setLocalIp(localIp);
    notifyListeners();

    if (!kIsWeb) {
      try {
        await _discoveryService.startDiscovery();
      } catch (e) {
        print('[AppState] Discovery start failed: $e');
      }
    }
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
        print('[AppState] Discovery broadcast failed: $e');
      }

      isHosting = true;
      _setStatus('Server running on $localIp:$hostPort', persistent: true);
    } on io.SocketException catch (e) {
      if (e.osError?.errorCode == 98 ||
          e.message.contains('Address already in use')) {
        _setStatus(
            'Port $hostPort is already in use. Please choose a different port.');
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
      try { await _discoveryService.stopHost(); }   catch (_) {}
      try { _discoveryService.clearResults(); }     catch (_) {}
      try { await _hostService.stopServer(); }      catch (_) {}
      try { _fileTransferService.clearHostedFiles(); } catch (_) {}
    }

    discoveredHosts  = [];
    isHosting        = false;
    connectionStatus = '';
    isBusy           = false;
    notifyListeners();
  }

  Future<void> toggleHosting(bool enable) =>
      enable ? startHosting() : stopHosting();

  Future<void> refreshDiscovery() async {
    if (kIsWeb || isScanning) return;
    isScanning = true;
    notifyListeners();

    try {
      await _discoveryService.startDiscovery();
    } catch (e) {
      print('[AppState] refreshDiscovery: $e');
    }

    await Future.delayed(const Duration(milliseconds: 700));
    isScanning = false;
    notifyListeners();
  }

  Future<void> connectTo(String ip, int port) async {
    if (isBusy) return;
    isBusy = true;
    _setStatus('Connecting to $ip:$port…', persistent: true);

    try {
      final success = await _clientService.connect(ip, port);
      isConnectedToHost = success;

      if (success) {
        _clientService.sendHandshake(deviceName);
        connectedHostIp   = ip;
        connectedHostPort = port;
        _setStatus('Connected to $ip:$port', persistent: true);
      } else {
        // CRITICAL: Do NOT remove from discovered list on failure.
        // The host may still be alive; TTL will remove it if it dies.
        _setStatus(
          'Could not reach $ip:$port after 3 attempts. '
          'Make sure both devices are on the same Wi-Fi network and the host '
          'app is in the foreground.',
        );
      }
    } on io.SocketException catch (_) {
      _setStatus(
        'Network error reaching $ip:$port. '
        'Check that both devices are on the same Wi-Fi and try again.',
      );
    } catch (_) {
      _setStatus('Could not connect. Please check the address and try again.');
    }

    isBusy = false;
    notifyListeners();
  }

  Future<void> disconnectFromHost() async {
    if (!kIsWeb) _clientService.disconnect();
    isConnectedToHost = false;
    connectedHostIp   = null;
    connectionStatus  = '';
    notifyListeners();
  }

  Future<void> shareText(String text) async {
    if (text.isEmpty) return;

    final payload = SharePayload(
      id:         _uuid.v4(),
      type:       FileTransferType.text,
      fileName:   'Text Message',
      size:       text.length,
      data:       text,
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
      id:         _uuid.v4(),
      type:       FileTransferType.file,
      fileName:   file.path.split(io.Platform.pathSeparator).last,
      size:       stat.size,
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
      ip:            ip,
      port:          port,
      id:            id,
      fileName:      fileName,
      saveDirectory: dir.path,
    );

    if (downloadedFile != null) {
      _setStatus('Downloaded: ${downloadedFile.path}');
    } else {
      _setStatus('Download failed. Is the host still online?');
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