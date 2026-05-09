import 'dart:io' show Platform;

/// 客户端全局配置。
///
/// - [defaultBaseUrl] 默认后端地址，用户可以在 [AppConfig] 设置页覆盖。
/// - Android 模拟器访问宿主机需要走 10.0.2.2，真机或桌面走 localhost。
class AppConfig {
  static String get defaultBaseUrl {
    // 生产环境域名，打包前可以改成你的线上地址
    const prod = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://mail.loli.free');
    if (prod.isNotEmpty) return prod;

    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:3001';
    } catch (_) {}
    return 'http://localhost:3001';
  }

  /// 本地存储的 key
  static const kTokenKey = 'auth_token';
  static const kBaseUrlKey = 'api_base_url';
  static const kUserKey = 'auth_user';

  /// MethodChannel 名，与 Android 原生代码保持一致
  static const kMailChannel = 'cn.mxrt/mail_setup';
}
