import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../state/auth_provider.dart';

/// 申请新邮箱页面（与 Web 的 /email-apply 等价）
class EmailApplyPage extends StatefulWidget {
  const EmailApplyPage({super.key});

  @override
  State<EmailApplyPage> createState() => _EmailApplyPageState();
}

class _EmailApplyPageState extends State<EmailApplyPage> {
  final _formKey = GlobalKey<FormState>();
  final _prefixCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  // 域名固定 loli.ee（和后端 DA_DOMAIN 一致），如有多域名可扩展
  String _domain = 'loli.ee';
  int _quota = 200;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final u = context.read<AuthProvider>().user;
    if (u != null && u.name.isNotEmpty) _nameCtrl.text = u.name;
  }

  @override
  void dispose() {
    _prefixCtrl.dispose();
    _nameCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final contactEmail = context.read<AuthProvider>().user?.email;
    try {
      final api = await ApiClient.instance();
      await api.applyEmail(
        email: '${_prefixCtrl.text.trim()}@$_domain',
        name: _nameCtrl.text.trim(),
        reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
        quota: _quota,
        contactEmail: contactEmail,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('申请已提交，审核结果将通过邮件通知')),
      );
      Navigator.of(context).pop();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text((e.error ?? e.message ?? '提交失败').toString())),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('申请邮箱')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('填写下面的信息，提交后等待管理员审核',
                    style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _prefixCtrl,
                        decoration: const InputDecoration(
                          labelText: '邮箱用户名',
                          prefixIcon: Icon(Icons.alternate_email),
                          hintText: '例如 jack',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return '请填写用户名';
                          if (!RegExp(r'^[a-zA-Z0-9._-]{2,32}$').hasMatch(v)) {
                            return '只允许字母、数字、._-';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _domain,
                        decoration: const InputDecoration(labelText: '域名'),
                        items: const [
                          DropdownMenuItem(value: 'loli.ee', child: Text('@loli.ee')),
                        ],
                        onChanged: (v) => setState(() => _domain = v ?? _domain),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '你的昵称',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '请填写昵称' : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  value: _quota,
                  decoration: const InputDecoration(
                    labelText: '需要的配额',
                    prefixIcon: Icon(Icons.storage_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 100, child: Text('100 MB')),
                    DropdownMenuItem(value: 200, child: Text('200 MB')),
                    DropdownMenuItem(value: 500, child: Text('500 MB')),
                    DropdownMenuItem(value: 1024, child: Text('1 GB')),
                  ],
                  onChanged: (v) => setState(() => _quota = v ?? 200),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _reasonCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '申请原因（可选）',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('提交申请'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
