import '../models/common.dart';
import '../models/shopping.dart';
import '../remote/api_client.dart';

/// UC03, UC04: danh sách mua sắm, nhiệm vụ mua, xác nhận mua.
class ShoppingRepository {
  ShoppingRepository(this._api);
  final ApiClient _api;

  ShoppingSession _session(ApiResponse r) =>
      ShoppingSession.fromJson(asJson(r.map['list']));

  Future<Paged<ShoppingSession>> sessions({
    String? status,
    bool assignedToMe = false,
    int page = 1,
  }) async {
    final r = await _api.get(
      '/shopping/item',
      query: {
        'status': status,
        'assignedToMe': assignedToMe ? 'true' : null,
        'page': page,
        'limit': 20,
      },
    );
    return Paged.fromJson(r.map, 'lists', ShoppingSession.fromJson);
  }

  Future<ShoppingSession> session(int id) async =>
      _session(await _api.get('/shopping/$id'));

  Future<ShoppingSession> createSession({
    required String name,
    String? assignToUsername,
    String? note,
  }) async => _session(
    await _api.post(
      '/shopping',
      data: {'name': name, 'assignToUsername': assignToUsername, 'note': note},
    ),
  );

  /// assignToUsername = '' để bỏ giao.
  Future<ShoppingSession> updateSession(
    int sessionId, {
    String? name,
    String? assignToUsername,
    String? note,
  }) async => _session(
    await _api.put(
      '/shopping',
      data: {
        'listId': sessionId,
        if (name != null) 'newName': name,
        if (assignToUsername != null) 'newAssignToUsername': assignToUsername,
        if (note != null) 'newNote': note,
      },
    ),
  );

  Future<void> deleteSession(int listId) =>
      _api.delete('/shopping', data: {'listId': listId});

  Future<ItemBatchResult> addItems(
    int sessionId,
    List<({String foodName, double quantity})> items,
  ) async {
    try {
      final r = await _api.post(
        '/shopping/item',
        data: {
          'listId': sessionId,
          'items': items
              .map((t) => {'foodName': t.foodName, 'quantity': t.quantity})
              .toList(),
        },
      );
      return _batch(r.map);
    } on ApiException catch (e) {
      // Không mục nào được thêm: server trả mã lỗi của mục đầu tiên kèm chi tiết
      if (e.data is Map && (e.data as Map)['failed'] != null) {
        final b = _batch(asJson(e.data));
        throw ApiException(
          e.code,
          b.failed.map((f) => '${f.foodName}: ${f.message}').join('\n'),
          status: e.status,
          data: e.data,
        );
      }
      rethrow;
    }
  }

  ItemBatchResult _batch(Json d) => ItemBatchResult(
    asList(d['created']).length,
    asList(d['failed'])
        .map(
          (f) => (
            foodName: f['foodName']?.toString() ?? '?',
            message: f['message']?.toString() ?? '',
          ),
        )
        .toList(),
    d['list'] is Map ? ShoppingSession.fromJson(asJson(d['list'])) : null,
  );

  Future<void> updateItem(int itemId, {String? foodName, double? quantity}) =>
      _api.put(
        '/shopping/item',
        data: {
          'itemId': itemId,
          if (foodName != null) 'newFoodName': foodName,
          if (quantity != null) 'newQuantity': quantity,
        },
      );

  Future<void> deleteItem(int itemId) =>
      _api.delete('/shopping/item', data: {'itemId': itemId});

  /// Xác nhận mua: gửi lại cùng [idempotencyKey] khi thử lại sẽ không cộng tồn kho lần 2 (NFR10).
  Future<ShoppingSession> purchase(
    int sessionId,
    List<PurchaseItem> items,
    String idempotencyKey,
  ) async {
    final r = await _api.post(
      '/shopping/purchase',
      data: {'listId': sessionId, 'items': items.map((i) => i.toJson()).toList()},
      headers: {'Idempotency-Key': idempotencyKey},
    );
    return _session(r);
  }

  Future<ShoppingSession> addPurchasedToFridge(
    int sessionId,
    List<Json> items,
    String idempotencyKey,
  ) async {
    final r = await _api.post(
      '/fridge/from-purchase',
      data: {'listId': sessionId, 'items': items},
      headers: {'Idempotency-Key': idempotencyKey},
    );
    return _session(r);
  }
}
