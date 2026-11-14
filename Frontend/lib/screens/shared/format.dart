import 'package:intl/intl.dart';

import '../../application/validation/validators.dart';



/// 1.0 -> "1", 0.250 -> "0,25"
String fmtQty(num q) {
  final s = q.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
  return s.replaceAll('.', ',');
}

String fmtQtyUnit(num q, String unit) => '${fmtQty(q)} $unit';



