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

  // ── Auto-connect hosts (by name) ──────────────────────────────────────────
  static List<String> getAutoConnectNames() {
    return _i.getStringList('auto_connect_names') ?? [];
  }

  static Future<bool> addAutoConnectName(String name) async {
    final names = getAutoConnectNames();
    if (names.contains(name)) return true;
    names.add(name);
    return _i.setStringList('auto_connect_names', names);
  }

  static Future<bool> removeAutoConnectName(String name) async {
    final names = getAutoConnectNames();
    names.remove(name);
    return _i.setStringList('auto_connect_names', names);
  }

  static Future<bool> clearAutoConnectHosts() async {
    return _i.remove('auto_connect_names');
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