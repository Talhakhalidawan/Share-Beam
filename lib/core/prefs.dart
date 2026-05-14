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

  // ── Device Name ───────────────────────────────────────────────────────────
  static String? getDeviceName() {
    return _i.getString('device_name');
  }

  static Future<bool> setDeviceName(String name) async {
    return _i.setString('device_name', name);
  }

  // ── Auto-connect hosts (JSON strings) ──────────────────────────────────────
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
    // Prevent duplicates
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

  static Future<bool> clearAutoConnectHosts() async {
    return _i.remove('auto_connect_hosts');
  }

  // ── Download Path ────────────────────────────────────────────────────────
  static String? getDownloadPath() {
    return _i.getString('download_path');
  }

  static Future<bool> setDownloadPath(String path) async {
    return _i.setString('download_path', path);
  }

  // ── Auto-Download Settings ────────────────────────────────────────────────
  static bool getAutoDownloadEnabled() {
    return _i.getBool('auto_download_enabled') ?? true;
  }

  static Future<bool> setAutoDownloadEnabled(bool value) async {
    return _i.setBool('auto_download_enabled', value);
  }

  static List<String> getAutoDownloadTypes() {
    return _i.getStringList('auto_download_types') ?? ['image'];
  }

  static Future<bool> setAutoDownloadTypes(List<String> types) async {
    return _i.setStringList('auto_download_types', types);
  }

  static int getAutoDownloadMaxSize() {
    return _i.getInt('auto_download_max_size') ?? 1; // Default 1 MB
  }

  static Future<bool> setAutoDownloadMaxSize(int value) async {
    return _i.setInt('auto_download_max_size', value);
  }
}