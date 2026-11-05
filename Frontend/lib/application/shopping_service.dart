import '../data/models/common.dart';
import '../data/models/shopping.dart';
import '../data/repositories/shopping_repository.dart';
import 'validation/validators.dart';

/// UC03 - Quản lý danh sách mua sắm, UC04 - Hoàn thành mua sắm.
class ShoppingService {
  ShoppingService(this._repo);
  final ShoppingRepository _repo;

  Future<Paged<ShoppingList>> lists({bool done = false, bool assignedToMe = false, int page = 1}) =>
      _repo.lists(status: done ? 'done' : 'open', assignedToMe: assignedToMe, page: page);

  Future<ShoppingList> list(int id) => _repo.list(id);

  /// Tạo danh sách và thêm mục là HAI thao tác API riêng (báo cáo mục 5.1.4): nếu thêm mục lỗi,
  /// danh sách đã tạo vẫn tồn tại và giao diện cho thử lại phần chưa lưu.
  Future<ShoppingList> createList({required String name, required DateTime date, String? assignToUsername, String? note}) =>
      _repo.createList(name: name.trim(), date: isoDate(date), assignToUsername: assignToUsername, note: note?.trim());

  Future<ShoppingList> updateList(ShoppingList list, {String? name, DateTime? date, String? assignToUsername, String? note}) => _repo.updateList(
        list.id,
        name: name != null && name.trim() != list.name ? name.trim() : null,
        date: date != null && isoDate(date) != list.date ? isoDate(date) : null,
        assignToUsername: assignToUsername != (list.assignedTo?.username ?? '') ? (assignToUsername ?? '') : null,
        note: note != (list.note ?? '') ? note : null,
      );

  Future<void> deleteList(ShoppingList list) => _repo.deleteList(list.id);

  Future<TaskBatchResult> addTasks(int listId, List<({String foodName, double quantity})> tasks) => _repo.addTasks(listId, tasks);
  Future<void> updateTask(ShoppingTask task, {String? foodName, double? quantity}) =>
      _repo.updateTask(task.id, foodName: foodName != task.food.name ? foodName : null, quantity: quantity != task.quantity ? quantity : null);
  Future<void> deleteTask(ShoppingTask task) => _repo.deleteTask(task.id);

  /// Xác nhận mua và đưa vào tủ lạnh. [idempotencyKey] được giữ nguyên khi người dùng bấm "Thử lại"
  /// sau lỗi mạng nên backend không cộng tồn kho lần thứ hai.
  Future<ShoppingList> purchase(ShoppingList list, List<PurchaseItem> items, String idempotencyKey) => _repo.purchase(list.id, items, idempotencyKey);
}
