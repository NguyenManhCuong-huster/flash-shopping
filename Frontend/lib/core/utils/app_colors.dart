import 'package:flutter/material.dart';

class AppColor {
  AppColor._();
  // ===== brand =====
  static const Color primary = AppColor.emerald500; // Màu chính
  static const Color secondary = AppColor.amber500; // Màu phụ
  static const Color tertiary = Color(0xFF34D399); // Màu thứ ba
  static const Color accent = Color(0xFF6EE7B7); // Màu nhấn
  static const Color info = Color(0xFF3B82F6); // Màu thông tin
  static const Color warning = Color(0xFFF59E0B); // Màu cảnh báo
  static const Color danger = Color(0xFFEF4444); // Màu lỗi
  static const Color success = Color(0xFF10B981); // Màu thành công
  static const Color background = Color(0xFFF3F4F6); // Màu nền
  static const Color text = AppColor.gray800; // Màu chữ
  static const Color muted = AppColor.gray400; // Màu chữ phụ
  static const Color border = Color(0xFFE5E7EB); // Màu viền
  static const Color inputFill = Color(0xFFF9FAFB); // Màu nền ô nhập
  static const Color divider = Color(0xFFE5E7EB); // Màu divider
  static const Color onPrimary = Color(0xFFFFFFFF); // Màu chữ trên màu chính
  static const Color onSecondary = Color(0xFFFFFFFF); // Màu chữ trên màu phụ
  static const Color onBackground = Color(0xFF111827); // Màu chữ trên nền
  static const Color onSurface = Color(0xFF111827); // Màu chữ trên bề mặt
  static const Color onError = Color(0xFFFFFFFF); // Màu chữ trên màu lỗi
  static const Color onSuccess = Color(0xFFFFFFFF); // Màu chữ trên màu thành công
  static const Color onWarning = Color(0xFF111827); // Màu chữ trên màu cảnh báo
  static const Color onInfo = Color(0xFFFFFFFF); // Màu chữ trên màu thông tin
  static const Color onAccent = Color(0xFF111827); // Màu chữ trên màu nhấn
  static const Color onTertiary = Color(0xFF111827); // Màu chữ trên màu thứ ba

  static const Color white = Color(0xFFFFFFFF);
  static const Color transparent = Color(0x00000000);
  // ===== gray =====
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray800 = Color(0xFF1F2937);
  static const Color gray900 = Color(0xFF111827);

  // ===== emerald =====
  static const Color emerald50 = Color(0xFFECFDF5);
  static const Color emerald100 = Color(0xFFD1FAE5);
  static const Color emerald200 = Color(0xFFA7F3D0);
  static const Color emerald300 = Color(0xFF6EE7B7);
  static const Color emerald400 = Color(0xFF34D399);
  static const Color emerald500 = Color(0xFF10B981);
  static const Color emerald600 = Color(0xFF059669);
  static const Color emerald700 = Color(0xFF047857);
  static const Color emerald800 = Color(0xFF065F46);
  static const Color emerald900 = Color(0xFF064E3B);

  // ===== amber =====
  static const Color amber50 = Color(0xFFFFFBEB);
  static const Color amber100 = Color(0xFFFEF3C7);
  static const Color amber200 = Color(0xFFFDE68A);
  static const Color amber300 = Color(0xFFFCD34D);
  static const Color amber400 = Color(0xFFFBBF24);
  static const Color amber500 = Color(0xFFF59E0B);
  static const Color amber600 = Color(0xFFD97706);
  static const Color amber700 = Color(0xFFB45309);
  static const Color amber800 = Color(0xFF92400E);
  static const Color amber900 = Color(0xFF78350F);

  // ===== red =====
  static const Color red50 = Color(0xFFFEF2F2);
  static const Color red100 = Color(0xFFFEE5E5);
  static const Color red200 = Color(0xFFFECACA);
  static const Color red300 = Color(0xFFFEA7A7);
  static const Color red400 = Color(0xFFF98C8C);
  static const Color red500 = Color(0xFFF15A5A);
  static const Color red600 = Color(0xFFE53935);
  static const Color red700 = Color(0xFFD32F2F);
  static const Color red800 = Color(0xFFC62828);
  static const Color red900 = Color(0xFFB71C1C);

  // ===== blue =====
  static const Color blue50 = Color(0xFFE3F2FD);
  static const Color blue100 = Color(0xFFBBDEFB);
  static const Color blue200 = Color(0xFF90CAF9);
  static const Color blue300 = Color(0xFF64B5F6);
  static const Color blue400 = Color(0xFF42A5F5);
  static const Color blue500 = Color(0xFF2196F3);
  static const Color blue600 = Color(0xFF1E88E5);
  static const Color blue700 = Color(0xFF1976D2);
  static const Color blue800 = Color(0xFF1565C0);
  static const Color blue900 = Color(0xFF0D47A1);

  // ===== sky =====
  static const Color sky50 = Color(0xFFE0F2FE);
  static const Color sky100 = Color(0xFFBAE6FD);
  static const Color sky200 = Color(0xFF7DD3FC);
  static const Color sky300 = Color(0xFF38BDF8);
  static const Color sky400 = Color(0xFF0EA5E9);
  static const Color sky500 = Color(0xFF0284C7);
  static const Color sky600 = Color(0xFF0369A1);
  static const Color sky700 = Color(0xFF075985);
  static const Color sky800 = Color(0xFF0C4A6E);
  static const Color sky900 = Color(0xFF082F49);

  // ===== green =====
  static const Color green50 = Color(0xFFE6F4EA);
  static const Color green100 = Color(0xFFC8E6C9);
  static const Color green200 = Color(0xFFA5D6A7);
  static const Color green300 = Color(0xFF81C784);
  static const Color green400 = Color(0xFF66BB6A);
  static const Color green500 = Color(0xFF4CAF50);
  static const Color green600 = Color(0xFF43A047);
  static const Color green700 = Color(0xFF388E3C);
  static const Color green800 = Color(0xFF2E7D32);
  static const Color green900 = Color(0xFF1B5E20);

  // ===== purple =====
  static const Color purple50 = Color(0xFFF3E8FF);
  static const Color purple100 = Color(0xFFE9D5FF);
  static const Color purple200 = Color(0xFFD8B4FE);
  static const Color purple300 = Color(0xFFC084FC);
  static const Color purple400 = Color(0xFFA855F7);
  static const Color purple500 = Color(0xFF9333EA);
  static const Color purple600 = Color(0xFF7E22CE);
  static const Color purple700 = Color(0xFF6B21A8);
  static const Color purple800 = Color(0xFF581C87);
  static const Color purple900 = Color(0xFF3B0764);

  static const Color surface = Color(0xFFFFFFFF);    // Mềm thiết bị
  static const Color hint = Color(0xFF9E9E9E);       // Gợi ý trong ô nhập


  // ===== Màu trạng thái hạn dùng =====
  static const Color expired = Color(0xFFC62828);
  static const Color expiring = Color(0xFFEF6C00);
  static const Color fresh = Color(0xFF2E7D32);
}
