import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'application/session_service.dart';
import 'bootstrap/app_dependencies.dart';
import 'presentation/auth/login_page.dart';
import 'presentation/home/home_shell.dart';
import 'presentation/shared/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi');
  final providers = await createDependencies();
  runApp(MultiProvider(providers: providers, child: const DiChoApp()));
}

class DiChoApp extends StatelessWidget {
  const DiChoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Đi chợ tiện lợi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const RootGate(),
    );
  }
}

/// Chọn màn hình gốc theo trạng thái phiên.
class RootGate extends StatefulWidget {
  const RootGate({super.key});
  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  @override
  void initState() {
    super.initState();
    context.read<SessionService>().restore();
  }

  @override
  Widget build(BuildContext context) {
    final status = context.watch<SessionService>().status;
    return switch (status) {
      SessionStatus.unknown => const Scaffold(body: Center(child: CircularProgressIndicator())),
      SessionStatus.loggedOut => const LoginPage(),
      SessionStatus.loggedIn => const HomeShell(),
    };
  }
}
