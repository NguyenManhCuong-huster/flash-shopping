import 'package:intl/intl.dart';

import '../../application/validation/validators.dart';

/// NFR02: ngày hiển thị dd/MM/yyyy; số lượng luôn kèm đơn vị.
final _date = DateFormat('dd/MM/yyyy');
final _dateTime = DateFormat('dd/MM/yyyy HH:mm');
final _weekday = DateFormat('EEE', 'vi');

String fmtDate(DateTime d) => _date.format(d);
String fmtDateTime(DateTime d) => _dateTime.format(d);
String fmtIsoDate(String iso) => iso.isEmpty ? '' : _date.format(parseIsoDate(iso));
String fmtWeekday(DateTime d) => _weekday.format(d);

/// 1.0 -> "1", 0.250 -> "0,25"
String fmtQty(num q) {
  final s = q.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
  return s.replaceAll('.', ',');
}

String fmtQtyUnit(num q, String unit) => '${fmtQty(q)} $unit';

String relativeTime(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'vừa xong';
  if (d.inHours < 1) return '${d.inMinutes} phút trước';
  if (d.inDays < 1) return '${d.inHours} giờ trước';
  if (d.inDays < 7) return '${d.inDays} ngày trước';
  return fmtDate(t);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
