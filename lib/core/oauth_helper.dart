import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// OAuth 登录辅助。
///
/// 桌面端流程：
/// 1. 启动一个临时本地 HTTP 服务器（随机端口）
/// 2. 打开浏览器访问后端 `/api/mobile/oauth/github?redirect_port=<port>`
/// 3. 后端完成 OAuth 后重定向到 `http://localhost:<port>/callback?token=xxx`
/// 4. 本地服务器收到请求，提取 token，关闭服务器
///
/// Android/iOS 端流程：
/// 使用自定义 URL Scheme `mxrtmail://oauth?token=xxx`
class OAuthHelper {
  /// 发起 GitHub OAuth 登录，返回 {token, name, email, role} 或 null。
  static Future<Map<String, String>?> loginWithGitHub({
    required String baseUrl,
  }) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return _desktopOAuth(baseUrl);
    }
    // 移动端走 URL Scheme（由 main.dart 的 deep link 监听处理）
    // 这里只负责打开浏览器
    final url = '$baseUrl/api/mobile/oauth/github';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    return null; // 移动端通过 deep link 回调处理
  }

  static Future<Map<String, String>?> _desktopOAuth(String baseUrl) async {
    final completer = Completer<Map<String, String>?>();

    // 启动临时 HTTP 服务器
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    debugPrint('[OAuth] Local callback server on port $port');

    // 超时 3 分钟自动关闭
    final timeout = Timer(const Duration(minutes: 3), () {
      if (!completer.isCompleted) {
        completer.complete(null);
        server.close();
      }
    });

    server.listen((request) {
      if (request.uri.path == '/callback') {
        final params = request.uri.queryParameters;
        final token = params['token'];

        if (token != null && token.isNotEmpty) {
          // 返回成功页面给浏览器
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.html
            ..write(_successHtml)
            ..close();

          if (!completer.isCompleted) {
            completer.complete({
              'token': token,
              'name': params['name'] ?? '',
              'email': params['email'] ?? '',
              'role': params['role'] ?? 'user',
            });
          }
        } else {
          request.response
            ..statusCode = 400
            ..headers.contentType = ContentType.html
            ..write(_errorHtml)
            ..close();

          if (!completer.isCompleted) {
            completer.complete(null);
          }
        }

        timeout.cancel();
        Future.delayed(const Duration(seconds: 1), () => server.close());
      } else {
        request.response
          ..statusCode = 404
          ..write('Not found')
          ..close();
      }
    });

    // 打开浏览器，带上 redirect_port 参数
    final oauthUrl = '$baseUrl/api/mobile/oauth/github?redirect_port=$port';
    await launchUrl(Uri.parse(oauthUrl), mode: LaunchMode.externalApplication);

    return completer.future;
  }

  static const _successHtml = '''<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>登录成功</title>
<style>body{display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;font-family:system-ui,sans-serif;background:#f1f5f9}
.box{text-align:center}.ok{font-size:48px;margin-bottom:12px}h2{color:#1e293b}p{color:#64748b;font-size:14px}</style></head>
<body><div class="box"><div class="ok">✅</div><h2>登录成功</h2><p>你可以关闭此页面，返回客户端</p></div></body></html>''';

  static const _errorHtml = '''<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>登录失败</title>
<style>body{display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;font-family:system-ui,sans-serif;background:#f1f5f9}
.box{text-align:center}.err{font-size:48px;margin-bottom:12px}h2{color:#dc2626}p{color:#64748b;font-size:14px}</style></head>
<body><div class="box"><div class="err">❌</div><h2>登录失败</h2><p>请关闭此页面重试</p></div></body></html>''';
}
