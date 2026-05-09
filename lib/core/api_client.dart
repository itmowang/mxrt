import 'package:dio/dio.dart';

import 'storage.dart';

/// 后端 API 的统一网络层。
///
/// - 自动拼接 baseUrl
/// - 自动带 `Authorization: Bearer <token>`
/// - 出错时把服务器返回的 error/ message 抽出来抛出，方便 UI 直接展示
class ApiClient {
  ApiClient._(this._storage) {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        contentType: 'application/json',
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.baseUrl = _storage.baseUrl;
          final token = _storage.token;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (err, handler) {
          // 把服务器错误消息提到异常的 message 里
          final data = err.response?.data;
          if (data is Map && (data['error'] != null || data['message'] != null)) {
            final msg = (data['error'] ?? data['message']).toString();
            handler.reject(
              DioException(
                requestOptions: err.requestOptions,
                response: err.response,
                type: err.type,
                error: msg,
                message: msg,
              ),
            );
            return;
          }
          handler.next(err);
        },
      ),
    );
  }

  final Storage _storage;
  late final Dio _dio;

  static ApiClient? _instance;
  static Future<ApiClient> instance() async {
    _instance ??= ApiClient._(await Storage.instance());
    return _instance!;
  }

  Dio get dio => _dio;

  // ---------- Auth ----------
  Future<Map<String, dynamic>> login(String email, String password) async {
    final r = await _dio.post('/api/mobile/login', data: {
      'email': email,
      'password': password,
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String code,
  }) async {
    final r = await _dio.post('/api/mobile/register', data: {
      'name': name,
      'email': email,
      'password': password,
      'code': code,
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<void> sendCode(String email, {String type = 'register'}) async {
    await _dio.post('/api/auth/send-code', data: {
      'email': email,
      'type': type,
    });
  }

  Future<Map<String, dynamic>> me() async {
    final r = await _dio.get('/api/mobile/me');
    return Map<String, dynamic>.from(r.data as Map);
  }

  // ---------- Mailbox ----------
  Future<List<Map<String, dynamic>>> listMailboxes() async {
    final r = await _dio.get('/api/mobile/mailbox');
    final list = (r.data as Map)['mailboxes'] as List? ?? const [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> applyEmail({
    required String email,
    required String name,
    String? reason,
    int? quota,
    String? contactEmail,
  }) async {
    final r = await _dio.post('/api/mobile/email-apply', data: {
      'email': email,
      'name': name,
      if (reason != null) 'reason': reason,
      if (quota != null) 'quota': quota,
      if (contactEmail != null) 'contactEmail': contactEmail,
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> resetMailboxPassword({
    required String mailboxId,
    required String newPassword,
  }) async {
    final r = await _dio.post('/api/mobile/mailbox-action', data: {
      'mailboxId': mailboxId,
      'action': 'resetPassword',
      'newPassword': newPassword,
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> deleteMailbox(String mailboxId) async {
    final r = await _dio.post('/api/mobile/mailbox-action', data: {
      'mailboxId': mailboxId,
      'action': 'delete',
    });
    return Map<String, dynamic>.from(r.data as Map);
  }
}
