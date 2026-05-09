import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 应用热更新检查。
///
/// 通过 GitHub Releases API 获取最新版本号，
/// 与当前版本比较，如果有新版则弹窗提示用户下载。
class AppUpdater {
  static const _currentVersion = '1.0.0';
  static const _owner = 'itmowang';
  static const _repo = 'mxrt';
  static const _releasesApi =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  /// 检查更新，如果有新版弹窗提示。
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final resp = await dio.get(_releasesApi);
      if (resp.statusCode != 200) return;

      final data = resp.data as Map<String, dynamic>;
      final tagName = (data['tag_name'] ?? '').toString().replaceAll('v', '');
      if (tagName.isEmpty) return;

      if (_isNewer(tagName, _currentVersion)) {
        if (!context.mounted) return;
        final body = (data['body'] ?? '').toString();
        final htmlUrl = (data['html_url'] ?? '').toString();

        // 找到对应平台的下载链接
        final assets = (data['assets'] as List?) ?? [];
        String? downloadUrl;
        if (Platform.isWindows) {
          downloadUrl = _findAsset(assets, '.zip') ?? _findAsset(assets, '.exe');
        } else if (Platform.isAndroid) {
          downloadUrl = _findAsset(assets, '.apk');
        }

        _showUpdateDialog(
          context,
          newVersion: tagName,
          changelog: body,
          downloadUrl: downloadUrl ?? htmlUrl,
        );
      }
    } catch (_) {
      // 静默失败，不影响正常使用
    }
  }

  static String? _findAsset(List assets, String ext) {
    for (final a in assets) {
      final name = (a['name'] ?? '').toString().toLowerCase();
      if (name.endsWith(ext)) {
        return (a['browser_download_url'] ?? '').toString();
      }
    }
    return null;
  }

  static bool _isNewer(String remote, String local) {
    final r = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final l = local.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final rv = i < r.length ? r[i] : 0;
      final lv = i < l.length ? l[i] : 0;
      if (rv > lv) return true;
      if (rv < lv) return false;
    }
    return false;
  }

  static void _showUpdateDialog(
    BuildContext context, {
    required String newVersion,
    required String changelog,
    required String downloadUrl,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('发现新版本 v$newVersion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (changelog.isNotEmpty) ...[
              const Text('更新内容：',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Text(changelog,
                      style: TextStyle(
                          color: Colors.grey.shade700, fontSize: 13)),
                ),
              ),
            ] else
              const Text('有新版本可用，建议更新。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              launchUrl(Uri.parse(downloadUrl),
                  mode: LaunchMode.externalApplication);
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }
}
