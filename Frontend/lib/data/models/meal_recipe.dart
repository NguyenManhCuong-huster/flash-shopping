import 'common.dart';

/// Tham chiếu rút gọn tới thực phẩm (id, tên, đơn vị).
class FoodRef {
  const FoodRef(this.id, this.name, this.unit, {this.imageUrl});
  final int id;
  final String name;
  final String unit;
  final String? imageUrl;

  factory FoodRef.fromJson(Json j) =>
      FoodRef(toInt(j['id']), j['name']?.toString() ?? '', j['unit']?.toString() ?? '', imageUrl: j['imageUrl']?.toString());
}

enum MealSlot {
  breakfast('sáng', 'Bữa sáng'),
  lunch('trưa', 'Bữa trưa'),
  dinner('tối', 'Bữa tối');

  const MealSlot(this.code, this.label);
  final String code;
  final String label;

  static MealSlot of(String? code) => MealSlot.values.firstWhere((m) => m.code == code, orElse: () => MealSlot.dinner);
}

class MealPlan {
  const MealPlan({required this.id, required this.date, required this.plannedAt, required this.meal, required this.food, this.recipeId, this.recipeName});
  final int id;
  final String date;
  final DateTime plannedAt;
  final MealSlot meal;
  final FoodRef food;
  final int? recipeId;
  final String? recipeName;

  factory MealPlan.fromJson(Json j) {
    final r = j['recipe'] is Map ? asJson(j['recipe']) : null;
    return MealPlan(
      id: toInt(j['id']),
      date: j['date']?.toString() ?? '',
      plannedAt: toDate(j['plannedAt']) ?? DateTime.now(),
      meal: MealSlot.of(j['mealName']?.toString()),
      food: FoodRef.fromJson(asJson(j['food'])),
      recipeId: r == null ? null : toInt(r['id']),
      recipeName: r?['name']?.toString(),
    );
  }
}

/// Trạng thái một nguyên liệu so với tủ lạnh.
class IngredientStatus {
  const IngredientStatus({required this.food, this.requiredQty, required this.available, required this.missing, required this.enough, this.expiringSoon = false});
  final FoodRef food;

  /// null = "cần có" (không định lượng)
  final double? requiredQty;
  final double available;
  final double missing;
  final bool enough;
  final bool expiringSoon;

  factory IngredientStatus.fromJson(Json j) => IngredientStatus(
        food: FoodRef.fromJson(asJson(j['food'])),
        requiredQty: toDoubleOrNull(j['requiredQuantity']),
        available: toDouble(j['availableQuantity']),
        missing: toDouble(j['missingQuantity']),
        enough: j['enough'] == true,
        expiringSoon: j['expiringSoon'] == true,
      );
}

class RecipeIngredient {
  const RecipeIngredient(this.food, this.quantity);
  final FoodRef food;
  final double? quantity;

  factory RecipeIngredient.fromJson(Json j) => RecipeIngredient(FoodRef.fromJson(asJson(j['food'])), toDoubleOrNull(j['quantity']));
}

class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.description,
    this.htmlContent,
    required this.food,
    this.createdById,
    this.createdByName,
    this.ingredients = const [],
  });

  final int id;
  final String name;
  final String description;
  final String? htmlContent;

  /// Nguyên liệu chính
  final FoodRef food;
  final int? createdById;
  final String? createdByName;
  final List<RecipeIngredient> ingredients;

  factory Recipe.fromJson(Json j) {
    final by = j['createdBy'] is Map ? asJson(j['createdBy']) : null;
    return Recipe(
      id: toInt(j['id']),
      name: j['name']?.toString() ?? '',
      description: j['description']?.toString() ?? '',
      htmlContent: j['htmlContent']?.toString(),
      food: FoodRef.fromJson(asJson(j['food'])),
      createdById: by == null ? null : toInt(by['id']),
      createdByName: by?['name']?.toString(),
      ingredients: asList(j['ingredients']).map(RecipeIngredient.fromJson).toList(),
    );
  }
}

class RecipeSuggestion {
  const RecipeSuggestion({required this.recipe, required this.total, required this.available, required this.canCook, required this.expiring, required this.ingredients});
  final Recipe recipe;
  final int total;
  final int available;
  final bool canCook;
  final List<String> expiring;
  final List<IngredientStatus> ingredients;

  List<IngredientStatus> get missing => ingredients.where((i) => !i.enough).toList();

  factory RecipeSuggestion.fromJson(Json j) => RecipeSuggestion(
        recipe: Recipe.fromJson(asJson(j['recipe'])),
        total: toInt(j['totalIngredients']),
        available: toInt(j['availableIngredients']),
        canCook: j['canCook'] == true,
        expiring: ((j['expiringIngredients'] as List?) ?? const []).map((e) => e.toString()).toList(),
        ingredients: asList(j['ingredients']).map(IngredientStatus.fromJson).toList(),
      );
}
