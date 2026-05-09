import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/theme.dart';
import 'core/api_client.dart';
import 'core/storage.dart';
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

class MxrtApp extends StatelessWidget {
  const MxrtApp({super.key, required this.api, required this.auth});
  final ApiClient api;
  final AuthProvider auth;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => MailboxProvider(api: api)),
      ],
      child: MaterialApp(
        title: '魔王数据邮箱',
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        home: const SplashPage(),
      ),
    );
  }
}
