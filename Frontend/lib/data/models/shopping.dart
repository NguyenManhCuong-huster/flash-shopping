import 'common.dart';
import 'food.dart';
import 'user.dart';
import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

enum ShoppingStatus {
  pending('pending', 'Chưa mua', AppColor.amber50, AppColor.amber500),
  bought('bought', 'Đã mua', AppColor.emerald50, AppColor.emerald500),
  inFridge('in_fridge', 'Đã cất vào tủ lạnh',AppColor.blue50, AppColor.blue500);

  const ShoppingStatus(
    this.value,
    this.label,
    this.badgeColor,
    this.labelColor,
  );
  final String value;
  final String label;
  final Color badgeColor;
  final Color labelColor;
  static ShoppingStatus of(String? value) => ShoppingStatus.values.firstWhere(
    (s) => s.value == value,
    orElse: () => ShoppingStatus.pending,
  );
}

class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.food,
    required this.quantity,
    required this.status,
    this.purchasedQuantity,
    this.purchasedByName,
    this.purchasedAt,
  });

  final int id;
  final Food food;
  final double quantity;
  final ShoppingStatus status;
  final double? purchasedQuantity;
  final String? purchasedByName;
  final DateTime? purchasedAt;
  // bool get isPending => status == ShoppingStatus.pending;
  // bool get isBought => status == ShoppingStatus.bought;
  // bool get isInFridge => status == ShoppingStatus.inFridge;

  factory ShoppingItem.fromJson(Json j) => ShoppingItem(
    id: toInt(j['id']),
    food: Food.fromJson(asJson(j['food'])),
    quantity: toDouble(j['quantity']),
    status: ShoppingStatus.of(j['status']?.toString()),
    purchasedQuantity: toDoubleOrNull(j['purchasedQuantity']),
    purchasedByName: asJson(j['purchasedBy'])['name']?.toString(),
    purchasedAt: toDate(j['purchasedAt']),
  );
}

class ShoppingSession {
  const ShoppingSession({
    required this.id,
    required this.name,
    this.note,
    required this.createdAt,
    this.assignedTo,
    required this.shoppingItems,
    required this.totalItems,
    this.completedAt,
    required this.purchasedItemsCount,
    required this.done,
  });

  final int id;
  final String name;
  final String? note;
  final DateTime createdAt;
  final Member? assignedTo;
  final List<ShoppingItem> shoppingItems;
  final int totalItems;
  final DateTime? completedAt;
  final int purchasedItemsCount;
  final bool done;

  List<ShoppingItem> get pendingItems => shoppingItems.where((item) => item.status == ShoppingStatus.pending).toList();
  List<ShoppingItem> get purchasedItems => shoppingItems.where((item) => item.status == ShoppingStatus.bought || item.status == ShoppingStatus.inFridge).toList();
  List<ShoppingItem> get fridgeItems => shoppingItems.where((item) => item.status == ShoppingStatus.inFridge).toList();

  factory ShoppingSession.fromJson(Json j) {
    final progress = asJson(j['progress']);
    return ShoppingSession(
      id: toInt(j['id']),
      name: j['name']?.toString() ?? '',
      note: j['note']?.toString(),
      createdAt:
          toDate(j['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      assignedTo: j['assignedTo'] is Map
          ? Member.fromJson(asJson(j['assignedTo']))
          : null,
      shoppingItems: asList(j['items']).map(ShoppingItem.fromJson).toList(),
      totalItems: toInt(progress['total']),
      completedAt: toDate(j['completedAt']),
      purchasedItemsCount: toInt(progress['purchased']),
      done: progress['done'] == true,
    );
  }
}

/// Kết quả thêm nhiều mục: mục lỗi được trả rõ để người dùng sửa (UC03 - 5a).
class ItemBatchResult {
  const ItemBatchResult(this.createdCount, this.failed, this.session);
  final int createdCount;
  final List<({String foodName, String message})> failed;
  final ShoppingSession? session;
}

/// Một dòng xác nhận mua gửi lên API (UC04).
class PurchaseItem {
  PurchaseItem({required this.itemId, required this.purchasedQuantity});
  final int itemId;
  double purchasedQuantity;

  Json toJson() => {'itemId': itemId, 'purchasedQuantity': purchasedQuantity};
}
