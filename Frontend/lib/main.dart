// import 'package:flutter/material.dart';
// import 'package:flutter_localizations/flutter_localizations.dart';
// import 'package:intl/date_symbol_data_local.dart';
// import 'package:provider/provider.dart';

// import './features/auth/session_service.dart';
// import 'bootstrap/app_dependencies.dart';
// import './features/auth/login_page.dart';
// import './core/main_layout.dart';
// import './core/theme.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await initializeDateFormatting('vi');
//   final providers = await createDependencies();
//   runApp(MultiProvider(providers: providers, child: PantrioApp()));
// }

// class PantrioApp extends StatelessWidget {
//   const PantrioApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Đi chợ tiện lợi',
//       debugShowCheckedModeBanner: false,
//       theme: AppTheme.light(),
//       locale: const Locale('vi'),
//       supportedLocales: const [Locale('vi'), Locale('en')],
//       localizationsDelegates: const [
//         GlobalMaterialLocalizations.delegate,
//         GlobalWidgetsLocalizations.delegate,
//         GlobalCupertinoLocalizations.delegate,
//       ],
//       home: const RootGate(),
//     );
//   }
// }

// /// Chọn màn hình gốc theo trạng thái phiên.
// class RootGate extends StatefulWidget {
//   const RootGate({super.key});
//   @override
//   State<RootGate> createState() => _RootGateState();
// }

// class _RootGateState extends State<RootGate> {
//   @override
//   void initState() {
//     super.initState();
//     _restoreSession();
//   }

//   void _restoreSession() {
//     WidgetsBinding.instance.addPostFrameCallback((_) async {
//       // Đợi hoàn tất frame hiện tại trước khi SessionService notifyListeners().
//       await Future<void>.delayed(Duration.zero);
//       if (!mounted) return;
//       await context.read<SessionService>().restore();
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     final status = context.watch<SessionService>().status;
//     return switch (status) {
//       SessionStatus.unknown => const Scaffold(
//         body: Center(child: CircularProgressIndicator()),
//       ),
//       SessionStatus.loggedOut => const LoginPage(),
//       SessionStatus.loggedIn => const MainScreenLayout(),
//     };
//   }
// }
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import './features/auth/session_service.dart';
import 'bootstrap/app_dependencies.dart';
import './features/auth/login_page.dart';
import './core/main_layout.dart';
import 'core/utils/app_colors.dart';
import 'core/utils/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AppSplashScreen()
    ),
  );

  _initApp();
}

Future<void> _initApp() async {
  await initializeDateFormatting('vi', null); // Nên truyền null ở tham số thứ 2 cho an toàn
  
  // Ép kiểu tường minh để MultiProvider không bị crash
  final List<SingleChildWidget> providers = await createDependencies();
  
  // 3. Khởi chạy ứng dụng thật đè lên màn hình chờ
  runApp(
    MultiProvider(
      providers: providers, 
      child: const PantrioApp(),
    )
  );
}

class AppSplashScreen extends StatelessWidget {
  const AppSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.emerald500,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Image.asset(
              'assets/images/logo_1.png',
              height: 120,
            ),            
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColor.white),
            ),
          ],
        ),
      ),
    );
  }
}

class PantrioApp extends StatelessWidget {
  const PantrioApp({super.key});

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

class RootGate extends StatefulWidget {
  const RootGate({super.key});
  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  void _restoreSession() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SessionService>().restore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = context.watch<SessionService>().status;
    return switch (status) {
      SessionStatus.unknown => const AppSplashScreen(),
      SessionStatus.loggedOut => const LoginPage(),
      SessionStatus.loggedIn => const MainScreenLayout(),
    };
  }
}