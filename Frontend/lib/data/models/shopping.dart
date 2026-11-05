import 'common.dart';
import 'food.dart';
import 'user.dart';

class ShoppingTask {
  const ShoppingTask({
    required this.id,
    required this.food,
    required this.quantity,
    required this.status,
    this.boughtQuantity,
    this.boughtByName,
    this.boughtAt,
  });

  final int id;
  final Food food;
  final double quantity;

  /// pending | bought
  final String status;
  final double? boughtQuantity;
  final String? boughtByName;
  final DateTime? boughtAt;

  bool get isBought => status == 'bought';

  factory ShoppingTask.fromJson(Json j) => ShoppingTask(
        id: toInt(j['id']),
        food: Food.fromJson(asJson(j['food'])),
        quantity: toDouble(j['quantity']),
        status: j['status']?.toString() ?? 'pending',
        boughtQuantity: toDoubleOrNull(j['boughtQuantity']),
        boughtByName: asJson(j['boughtBy'])['name']?.toString(),
        boughtAt: toDate(j['boughtAt']),
      );
}

class ShoppingList {
  const ShoppingList({
    required this.id,
    required this.name,
    this.note,
    required this.date,
    this.assignedTo,
    required this.tasks,
    required this.total,
    required this.bought,
    required this.done,
  });

  final int id;
  final String name;
  final String? note;

  /// Ngày đi chợ dạng YYYY-MM-DD
  final String date;
  final Member? assignedTo;
  final List<ShoppingTask> tasks;
  final int total;
  final int bought;
  final bool done;

  List<ShoppingTask> get pendingTasks => tasks.where((t) => !t.isBought).toList();

  factory ShoppingList.fromJson(Json j) {
    final progress = asJson(j['progress']);
    return ShoppingList(
      id: toInt(j['id']),
      name: j['name']?.toString() ?? '',
      note: j['note']?.toString(),
      date: j['date']?.toString() ?? '',
      assignedTo: j['assignedTo'] is Map ? Member.fromJson(asJson(j['assignedTo'])) : null,
      tasks: asList(j['tasks']).map(ShoppingTask.fromJson).toList(),
      total: toInt(progress['total']),
      bought: toInt(progress['bought']),
      done: progress['done'] == true,
    );
  }
}

/// Kết quả thêm nhiều mục: mục lỗi được trả rõ để người dùng sửa (UC03 - 5a).
class TaskBatchResult {
  const TaskBatchResult(this.createdCount, this.failed, this.list);
  final int createdCount;
  final List<({String foodName, String message})> failed;
  final ShoppingList? list;
}

/// Một dòng xác nhận mua gửi lên API (UC04).
class PurchaseItem {
  PurchaseItem({required this.taskId, required this.boughtQuantity, this.addToFridge = true, this.useWithin, this.location = StorageLocation.cool});
  final int taskId;
  double boughtQuantity;
  bool addToFridge;

  /// Ngày hết hạn YYYY-MM-DD
  String? useWithin;
  StorageLocation location;

  Json toJson() => {
        'taskId': taskId,
        'boughtQuantity': boughtQuantity,
        'addToFridge': addToFridge,
        if (addToFridge) 'useWithin': useWithin,
        if (addToFridge) 'location': location.code,
      };
}
