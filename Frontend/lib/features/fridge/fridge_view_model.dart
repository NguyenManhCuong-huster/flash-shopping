import 'dart:async';
import '../food/food.dart';
import '../food/food_service.dart';
import '../../core/base_view_model.dart';

class FridgeViewModel extends BaseViewModel {
  FridgeViewModel(this._pantry);
  final FoodService _pantry;

  List<FridgeItem> items = [];
  FridgeSummary summary = const FridgeSummary();
  StorageLocation? location;
  bool onlyExpiring = false;
  String query = '';
  int _page = 1;
  int _totalPages = 1;

  Future<void> load() => runLoad(() async {
    _page = 1;
    final result = await _pantry.fridge(
      query: query,
      location: location,
      expiringDays: onlyExpiring ? 3 : null,
    );
    items = result.items;
    summary = result.summary;
    _totalPages = result.totalPages;
  });

  /// Tải cuộn: 50 mục mỗi lần (NFR08).
  Future<void> loadMore() async {
    if (_page >= _totalPages || loading) return;
    final result = await _pantry.fridge(
      query: query,
      location: location,
      expiringDays: onlyExpiring ? 3 : null,
      page: ++_page,
    );
    items = [...items, ...result.items];
    notifyListeners();
  }

  void setLocation(StorageLocation? l) {
    location = l;
    load();
  }

  void toggleExpiring() {
    onlyExpiring = !onlyExpiring;
    load();
  }
}

class FridgeItemViewModel extends BaseViewModel {
  FridgeItemViewModel(this._foodService, this.fridgeItemId);
  final FoodService _foodService;
  final int fridgeItemId;

  FridgeItem? _fridgeItem;
  bool removed = false;
  FridgeItem? get fridgeItem => _fridgeItem;

  Future<void> load() => runLoad(
    () async => _fridgeItem = await _foodService.fridgeItem(fridgeItemId),
  );

  /// Trả về true nếu đã dùng hết (mục bị xóa khỏi tủ).
  Future<bool> consume(
    double quantity, {
    required bool discard,
    String? note,
  }) => runSave(() async {
    final updatedFridgeItem = await _foodService.consume(
      _fridgeItem!,
      quantity,
      discard: discard,
      note: note,
    );
    if (updatedFridgeItem == null) {
      removed = true;
      return true;
    }
    _fridgeItem = updatedFridgeItem;
    return false;
  });
  
  // Future<void> add({
  //   required Food food,
  //   required double quantity,
  //   required DateTime expiry,
  //   required StorageLocation location,
  //   String? note,
  // }) => runSave(
  //   () => _pantry.addToFridge(
  //     foodName: food.name,
  //     quantity: quantity,
  //     expiry: expiry,
  //     location: location,
  //     note: note,
  //   ),
  // );

  Future<void> update(
    FridgeItem item, {
    DateTime? useWithin,
    StorageLocation? location,
    String? note,
  }) => runSave(
    () => _foodService.updateFridgeItem(
      item,
      useWithin: useWithin,
      location: location,
      note: note,
    ),
  );
  Future<void> delete() => runSave(() async {
    await _foodService.removeFromFridge(fridgeItem!);
    removed = true;
  });
}
