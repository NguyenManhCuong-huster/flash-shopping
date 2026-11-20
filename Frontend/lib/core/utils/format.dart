import 'package:intl/intl.dart';

class FormatUtils {
  // Ngày/tháng/năm
  // Ví dụ: 12/11/2026
  static String formatDate(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy', 'vi').format(dateTime);
  }

  // Ngày/tháng/năm, giờ:phút (24 tiếng)
  // Ví dụ: 12/11/2026, 21:44
  static String formatDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy, HH:mm', 'vi').format(dateTime);
  }

  // Ngày/tháng/năm - Thứ đầy đủ
  // Ví dụ: 12/11/2026 - Thứ Năm
  static String formatDateWithWeekday(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy - EEEE', 'vi').format(dateTime);
  }

  // Thứ đầy đủ - ngày/tháng/năm
  // Ví dụ: Thứ Năm - 12/11/2026
  static String formatWeekdayWithDate(DateTime dateTime) {
    return DateFormat('EEEE - dd/MM/yyyy', 'vi').format(dateTime);
  }

  // Lấy tên thứ viết tắt
  // Ví dụ: T5
  static String formatWeekday(DateTime dateTime) {
    return DateFormat('EEE', 'vi').format(dateTime);
  }

  // Chuyển chuỗi ISO 8601 thành ngày/tháng/năm
  // Ví dụ: 2026-11-12T10:30:00 -> 12/11/2026
  static String formatIsoDate(String iso) {
    if (iso.isEmpty) return '';

    final dateTime = DateTime.tryParse(iso);
    if (dateTime == null) return '';

    return formatDate(dateTime);
  }

  // Hiển thị thời gian tương đối
  // Ví dụ: vừa xong, 5 phút trước, 3 giờ trước, 2 ngày trước
  // Nếu quá 7 ngày: hiển thị ngày/tháng/năm
  static String relativeTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inMinutes < 1) return 'vừa xong';
    if (difference.inHours < 1) {
      return '${difference.inMinutes} phút trước';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours} giờ trước';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays} ngày trước';
    }

    return formatDate(dateTime);
  }

  // Chỉ lấy ngày, bỏ giờ/phút/giây
  // Ví dụ: 12/11/2026 21:44 -> 12/11/2026 00:00
  static DateTime dateOnly(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  /// 1.0 -> "1", 0.250 -> "0,25"
  static String formatQuantity(num q) {
    final s = q.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
    return s.replaceAll('.', ',');
  }

  static String formatQuantityUnit(num q, String unit) => '${formatQuantity(q)} $unit';
}
