import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../services/discovery_service.dart';
import '../services/transfer_service.dart';
import 'models.dart';

class AppState extends ChangeNotifier {
  final DiscoveryService _discoveryService = DiscoveryService();
  final TransferService _transferService = TransferService();

  bool isHosting = false;
  String localIp = '127.0.0.1';
  List<DiscoveredDevice> connectedDevices = [];
  List<SharePayload> history = [];
  Map<String, double> downloadsProgress = {};

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
  }

  Future<void> _initNetwork() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLinkLocal: true);
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback && addr.address.startsWith('192.168')) {
             localIp = addr.address;
             notifyListeners();
          }
        }
      }
    } catch (e) {
      print('Network lookup error: $e');
    }
  }

  Future<void> toggleHosting(bool enable) async {
    isHosting = enable;
    if (enable) {
      const port = 8080; 
      await _transferService.startServer(localIp, port);
      await _discoveryService.startHost('ShareBeam Host', port);
      await _discoveryService.startDiscovery();
    } else {
      await _discoveryService.stopHost();
      await _discoveryService.stopDiscovery();
      await _transferService.stopServer();
      connectedDevices.clear();
    }
    notifyListeners();
  }

  Future<void> connectTo(String ip, int port) async {
    await _transferService.connectToHost(ip, port);
  }

  Future<void> disconnectFromHost() async {
    _transferService.disconnectFromHost();
  }

  Future<void> shareText(String text) async {
    if (text.isEmpty) return;
    
    final payload = SharePayload(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: FileTransferType.text,
      fileName: 'Text Message',
      size: text.length,
      data: text,
      senderName: Platform.localHostname,
    );
    history.insert(0, payload);
    notifyListeners();
    await _transferService.sendPayload(payload);
  }

  Future<void> shareFile(File file) async {
     final stat = await file.stat();
     
     final payload = SharePayload(
       id: DateTime.now().millisecondsSinceEpoch.toString(),
       type: FileTransferType.file,
       fileName: file.path.split(Platform.pathSeparator).last,
       size: stat.size,
       senderName: Platform.localHostname,
     );
     
     history.insert(0, payload);
     notifyListeners();
     await _transferService.sendPayload(payload, fileToHost: file);
  }

  Future<void> downloadLargeFile(String ip, int port, String id, String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final downloadedFile = await _transferService.downloadFile(ip, port, id, fileName, dir.path);
    if (downloadedFile != null) {
       print('File downloaded to ${downloadedFile.path}');
    }
  }
}
