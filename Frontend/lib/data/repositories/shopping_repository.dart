import '../models/common.dart';
import '../models/shopping.dart';
import '../remote/api_client.dart';

/// UC03, UC04: danh sách mua sắm, nhiệm vụ mua, xác nhận mua.
class ShoppingRepository {
  ShoppingRepository(this._api);
  final ApiClient _api;

  ShoppingList _list(ApiResponse r) => ShoppingList.fromJson(asJson(r.map['list']));

  Future<Paged<ShoppingList>> lists({String? status, bool assignedToMe = false, int page = 1}) async {
    final r = await _api.get('/shopping/task', query: {'status': status, 'assignedToMe': assignedToMe ? 'true' : null, 'page': page, 'limit': 20});
    return Paged.fromJson(r.map, 'lists', ShoppingList.fromJson);
  }

  Future<ShoppingList> list(int id) async => _list(await _api.get('/shopping/$id'));

  Future<ShoppingList> createList({required String name, required String date, String? assignToUsername, String? note}) async =>
      _list(await _api.post('/shopping', data: {'name': name, 'date': date, 'assignToUsername': assignToUsername, 'note': note}));

  /// assignToUsername = '' để bỏ giao.
  Future<ShoppingList> updateList(int listId, {String? name, String? date, String? assignToUsername, String? note}) async => _list(await _api.put('/shopping', data: {
        'listId': listId,
        if (name != null) 'newName': name,
        if (date != null) 'newDate': date,
        if (assignToUsername != null) 'newAssignToUsername': assignToUsername,
        if (note != null) 'newNote': note,
      }));

  Future<void> deleteList(int listId) => _api.delete('/shopping', data: {'listId': listId});

  Future<TaskBatchResult> addTasks(int listId, List<({String foodName, double quantity})> tasks) async {
    try {
      final r = await _api.post('/shopping/task', data: {
        'listId': listId,
        'tasks': tasks.map((t) => {'foodName': t.foodName, 'quantity': t.quantity}).toList(),
      });
      return _batch(r.map);
    } on ApiException catch (e) {
      // Không mục nào được thêm: server trả mã lỗi của mục đầu tiên kèm chi tiết
      if (e.data is Map && (e.data as Map)['failed'] != null) {
        final b = _batch(asJson(e.data));
        throw ApiException(e.code, b.failed.map((f) => '${f.foodName}: ${f.message}').join('\n'), status: e.status, data: e.data);
      }
      rethrow;
    }
  }

  TaskBatchResult _batch(Json d) => TaskBatchResult(
        asList(d['created']).length,
        asList(d['failed']).map((f) => (foodName: f['foodName']?.toString() ?? '?', message: f['message']?.toString() ?? '')).toList(),
        d['list'] is Map ? ShoppingList.fromJson(asJson(d['list'])) : null,
      );

  Future<void> updateTask(int taskId, {String? foodName, double? quantity}) =>
      _api.put('/shopping/task', data: {'taskId': taskId, if (foodName != null) 'newFoodName': foodName, if (quantity != null) 'newQuantity': quantity});

  Future<void> deleteTask(int taskId) => _api.delete('/shopping/task', data: {'taskId': taskId});

  /// Xác nhận mua: gửi lại cùng [idempotencyKey] khi thử lại sẽ không cộng tồn kho lần 2 (NFR10).
  Future<ShoppingList> purchase(int listId, List<PurchaseItem> items, String idempotencyKey) async {
    final r = await _api.post(
      '/shopping/purchase',
      data: {'listId': listId, 'items': items.map((i) => i.toJson()).toList()},
      headers: {'Idempotency-Key': idempotencyKey},
    );
    return _list(r);
  }
}
