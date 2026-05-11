import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/theme.dart';
import 'core/api_client.dart';
import 'core/storage.dart';
import 'pages/home_page.dart';
import 'pages/splash_page.dart';
import 'state/auth_provider.dart';
import 'state/mailbox_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await Storage.instance();
  final api = await ApiClient.instance();
  final auth = AuthProvider(api: api, storage: storage);
  // bootstrap 异步进行，UI 先渲染 splash
  auth.bootstrap();

  runApp(MxrtApp(api: api, auth: auth));
}

class MxrtApp extends StatefulWidget {
  const MxrtApp({super.key, required this.api, required this.auth});
  final ApiClient api;
  final AuthProvider auth;

  @override
  State<MxrtApp> createState() => _MxrtAppState();
}

class _MxrtAppState extends State<MxrtApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final AppLinks _appLinks;
  StreamSubscription? _linkSub;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    // 处理 App 冷启动时的 deep link
    try {
      final initialUri = await _appLinks.getInitialAppLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (_) {}

    // 监听 App 运行中收到的 deep link
    _linkSub = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    // 处理 mxrtmail://oauth?token=xxx&name=xxx&email=xxx&role=xxx
    if (uri.scheme == 'mxrtmail' && uri.host == 'oauth') {
      final token = uri.queryParameters['token'];
      if (token != null && token.isNotEmpty) {
        final user = {
          'name': uri.queryParameters['name'] ?? '',
          'email': uri.queryParameters['email'] ?? '',
          'role': uri.queryParameters['role'] ?? 'user',
        };
        widget.auth.loginWithToken(token: token, user: user);

        // 跳转到首页
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomePage()),
            (route) => false,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.auth),
        ChangeNotifierProvider(create: (_) => MailboxProvider(api: widget.api)),
      ],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: '魔王数据邮箱',
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        home: const SplashPage(),
      ),
    );
  }
}
