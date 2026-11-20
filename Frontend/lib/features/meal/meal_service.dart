import '../../core/model_common.dart';
import 'meal_recipe.dart';
import '../shopping/shopping.dart';
import 'meal_recipe_repository.dart';
import '../../core/utils/validators.dart';

/// UC07 công thức, UC08 kế hoạch bữa ăn, UC09 gợi ý món.
class MealService {
  MealService(this._repo);
  final MealRecipeRepository _repo;

  Future<List<MealPlan>> week(DateTime start) => _repo.mealPlans(from: isoDate(start), to: isoDate(start.add(const Duration(days: 6))));

  Future<MealPlan> createMealPlan({required Recipe recipe, required DateTime date, required MealPeriod period}) =>
      _repo.createMealPlan(recipeId: recipe.id, date: isoDate(date), period: period.code);

  Future<void> deleteMealPlan(MealPlan plan) => _repo.deleteMealPlan(plan.id);

  Future<List<IngredientStatus>> ingredientsFor(MealPlan plan) => _repo.ingredients(planId: plan.id);
  Future<List<IngredientStatus>> ingredientsForDay(DateTime day) => _repo.ingredients(date: isoDate(day));

  /// Thao tác tùy chọn riêng (extend): không tự chạy khi lưu kế hoạch.
  Future<ShoppingSession?> addMissingToShopping({MealPlan? plan, DateTime? day, int? sessionId}) =>
      _repo.addMissingToShopping(planId: plan?.id, date: plan == null && day != null ? isoDate(day) : null, sessionId: sessionId);

  // ---------- Công thức ----------
  Future<Paged<Recipe>> recipes({String? q, int page = 1}) => _repo.recipes(q: q, page: page);
  Future<Recipe> recipe(int id) => _repo.recipe(id);

  Future<Recipe> saveRecipe({
    Recipe? existing,
    required String foodName,
    required String name,
    required String description,
    required String instructions,
    required List<({String foodName, double? quantity})> ingredients,
  }) {
    final html = instructionsToHtml(instructions);
    if (existing == null) {
      return _repo.createRecipe(foodName: foodName, name: name.trim(), description: description.trim(), html: html, ingredients: ingredients);
    }
    return _repo.updateRecipe(
      existing.id,
      foodName: foodName != existing.food.name ? foodName : null,
      name: name.trim(),
      description: description.trim(),
      html: html,
      ingredients: ingredients,
    );
  }

  Future<void> deleteRecipe(Recipe r) => _repo.deleteRecipe(r.id);

  Future<List<RecipeSuggestion>> suggestions({bool onlyCookable = false}) => _repo.suggestions(onlyCookable: onlyCookable);

  /// Mỗi dòng cách làm -> một đoạn <p>; ký tự HTML được thoát.
  static String instructionsToHtml(String text) {
    String esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
    return text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).map((l) => '<p>${esc(l)}</p>').join();
  }

  /// HTML công thức (đã được backend làm sạch) -> văn bản để hiển thị/sửa.
  static String htmlToText(String? html) {
    if (html == null) return '';
    return html
        .replaceAll(RegExp(r'</(p|li|h\d|blockquote)>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}
