import 'common.dart';

class Food {
  const Food({required this.id, required this.name, this.imageUrl, required this.category, required this.unit});
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

/// Vị trí lưu trữ trong tủ lạnh.
enum StorageLocation {
  cool('cool', 'Ngăn mát'),
  freezer('freezer', 'Ngăn đông'),
  other('other', 'Khác');

  const StorageLocation(this.code, this.label);
  final String code;
  final String label;

  static StorageLocation of(String? code) =>
      StorageLocation.values.firstWhere((l) => l.code == code, orElse: () => StorageLocation.cool);
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
  });

  final int id;
  final Food food;
  final double quantity;
  final DateTime useWithin;
  final StorageLocation location;
  final String? note;

  /// Phiên bản bản ghi để phát hiện cập nhật đồng thời (gửi kèm khi sửa/tiêu thụ).
  final int version;

  /// fresh | expiring | expired
  final String status;
  final int daysLeft;

  factory FridgeItem.fromJson(Json j) => FridgeItem(
        id: toInt(j['id']),
        food: Food.fromJson(asJson(j['food'])),
        quantity: toDouble(j['quantity']),
        useWithin: toDate(j['useWithin']) ?? DateTime.now(),
        location: StorageLocation.of(j['location']?.toString()),
        note: j['note']?.toString(),
        version: toInt(j['version']),
        status: j['status']?.toString() ?? 'fresh',
        daysLeft: toInt(j['daysLeft']),
      );
}

class FridgeSummary {
  const FridgeSummary({this.total = 0, this.expiring = 0, this.expired = 0});
  final int total;
  final int expiring;
  final int expired;

  factory FridgeSummary.fromJson(Json j) =>
      FridgeSummary(total: toInt(j['total']), expiring: toInt(j['expiring']), expired: toInt(j['expired']));
}

class FridgeResult {
  const FridgeResult(this.items, this.summary, {this.page = 1, this.totalPages = 1});
  final List<FridgeItem> items;
  final FridgeSummary summary;
  final int page;
  final int totalPages;
}
