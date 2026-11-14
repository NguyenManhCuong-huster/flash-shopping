import '../data/models/common.dart';
import '../data/models/shopping.dart';
import '../data/repositories/shopping_repository.dart';

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

  Future<ShoppingSession> session(int id) => _repo.session(id);

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

  Future<void> deleteSession(ShoppingSession session) => _repo.deleteSession(session.id);

  Future<ItemBatchResult> addItem(
    int sessionId,
    List<({String foodName, double quantity})> items,
  ) => _repo.addItems(sessionId, items);
  Future<void> updateItem(
    ShoppingItem item, {
    String? foodName,
    double? quantity,
  }) => _repo.updateItem(
    item.id,
    foodName: foodName != item.food.name ? foodName : null,
    quantity: quantity != item.quantity ? quantity : null,
  );
  Future<void> deleteItem(ShoppingItem item) => _repo.deleteItem(item.id);

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
