import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Prefs {
  static SharedPreferences? _instance;
  static Future<void> init() async {
    _instance = await SharedPreferences.getInstance();
  }

  static SharedPreferences get _i {
    if (_instance == null) throw Exception('Prefs not initialized. Call Prefs.init() in main()');
    return _instance!;
  }

  static String? getDeviceName() => _i.getString('device_name');
  static Future<bool> setDeviceName(String name) => _i.setString('device_name', name);

  static Future<bool> setAccentColor(int value) => _i.setInt('accent_color', value);
  static int? getAccentColor() => _i.getInt('accent_color');

  static Future<bool> setSentBubbleColor(int value) => _i.setInt('bubble_color', value);
  static int? getSentBubbleColor() => _i.getInt('bubble_color');

  static Future<bool> setSaveDirectory(String path) => _i.setString('save_dir', path);
  static String? getSaveDirectory() => _i.getString('save_dir');

  static Future<bool> setAutoDownloadImages(bool v) => _i.setBool('auto_dl_images', v);
  static bool getAutoDownloadImages() => _i.getBool('auto_dl_images') ?? true;

  static Future<bool> setAutoDownloadFiles(bool v) => _i.setBool('auto_dl_files', v);
  static bool getAutoDownloadFiles() => _i.getBool('auto_dl_files') ?? false;

  static Future<bool> setAutoDownloadText(bool v) => _i.setBool('auto_dl_text', v);
  static bool getAutoDownloadText() => _i.getBool('auto_dl_text') ?? false;

  static Future<bool> setAutoDownloadThreshold(int bytes) => _i.setInt('auto_dl_threshold', bytes);
  static int getAutoDownloadThreshold() => _i.getInt('auto_dl_threshold') ?? 1048576;

  static Future<bool> setNotificationsEnabled(bool v) => _i.setBool('notif_enabled', v);
  static bool getNotificationsEnabled() => _i.getBool('notif_enabled') ?? true;

  static Future<bool> setPersistentNotificationEnabled(bool v) => _i.setBool('persistent_notif', v);
  static bool getPersistentNotificationEnabled() => _i.getBool('persistent_notif') ?? false;

  static List<Map<String, dynamic>> getAutoConnectHosts() {
    final raw = _i.getStringList('auto_connect_hosts') ?? [];
    return raw.map((s) {
      try {
        return jsonDecode(s) as Map<String, dynamic>;
      } catch (_) {
        return <String, dynamic>{};
      }
    }).where((m) => m.isNotEmpty).toList();
  }

  static Future<bool> addAutoConnectHost(String ip, int port, String name) async {
    final hosts = getAutoConnectHosts();
    if (hosts.any((h) => h['ip'] == ip && h['port'] == port)) return true;
    hosts.add({'ip': ip, 'port': port, 'name': name});
    final raw = hosts.map((h) => jsonEncode(h)).toList();
    return _i.setStringList('auto_connect_hosts', raw);
  }

  static Future<bool> removeAutoConnectHost(String ip, int port) async {
    final hosts = getAutoConnectHosts();
    hosts.removeWhere((h) => h['ip'] == ip && h['port'] == port);
    final raw = hosts.map((h) => jsonEncode(h)).toList();
    return _i.setStringList('auto_connect_hosts', raw);
  }

  static Future<bool> clearAutoConnectHosts() => _i.remove('auto_connect_hosts');
}