import '../../core/model_common.dart';
import '../food/food.dart';
import '../user/user.dart';
import 'shopping.dart';
import 'shopping_repository.dart';

/// UC03 - Quản lý danh sách mua sắm, UC04 - Hoàn thành mua sắm.
class ShoppingService {
  ShoppingService(this._repo);
  final ShoppingRepository _repo;

  Future<Paged<ShoppingSession>> sessions({
    bool done = false,
    bool assignedToMe = false,
    int page = 1,
  }) => _repo.sessions(
    status: done ? 'done' : 'open',
    assignedToMe: assignedToMe,
    page: page,
  );

  Future<ShoppingSession> getSession(int id) => _repo.session(id);

  /// Tạo danh sách và thêm mục là HAI thao tác API riêng (báo cáo mục 5.1.4): nếu thêm mục lỗi,
  /// danh sách đã tạo vẫn tồn tại và giao diện cho thử lại phần chưa lưu.
  Future<ShoppingSession> createSession({
    required String name,
    String? assignToUsername,
    String? note,
  }) => _repo.createSession(
    name: name.trim(),
    assignToUsername: assignToUsername,
    note: note?.trim(),
  );

  Future<ShoppingSession> updateSession(
    ShoppingSession session, {
    String? name,
    String? assignToUsername,
    String? note,
  }) => _repo.updateSession(
    session.id,
    name: name != null && name.trim() != session.name ? name.trim() : null,
    assignToUsername: assignToUsername != (session.assignedTo?.username ?? '')
        ? (assignToUsername ?? '')
        : null,
    note: note != (session.note ?? '') ? note : null,
  );

  Future<void> deleteSession(ShoppingSession session) =>
      _repo.deleteSession(session.id);

  // Future<List<Food>> searchGroupFoods({
  //   required int groupId,
  //   required String query,
  // }) => _repo.searchGroupFoods(groupId: groupId, query: query);
  
  Future<ItemBatchResult> addItem({
    required int sessionId,
    required int? foodId,
    required String foodName,
    required int? categoryId,
    required int? unitId,
    required double quantity,
    String? note,
  }) => _repo.addItem(
    sessionId: sessionId,
    foodId: foodId,
    foodName: foodName.trim(),
    categoryId: categoryId,
    unitId: unitId,
    quantity: quantity,
    note: note?.trim(),
  );
  Future<void> updateItem(int itemId, {double? quantity, String? note}) =>
      _repo.updateItem(itemId, quantity: quantity, note: note);
  Future<void> deleteItem(int itemId) => _repo.deleteItem(itemId);

  /// Chỉ xác nhận các món đã mua. Nhập tủ lạnh là thao tác riêng ở phiên sau.
  Future<ShoppingSession> purchase(
    ShoppingSession session,
    List<PurchaseItem> items,
    String idempotencyKey,
  ) => _repo.purchase(session.id, items, idempotencyKey);

  Future<ShoppingSession> addPurchasedToFridge(
    ShoppingSession session,
    List<Json> items,
    String idempotencyKey,
  ) => _repo.addPurchasedToFridge(session.id, items, idempotencyKey);
}
