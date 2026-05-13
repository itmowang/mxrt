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

    // 有 token + 有缓存用户 → 立即标记为已登录（不等网络）
    if (cached != null) {
      _user = AppUser.fromJson(cached);
      _status = AuthStatus.loggedIn;
      notifyListeners();
    }

    // 后台静默验证 token 是否还有效
    try {
      final me = await api.me();
      _user = AppUser.fromJson(me);
      await storage.setUser(me);
      if (_status != AuthStatus.loggedIn) {
        _status = AuthStatus.loggedIn;
        notifyListeners();
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // token 确实过期了，清掉
        await storage.clearAuth();
        _user = null;
        _status = AuthStatus.loggedOut;
        notifyListeners();
      }
      // 其他网络错误不处理，保持已登录状态
    } catch (_) {
      // 保持当前状态
    }
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
