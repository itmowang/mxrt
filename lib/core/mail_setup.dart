import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/mailbox.dart';
import 'config.dart';

/// 一键把邮箱配置添加到系统邮件应用。
///
/// 策略（按优先级）：
///
/// Android:
///   1. 尝试打开 Gmail 的"添加 IMAP 账户"（覆盖率最高）
///   2. 尝试系统邮件 App 的 Intent
///   3. 兜底：弹出配置详情 + 一键复制 + 打开系统设置
///
/// Windows:
///   1. 打开系统"邮件和账户"设置页
///   2. 同时把配置复制到剪贴板
///
/// 所有平台通用兜底：显示配置信息 + 一键复制
class MailSetup {
  static const _channel = MethodChannel(AppConfig.kMailChannel);

  /// 在 Android 上尝试多种方式添加邮箱
  static Future<MailSetupResult> addToSystem(
    BuildContext context,
    Mailbox mb,
  ) async {
    if (mb.mailPass == null || mb.mailPass!.isEmpty) {
      return MailSetupResult(
        success: false,
        message: '邮箱密码未设置，请先重置密码',
      );
    }

    if (Platform.isAndroid) {
      return _androidSetup(context, mb);
    } else if (Platform.isWindows) {
      return _windowsSetup(context, mb);
    } else if (Platform.isMacOS) {
      return _macSetup(context, mb);
    } else {
      // 通用兜底
      await _copyConfigToClipboard(mb);
      return MailSetupResult(
        success: true,
        message: '配置已复制到剪贴板，请手动粘贴到邮件客户端',
      );
    }
  }

  /// Android: 尝试 Gmail → 系统邮件 → 兜底复制
  static Future<MailSetupResult> _androidSetup(
    BuildContext context,
    Mailbox mb,
  ) async {
    try {
      // 方案1: 尝试通过 MethodChannel 调用原生 Intent
      final result = await _channel.invokeMethod<String>('addImapAccount', {
        'email': mb.email,
        'password': mb.mailPass ?? '',
        'imapHost': mb.config.imapHost,
        'imapPort': mb.config.imapPort,
        'smtpHost': mb.config.smtpHost,
        'smtpPort': mb.config.smtpPort,
        'displayName': mb.email,
      });

      if (result == 'gmail') {
        return MailSetupResult(
          success: true,
          message: 'Gmail 已打开，请按提示完成添加',
        );
      } else if (result == 'system') {
        return MailSetupResult(
          success: true,
          message: '系统邮件已打开，请按提示完成添加',
        );
      } else if (result == 'settings') {
        await _copyConfigToClipboard(mb);
        return MailSetupResult(
          success: true,
          message: '已打开账户设置并复制配置到剪贴板，请手动添加 IMAP 账户',
        );
      }
    } on PlatformException catch (_) {
      // 原生调用失败，走兜底
    } catch (_) {}

    // 兜底：复制配置
    await _copyConfigToClipboard(mb);
    return MailSetupResult(
      success: true,
      message: '配置已复制到剪贴板，请打开邮件应用手动添加',
    );
  }

  /// Windows: 打开系统邮件设置 + 复制配置
  static Future<MailSetupResult> _windowsSetup(
    BuildContext context,
    Mailbox mb,
  ) async {
    await _copyConfigToClipboard(mb);

    // 尝试打开 Windows 邮件和账户设置
    try {
      final uri = Uri.parse('ms-settings:emailandaccounts');
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) {
        return MailSetupResult(
          success: true,
          message: '已打开系统"邮件和账户"设置，配置已复制到剪贴板。\n\n'
              '请点击"添加账户" → "其他账户(POP, IMAP)" → 粘贴配置信息',
        );
      }
    } catch (_) {}

    // 尝试打开 Thunderbird（如果安装了）
    try {
      final tbUri = Uri.parse(
          'thunderbird://newmailaccount?email=${Uri.encodeComponent(mb.email)}');
      await launchUrl(tbUri, mode: LaunchMode.externalApplication);
    } catch (_) {}

    return MailSetupResult(
      success: true,
      message: '配置已复制到剪贴板，请打开你的邮件客户端（Outlook/Thunderbird/Foxmail）手动添加',
    );
  }

  /// macOS: 打开系统偏好设置
  static Future<MailSetupResult> _macSetup(
    BuildContext context,
    Mailbox mb,
  ) async {
    await _copyConfigToClipboard(mb);
    try {
      final uri = Uri.parse(
          'x-apple.systempreferences:com.apple.Internet-Accounts');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    return MailSetupResult(
      success: true,
      message: '配置已复制到剪贴板，请在"系统设置 → 互联网账户"中添加',
    );
  }

  /// 把邮箱配置格式化后复制到剪贴板
  static Future<void> _copyConfigToClipboard(Mailbox mb) async {
    final text = '''邮箱: ${mb.email}
密码: ${mb.mailPass ?? '(未设置)'}

收件服务器 (IMAP):
  服务器: ${mb.config.imapHost}
  端口: ${mb.config.imapPort}
  安全: SSL/TLS
  用户名: ${mb.email}

发件服务器 (SMTP):
  服务器: ${mb.config.smtpHost}
  端口: ${mb.config.smtpPort}
  安全: SSL/TLS
  用户名: ${mb.email}''';

    await Clipboard.setData(ClipboardData(text: text));
    Fluttertoast.showToast(msg: '邮箱配置已复制到剪贴板');
  }
}

class MailSetupResult {
  MailSetupResult({required this.success, required this.message});
  final bool success;
  final String message;
}
