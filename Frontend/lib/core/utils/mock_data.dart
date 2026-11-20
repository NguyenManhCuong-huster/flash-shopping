import '../../features/ai/ai.dart';
import '../model_common.dart';
import '../../features/food/food.dart';
import '../../features/meal/meal_recipe.dart';
import '../../features/notifications/misc.dart';
import '../../features/shopping/shopping.dart';
import '../../features/user/user.dart';

/// Bộ dữ liệu giả lập (mock data) cho tất cả các model,
/// dùng để gọi thử giao diện khi chưa kết nối API thực.
class MockData {
  // =========================================================================
  // NAMED ITEM (danh mục / đơn vị)
  // =========================================================================

  static final List<NamedItem> categories = [
    NamedItem(1, 'Rau quả'),
    NamedItem(2, 'Thịt'),
    NamedItem(3, 'Hải sản'),
    NamedItem(4, 'Đồ khô'),
    NamedItem(5, 'Sữa & trứng'),
    NamedItem(6, 'Gia vị'),
  ];

  static final List<NamedItem> units = [
    NamedItem(1, 'kg'),
    NamedItem(2, 'quả'),
    NamedItem(3, 'bó'),
    NamedItem(4, 'gói'),
    NamedItem(5, 'chai'),
    NamedItem(6, 'cái'),
  ];

  // =========================================================================
  // FOOD & FOODREF
  // =========================================================================

  static final List<Food> foods = [
    Food(
      id: 1,
      name: 'Gà',
      imageUrl: 'https://example.com/images/ga.jpg',
      category: categories[1],
      unit: units[0],
    ),
    Food(
      id: 2,
      name: 'Thịt bò',
      imageUrl: 'https://example.com/images/thit-bo.jpg',
      category: categories[1],
      unit: units[0],
    ),
    Food(
      id: 3,
      name: 'Cá hồi',
      imageUrl: 'https://example.com/images/ca-hoi.jpg',
      category: categories[2],
      unit: units[0],
    ),
    Food(
      id: 4,
      name: 'Tôm',
      imageUrl: 'https://example.com/images/tom.jpg',
      category: categories[2],
      unit: units[0],
    ),
    Food(
      id: 5,
      name: 'Trứng',
      imageUrl: 'https://example.com/images/trung.jpg',
      category: categories[4],
      unit: units[1],
    ),
    Food(
      id: 6,
      name: 'Cà rốt',
      imageUrl: 'https://example.com/images/cau-rot.jpg',
      category: categories[0],
      unit: units[0],
    ),
    Food(
      id: 7,
      name: 'Bông cải xanh',
      imageUrl: 'https://example.com/images/bong-cai-xanh.jpg',
      category: categories[0],
      unit: units[2],
    ),
    Food(
      id: 8,
      name: 'Cà chua',
      imageUrl: 'https://example.com/images/ca-chua.jpg',
      category: categories[0],
      unit: units[0],
    ),
    Food(
      id: 9,
      name: 'Hành lá',
      imageUrl: 'https://example.com/images/hanh-la.jpg',
      category: categories[0],
      unit: units[2],
    ),
    Food(
      id: 10,
      name: 'Gạo',
      imageUrl: 'https://example.com/images/gao.jpg',
      category: categories[3],
      unit: units[0],
    ),
    Food(
      id: 11,
      name: 'Mì khô',
      imageUrl: 'https://example.com/images/mi-kho.jpg',
      category: categories[3],
      unit: units[3],
    ),
    Food(
      id: 12,
      name: 'Nấm',
      imageUrl: 'https://example.com/images/nam.jpg',
      category: categories[0],
      unit: units[0],
    ),
  ];

  static final List<FoodRef> foodRefs = foods
      .map((f) => FoodRef(f.id, f.name, f.unit.name, imageUrl: f.imageUrl))
      .toList();

  // =========================================================================
  // FRIDGE (tủ lạnh)
  // =========================================================================

  static final List<FridgeItem> fridgeItems = [
    FridgeItem(
      id: 1,
      food: foods[0],
      quantity: 0.5,
      useWithin: DateTime.now().add(const Duration(days: 5)),
      location: StorageLocation.cool,
      note: 'Mua hôm qua',
      version: 1,
      status: FridgeItemStatus.fresh,
      daysLeft: 5,
      purchasedAt: DateTime.now().subtract(const Duration(days: 1)),
      storedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    FridgeItem(
      id: 2,
      food: foods[2],
      quantity: 0.3,
      useWithin: DateTime.now().add(const Duration(days: 1)),
      location: StorageLocation.freezer,
      note: '',
      version: 1,
      status: FridgeItemStatus.expiring,
      daysLeft: 1,
      purchasedAt: DateTime.now().subtract(const Duration(days: 2)),
      storedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    FridgeItem(
      id: 3,
      food: foods[5],
      quantity: 0.4,
      useWithin: DateTime.now().add(const Duration(days: 7)),
      location: StorageLocation.cool,
      note: '',
      version: 1,
      status: FridgeItemStatus.fresh,
      daysLeft: 7,
      purchasedAt: DateTime.now().subtract(const Duration(days: 1)),
      storedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    FridgeItem(
      id: 4,
      food: foods[6],
      quantity: 0.2,
      useWithin: DateTime.now().subtract(const Duration(days: 1)),
      location: StorageLocation.cool,
      note: 'Quá hạn',
      version: 1,
      status: FridgeItemStatus.expired,
      daysLeft: -1,
      purchasedAt: DateTime.now().subtract(const Duration(days: 5)),
      storedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    FridgeItem(
      id: 5,
      food: foods[4],
      quantity: 6,
      useWithin: DateTime.now().add(const Duration(days: 14)),
      location: StorageLocation.cool,
      note: 'Hộp trứng',
      version: 1,
      status: FridgeItemStatus.fresh,
      daysLeft: 14,
      purchasedAt: DateTime.now().subtract(const Duration(days: 1)),
      storedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    FridgeItem(
      id: 6,
      food: foods[8],
      quantity: 0.1,
      useWithin: DateTime.now().add(const Duration(days: 2)),
      location: StorageLocation.cool,
      note: '',
      version: 1,
      status: FridgeItemStatus.expiring,
      daysLeft: 2,
      purchasedAt: DateTime.now().subtract(const Duration(days: 1)),
      storedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    FridgeItem(
      id: 7,
      food: foods[10],
      quantity: 3,
      useWithin: DateTime.now().add(const Duration(days: 60)),
      location: StorageLocation.other,
      note: '',
      version: 1,
      status: FridgeItemStatus.fresh,
      daysLeft: 60,
      purchasedAt: DateTime.now().subtract(const Duration(days: 1)),
      storedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  static final FridgeSummary fridgeSummary = FridgeSummary(
    total: fridgeItems.length,
    expiring: fridgeItems
        .where((i) => i.status == FridgeItemStatus.expiring)
        .length,
    expired: fridgeItems
        .where((i) => i.status == FridgeItemStatus.expired)
        .length,
  );

  static final FridgeResult fridgeResult = FridgeResult(
    fridgeItems,
    fridgeSummary,
    page: 1,
    totalPages: 1,
  );

  // =========================================================================
  // MEAL PLAN (kế hoạch bữa ăn)
  // =========================================================================

  static final DateTime _planBaseDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  static final List<MealPlan> mealPlans = [
    MealPlan(
      id: 1,
      name: 'Trứng ốp la',
      date: DateTime.now(),
      plannedAt: _planBaseDate.add(const Duration(hours: 7)),
      mealPeriod: MealPeriod.breakfast,
      food: foodRefs[5],
      recipeId: null,
    ),
    MealPlan(
      id: 2,
      date: _planBaseDate,
      plannedAt: _planBaseDate.add(const Duration(hours: 12)),
      mealPeriod: MealPeriod.lunch,
      name: 'Gà xào cà rốt',
      food: foodRefs[0],
      recipeId: 1,
    ),
    MealPlan(
      id: 3,
      name: 'Cá hồi nướng sốt chanh',
      date: _planBaseDate,
      plannedAt: _planBaseDate.add(const Duration(hours: 18)),
      mealPeriod: MealPeriod.dinner,
      food: foodRefs[2],
      recipeId: 2,
    ),
    MealPlan(
      id: 4,
      name: 'Cháo gà',
      date: _planBaseDate.add(const Duration(days: 1)),
      plannedAt: _planBaseDate.add(const Duration(days: 1, hours: 7)),
      mealPeriod: MealPeriod.breakfast,
      food: foodRefs[9],
      recipeId: null,
    ),
    MealPlan(
      id: 5,
      name: 'Thịt bò xào nấm',
      date: _planBaseDate.add(const Duration(days: 1)),
      plannedAt: _planBaseDate.add(const Duration(days: 1, hours: 12)),
      mealPeriod: MealPeriod.lunch,
      food: foodRefs[1],
      recipeId: 3,
    ),
    MealPlan(
      id: 6,
      name: 'Tôm rang muối ớt',
      date: _planBaseDate.add(const Duration(days: 1)),
      plannedAt: _planBaseDate.add(const Duration(days: 1, hours: 18)),
      mealPeriod: MealPeriod.dinner,
      food: foodRefs[3],
      recipeId: null,
    ),
    MealPlan(
      id: 7,
      name: 'Mì tôm xào rau',
      date: _planBaseDate.add(const Duration(days: 2)),
      plannedAt: _planBaseDate.add(const Duration(days: 2, hours: 7)),
      mealPeriod: MealPeriod.breakfast,
      food: foodRefs[10],
      recipeId: null,
    ),
    MealPlan(
      id: 8,
      name: 'Gà xào cà rốt',
      date: _planBaseDate.add(const Duration(days: 2)),
      plannedAt: _planBaseDate.add(const Duration(days: 2, hours: 12)),
      mealPeriod: MealPeriod.lunch,
      food: foodRefs[0],
      recipeId: 1,
    ),
    MealPlan(
      id: 9,
      name: 'Canh cải xanh ninh',
      date: _planBaseDate.add(const Duration(days: 2)),
      plannedAt: _planBaseDate.add(const Duration(days: 2, hours: 18)),
      mealPeriod: MealPeriod.dinner,
      food: foodRefs[6],
      recipeId: null,
    ),
    MealPlan(
      id: 10,
      name: 'Trứng ốp la',
      date: _planBaseDate.add(const Duration(days: 3)),
      plannedAt: _planBaseDate.add(const Duration(days: 3, hours: 7)),
      mealPeriod: MealPeriod.breakfast,
      food: foodRefs[5],
      recipeId: null,
    ),
    MealPlan(
      id: 11,
      name: 'Cà rốt luộc',
      date: _planBaseDate.add(const Duration(days: 3)),
      plannedAt: _planBaseDate.add(const Duration(days: 3, hours: 12)),
      mealPeriod: MealPeriod.lunch,
      food: foodRefs[5],
      recipeId: null,
    ),
    MealPlan(
      id: 12,
      name: 'Cá hồi nướng sốt chanh',
      date: _planBaseDate.add(const Duration(days: 3)),
      plannedAt: _planBaseDate.add(const Duration(days: 3, hours: 18)),
      mealPeriod: MealPeriod.dinner,
      food: foodRefs[2],
      recipeId: 2,
    ),
    MealPlan(
      id: 13,
      name: 'Xôi gà',
      date: _planBaseDate.add(const Duration(days: 4)),
      plannedAt: _planBaseDate.add(const Duration(days: 4, hours: 7)),
      mealPeriod: MealPeriod.breakfast,
      food: foodRefs[9],
      recipeId: null,
    ),
    MealPlan(
      id: 14,
      name: 'Thịt bò xào nấm',
      date: _planBaseDate.add(const Duration(days: 4)),
      plannedAt: _planBaseDate.add(const Duration(days: 4, hours: 12)),
      mealPeriod: MealPeriod.lunch,
      food: foodRefs[1],
      recipeId: 3,
    ),
    MealPlan(
      id: 15,
      name: 'Canh cà chua trứng',
      date: _planBaseDate.add(const Duration(days: 4)),
      plannedAt: _planBaseDate.add(const Duration(days: 4, hours: 18)),
      mealPeriod: MealPeriod.dinner,
      food: foodRefs[7],
      recipeId: null,
    ),
    MealPlan(
      id: 16,
      name: 'Bánh mì trứng',
      date: _planBaseDate.add(const Duration(days: 5)),
      plannedAt: _planBaseDate.add(const Duration(days: 5, hours: 7)),
      mealPeriod: MealPeriod.breakfast,
      food: foodRefs[4],
      recipeId: null,
    ),
    MealPlan(
      id: 17,
      name: 'Tôm hấp',
      date: _planBaseDate.add(const Duration(days: 5)),
      plannedAt: _planBaseDate.add(const Duration(days: 5, hours: 12)),
      mealPeriod: MealPeriod.lunch,
      food: foodRefs[4],
      recipeId: null,
    ),
    MealPlan(
      id: 18,
      name: 'Gà xào cà rốt',
      date: _planBaseDate.add(const Duration(days: 5)),
      plannedAt: _planBaseDate.add(const Duration(days: 5, hours: 18)),
      mealPeriod: MealPeriod.dinner,
      food: foodRefs[0],
      recipeId: 1,
    ),
    MealPlan(
      id: 19,
      name: 'Cháo cá',
      date: _planBaseDate.add(const Duration(days: 6)),
      plannedAt: _planBaseDate.add(const Duration(days: 6, hours: 7)),
      mealPeriod: MealPeriod.breakfast,
      food: foodRefs[9],
      recipeId: null,
    ),
    MealPlan(
      id: 20,
      name: 'Cá hồi nướng sốt chanh',
      date: _planBaseDate.add(const Duration(days: 6)),
      plannedAt: _planBaseDate.add(const Duration(days: 6, hours: 12)),
      mealPeriod: MealPeriod.lunch,
      food: foodRefs[2],
      recipeId: 2,
    ),
    MealPlan(
      id: 21,
      name: 'Salad cà rốt',
      date: _planBaseDate.add(const Duration(days: 6)),
      plannedAt: _planBaseDate.add(const Duration(days: 6, hours: 18)),
      mealPeriod: MealPeriod.dinner,
      food: foodRefs[5],
      recipeId: null,
    ),
  ];

  // =========================================================================
  // RECIPE (công thức)
  // =========================================================================

  static final List<RecipeIngredient> recipe1Ingredients = [
    RecipeIngredient(foodRefs[0], 0.3),
    RecipeIngredient(foodRefs[5], 0.2),
    RecipeIngredient(foodRefs[8], 0.05),
    RecipeIngredient(foodRefs[6], 0.1),
  ];

  static final List<RecipeIngredient> recipe2Ingredients = [
    RecipeIngredient(foodRefs[2], 0.5),
    RecipeIngredient(foodRefs[8], 0.03),
    RecipeIngredient(foodRefs[7], 0.2),
  ];

  static final List<RecipeIngredient> recipe3Ingredients = [
    RecipeIngredient(foodRefs[1], 0.4),
    RecipeIngredient(foodRefs[11], 0.2),
    RecipeIngredient(foodRefs[8], 0.05),
  ];

  static final List<RecipeIngredient> recipe4Ingredients = [
    RecipeIngredient(foodRefs[3], 0.4),
    RecipeIngredient(foodRefs[10], 1),
    RecipeIngredient(foodRefs[6], 0.2),
    RecipeIngredient(foodRefs[5], 0.1),
  ];

  static final List<RecipeIngredient> recipe5Ingredients = [
    RecipeIngredient(foodRefs[4], 2),
    RecipeIngredient(foodRefs[7], 0.3),
  ];

  static final List<Recipe> recipes = [
    Recipe(
      id: 1,
      name: 'Gà xào cà rốt',
      description: 'Món gà xào với cà rốt và rau củ.',
      htmlContent:
          '<p>1. Ướp gà 15 phút.</p><p>2. Xào cà rốt và hành lá.</p><p>3. Cho gà vào xào chín.</p>',
      food: foodRefs[0],
      createdById: 1,
      createdByName: 'Người dùng',
      ingredients: recipe1Ingredients,
    ),
    Recipe(
      id: 2,
      name: 'Cá hồi nướng sốt chanh',
      description: 'Cá hồi nướng với sốt chanh.',
      htmlContent:
          '<p>1. Muối cá 10 phút.</p><p>2. Pha sốt chanh.</p><p>3. Nướng cá 20 phút.</p>',
      food: foodRefs[2],
      createdById: 1,
      createdByName: 'Người dùng',
      ingredients: recipe2Ingredients,
    ),
    Recipe(
      id: 3,
      name: 'Thịt bò xào nấm',
      description: 'Thịt bò xào nấm shiitake.',
      htmlContent:
          '<p>1. Bảo hành thịt bò.</p><p>2. Xào nấm với dầu oliu.</p><p>3. Cho thịt vào xào.</p>',
      food: foodRefs[1],
      createdById: 1,
      createdByName: 'Người dùng',
      ingredients: recipe3Ingredients,
    ),
    Recipe(
      id: 4,
      name: 'Mì tôm xào rau',
      description: 'Mì khô xào tôm và rau củ.',
      htmlContent:
          '<p>1. Luộc mì khô.</p><p>2. Xào tôm và rau.</p><p>3. Trộn mì với tôm.</p>',
      food: foodRefs[10],
      createdById: 1,
      createdByName: 'Người dùng',
      ingredients: recipe4Ingredients,
    ),
    Recipe(
      id: 5,
      name: 'Trứng cà chua xào',
      description: 'Trứng xào cà chua.',
      htmlContent:
          '<p>1. Trứng đánh chung.</p><p>2. Xào cà chua.</p><p>3. Cho trứng vào xào chín.</p>',
      food: foodRefs[4],
      createdById: 1,
      createdByName: 'Người dùng',
      ingredients: recipe5Ingredients,
    ),
  ];

  // =========================================================================
  // INGREDIENT STATUS & RECIPE SUGGESTION
  // =========================================================================

  static final List<IngredientStatus> ingredientStatuses = [
    IngredientStatus(
      food: foodRefs[0],
      requiredQty: 0.3,
      available: 0.5,
      missing: 0,
      enough: true,
      expiringSoon: false,
    ),
    IngredientStatus(
      food: foodRefs[2],
      requiredQty: 0.5,
      available: 0.3,
      missing: 0.2,
      enough: false,
      expiringSoon: true,
    ),
    IngredientStatus(
      food: foodRefs[5],
      requiredQty: 0.2,
      available: 0.4,
      missing: 0,
      enough: true,
      expiringSoon: false,
    ),
    IngredientStatus(
      food: foodRefs[6],
      requiredQty: 0.1,
      available: 0.2,
      missing: 0,
      enough: true,
      expiringSoon: false,
    ),
    IngredientStatus(
      food: foodRefs[8],
      requiredQty: 0.05,
      available: 0.1,
      missing: 0,
      enough: true,
      expiringSoon: true,
    ),
    IngredientStatus(
      food: foodRefs[10],
      requiredQty: 1,
      available: 3,
      missing: 0,
      enough: true,
      expiringSoon: false,
    ),
    IngredientStatus(
      food: foodRefs[3],
      requiredQty: 0.4,
      available: 0.2,
      missing: 0.2,
      enough: false,
      expiringSoon: false,
    ),
    IngredientStatus(
      food: foodRefs[4],
      requiredQty: null,
      available: 6,
      missing: 0,
      enough: true,
      expiringSoon: false,
    ),
  ];

  static final List<RecipeSuggestion> recipeSuggestions = [
    RecipeSuggestion(
      recipe: recipes[0],
      total: recipe1Ingredients.length,
      available: 4,
      canCook: true,
      expiring: [],
      ingredients: ingredientStatuses
          .where(
            (e) => [
              foodRefs[0],
              foodRefs[5],
              foodRefs[6],
              foodRefs[8],
            ].contains(e.food),
          )
          .toList(),
    ),
    RecipeSuggestion(
      recipe: recipes[1],
      total: recipe2Ingredients.length,
      available: 2,
      canCook: false,
      expiring: ['Cá hồi', 'Hành lá'],
      ingredients: ingredientStatuses
          .where(
            (e) => [foodRefs[2], foodRefs[8], foodRefs[7]].contains(e.food),
          )
          .toList(),
    ),
    RecipeSuggestion(
      recipe: recipes[4],
      total: recipe5Ingredients.length,
      available: 2,
      canCook: true,
      expiring: [],
      ingredients: ingredientStatuses
          .where((e) => [foodRefs[4], foodRefs[7]].contains(e.food))
          .toList(),
    ),
  ];

  // =========================================================================
  // SHOPPING (danh sách mua sắm)
  // =========================================================================

  static final List<ShoppingItem> shoppingItems = [
    ShoppingItem(
      id: 1,
      food: foods[2],
      quantity: 0.5,
      status: ShoppingStatus.pending,
    ),
    ShoppingItem(
      id: 2,
      food: foods[3],
      quantity: 0.4,
      status: ShoppingStatus.pending,
    ),
    ShoppingItem(
      id: 3,
      food: foods[0],
      quantity: 0.3,
      status: ShoppingStatus.bought,
      purchasedQuantity: 0.3,
      purchasedByName: 'Người dùng',
      purchasedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    ShoppingItem(
      id: 4,
      food: foods[6],
      quantity: 0.2,
      status: ShoppingStatus.bought,
      purchasedQuantity: 0.2,
      purchasedByName: 'Người dùng',
      purchasedAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    ShoppingItem(
      id: 5,
      food: foods[1],
      quantity: 0.4,
      status: ShoppingStatus.pending,
    ),
  ];

  static final List<ShoppingSession> shoppingSessions = [
    ShoppingSession(
      id: 1,
      name: 'Danh sách chợ tuần này',
      note: 'Mua đầy đủ cho bữa ăn tuần',
      createdAt: DateTime.now(),
      assignedTo: members[0],
      shoppingItems: shoppingItems.take(3).toList(),
      totalItems: 3,
      completedAt: null,
      purchasedItemsCount: 1,
      done: false,
    ),
    ShoppingSession(
      id: 2,
      name: 'Danh sách chợ tuần trước',
      note: 'Đã mua xong',
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      assignedTo: members[1],
      shoppingItems: shoppingItems.skip(3).take(2).toList(),
      totalItems: 2,
      completedAt: DateTime.now().subtract(const Duration(days: 6)),
      purchasedItemsCount: 2,
      done: true,
    ),
  ];

  static final ItemBatchResult itemBatchResultSuccess = ItemBatchResult(
    3,
    [],
    shoppingSessions[0],
  );

  static final ItemBatchResult itemBatchResultFailed = ItemBatchResult(1, [
    (foodName: 'Cá hồi', message: 'Không tìm thấy thực phẩm'),
    (foodName: 'Tôm', message: 'Số lượng quá lớn'),
  ], null);

  static final List<PurchaseItem> purchaseItems = [
    PurchaseItem(itemId: 1, purchasedQuantity: 0.5),
    PurchaseItem(itemId: 2, purchasedQuantity: 0.4),
  ];

  // =========================================================================
  // USER & GROUP & AUTH
  // =========================================================================

  static final GroupRef userGroupRef = GroupRef(1, 'Gia đình Nguyễn', 'admin');

  static final User currentUser = User(
    id: 1,
    email: 'nguyen.van.a@example.com',
    name: 'Nguyễn Văn A',
    username: 'nguyenvana',
    language: Language.vi,
    timezone: 'Asia/Ho_Chi_Minh',
    imageUrl: 'https://example.com/avatars/user1.jpg',
    systemRole: 'user',
    isActive: true,
    group: userGroupRef,
    groupId: 1,
    groupRole: 'admin',
  );

  static final List<User> users = [
    currentUser,
    User(
      id: 2,
      email: 'tran.thi.b@example.com',
      name: 'Trần Thị B',
      username: 'tranthib',
      language: Language.vi,
      timezone: 'Asia/Ho_Chi_Minh',
      imageUrl: 'https://example.com/avatars/user2.jpg',
      systemRole: 'user',
      isActive: true,
      group: userGroupRef,
      groupId: 1,
      groupRole: 'member',
    ),
    User(
      id: 3,
      email: 'le.van.c@example.com',
      name: 'Lê Văn C',
      username: 'levanc',
      language: Language.vi,
      timezone: 'Asia/Ho_Chi_Minh',
      imageUrl: 'https://example.com/avatars/user3.jpg',
      systemRole: 'user',
      isActive: true,
      group: userGroupRef,
      groupId: 1,
      groupRole: 'member',
    ),
    User(
      id: 4,
      email: 'pham.thi.d@example.com',
      name: 'Phạm Thị D',
      username: 'phamthid',
      language: Language.vi,
      timezone: 'Asia/Ho_Chi_Minh',
      imageUrl: 'https://example.com/avatars/user4.jpg',
      systemRole: 'user',
      isActive: true,
    ),
    User(
      id: 5,
      email: 'nguyen.thi.e@example.com',
      name: 'Nguyễn Thị E',
      username: 'nguyenthi e',
      language: Language.vi,
      timezone: 'Asia/Ho_Chi_Minh',
      imageUrl: 'https://example.com/avatars/user5.jpg',
      systemRole: 'user',
      isActive: true,
    ),
    User(
      id: 6,
      email: 'tran.van.f@example.com',
      name: 'Trần Văn F',
      username: 'tranvanf',
      language: Language.vi,
      timezone: 'Asia/Ho_Chi_Minh',
      imageUrl: 'https://example.com/avatars/user6.jpg',
      systemRole: 'user',
      isActive: true,
    ),
    User(
      id: 7,
      email: 'le.thi.g@example.com',
      name: 'Lê Thị G',
      username: 'lethig',
      language: Language.vi,
      timezone: 'Asia/Ho_Chi_Minh',
      imageUrl: 'https://example.com/avatars/user7.jpg',
      systemRole: 'user',
      isActive: true,
    ),
    User(
      id: 8,
      email: 'pham.van.h@example.com',
      name: 'Phạm Văn H',
      username: 'phamvanh',
      language: Language.vi,
      timezone: 'Asia/Ho_Chi_Minh',
      imageUrl: 'https://example.com/avatars/user8.jpg',
      systemRole: 'user',
      isActive: true,
    ),
    User(
      id: 9,
      email: 'nguyen.thi.i@example.com',
      name: 'Nguyễn Thị I',
      username: 'nguyenthi i',
      language: Language.vi,
      timezone: 'Asia/Ho_Chi_Minh',
      imageUrl: 'https://example.com/avatars/user9.jpg',
      systemRole: 'user',
      isActive: true,
    ),
    User(
      id: 10,
      email: 'tran.thi.j@example.com',
      name: 'Trần Thị J',
      username: 'tranthij',
      language: Language.vi,
      timezone: 'Asia/Ho_Chi_Minh',
      imageUrl: 'https://example.com/avatars/user10.jpg',
      systemRole: 'user',
      isActive: true,
    ),
  ];

  static final List<Member> members = [
    Member(
      id: 1,
      name: 'Nguyễn Văn A',
      username: 'nguyenvana',
      imageUrl: 'https://example.com/avatars/user1.jpg',
      role: 'admin',
    ),
    Member(
      id: 2,
      name: 'Trần Thị B',
      username: 'tranthib',
      imageUrl: 'https://example.com/avatars/user2.jpg',
      role: 'member',
    ),
    Member(
      id: 3,
      name: 'Lê Văn C',
      username: 'levanc',
      imageUrl: 'https://example.com/avatars/user3.jpg',
      role: 'member',
    ),
  ];

  static final Group group = Group(
    id: 1,
    name: 'Nhóm Gia đình ',
    members: members,
  );

  static final AuthTokens authTokens = AuthTokens(
    'access_token_mock_123456',
    'refresh_token_mock_789012',
    currentUser,
  );

  // =========================================================================
  // NOTIFICATION
  // =========================================================================

  static final List<AppNotification> notifications = [
    AppNotification(
      id: 1,
      type: 'fridge_expiring',
      title: 'Cá hồi sắp hết hạn',
      body: 'Cá hồi trong tủ lạnh sẽ hết hạn trong 1 ngày.',
      data: {'fridgeItemId': 2},
      read: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    AppNotification(
      id: 2,
      type: 'fridge_expired',
      title: 'Bông cải xanh đã hết hạn',
      body: 'Bông cải xanh đã quá hạn 1 ngày.',
      data: {'fridgeItemId': 4},
      read: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
    ),
    AppNotification(
      id: 3,
      type: 'shopping_reminder',
      title: 'Nhắc nhở mua sắm',
      body: 'Đến ngày đi chợ, hãy kiểm tra danh sách mua sắm.',
      data: {},
      read: true,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    AppNotification(
      id: 4,
      type: 'meal_plan',
      title: 'Kế hoạch bữa ăn mới',
      body: 'Bạn có kế hoạch bữa ăn mới cho ngày mai.',
      data: {},
      read: true,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  // =========================================================================
  // STATS (thống kê)
  // =========================================================================

  static final List<FoodStat> foodStats = [
    FoodStat('Gà', 'kg', 'Thịt', 2.0, 2.0, 1.5, 0.5),
    FoodStat('Cá hồi', 'kg', 'Hải sản', 1.0, 1.0, 0.7, 0.3),
    FoodStat('Cà rốt', 'kg', 'Rau quả', 1.0, 1.0, 0.8, 0.2),
    FoodStat('Trứng', 'quả', 'Sữa & trứng', 12.0, 12.0, 10.0, 2.0),
  ];

  static final List<CategoryStat> categoryStats = [
    CategoryStat('Thịt', 2, 5, 1),
    CategoryStat('Hải sản', 1, 2, 1),
    CategoryStat('Rau quả', 3, 8, 2),
    CategoryStat('Sữa & trứng', 1, 10, 2),
  ];

  static final StatsReport statsReport = StatsReport(
    from: '2026-01-01',
    to: '2026-01-31',
    totals: {'purchased': 10, 'consumed': 8, 'discarded': 2},
    wasteRate: 0.2,
    lists: 4,
    items: 12,
    purchasedItems: 8,
    byFood: foodStats,
    byCategory: categoryStats,
  );

  // =========================================================================
  // STOCK EVENT & AUDIT LOG
  // =========================================================================

  static final List<StockEvent> stockEvents = [
    StockEvent(
      id: 1,
      type: 'purchase',
      foodName: 'Gà',
      unit: 'kg',
      quantity: 0.5,
      actorName: 'Nguyễn Văn A',
      note: 'Mua từ siêu thị',
      occurredAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    StockEvent(
      id: 2,
      type: 'consume',
      foodName: 'Gà',
      unit: 'kg',
      quantity: 0.2,
      actorName: 'Nguyễn Văn A',
      note: 'Nấu gà xào cà rốt',
      occurredAt: DateTime.now().subtract(const Duration(hours: 10)),
    ),
    StockEvent(
      id: 3,
      type: 'discard',
      foodName: 'Bông cải xanh',
      unit: 'bó',
      quantity: 0.2,
      actorName: 'Nguyễn Văn A',
      note: 'Quá hạn',
      occurredAt: DateTime.now().subtract(const Duration(hours: 20)),
    ),
    StockEvent(
      id: 4,
      type: 'add',
      foodName: 'Trứng',
      unit: 'quả',
      quantity: 6,
      actorName: 'Trần Thị B',
      note: 'Thêm từ tủ lạnh',
      occurredAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  static final List<AuditLog> auditLogs = [
    AuditLog(
      id: 1,
      action: 'create_meal_plan',
      entityType: 'MealPlan',
      entityId: 1,
      source: 'app',
      actorName: 'Nguyễn Văn A',
      actorEmail: 'nguyen.van.a@example.com',
      occurredAt: DateTime.now().subtract(const Duration(hours: 5)),
      metadata: {'meal': 'breakfast', 'date': '2026-01-15'},
    ),
    AuditLog(
      id: 2,
      action: 'update_recipe',
      entityType: 'Recipe',
      entityId: 2,
      source: 'app',
      actorName: 'Nguyễn Văn A',
      actorEmail: 'nguyen.van.a@example.com',
      occurredAt: DateTime.now().subtract(const Duration(days: 1)),
      metadata: {'field': 'description'},
    ),
    AuditLog(
      id: 3,
      action: 'delete_shopping_item',
      entityType: 'ShoppingItem',
      entityId: 99,
      source: 'app',
      actorName: 'Trần Thị B',
      actorEmail: 'tran.thi.b@example.com',
      occurredAt: DateTime.now().subtract(const Duration(days: 2)),
      metadata: {'reason': 'duplicate'},
    ),
  ];

  // =========================================================================
  // AI
  // =========================================================================

  static final List<AiConversation> aiConversations = [
    AiConversation(
      1,
      'Cách nấu gà xào cà rốt',
      DateTime.now().subtract(const Duration(hours: 2)),
    ),
    AiConversation(
      2,
      'Thực phẩm sắp hết hạn trong tủ lạnh',
      DateTime.now().subtract(const Duration(days: 1)),
    ),
    AiConversation(
      3,
      'Đề xuất món ăn cho tuần tới',
      DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  static final List<AiMessage> aiMessages1 = [
    AiMessage(
      id: 1,
      role: 'user',
      text: 'Tôi có gà và cà rốt, nấu món gì tốt?',
    ),
    AiMessage(
      id: 2,
      role: 'assistant',
      text: 'Bạn có thể nấu gà xào cà rốt, món này dễ làm và dinh dưỡng.',
      toolCalls: const ['suggest_recipe'],
      attachmentCount: 0,
    ),
  ];

  static final List<AiMessage> aiMessages2 = [
    AiMessage(id: 3, role: 'user', text: 'Tủ lạnh của tôi có gì sắp hết hạn?'),
    AiMessage(
      id: 4,
      role: 'assistant',
      text: 'Cá hồi sắp hết hạn trong 1 ngày và hành lá trong 2 ngày.',
      toolCalls: const ['check_fridge'],
      attachmentCount: 0,
    ),
  ];

  static final List<AiAction> aiActions = [
    AiAction(
      id: 1,
      tool: 'suggest_recipe',
      riskLevel: 'read',
      summary: 'Đề xuất công thức nấu ăn từ nguyên liệu có sẵn',
      status: 'executed',
      resultCode: 'success',
      expiresAt: null,
    ),
    AiAction(
      id: 2,
      tool: 'add_shopping_items',
      riskLevel: 'write',
      summary: 'Thêm cá hồi vào danh sách mua sắm',
      status: 'proposed',
      dependsOn: 1,
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
    ),
    AiAction(
      id: 3,
      tool: 'delete_expired_food',
      riskLevel: 'destructive',
      summary: 'Xóa bông cải xanh đã hết hạn khỏi tủ lạnh',
      status: 'rejected',
      resultCode: 'user_rejected',
      expiresAt: null,
    ),
  ];

  static final AiChatResult aiChatResult = AiChatResult(
    1,
    'Bạn có thể nấu gà xào cà rốt với nguyên liệu có sẵn.',
    aiActions.where((a) => a.status == 'proposed').toList(),
  );

  static final AiConversationDetail aiConversationDetail = AiConversationDetail(
    aiConversations[0],
    aiMessages1,
    aiActions.where((a) => a.status != 'rejected').toList(),
  );

  static final AiSettings aiSettings = AiSettings(
    enabled: true,
    autoExecuteLevel: 'read',
    dailyTokenLimit: 1000,
    available: true,
  );

  static final List<AiSuggestion> aiSuggestions = [
    AiSuggestion(1, AiSuggestionType.recipe, 'Gợi ý nấu ăn từ tủ lạnh'),
    AiSuggestion(2, AiSuggestionType.shopping, 'Gợi ý danh sách mua sắm'),
    AiSuggestion(3, AiSuggestionType.food, 'Gợi ý giảm thiểu thực phẩm thải bỏ'),
  ];

  static final AiActionResult aiActionResultSuccess = AiActionResult(
    1,
    'success',
    'Đã thực hiện thành công.',
  );

  static final AiActionResult aiActionResultFailed = AiActionResult(
    2,
    'failed',
    'Không thể kết nối đến máy chủ AI.',
  );

  // =========================================================================
  // HÀM TIỆN ÍCH
  // =========================================================================
  static User getCurrentUser() {
    return currentUser;
  }

  static Group getCurrentGroup() {
    return group;
  }

  static List<AiSuggestion> getAiSuggestions() {
    return aiSuggestions;
  }

  static MealPlan getRandomMealPlan() {
    final index = DateTime.now().millisecond % mealPlans.length;
    return mealPlans[index];
  }

  static List<FridgeItem> getFridgeItemsExpiringSoon() {
    return fridgeItems.where((i) => i.daysLeft > 0 && i.daysLeft <= 2).toList();
  }

  static List<FridgeItem> getFridgeItemsExpired() {
    return fridgeItems.where((i) => i.daysLeft < 0).toList();
  }

  static List<FridgeItem> getFridgeItemsFresh() {
    return fridgeItems.where((i) => i.daysLeft > 2).toList();
  }

  static List<MealPlan> getMealPlansByDate(DateTime date) {
    return mealPlans.where((meal) => meal.date == date).toList();
  }

  static List<MealPlan> getMealPlansByPeriod(MealPeriod slot) {
    return mealPlans.where((p) => p.mealPeriod == slot).toList();
  }

  static List<Recipe> getRecipesByFoodId(int foodId) {
    return recipes.where((r) => r.food.id == foodId).toList();
  }

  static List<RecipeSuggestion> getCookableSuggestions() {
    return recipeSuggestions.where((s) => s.canCook).toList();
  }

  static List<RecipeSuggestion> getNotCookableSuggestions() {
    return recipeSuggestions.where((s) => !s.canCook).toList();
  }

  static ShoppingSession getCurrentShoppingSession(int id) {
    return shoppingSessions.firstWhere((s) => s.id == id);
  }

  static List<ShoppingItem> getPendingShoppingItems() {
    return shoppingItems
        .where((i) => i.status == ShoppingStatus.pending)
        .toList();
  }

  static List<ShoppingItem> getBoughtShoppingItems() {
    return shoppingItems
        .where((i) => i.status != ShoppingStatus.pending)
        .toList();
  }

  static List<AppNotification> getNotificationsUnread() {
    return notifications.where((n) => !n.read).toList();
  }

  static ShoppingSession getShoppingSessionById(int id) {
    return shoppingSessions.firstWhere((l) => l.id == id);
  }

  static List<Food> getFoodsByCategoryId(int categoryId) {
    return foods.where((f) => f.category.id == categoryId).toList();
  }

  static List<Food> getFoodsByUnitId(int unitId) {
    return foods.where((f) => f.unit.id == unitId).toList();
  }

  static int getTotalFoods() {
    return foods.length;
  }
}
