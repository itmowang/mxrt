import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config.dart';
import '../state/auth_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _urlCtrl;

  @override
  void initState() {
    super.initState();
    _urlCtrl =
        TextEditingController(text: context.read<AuthProvider>().baseUrl);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写完整的 http(s) 地址')),
      );
      return;
    }
    await context.read<AuthProvider>().updateBaseUrl(url);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('服务器地址已更新')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('服务器设置')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '客户端要连接的 auth-app 后端地址',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                '默认值：${AppConfig.defaultBaseUrl}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'API Base URL',
                  hintText: 'https://mail.example.com',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _save, child: const Text('保存')),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  _urlCtrl.text = AppConfig.defaultBaseUrl;
                },
                child: const Text('恢复默认'),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                '提示：\n'
                '• Android 模拟器访问本机请用 http://10.0.2.2:3001\n'
                '• 真机需要服务器可被公网访问或在同一局域网\n'
                '• 如果后端启用 HTTPS，请使用 https:// 开头',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
