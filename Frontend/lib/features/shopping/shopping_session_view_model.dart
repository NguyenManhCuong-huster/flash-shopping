import 'dart:async';
import '../group/account_service.dart';
import '../../core/base_view_model.dart';
import '../../core/utils/validators.dart';
import '../food/food.dart';
import './shopping_service.dart';
import './shopping.dart';
import '../user/user.dart';

class ShoppingSessionViewModel extends BaseViewModel {
  ShoppingSessionViewModel(this._shopping);
  final ShoppingService _shopping;

  List<ShoppingSession> shoppingSessions = [];
  bool done = false;
  bool mine = false;
  int _page = 1;
  bool hasMore = false;

  Future<void> load() => runLoad(() async {
    _page = 1;
    final r = await _shopping.sessions(done: done, assignedToMe: mine);
    shoppingSessions = r.items;
    hasMore = r.hasMore;
  });

  Future<void> loadMore() async {
    if (!hasMore || loading) return;
    final r = await _shopping.sessions(
      done: done,
      assignedToMe: mine,
      page: ++_page,
    );
    shoppingSessions = [...shoppingSessions, ...r.items];
    hasMore = r.hasMore;
    notifyListeners();
  }

  void setDone(bool value) {
    done = value;
    load();
  }

  void toggleMine() {
    mine = !mine;
    load();
  }
}

class ShoppingSessionFormViewModel extends BaseViewModel {
  ShoppingSessionFormViewModel(this._shopping, this._account);
  final ShoppingService _shopping;
  final AccountService _account;

  List<Member> members = [];

  Future<void> load() => runLoad(() async => members = (await _account.group()).members);

  Future<ShoppingSession> submitForm({
    ShoppingSession? existing,
    required String name,
    String? assignee,
    String? note,
  }) => runSave(
    () => existing == null
        ? _shopping.createSession(
            name: name,
            assignToUsername: assignee,
            note: note,
          )
        : _shopping.updateSession(
            existing,
            name: name,
            assignToUsername: assignee,
            note: note,
          ),
  );
}

class ShoppingSessionDetailViewModel extends BaseViewModel {
  ShoppingSessionDetailViewModel(
    this._shopping,
    this.shoppingSessionId);
  final ShoppingService _shopping;
  final int shoppingSessionId;

  ShoppingSession? _session;
  ShoppingSession? get shoppingSession => _session;

  Future<void> load() => runLoad(() async => _session = await _shopping.getSession(shoppingSessionId));

  Future<ItemBatchResult> addItem({
    required int sessionId,
    required int? foodId,
    required String foodName,
    required int? categoryId,
    required int? unitId,
    required double quantity,
    String? note,
  }) => runSave(() async {
    final r = await _shopping.addItem(
      sessionId: shoppingSessionId,
      foodId: foodId,
      foodName: foodName,
      categoryId: categoryId,
      unitId: unitId,
      quantity: quantity,
      note: note,
    );
    if (r.session != null) _session = r.session;
    return r;
  });

    Future<void> updateItem({
    required int shoppingItemId,
    double? quantity,
    String? note,
  }) => runSave(
    () => _shopping.updateItem(shoppingItemId, quantity: quantity, note: note),
  );

  Future<void> deleteItem(int itemId) => runSave(() async {
    await _shopping.deleteItem(itemId);
    _session = await _shopping.getSession(shoppingSessionId);
  });

  Future<void> purchaseItem(ShoppingItem item, double purchasedQuantity) =>
      runSave(() async {
        _session = await _shopping.purchase(_session!, [
          PurchaseItem(itemId: item.id, purchasedQuantity: purchasedQuantity),
        ], newIdempotencyKey());
      });

  Future<void> addItemToFridge(
    ShoppingItem item, {
    required DateTime useWithin,
    required StorageLocation location,
    String? note,
  }) => runSave(() async {
    _session = await _shopping.addPurchasedToFridge(_session!, [
      {
        'itemId': item.id,
        'useWithin': useWithin.toIso8601String(),
        'location': location.code,
        'note': note,
      },
    ], newIdempotencyKey());
  });

  Future<void> deleteSession() =>
      runSave(() => _shopping.deleteSession(_session!));
}