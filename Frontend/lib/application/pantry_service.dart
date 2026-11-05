import 'dart:io';

import '../data/models/common.dart';
import '../data/models/food.dart';
import '../data/repositories/food_repository.dart';
import 'validation/validators.dart';

/// Thực phẩm + tủ lạnh (UC05). Lưu đệm danh mục/đơn vị vì ít thay đổi.
class PantryService {
  PantryService(this._repo);
  final FoodRepository _repo;

  List<NamedItem>? _categories;
  List<NamedItem>? _units;

  Future<List<NamedItem>> categories({bool refresh = false}) async => (!refresh && _categories != null) ? _categories! : (_categories = await _repo.categories());
  Future<List<NamedItem>> units({bool refresh = false}) async => (!refresh && _units != null) ? _units! : (_units = await _repo.units());

  Future<Paged<Food>> foods({String? q, int? categoryId, int page = 1}) => _repo.foods(q: q, categoryId: categoryId, page: page);

  Future<Food> createFood({required String name, required String category, required String unit, File? image}) =>
      _repo.createFood(name: name.trim(), category: category, unit: unit, image: image);

  Future<Food> updateFood(Food food, {String? newName, String? newCategory, String? newUnit, File? image}) => _repo.updateFood(
        name: food.name,
        newName: (newName != null && newName.trim() != food.name) ? newName.trim() : null,
        newCategory: newCategory != food.category.name ? newCategory : null,
        newUnit: newUnit != food.unit.name ? newUnit : null,
        image: image,
      );

  Future<void> deleteFood(Food food) => _repo.deleteFood(food.name);

  // ---------- Tủ lạnh ----------
  Future<FridgeResult> fridge({String? q, StorageLocation? location, int? expiringDays, int page = 1}) =>
      _repo.fridge(q: q, location: location?.code, expiringDays: expiringDays, page: page);

  Future<FridgeItem> fridgeItem(int id) => _repo.fridgeItem(id);

  Future<FridgeItem> addToFridge({required String foodName, required double quantity, required DateTime expiry, required StorageLocation location, String? note}) =>
      _repo.addToFridge(foodName: foodName, quantity: quantity, useWithin: isoDate(expiry), location: location.code, note: note?.trim());

  /// Gửi kèm version: nếu người khác đã sửa trước, backend trả 00523 để người dùng tải lại.
  Future<FridgeItem> updateFridgeItem(FridgeItem item, {double? quantity, DateTime? expiry, StorageLocation? location, String? note}) => _repo.updateFridgeItem(
        itemId: item.id,
        version: item.version,
        quantity: quantity != item.quantity ? quantity : null,
        useWithin: expiry == null ? null : isoDate(expiry),
        location: location != item.location ? location?.code : null,
        note: note != item.note ? (note ?? '') : null,
      );

  Future<void> removeFromFridge(FridgeItem item) => _repo.deleteFridgeItem(item.id);

  /// Ghi nhận dùng hoặc bỏ đi (trừ tồn trong một giao dịch ở backend).
  Future<FridgeItem?> consume(FridgeItem item, double quantity, {bool discard = false, String? note}) =>
      _repo.consume(itemId: item.id, quantity: quantity, type: discard ? 'discard' : 'consume', version: item.version, note: note);
}
