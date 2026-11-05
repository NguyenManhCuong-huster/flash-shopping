import 'dart:io';

import '../models/common.dart';
import '../models/food.dart';
import '../remote/api_client.dart';

/// Thực phẩm, danh mục, đơn vị và tủ lạnh (UC05).
class FoodRepository {
  FoodRepository(this._api);
  final ApiClient _api;

  // ---------- Danh mục, đơn vị ----------
  Future<List<NamedItem>> categories() async =>
      asList((await _api.get('/food/category')).map['categories']).map(NamedItem.fromJson).toList();
  Future<List<NamedItem>> units() async => asList((await _api.get('/food/unit')).map['units']).map(NamedItem.fromJson).toList();

  // ---------- Thực phẩm ----------
  Future<Paged<Food>> foods({String? q, int? categoryId, int page = 1}) async {
    final r = await _api.get('/food', query: {'q': q, 'categoryId': categoryId, 'page': page, 'limit': 50});
    return Paged.fromJson(r.map, 'foods', Food.fromJson);
  }

  Future<Food> createFood({required String name, required String category, required String unit, File? image}) async {
    final r = await _api.multipart('POST', '/food', {'name': name, 'foodCategoryName': category, 'unitName': unit}, image);
    return Food.fromJson(asJson(r.map['food']));
  }

  Future<Food> updateFood({required String name, String? newName, String? newCategory, String? newUnit, File? image}) async {
    final r = await _api.multipart('PUT', '/food', {'name': name, 'newName': newName, 'newCategory': newCategory, 'newUnit': newUnit}, image);
    return Food.fromJson(asJson(r.map['food']));
  }

  Future<void> deleteFood(String name) => _api.delete('/food', data: {'name': name});

  // ---------- Tủ lạnh ----------
  Future<FridgeResult> fridge({String? q, String? location, int? expiringDays, int page = 1}) async {
    final r = await _api.get('/fridge', query: {'q': q, 'location': location, 'expiringDays': expiringDays, 'page': page, 'limit': 50});
    final d = r.map;
    return FridgeResult(
      asList(d['items']).map(FridgeItem.fromJson).toList(),
      FridgeSummary.fromJson(asJson(d['summary'])),
      page: toInt(d['page']),
      totalPages: toInt(d['totalPages']),
    );
  }

  Future<FridgeItem> fridgeItem(int id) async => FridgeItem.fromJson(asJson((await _api.get('/fridge/item/$id')).map['item']));

  Future<FridgeItem> addToFridge({required String foodName, required double quantity, required String useWithin, required String location, String? note}) async {
    final r = await _api.post('/fridge', data: {'foodName': foodName, 'quantity': quantity, 'useWithin': useWithin, 'location': location, 'note': note});
    return FridgeItem.fromJson(asJson(r.map['item']));
  }

  Future<FridgeItem> updateFridgeItem({required int itemId, required int version, double? quantity, String? useWithin, String? location, String? note}) async {
    final r = await _api.put('/fridge', data: {
      'itemId': itemId,
      'version': version,
      if (quantity != null) 'newQuantity': quantity,
      if (useWithin != null) 'newUseWithin': useWithin,
      if (location != null) 'newLocation': location,
      if (note != null) 'newNote': note,
    });
    return FridgeItem.fromJson(asJson(r.map['item']));
  }

  Future<void> deleteFridgeItem(int itemId) => _api.delete('/fridge', data: {'itemId': itemId});

  /// Trả về mục sau khi trừ (null nếu đã dùng hết).
  Future<FridgeItem?> consume({required int itemId, required double quantity, required String type, required int version, String? note}) async {
    final r = await _api.post('/fridge/consume', data: {'itemId': itemId, 'quantity': quantity, 'type': type, 'version': version, 'note': note});
    final item = r.map['item'];
    return item == null ? null : FridgeItem.fromJson(asJson(item));
  }
}
