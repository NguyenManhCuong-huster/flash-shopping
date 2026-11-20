import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../core/utils/app_colors.dart';

/// Kiểu dữ liệu dùng chung giữa các model.
typedef Json = Map<String, dynamic>;

double toDouble(dynamic v) => v == null
    ? 0
    : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
double? toDoubleOrNull(dynamic v) => v == null ? null : toDouble(v);
int toInt(dynamic v) =>
    v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);
DateTime? toDate(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
Json asJson(dynamic v) =>
    (v as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
List<Json> asList(dynamic v) =>
    ((v as List?) ?? const []).map((e) => asJson(e)).toList();

enum CategoryType {
  vegetable(1, 'Rau quả', LucideIcons.leaf, AppColor.green50, AppColor.green500),
  meat(2, 'Thịt', LucideIcons.drumstick,  AppColor.red50, AppColor.red500),
  seafood(3, 'Hải sản', Icons.set_meal_outlined,  AppColor.blue50, AppColor.blue500), // Có thể kết hợp Material Icons nếu Lucide thiếu
  dryFood(4, 'Đồ khô', LucideIcons.wheat, AppColor.amber50, AppColor.amber500),
  dairy(5, 'Sữa & trứng', LucideIcons.egg, AppColor.amber50, AppColor.amber500),
  spice(6, 'Gia vị', LucideIcons.droplet, AppColor.amber50, AppColor.amber500),
  unknown(0, 'Khác', LucideIcons.helpCircle, AppColor.gray50, AppColor.gray500); // Giá trị dự phòng (Fallback)

  final int id;
  final String label;
  final IconData icon;
  final Color badgeColor;
  final Color color;

  const CategoryType(this.id, this.label, this.icon, this.badgeColor, this.color);

  static CategoryType getCategoryTypeFromId(int id) {
    return CategoryType.values.firstWhere(
      (type) => type.id == id,
      orElse: () => CategoryType.unknown,
    );
  }
}
class NamedItem {
  const NamedItem(this.id, this.name, {this.type});
  final int id;
  final String name;
  final String? type;

  factory NamedItem.fromJson(Json j) => NamedItem(
    toInt(j['id']),
    j['name']?.toString() ?? '',
    type: j['type']?.toString(),
  );

  @override
  bool operator ==(Object other) => other is NamedItem && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

/// Kết quả phân trang (tối đa 50 bản ghi mỗi lần tải - NFR08).
class Paged<T> {
  const Paged(this.items, {this.page = 1, this.totalPages = 1, this.total = 0});
  final List<T> items;
  final int page;
  final int totalPages;
  final int total;

  bool get hasMore => page < totalPages;

  factory Paged.fromJson(Json j, String key, T Function(Json) parse) => Paged(
    asList(j[key]).map(parse).toList(),
    page: toInt(j['page'] ?? 1),
    totalPages: toInt(j['totalPages'] ?? 1),
    total: toInt(j['total'] ?? 0),
  );
}
