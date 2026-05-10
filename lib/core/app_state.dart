import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../services/discovery_service.dart';
import '../services/transfer_service.dart';
import 'models.dart';

class AppState extends ChangeNotifier {
  final DiscoveryService _discoveryService = DiscoveryService();
  final TransferService _transferService = TransferService();

  bool isHosting = false;
  bool isConnectedToHost = false;
  String localIp = '127.0.0.1';
  String connectionStatus = '';
  List<DiscoveredDevice> connectedDevices = [];
  List<SharePayload> history = [];
  Map<String, double> downloadsProgress = {};

  static const int serverPort = 8080;

  AppState() {
    _initNetwork();
    _discoveryService.devicesStream.listen((devices) {
      connectedDevices = devices;
      notifyListeners();
    });
    
    _transferService.payloadStream.listen((payload) {
      history.insert(0, payload);
      notifyListeners();
    });

    _transferService.progressStream.listen((progressMap) {
      downloadsProgress.addAll(progressMap);
      notifyListeners();
    });

    _transferService.connectionStatusStream.listen((status) {
      connectionStatus = status;
      notifyListeners();
    });
  }

  Future<void> _initNetwork() async {
    if (kIsWeb) {
      localIp = 'Web-Client';
      notifyListeners();
      return;
    }
    try {
      final interfaces = await io.NetworkInterface.list(
        type: io.InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback) {
            localIp = addr.address;
            notifyListeners();
            return; // Use the first non-loopback IPv4
          }
        }
      }
    } catch (e) {
      print('Network lookup error: $e');
    }
  }

  Future<void> toggleHosting(bool enable) async {
    if (enable) {
      if (kIsWeb) {
        connectionStatus = 'Failed: Hosting is not supported on Web Browsers. Please compile & run as a Native App (Linux/Windows/macOS or Mobile).';
        isHosting = false;
        notifyListeners();
        return;
      }
      try {
        await _transferService.startServer(serverPort);
        await _discoveryService.startHost('ShareBeam Host', serverPort);
        await _discoveryService.startDiscovery();
        isHosting = true;
        connectionStatus = 'Server running on $localIp:$serverPort';
      } catch (e) {
        connectionStatus = 'Failed to start server: $e';
        isHosting = false;
      }
    } else {
      if (!kIsWeb) {
         await _discoveryService.stopHost();
         await _discoveryService.stopDiscovery();
         await _transferService.stopServer();
      }
      connectedDevices.clear();
      isHosting = false;
      connectionStatus = '';
    }
    notifyListeners();
  }

  Future<void> connectTo(String ip, int port) async {
    connectionStatus = 'Connecting to $ip:$port...';
    notifyListeners();

    final success = await _transferService.connectToHost(ip, port);
    isConnectedToHost = success;
    if (success) {
      connectionStatus = 'Connected to $ip:$port';
    } else {
      connectionStatus = 'Failed to connect to $ip:$port';
    }
    notifyListeners();
  }

  Future<void> disconnectFromHost() async {
    if (!kIsWeb) {
       _transferService.disconnectFromHost();
    }
    isConnectedToHost = false;
    connectionStatus = '';
    notifyListeners();
  }

  Future<void> shareText(String text) async {
    if (text.isEmpty) return;
    
    final senderName = kIsWeb ? 'Web User' : io.Platform.localHostname;
    
    final payload = SharePayload(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: FileTransferType.text,
      fileName: 'Text Message',
      size: text.length,
      data: text,
      senderName: senderName,
    );
    history.insert(0, payload);
    notifyListeners();
    await _transferService.sendPayload(payload);
  }

  Future<void> shareFile(io.File file) async {
     if (kIsWeb) {
        connectionStatus = 'File sharing natively unsupported on Web Client';
        notifyListeners();
        return;
     }
     final stat = await file.stat();
     
     final payload = SharePayload(
       id: DateTime.now().millisecondsSinceEpoch.toString(),
       type: FileTransferType.file,
       fileName: file.path.split(io.Platform.pathSeparator).last,
       size: stat.size,
       senderName: io.Platform.localHostname,
     );
     
     history.insert(0, payload);
     notifyListeners();
     await _transferService.sendPayload(payload, fileToHost: file);
  }

  Future<void> downloadLargeFile(String ip, int port, String id, String fileName) async {
    if (kIsWeb) {
        connectionStatus = 'File downloading natively unsupported on Web Client';
        notifyListeners();
        return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final downloadedFile = await _transferService.downloadFile(ip, port, id, fileName, dir.path);
    if (downloadedFile != null) {
       print('File downloaded to ${downloadedFile.path}');
       connectionStatus = 'File downloaded to ${downloadedFile.path}';
       notifyListeners();
    }
  }
}
