import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/storage.dart';
import '../models/user.dart';

enum AuthStatus { unknown, loggedOut, loggedIn }

/// 登录/登出状态。
class AuthProvider extends ChangeNotifier {
  AuthProvider({required this.api, required this.storage});

  final ApiClient api;
  final Storage storage;

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _user;
  String? _lastError;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  String? get lastError => _lastError;
  String get baseUrl => storage.baseUrl;

  /// 启动时尝试用缓存 token 自动登录。
  Future<void> bootstrap() async {
    final token = storage.token;
    final cached = storage.user;
    if (token == null || token.isEmpty) {
      _status = AuthStatus.loggedOut;
      notifyListeners();
      return;
    }
    // 先用缓存快速渲染
    if (cached != null) _user = AppUser.fromJson(cached);

    try {
      final me = await api.me();
      _user = AppUser.fromJson(me);
      await storage.setUser(me);
      _status = AuthStatus.loggedIn;
    } on DioException catch (e) {
      // token 失效 / 网络失败
      if (e.response?.statusCode == 401) {
        await storage.clearAuth();
        _user = null;
        _status = AuthStatus.loggedOut;
      } else {
        // 网络错误也保持已登录状态，等进入页面后用户手动刷新
        _status = _user != null ? AuthStatus.loggedIn : AuthStatus.loggedOut;
      }
    } catch (_) {
      _status = _user != null ? AuthStatus.loggedIn : AuthStatus.loggedOut;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _lastError = null;
    try {
      final resp = await api.login(email, password);
      final token = resp['token'] as String?;
      final userJson = resp['user'] as Map?;
      if (token == null || userJson == null) {
        _lastError = '登录返回数据异常';
        notifyListeners();
        return false;
      }
      await storage.setToken(token);
      await storage.setUser(Map<String, dynamic>.from(userJson));
      _user = AppUser.fromJson(Map<String, dynamic>.from(userJson));
      _status = AuthStatus.loggedIn;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _lastError = (e.error ?? e.message ?? '登录失败').toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String code,
  }) async {
    _lastError = null;
    try {
      final resp = await api.register(
        name: name,
        email: email,
        password: password,
        code: code,
      );
      final token = resp['token'] as String?;
      final userJson = resp['user'] as Map?;
      if (token == null || userJson == null) {
        _lastError = '注册返回数据异常';
        notifyListeners();
        return false;
      }
      await storage.setToken(token);
      await storage.setUser(Map<String, dynamic>.from(userJson));
      _user = AppUser.fromJson(Map<String, dynamic>.from(userJson));
      _status = AuthStatus.loggedIn;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _lastError = (e.error ?? e.message ?? '注册失败').toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await storage.clearAuth();
    _user = null;
    _status = AuthStatus.loggedOut;
    notifyListeners();
  }

  /// 直接用已有的 token 登录（OAuth 回调后使用）
  Future<void> loginWithToken({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    await storage.setToken(token);
    await storage.setUser(user);
    _user = AppUser.fromJson(user);
    _status = AuthStatus.loggedIn;
    notifyListeners();
    // 异步刷新完整用户信息
    try {
      final me = await api.me();
      _user = AppUser.fromJson(me);
      await storage.setUser(me);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> updateBaseUrl(String url) async {
    await storage.setBaseUrl(url.trim());
    notifyListeners();
  }
}
