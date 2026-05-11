import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../state/auth_provider.dart';
import 'home_page.dart';

/// 扫码登录页面。
/// 扫描 PC/网页端个人中心的"快速登录码"，自动完成登录。
class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _processing = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final value = barcode.rawValue!;
    // 检查是否是我们的登录码 URL
    if (!value.contains('/api/mobile/qr-login/verify')) {
      setState(() => _error = '无效的二维码，请扫描个人中心的"快速登录码"');
      return;
    }

    setState(() {
      _processing = true;
      _error = null;
    });
    _controller.stop();

    try {
      // 从 URL 中提取 code 参数
      final uri = Uri.parse(value);
      final code = uri.queryParameters['code'] ?? '';
      if (code.isEmpty) {
        setState(() {
          _error = '二维码格式错误';
          _processing = false;
        });
        _controller.start();
        return;
      }

      // 调用验证接口
      final api = await ApiClient.instance();
      final resp = await api.dio.get('/api/mobile/qr-login/verify',
          queryParameters: {'code': code});
      final data = resp.data as Map<String, dynamic>;

      final token = data['token'] as String?;
      final userJson = data['user'] as Map?;

      if (token == null || userJson == null) {
        setState(() {
          _error = '登录失败：返回数据异常';
          _processing = false;
        });
        _controller.start();
        return;
      }

      // 登录成功
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      await auth.loginWithToken(
        token: token,
        user: Map<String, dynamic>.from(userJson),
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } on DioException catch (e) {
      setState(() {
        _error = (e.error ?? e.message ?? '验证失败').toString();
        _processing = false;
      });
      _controller.start();
    } catch (e) {
      setState(() {
        _error = '扫码失败: $e';
        _processing = false;
      });
      _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扫码登录')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
                // 扫描框提示
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white70, width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                if (_processing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text('正在登录...',
                              style: TextStyle(color: Colors.white, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              children: [
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.red.shade700, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!,
                              style: TextStyle(
                                  color: Colors.red.shade700, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                Text(
                  '将摄像头对准 PC/网页端个人中心的"快速登录码"',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
