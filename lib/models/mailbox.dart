/// 邮箱模型及相关配置，和后端 `/api/mobile/mailbox` 的返回结构对齐。
class MailboxConfig {
  MailboxConfig({
    required this.email,
    required this.domain,
    required this.imapHost,
    required this.imapPort,
    required this.smtpHost,
    required this.smtpPort,
    required this.pop3Host,
    required this.pop3Port,
    required this.webmail,
  });

  final String email;
  final String domain;
  final String imapHost;
  final int imapPort;
  final String smtpHost;
  final int smtpPort;
  final String pop3Host;
  final int pop3Port;
  final String webmail;

  factory MailboxConfig.fromJson(Map<String, dynamic> json) {
    final imap = (json['imap'] ?? {}) as Map;
    final smtp = (json['smtp'] ?? {}) as Map;
    final pop3 = (json['pop3'] ?? {}) as Map;
    return MailboxConfig(
      email: (json['email'] ?? '').toString(),
      domain: (json['domain'] ?? '').toString(),
      imapHost: (imap['host'] ?? '').toString(),
      imapPort: (imap['port'] ?? 993) as int,
      smtpHost: (smtp['host'] ?? '').toString(),
      smtpPort: (smtp['port'] ?? 465) as int,
      pop3Host: (pop3['host'] ?? '').toString(),
      pop3Port: (pop3['port'] ?? 995) as int,
      webmail: (json['webmail'] ?? '').toString(),
    );
  }
}

class Mailbox {
  Mailbox({
    required this.id,
    required this.email,
    required this.emailUser,
    required this.domain,
    required this.quota,
    required this.status,
    required this.hasPassword,
    required this.mailPass,
    required this.createdAt,
    required this.config,
  });

  final String id;
  final String email;
  final String emailUser;
  final String domain;
  final int quota;
  final String status;
  final bool hasPassword;
  final String? mailPass;
  final DateTime? createdAt;
  final MailboxConfig config;

  factory Mailbox.fromJson(Map<String, dynamic> json) {
    return Mailbox(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      emailUser: (json['emailUser'] ?? '').toString(),
      domain: (json['domain'] ?? '').toString(),
      quota: (json['quota'] ?? 0) as int,
      status: (json['status'] ?? '').toString(),
      hasPassword: json['hasPassword'] == true,
      mailPass: json['mailPass']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      config: MailboxConfig.fromJson(
        Map<String, dynamic>.from((json['config'] ?? {}) as Map),
      ),
    );
  }
}
