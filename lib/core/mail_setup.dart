import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/mailbox.dart';
import 'config.dart';

/// 一键把邮箱配置添加到系统邮件应用。
///
/// Android: 通过 MethodChannel 调用原生的 `AccountManager.addAccount(IMAP)`，
///   系统会弹出标准的"添加 IMAP 账户"向导并预填服务器/用户名/密码。
///   小米 / 荣耀 / 华为 / OPPO / vivo / 原生 Android 都支持这个系统级 Intent。
///
/// 桌面端 / 其他平台: 回退为打开 webmail 或提示用户手动配置。
class MailSetup {
  static const _channel = MethodChannel(AppConfig.kMailChannel);

  /// 尝试一键添加。返回 true 表示系统向导被成功启动。
  static Future<MailSetupResult> addToSystem(Mailbox mb) async {
    if (Platform.isAndroid) {
      try {
        final ok = await _channel.invokeMethod<bool>('addImapAccount', {
          'email': mb.email,
          'password': mb.mailPass ?? '',
          'imapHost': mb.config.imapHost,
          'imapPort': mb.config.imapPort,
          'smtpHost': mb.config.smtpHost,
          'smtpPort': mb.config.smtpPort,
          'displayName': mb.email,
        });
        return MailSetupResult(
          success: ok == true,
          message: ok == true ? '系统向导已打开，请按提示完成' : '当前设备未找到可用的系统邮件向导',
        );
      } on PlatformException catch (e) {
        return MailSetupResult(success: false, message: e.message ?? '系统调用失败');
      } catch (e) {
        return MailSetupResult(success: false, message: '系统调用失败: $e');
      }
    }

    // 其他平台直接打开 webmail
    final uri = Uri.parse(mb.config.webmail);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    return MailSetupResult(
      success: ok,
      message: ok ? '已打开 Webmail' : '无法打开默认浏览器',
    );
  }
}

class MailSetupResult {
  MailSetupResult({required this.success, required this.message});
  final bool success;
  final String message;
}
