import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/mail_setup.dart';
import '../models/mailbox.dart';
import '../state/auth_provider.dart';
import '../state/mailbox_provider.dart';

/// 邮箱详情 / 一键绑定核心页面
class MailboxDetailPage extends StatefulWidget {
  const MailboxDetailPage({super.key, required this.mailbox});
  final Mailbox mailbox;

  @override
  State<MailboxDetailPage> createState() => _MailboxDetailPageState();
}

class _MailboxDetailPageState extends State<MailboxDetailPage> {
  Mailbox get _mb {
    // 如果列表被刷新过，使用最新快照
    final list = context.watch<MailboxProvider>().mailboxes;
    return list.firstWhere(
      (m) => m.id == widget.mailbox.id,
      orElse: () => widget.mailbox,
    );
  }

  Future<void> _copy(String text, {String? hint}) async {
    await Clipboard.setData(ClipboardData(text: text));
    Fluttertoast.showToast(msg: hint ?? '已复制');
  }

  Future<void> _oneClickBind() async {
    final mb = _mb;
    if (mb.mailPass == null || mb.mailPass!.isEmpty) {
      final ok = await _promptResetFirst();
      if (ok != true) return;
    }
    if (!mounted) return;
    final fresh = _mb; // 刷新后的最新
    if (fresh.mailPass == null || fresh.mailPass!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('邮箱密码尚未设置，无法一键绑定')),
      );
      return;
    }
    final result = await MailSetup.addToSystem(context, fresh);
    if (!mounted) return;
    // 显示详细结果对话框
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          result.success ? Icons.check_circle : Icons.error_outline,
          color: result.success ? Colors.green : Colors.red,
          size: 36,
        ),
        title: Text(result.success ? '操作成功' : '操作失败'),
        content: Text(result.message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _promptResetFirst() async {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('还没有邮箱密码'),
        content: const Text('一键绑定需要先重置邮箱密码（密码本身存储在服务端，仅用于你个人绑定）。是否现在去重置？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context, true);
              await _showResetPasswordDialog();
            },
            child: const Text('去重置'),
          ),
        ],
      ),
    );
  }

  Future<void> _showResetPasswordDialog() async {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final provider = context.read<MailboxProvider>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重置邮箱密码'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: ctrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '新密码',
                  helperText: '至少 8 位，含大写字母、小写字母和数字',
                ),
                validator: (v) {
                  if (v == null || v.length < 8) return '至少 8 位';
                  if (!RegExp(r'[a-z]').hasMatch(v) ||
                      !RegExp(r'[A-Z]').hasMatch(v) ||
                      !RegExp(r'[0-9]').hasMatch(v)) {
                    return '必须包含大小写字母和数字';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (saved == true) {
      final err = await provider.resetPassword(_mb.id, ctrl.text);
      if (!mounted) return;
      if (err == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('邮箱密码已重置')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err)),
        );
      }
    }
  }

  Future<void> _openWebmail() async {
    final uri = Uri.parse(_mb.config.webmail);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _deleteMailbox() async {
    final provider = context.read<MailboxProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除邮箱？'),
        content: Text('这将永久删除 ${_mb.email}，邮件内容无法恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final err = await provider.deleteMailbox(_mb.id);
    if (!mounted) return;
    if (err == null) {
      navigator.pop();
    } else {
      messenger.showSnackBar(SnackBar(content: Text(err)));
    }
  }

  String get _mobileconfigUrl {
    final base = context.read<AuthProvider>().baseUrl;
    final email = Uri.encodeComponent(_mb.email);
    final pass = Uri.encodeComponent(_mb.mailPass ?? '');
    return '$base/api/mail-config?email=$email&password=$pass';
  }

  @override
  Widget build(BuildContext context) {
    final mb = _mb;
    final cfg = mb.config;
    return Scaffold(
      appBar: AppBar(
        title: Text(mb.email),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'reset') await _showResetPasswordDialog();
              if (v == 'delete') await _deleteMailbox();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'reset',
                child: Row(children: [
                  Icon(Icons.password, size: 18),
                  SizedBox(width: 8),
                  Text('重置邮箱密码'),
                ]),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('删除邮箱', style: TextStyle(color: Colors.red)),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeroCard(mailbox: mb),
          const SizedBox(height: 16),

          // 一键绑定区域
          const _SectionTitle(title: '快捷操作'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ActionTile(
                    icon: Icons.smartphone,
                    title: Platform.isAndroid
                        ? '一键添加到手机系统邮箱'
                        : Platform.isIOS
                            ? '一键添加到 iPhone 邮箱'
                            : '在浏览器登录 Webmail',
                    subtitle: Platform.isAndroid
                        ? '自动打开系统向导并预填服务器、账号、密码（支持小米、荣耀等）'
                        : Platform.isIOS
                            ? '下载 .mobileconfig 配置描述文件，安装后自动生效'
                            : '打开默认浏览器登录你的 Roundcube',
                    onTap: () async {
                      if (Platform.isIOS) {
                        final url = _mobileconfigUrl;
                        await launchUrl(Uri.parse(url),
                            mode: LaunchMode.externalApplication);
                      } else if (Platform.isAndroid) {
                        await _oneClickBind();
                      } else {
                        await _openWebmail();
                      }
                    },
                  ),
                  const Divider(height: 24),
                  _ActionTile(
                    icon: Icons.open_in_browser,
                    title: '打开 Webmail',
                    subtitle: cfg.webmail,
                    onTap: _openWebmail,
                  ),
                  const Divider(height: 24),
                  _ActionTile(
                    icon: Icons.password,
                    title: mb.hasPassword ? '修改邮箱密码' : '设置邮箱密码',
                    subtitle: '邮箱登录 IMAP/SMTP 使用的密码',
                    onTap: _showResetPasswordDialog,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          const _SectionTitle(title: '客户端配置'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _CopyRow(label: '邮箱地址', value: mb.email, onCopy: _copy),
                  _CopyRow(
                    label: '用户名',
                    value: mb.email,
                    onCopy: _copy,
                  ),
                  if (mb.mailPass != null && mb.mailPass!.isNotEmpty)
                    _CopyRow(
                      label: '密码',
                      value: mb.mailPass!,
                      obscure: true,
                      onCopy: _copy,
                    ),
                  const Divider(),
                  _CopyRow(
                    label: 'IMAP',
                    value: '${cfg.imapHost}:${cfg.imapPort} (SSL/TLS)',
                    copyValue: cfg.imapHost,
                    onCopy: _copy,
                  ),
                  _CopyRow(
                    label: 'SMTP',
                    value: '${cfg.smtpHost}:${cfg.smtpPort} (SSL/TLS)',
                    copyValue: cfg.smtpHost,
                    onCopy: _copy,
                  ),
                  _CopyRow(
                    label: 'POP3',
                    value: '${cfg.pop3Host}:${cfg.pop3Port} (SSL/TLS)',
                    copyValue: cfg.pop3Host,
                    onCopy: _copy,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          _HelpTile(),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.mailbox});
  final Mailbox mailbox;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withOpacity(.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mail, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mailbox.email,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '配额 ${mailbox.quota} MB · 状态 ${mailbox.status}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: .5,
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}

class _CopyRow extends StatefulWidget {
  const _CopyRow({
    required this.label,
    required this.value,
    required this.onCopy,
    this.copyValue,
    this.obscure = false,
  });
  final String label;
  final String value;
  final String? copyValue;
  final bool obscure;
  final Future<void> Function(String text, {String? hint}) onCopy;

  @override
  State<_CopyRow> createState() => _CopyRowState();
}

class _CopyRowState extends State<_CopyRow> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final showValue =
        widget.obscure && !_visible ? '•' * 8 : widget.value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              widget.label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
          Expanded(
            child: SelectableText(
              showValue,
              style: const TextStyle(
                  fontSize: 13, fontFamily: 'monospace'),
            ),
          ),
          if (widget.obscure)
            IconButton(
              icon: Icon(_visible
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _visible = !_visible),
              visualDensity: VisualDensity.compact,
            ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () =>
                widget.onCopy(widget.copyValue ?? widget.value, hint: '已复制 ${widget.label}'),
            visualDensity: VisualDensity.compact,
            tooltip: '复制',
          ),
        ],
      ),
    );
  }
}

class _HelpTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) {
      return Card(
        color: Colors.blue.shade50,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.tips_and_updates_outlined,
                  color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '在小米 / 荣耀 / 华为 / OPPO / vivo 等系统中，「一键添加」会打开系统原生"添加账户"向导并预填信息。如果系统屏蔽了该入口，可使用上方配置手动填入系统邮件应用。',
                  style: TextStyle(color: Colors.blue.shade800, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (Platform.isIOS) {
      return Card(
        color: Colors.blue.shade50,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.tips_and_updates_outlined,
                  color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '点击"一键添加"将下载 .mobileconfig，前往「设置 → 已下载描述文件」完成安装即可。',
                  style: TextStyle(color: Colors.blue.shade800, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      color: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.desktop_windows_outlined,
                color: Colors.grey.shade700, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '在 Windows / macOS / Linux 上，请将上面的 IMAP/SMTP 服务器信息填入你的邮件客户端（Outlook、Thunderbird、Foxmail 等）。',
                style: TextStyle(color: Colors.grey.shade800, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
