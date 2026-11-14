import 'common.dart';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../utils/app_colors.dart';

class Food {
  const Food({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.category,
    required this.unit,
  });
  final int id;
  final String name;
  final String? imageUrl;
  final NamedItem category;
  final NamedItem unit;

  factory Food.fromJson(Json j) => Food(
    id: toInt(j['id']),
    name: j['name']?.toString() ?? '',
    imageUrl: j['imageUrl']?.toString(),
    category: NamedItem.fromJson(asJson(j['category'])),
    unit: NamedItem.fromJson(asJson(j['unit'])),
  );
}

enum StorageLocation {
  cool('cool', 'Ngăn mát', LucideIcons.airVent),
  freezer('freezer', 'Ngăn đông', LucideIcons.snowflake),
  other('other', 'Khác', LucideIcons.box);

  const StorageLocation(this.code, this.label, this.icon);
  final String code;
  final String label;
  final IconData? icon;
  static StorageLocation of(String? code) => StorageLocation.values.firstWhere(
    (l) => l.code == code,
    orElse: () => StorageLocation.cool,
  );
}

enum FridgeItemStatus {
  fresh('fresh', 'Tươi', AppColor.emerald50, AppColor.emerald500),
  expiring('expiring', 'Sắp hết hạn', AppColor.amber50, AppColor.amber500),
  expired('expired', 'Hết hạn', AppColor.red50, AppColor.red500);

  const FridgeItemStatus(this.code, this.label, this.badgeColor, this.labelColor);
  final String code;
  final String label;
  final Color badgeColor;
  final Color labelColor;
  static FridgeItemStatus of(String? code) => FridgeItemStatus.values
      .firstWhere((s) => s.code == code, orElse: () => FridgeItemStatus.fresh);
}

class FridgeItem {
  const FridgeItem({
    required this.id,
    required this.food,
    required this.quantity,
    required this.useWithin,
    required this.location,
    this.note,
    required this.version,
    required this.status,
    required this.daysLeft,
    this.purchasedAt,
    this.storedAt,
  });

  final int id;
  final Food food;
  final double quantity;
  final DateTime useWithin;
  final StorageLocation location;
  final String? note;
  final int version; // Phiên bản bản ghi để phát hiện cập nhật đồng thời (gửi kèm khi sửa/tiêu thụ).
  final FridgeItemStatus status;
  final int daysLeft;
  final DateTime? purchasedAt;
  final DateTime? storedAt;

  factory FridgeItem.fromJson(Json j) => FridgeItem(
    id: toInt(j['id']),
    food: Food.fromJson(asJson(j['food'])),
    quantity: toDouble(j['quantity']),
    useWithin: toDate(j['useWithin']) ?? DateTime.now(),
    location: StorageLocation.of(j['location']?.toString()),
    note: j['note']?.toString(),
    version: toInt(j['version']),
    status: FridgeItemStatus.of(j['status']?.toString()),
    daysLeft: toInt(j['daysLeft']),
    purchasedAt: toDate(j['purchasedAt']),
    storedAt: toDate(j['storedAt']) ?? toDate(j['createdAt']),
  );
}

class FridgeSummary {
  const FridgeSummary({this.total = 0, this.cool = 0, this.freezer = 0, this.fresh = 0, this.expiring = 0, this.expired = 0});
  final int total;
  final int cool;
  final int freezer;
  final int fresh;
  final int expiring;
  final int expired;

  factory FridgeSummary.fromJson(Json j) => FridgeSummary(
    total: toInt(j['total']),
    expiring: toInt(j['expiring']),
    expired: toInt(j['expired']),
  );
}

class FridgeResult {
  const FridgeResult(
    this.items,
    this.summary, {
    this.page = 1,
    this.totalPages = 1,
  });
  final List<FridgeItem> items;
  final FridgeSummary summary;
  final int page;
  final int totalPages;
}
