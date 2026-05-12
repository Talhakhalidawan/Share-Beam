import 'dart:io';
import 'package:flutter/foundation.dart';

class NetworkService {
  /// Returns the best local IPv4 address.
  /// Prioritizes Wi-Fi / Ethernet over Docker, VPN, and virtual interfaces.
  static Future<String> getLocalIp() async {
    if (kIsWeb) return 'Web-Client';

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      final preferred = ['wlan', 'wlo', 'wl', 'wifi', 'eth', 'eno', 'en'];
      final blocked   = ['docker', 'vmnet', 'veth', 'tun', 'tap', 'tailscale',
                         'zerotier', 'br-', 'lo', 'virbr', 'ppp'];

      String? fallback;

      for (var interface in interfaces) {
        final name = interface.name.toLowerCase();

        // Skip virtual / VPN / loopback interfaces
        if (blocked.any((b) => name.startsWith(b) || name.contains(b))) continue;

        for (var addr in interface.addresses) {
          if (addr.isLoopback) continue;
          final ip = addr.address;
          if (ip.startsWith('169.254.')) continue; // APIPA

          // Return immediately for preferred interfaces (Wi-Fi, Ethernet)
          if (preferred.any((p) => name.startsWith(p))) {
            return ip;
          }

          fallback ??= ip;
        }
      }

      return fallback ?? '127.0.0.1';
    } catch (e) {
      print('[NetworkService] Error: $e');
      return '127.0.0.1';
    }
  }

  /// Returns ALL usable local IPv4 addresses (for multi-interface broadcast).
  static Future<List<String>> getAllLocalIps() async {
    if (kIsWeb) return ['Web-Client'];

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      final blocked = ['docker', 'vmnet', 'veth', 'tun', 'tap', 'tailscale',
                       'zerotier', 'br-', 'lo', 'virbr', 'ppp'];

      final ips = <String>[];

      for (var interface in interfaces) {
        final name = interface.name.toLowerCase();
        if (blocked.any((b) => name.startsWith(b) || name.contains(b))) continue;

        for (var addr in interface.addresses) {
          if (addr.isLoopback) continue;
          final ip = addr.address;
          if (ip.startsWith('169.254.')) continue;
          ips.add(ip);
        }
      }

      return ips.isNotEmpty ? ips : ['127.0.0.1'];
    } catch (e) {
      return ['127.0.0.1'];
    }
  }
}