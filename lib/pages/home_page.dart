import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/updater.dart';
import '../models/mailbox.dart';
import '../state/auth_provider.dart';
import '../state/mailbox_provider.dart';
import 'email_apply_page.dart';
import 'login_page.dart';
import 'mailbox_detail_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MailboxProvider>().refresh();
      // 启动时检查更新
      AppUpdater.checkForUpdate(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final mbp = context.watch<MailboxProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的邮箱'),
        actions: [
          IconButton(
            onPressed: () => mbp.refresh(),
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) async {
              if (v == 'settings') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              } else if (v == 'logout') {
                await auth.logout();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (r) => false,
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'settings',
                child: Row(children: [
                  Icon(Icons.settings_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('服务器设置'),
                ]),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(children: [
                  Icon(Icons.logout, size: 18),
                  SizedBox(width: 8),
                  Text('退出登录'),
                ]),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const EmailApplyPage()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('申请新邮箱'),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<MailboxProvider>().refresh(),
        child: _buildBody(auth, mbp),
      ),
    );
  }

  Widget _buildBody(AuthProvider auth, MailboxProvider mbp) {
    if (mbp.loading && mbp.mailboxes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (mbp.error != null && mbp.mailboxes.isEmpty) {
      return _ErrorState(message: mbp.error!, onRetry: () => mbp.refresh());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        _WelcomeCard(name: auth.user?.name ?? ''),
        const SizedBox(height: 16),
        if (mbp.mailboxes.isEmpty)
          _EmptyState(
            onApply: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EmailApplyPage()),
            ),
          )
        else
          ...mbp.mailboxes.map(
            (mb) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MailboxCard(
                mailbox: mb,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MailboxDetailPage(mailbox: mb),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        const _QqGroupCard(),
      ],
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.name});
  final String name;

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
      child: Row(
        children: [
          const Icon(Icons.waving_hand, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? '你好' : '你好，$name',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  '一键把你的邮箱添加到手机/电脑邮件应用',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MailboxCard extends StatelessWidget {
  const _MailboxCard({required this.mailbox, required this.onTap});
  final Mailbox mailbox;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.mail_outline,
                    color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mailbox.email,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _Tag(
                          text: '配额 ${mailbox.quota}MB',
                          color: Colors.blue.shade50,
                          fg: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 6),
                        _Tag(
                          text: mailbox.hasPassword ? '可一键绑定' : '需重置密码',
                          color: mailbox.hasPassword
                              ? Colors.green.shade50
                              : Colors.orange.shade50,
                          fg: mailbox.hasPassword
                              ? Colors.green.shade700
                              : Colors.orange.shade800,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black26),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color, required this.fg});
  final String text;
  final Color color;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onApply});
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
        child: Column(
          children: [
            Icon(Icons.mark_email_unread_outlined,
                size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('你还没有邮箱',
                style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('点击下方按钮申请一个专属邮箱',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onApply,
              icon: const Icon(Icons.add),
              label: const Text('申请邮箱'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 60),
        Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
        const SizedBox(height: 12),
        Text(
          '加载失败',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.red.shade700),
        ),
        const SizedBox(height: 6),
        Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
        const SizedBox(height: 16),
        Center(
          child: FilledButton(onPressed: onRetry, child: const Text('重试')),
        ),
      ],
    );
  }
}

class _QqGroupCard extends StatelessWidget {
  const _QqGroupCard();

  static const _qqGroup = '339803174';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.groups, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '加入 QQ 交流群',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '群号: $_qqGroup',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                Clipboard.setData(const ClipboardData(text: _qqGroup));
                Fluttertoast.showToast(msg: '群号已复制');
              },
              child: const Text('复制'),
            ),
            const SizedBox(width: 4),
            FilledButton(
              onPressed: () {
                final uri = Uri.parse(
                  'mqqopensdkapi://bizAgent/qm/qr?url=http%3A%2F%2Fqm.qq.com%2Fcgi-bin%2Fqm%2Fqr%3Ffrom%3Dapp%26p%3Dandroid%26jump_from%3Dwebapi%26k%3D%26group_code%3D$_qqGroup',
                );
                launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) {
                  // QQ 未安装则打开网页
                  launchUrl(
                    Uri.parse('https://qm.qq.com/cgi-bin/qm/qr?k=&group_code=$_qqGroup'),
                    mode: LaunchMode.externalApplication,
                  );
                });
              },
              child: const Text('加群'),
            ),
          ],
        ),
      ),
    );
  }
}
