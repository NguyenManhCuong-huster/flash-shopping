import 'common.dart';

/// Thông báo trong ứng dụng (nhắc hạn sử dụng - UC06).
class AppNotification {
  const AppNotification({required this.id, required this.type, required this.title, required this.body, required this.data, required this.read, required this.createdAt});
  final int id;
  final String type;
  final String title;
  final String body;
  final Json data;
  final bool read;
  final DateTime createdAt;

  int? get fridgeItemId => data['fridgeItemId'] == null ? null : toInt(data['fridgeItemId']);

  factory AppNotification.fromJson(Json j) => AppNotification(
        id: toInt(j['id']),
        type: j['type']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        body: j['body']?.toString() ?? '',
        data: asJson(j['data']),
        read: j['read'] == true,
        createdAt: toDate(j['createdAt']) ?? DateTime.now(),
      );
}

class FoodStat {
  const FoodStat(this.foodName, this.unit, this.category, this.purchased, this.added, this.consumed, this.discarded);
  final String foodName;
  final String unit;
  final String category;
  final double purchased;
  final double added;
  final double consumed;
  final double discarded;

  factory FoodStat.fromJson(Json j) => FoodStat(
        j['foodName']?.toString() ?? '',
        j['unit']?.toString() ?? '',
        j['category']?.toString() ?? '',
        toDouble(j['purchased']),
        toDouble(j['added']),
        toDouble(j['consumed']),
        toDouble(j['discarded']),
      );
}

class CategoryStat {
  const CategoryStat(this.category, this.inEvents, this.consumeEvents, this.discardEvents);
  final String category;
  final int inEvents;
  final int consumeEvents;
  final int discardEvents;

  factory CategoryStat.fromJson(Json j) =>
      CategoryStat(j['category']?.toString() ?? '', toInt(j['inEvents']), toInt(j['consumeEvents']), toInt(j['discardEvents']));
}

/// Báo cáo mua sắm & tiêu thụ (UC10).
class StatsReport {
  const StatsReport({
    required this.from,
    required this.to,
    required this.totals,
    required this.wasteRate,
    required this.lists,
    required this.tasks,
    required this.boughtTasks,
    required this.byFood,
    required this.byCategory,
  });

  final String from;
  final String to;
  final Map<String, int> totals;
  final double wasteRate;
  final int lists;
  final int tasks;
  final int boughtTasks;
  final List<FoodStat> byFood;
  final List<CategoryStat> byCategory;

  factory StatsReport.fromJson(Json j) {
    final shopping = asJson(j['shopping']);
    return StatsReport(
      from: j['from']?.toString() ?? '',
      to: j['to']?.toString() ?? '',
      totals: asJson(j['totals']).map((k, v) => MapEntry(k, toInt(v))),
      wasteRate: toDouble(j['wasteRate']),
      lists: toInt(shopping['lists']),
      tasks: toInt(shopping['tasks']),
      boughtTasks: toInt(shopping['boughtTasks']),
      byFood: asList(j['byFood']).map(FoodStat.fromJson).toList(),
      byCategory: asList(j['byCategory']).map(CategoryStat.fromJson).toList(),
    );
  }
}

class StockEvent {
  const StockEvent({required this.id, required this.type, required this.foodName, required this.unit, required this.quantity, this.actorName, this.note, required this.occurredAt});
  final int id;

  /// purchase | add | consume | discard | adjust | remove
  final String type;
  final String foodName;
  final String unit;
  final double quantity;
  final String? actorName;
  final String? note;
  final DateTime occurredAt;

  factory StockEvent.fromJson(Json j) => StockEvent(
        id: toInt(j['id']),
        type: j['type']?.toString() ?? '',
        foodName: j['foodName']?.toString() ?? '',
        unit: j['unit']?.toString() ?? '',
        quantity: toDouble(j['quantity']),
        actorName: asJson(j['actor'])['name']?.toString(),
        note: j['note']?.toString(),
        occurredAt: toDate(j['occurredAt']) ?? DateTime.now(),
      );
}

/// Nhật ký hệ thống (trang quản trị).
class AuditLog {
  const AuditLog({required this.id, required this.action, this.entityType, this.entityId, required this.source, this.actorName, this.actorEmail, required this.occurredAt, required this.metadata});
  final int id;
  final String action;
  final String? entityType;
  final int? entityId;
  final String source;
  final String? actorName;
  final String? actorEmail;
  final DateTime occurredAt;
  final Json metadata;

  factory AuditLog.fromJson(Json j) {
    final actor = asJson(j['actor']);
    return AuditLog(
      id: toInt(j['id']),
      action: j['action']?.toString() ?? '',
      entityType: j['entityType']?.toString(),
      entityId: j['entityId'] == null ? null : toInt(j['entityId']),
      source: j['source']?.toString() ?? 'app',
      actorName: actor['name']?.toString(),
      actorEmail: actor['email']?.toString(),
      occurredAt: toDate(j['occurredAt']) ?? DateTime.now(),
      metadata: asJson(j['metadata']),
    );
  }
}
