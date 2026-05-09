import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

/// shared_preferences 的简薄包装，集中管理我们关心的 key。
class Storage {
  Storage._(this._sp);

  final SharedPreferences _sp;

  static Storage? _instance;
  static Future<Storage> instance() async {
    _instance ??= Storage._(await SharedPreferences.getInstance());
    return _instance!;
  }

  String? get token => _sp.getString(AppConfig.kTokenKey);
  Future<void> setToken(String? v) async {
    if (v == null) {
      await _sp.remove(AppConfig.kTokenKey);
    } else {
      await _sp.setString(AppConfig.kTokenKey, v);
    }
  }

  String get baseUrl => _sp.getString(AppConfig.kBaseUrlKey) ?? AppConfig.defaultBaseUrl;
  Future<void> setBaseUrl(String v) => _sp.setString(AppConfig.kBaseUrlKey, v);

  Map<String, dynamic>? get user {
    final raw = _sp.getString(AppConfig.kUserKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> setUser(Map<String, dynamic>? v) async {
    if (v == null) {
      await _sp.remove(AppConfig.kUserKey);
    } else {
      await _sp.setString(AppConfig.kUserKey, jsonEncode(v));
    }
  }

  Future<void> clearAuth() async {
    await _sp.remove(AppConfig.kTokenKey);
    await _sp.remove(AppConfig.kUserKey);
  }
}
