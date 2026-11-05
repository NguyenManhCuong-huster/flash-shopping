import 'package:flutter/material.dart';

/// NFR01: nền trắng, chữ đen, phông Arial 14pt, văn bản căn trái; màu và biểu tượng đồng bộ.
class AppTheme {
  AppTheme._();

  static const primary = Color(0xFF2E7D32);
  static const warning = Color(0xFFEF6C00);
  static const danger = Color(0xFFC62828);
  static const muted = Color(0xFF616161);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.light).copyWith(
      primary: primary,
      surface: Colors.white,
      onSurface: Colors.black,
      error: danger,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: 'Arial');
    return base.copyWith(
      scaffoldBackgroundColor: Colors.white,
      textTheme: base.textTheme.apply(bodyColor: Colors.black, displayColor: Colors.black).copyWith(
            bodyMedium: const TextStyle(fontSize: 14, color: Colors.black, fontFamily: 'Arial'),
            bodyLarge: const TextStyle(fontSize: 15, color: Colors.black, fontFamily: 'Arial'),
          ),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0, scrolledUnderElevation: 1, centerTitle: false),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      navigationBarTheme: NavigationBarThemeData(backgroundColor: Colors.white, indicatorColor: primary.withValues(alpha: 0.15)),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}

/// Màu theo trạng thái hạn dùng.
Color statusColor(String status) => switch (status) {
      'expired' => AppTheme.danger,
      'expiring' => AppTheme.warning,
      _ => AppTheme.primary,
    };

String statusLabel(String status, int daysLeft) => switch (status) {
      'expired' => 'Đã hết hạn',
      'expiring' => daysLeft <= 0 ? 'Hết hạn hôm nay' : 'Còn $daysLeft ngày',
      _ => 'Còn $daysLeft ngày',
    };
