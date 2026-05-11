import 'dart:io';
import 'package:flutter/foundation.dart';

class NetworkService {
  /// Returns the local IPv4 address of the device.
  static Future<String> getLocalIp() async {
    if (kIsWeb) return 'Web-Client';
    
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      print('[NetworkService] Error looking up IP: $e');
    }
    return '127.0.0.1';
  }
}
