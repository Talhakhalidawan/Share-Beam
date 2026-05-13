import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../services/discovery_service.dart';
import '../services/host_service.dart';
import '../services/client_service.dart';
import '../services/file_transfer_service.dart';
import '../services/network_service.dart';
import 'models.dart';
import 'prefs.dart';

enum NotificationType { info, error, success }

class AppNotification {
  final String message;
  final NotificationType type;
  AppNotification(this.message, this.type);
}

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

  // ── Download tracking ────────────────────────────────────────────────────
  Map<String, String> downloadedFilePaths = {};

  // ── Auto-download settings (tweak these anytime) ─────────────────────────
  bool autoDownloadImages        = true;
  int  autoDownloadSizeThreshold = 1048576; // 1 MB

  final StreamController<AppNotification> _notificationController =
      StreamController<AppNotification>.broadcast();
  Stream<AppNotification> get notificationStream =>
      _notificationController.stream;

  String get deviceName => _deviceName;

  set deviceName(String name) {
    _deviceName = _trimName(name);
    Prefs.setDeviceName(_deviceName);
    notifyListeners();
  }

  static String _trimName(String name) {
    name = name.trim();
    if (name.length <= 15) return name;

    // Split into words
    List<String> words = name.split(' ');
    // Keep removing last word until it fits in 15 or only 1 word left
    while (words.length > 1 && words.join(' ').length > 15) {
      words.removeLast();
    }

    String result = words.join(' ');
    // If even the first word is > 15, hard trim it
    if (result.length > 15) {
      result = result.substring(0, 15).trim();
    }
    return result;
  }

  AppState() {
    _initNetwork();

    _discoveryService.devicesStream.listen((devices) {
      discoveredHosts = devices;
      if (!isHosting && !isConnectedToHost && !isBusy && devices.isNotEmpty) {
        _tryAutoConnect(devices);
      }
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
      _setStatus(
          'The host has stopped the server. You have been disconnected.');
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

    if (status.isNotEmpty) {
      final type = (status.toLowerCase().contains('error') ||
              status.toLowerCase().contains('failed') ||
              status.toLowerCase().contains('could not') ||
              status.toLowerCase().contains('already in use'))
          ? NotificationType.error
          : (status.toLowerCase().contains('connected') ||
                  status.toLowerCase().contains('running'))
              ? NotificationType.success
              : NotificationType.info;

      _notificationController.add(AppNotification(status, type));
    }

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

      if (payload.senderIp != null && payload.senderPort != null) {
        final shouldAuto = (payload.type == FileTransferType.image ||
                payload.type == FileTransferType.file) &&
            autoDownloadImages &&
            payload.size <= autoDownloadSizeThreshold;
        if (shouldAuto) _autoDownload(payload);
      }
    }
  }

  Future<void> _autoDownload(SharePayload payload) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = await _fileTransferService.downloadFile(
        ip: payload.senderIp!,
        port: payload.senderPort!,
        id: payload.id,
        fileName: payload.fileName,
        saveDirectory: dir.path,
      );
      if (file != null) {
        downloadedFilePaths[payload.id] = file.path;
        notifyListeners();
      }
    } catch (e) {
      print('[AppState] Auto-download failed: $e');
    }
  }

  Future<void> downloadPayload(SharePayload payload) async {
    if (payload.senderIp == null || payload.senderPort == null) {
      _setStatus('Cannot download: sender info missing');
      return;
    }
    await _autoDownload(payload);
  }

  void _handleClientListUpdate(List<String> rawList) {
    final myName = deviceName;
    participants = rawList.map((name) {
      if (name == '$myName (Host)') return '$myName (Host, You)';
      if (name == myName) return '$myName (You)';
      return name;
    }).toList();
    notifyListeners();
  }

  void _tryAutoConnect(List<DiscoveredDevice> devices) {
    final saved = Prefs.getAutoConnectHosts();
    if (saved.isEmpty) return;

    for (final device in devices) {
      for (final entry in saved) {
        if (device.ip == entry['ip'] && device.port == entry['port']) {
          if (device.ip == localIp && device.port == hostPort) continue;
          print('[AppState] Auto-connecting to ${device.name}');
          connectTo(device.ip, device.port);
          return;
        }
      }
    }
  }

  Future<void> _initNetwork() async {
    localIp = await NetworkService.getLocalIp();
    _discoveryService.setLocalIp(localIp);

    if (!kIsWeb) {
      _discoveryService.startDiscovery().catchError((e) {
        print('[AppState] Discovery start failed: $e');
      });
    }

    final savedName = Prefs.getDeviceName();
    if (savedName != null && savedName.isNotEmpty) {
      _deviceName = _trimName(savedName);
      notifyListeners();
    } else {
      _getDeviceModelName().then((model) {
        _deviceName = _trimName(model);
        Prefs.setDeviceName(_deviceName);
        notifyListeners();
      });
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
      try { await _discoveryService.stopHost(); } catch (_) {}
      try { await _hostService.stopServer(); } catch (_) {}
      try { _fileTransferService.clearHostedFiles(); } catch (_) {}
    }

    discoveredHosts.removeWhere((d) => d.ip == localIp && d.port == hostPort);
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
        connectedHostIp = ip;
        connectedHostPort = port;
        _setStatus('Connected to $ip:$port', persistent: true);
      } else {
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
    if (!kIsWeb) {
      _clientService.disconnect();
      if (!isHosting) {
        await _hostService.stopServer();
        _fileTransferService.clearHostedFiles();
      }
    }
    isConnectedToHost = false;
    connectedHostIp = null;
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

  Future<void> _ensureServerRunning() async {
    if (_hostService.isServerRunning) return;
    try {
      final router = Router();
      _fileTransferService.setupRoutes(router);
      // Even as a client, we start the host service server so we can serve files.
      // We don't start discovery though.
      await _hostService.startServer(hostPort, deviceName, router);
      print('[AppState] Background file server started on $hostPort');
    } catch (e) {
      print('[AppState] Could not start background file server: $e');
    }
  }

  Future<void> shareFile(io.File file) async {
    if (kIsWeb) {
      _setStatus('File sharing not supported on Web Client');
      return;
    }

    await _ensureServerRunning();

    final stat = await file.stat();
    final ext = file.path
        .split(io.Platform.pathSeparator)
        .last
        .toLowerCase()
        .split('.')
        .last;
    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic']
        .contains(ext);

    final payload = SharePayload(
      id: _uuid.v4(),
      type: isImage ? FileTransferType.image : FileTransferType.file,
      fileName: file.path.split(io.Platform.pathSeparator).last,
      size: stat.size,
      senderName: deviceName,
      senderIp: localIp,
      senderPort: hostPort,
    );

    history.add(payload);
    downloadedFilePaths[payload.id] = file.path;
    notifyListeners();

    _fileTransferService.hostFile(payload.id, file);

    if (isHosting) {
      _hostService.sendPayload(payload);
    } else if (isConnectedToHost) {
      _clientService.sendPayload(payload);
    }
  }

  Future<void> shareImageBytes(Uint8List bytes, String fileName) async {
    if (kIsWeb) {
      _setStatus('Image sharing not supported on Web Client');
      return;
    }
    final dir = await getTemporaryDirectory();
    final file = io.File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    await shareFile(file);
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
      downloadedFilePaths[id] = downloadedFile.path;
      _setStatus('Downloaded: ${downloadedFile.path}');
      notifyListeners();
    } else {
      _setStatus('Download failed. Is the host still online?');
    }
  }

  Future<String> _getDeviceModelName() async {
    if (kIsWeb) return 'Web User';

    final deviceInfo = DeviceInfoPlugin();
    try {
      if (io.Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (io.Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.name;
      } else if (io.Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        return linuxInfo.prettyName;
      } else if (io.Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        return macInfo.model;
      } else if (io.Platform.isWindows) {
        final winInfo = await deviceInfo.windowsInfo;
        return winInfo.computerName;
      }
    } catch (e) {
      print('[AppState] Failed to get device model: $e');
    }
    return io.Platform.localHostname;
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