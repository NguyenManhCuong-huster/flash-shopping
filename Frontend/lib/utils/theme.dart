import 'package:flutter/material.dart';
import 'app_colors.dart';

/// NFR01: nền trắng, chữ đen, phông Inter 16pt, văn bản căn trái; màu và biểu tượng đồng bộ.
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColor.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColor.primary,
          surface: AppColor.background,
          onSurface: AppColor.text,
          error: AppColor.danger,
        );

    // Cập nhật fontFamily thành Inter theo NFR01
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Inter',
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColor.background,
      textTheme: base.textTheme
          .apply(bodyColor: AppColor.text, displayColor: AppColor.text)
          .copyWith(
            // Đặt font size 16 mặc định cho bodyMedium theo NFR01
            bodyMedium: const TextStyle(
              fontSize: 16,
              color: AppColor.text,
              fontFamily: 'Inter',
            ),
            bodyLarge: const TextStyle(
              fontSize: 18,
              color: AppColor.text,
              fontFamily: 'Inter',
            ),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColor.background,
        foregroundColor: AppColor.text,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false, // Văn bản căn trái theo NFR01
      ),
      cardTheme: CardThemeData(
        color: AppColor.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColor.border),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
        filled: true,
        fillColor: AppColor.inputFill,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColor.background,
        indicatorColor: AppColor.primary.withValues(alpha: 0.15),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Màu theo trạng thái hạn dùng.
Color statusBackgroundColor(String status) => switch (status) {
  'expired' => AppColor.red100,
  'expiring' => AppColor.amber100,
  _ => AppColor.green100,
};

Color statusLabelColor(String status) => switch (status) {
  'expired' => AppColor.red500,
  'expiring' => AppColor.amber500,
  _ => AppColor.green500,
};
String statusLabel(String status, int daysLeft) => switch (status) {
  'expired' => 'Đã hết hạn',
  'expiring' => daysLeft <= 0 ? 'Hết hạn hôm nay' : 'Còn $daysLeft ngày',
  _ => 'Còn $daysLeft ngày',
};
