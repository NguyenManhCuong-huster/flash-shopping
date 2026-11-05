import '../models/common.dart';
import '../models/meal_recipe.dart';
import '../models/shopping.dart';
import '../remote/api_client.dart';

/// UC07, UC08, UC09: công thức, kế hoạch bữa ăn, gợi ý món.
class MealRecipeRepository {
  MealRecipeRepository(this._api);
  final ApiClient _api;

  // ---------- Kế hoạch bữa ăn ----------
  Future<List<MealPlan>> plans({required String from, required String to}) async {
    final r = await _api.get('/meal', query: {'from': from, 'to': to});
    return asList(r.map['plans']).map(MealPlan.fromJson).toList();
  }

  Future<MealPlan> createPlan({String? foodName, int? recipeId, required String date, required String meal}) async {
    final r = await _api.post('/meal', data: {'foodName': foodName, 'recipeId': recipeId, 'timestamp': date, 'name': meal});
    return MealPlan.fromJson(asJson(r.map['plan']));
  }

  Future<MealPlan> updatePlan(int planId, {String? foodName, String? date, String? meal}) async {
    final r = await _api.put('/meal', data: {
      'planId': planId,
      if (foodName != null) 'newFoodName': foodName,
      if (date != null) 'newTimestamp': date,
      if (meal != null) 'newName': meal,
    });
    return MealPlan.fromJson(asJson(r.map['plan']));
  }

  Future<void> deletePlan(int planId) => _api.delete('/meal', data: {'planId': planId});

  Future<List<IngredientStatus>> ingredients({int? planId, String? date}) async {
    final r = await _api.get('/meal/ingredients', query: {'planId': planId, 'date': date});
    return asList(r.map['ingredients']).map(IngredientStatus.fromJson).toList();
  }

  /// Thêm nguyên liệu thiếu vào danh sách có sẵn (listId) hoặc danh sách mới. Trả null nếu không thiếu gì.
  Future<ShoppingList?> addMissingToShopping({int? planId, String? date, int? listId, String? newListName}) async {
    final r = await _api.post('/meal/missing-to-shopping', data: {'planId': planId, 'date': date, 'listId': listId, 'newListName': newListName});
    return r.map['list'] == null ? null : ShoppingList.fromJson(asJson(r.map['list']));
  }

  // ---------- Công thức ----------
  Future<Paged<Recipe>> recipes({String? q, int? foodId, int page = 1}) async {
    final r = await _api.get('/recipe', query: {'q': q, 'foodId': foodId, 'page': page, 'limit': 20});
    return Paged.fromJson(r.map, 'recipes', Recipe.fromJson);
  }

  Future<Recipe> recipe(int id) async => Recipe.fromJson(asJson((await _api.get('/recipe/$id')).map['recipe']));

  Future<Recipe> createRecipe({required String foodName, required String name, required String description, required String html, required List<({String foodName, double? quantity})> ingredients}) async {
    final r = await _api.post('/recipe', data: {
      'foodName': foodName,
      'name': name,
      'description': description,
      'htmlContent': html,
      'ingredients': ingredients.map((i) => {'foodName': i.foodName, 'quantity': i.quantity}).toList(),
    });
    return Recipe.fromJson(asJson(r.map['recipe']));
  }

  Future<Recipe> updateRecipe(int id, {String? foodName, String? name, String? description, String? html, List<({String foodName, double? quantity})>? ingredients}) async {
    final r = await _api.put('/recipe', data: {
      'recipeId': id,
      if (foodName != null) 'newFoodName': foodName,
      if (name != null) 'newName': name,
      if (description != null) 'newDescription': description,
      if (html != null) 'newHtmlContent': html,
      if (ingredients != null) 'newIngredients': ingredients.map((i) => {'foodName': i.foodName, 'quantity': i.quantity}).toList(),
    });
    return Recipe.fromJson(asJson(r.map['recipe']));
  }

  Future<void> deleteRecipe(int id) => _api.delete('/recipe', data: {'recipeId': id});

  Future<List<RecipeSuggestion>> suggestions({bool onlyCookable = false}) async {
    final r = await _api.get('/recipe/suggest', query: {'onlyCookable': onlyCookable ? 'true' : null});
    return asList(r.map['suggestions']).map(RecipeSuggestion.fromJson).toList();
  }
}
