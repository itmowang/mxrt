import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/mailbox.dart';

class MailboxProvider extends ChangeNotifier {
  MailboxProvider({required this.api});

  final ApiClient api;

  List<Mailbox> _mailboxes = const [];
  bool _loading = false;
  String? _error;

  List<Mailbox> get mailboxes => _mailboxes;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> refresh() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final list = await api.listMailboxes();
      _mailboxes = list.map(Mailbox.fromJson).toList();
    } on DioException catch (e) {
      _error = (e.error ?? e.message ?? '加载失败').toString();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String?> resetPassword(String mailboxId, String newPassword) async {
    try {
      final r = await api.resetMailboxPassword(
        mailboxId: mailboxId,
        newPassword: newPassword,
      );
      final success = r['success'] == true;
      if (success) {
        await refresh();
        return null;
      }
      return (r['message'] ?? '重置失败').toString();
    } on DioException catch (e) {
      return (e.error ?? e.message ?? '重置失败').toString();
    }
  }

  Future<String?> deleteMailbox(String mailboxId) async {
    try {
      await api.deleteMailbox(mailboxId);
      await refresh();
      return null;
    } on DioException catch (e) {
      return (e.error ?? e.message ?? '删除失败').toString();
    }
  }
}
