import 'dart:math';

/// Quy tắc kiểm tra đầu vào phía ứng dụng. Thông báo chỉ rõ trường sai, lý do và cách sửa (NFR05).
/// Backend vẫn kiểm tra lại mọi dữ liệu.
class Validators {
  Validators._();

  static String? required(String? v, String field) => (v == null || v.trim().isEmpty) ? '$field không được để trống' : null;

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email không được để trống';
    final ok = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(v.trim());
    return ok ? null : 'Email không hợp lệ, ví dụ đúng: ten@gmail.com';
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Mật khẩu không được để trống';
    if (v.length < 6 || v.length > 20) return 'Mật khẩu cần từ 6 đến 20 ký tự (hiện có ${v.length})';
    return null;
  }

  static String? name(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Họ tên không được để trống';
    if (s.length < 4 || s.length > 29) return 'Họ tên cần từ 4 đến 29 ký tự';
    return null;
  }

  static String? username(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Tên người dùng không được để trống';
    if (!RegExp(r'^[A-Za-z0-9_.]{4,14}$').hasMatch(s)) {
      return 'Tên người dùng 4-14 ký tự, chỉ gồm chữ không dấu, số, dấu chấm hoặc gạch dưới';
    }
    return null;
  }

  static String? otp(String? v) => RegExp(r'^\d{6}$').hasMatch(v?.trim() ?? '') ? null : 'Mã xác minh gồm 6 chữ số trong email';

  /// Số lượng dương, chấp nhận dấu phẩy thập phân.
  static String? quantity(String? v, {String field = 'Số lượng'}) {
    final n = parseQuantity(v);
    if (v == null || v.trim().isEmpty) return '$field không được để trống';
    if (n == null) return '$field phải là số, ví dụ 1.5';
    if (n <= 0) return '$field phải lớn hơn 0';
    return null;
  }

  static double? parseQuantity(String? v) => v == null ? null : double.tryParse(v.trim().replaceAll(',', '.'));

  static String? maxLength(String? v, int max, String field) => (v != null && v.length > max) ? '$field tối đa $max ký tự' : null;
}

/// 'YYYY-MM-DD' theo ngày địa phương.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseIsoDate(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

/// Khóa chống lặp ngẫu nhiên cho thao tác xác nhận mua.
String newIdempotencyKey() {
  final r = Random.secure();
  return List.generate(24, (_) => r.nextInt(16).toRadixString(16)).join();
}
