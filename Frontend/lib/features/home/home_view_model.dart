import '../../core/base_view_model.dart';
import '../../core/model_common.dart';
import '../../core/utils/mock_data.dart';
import '../../core/utils/validators.dart';
import '../ai/admin_ai_service.dart';
import '../ai/ai.dart';
import '../auth/session_service.dart';
import '../food/food_service.dart';
import '../meal/meal_service.dart';
import '../shopping/shopping_service.dart';
import '../food/food.dart';
import '../meal/meal_recipe.dart';
import '../shopping/shopping.dart';

class HomeViewModel extends BaseViewModel {
  HomeViewModel(
    this._pantry,
    this._meals,
    this._shopping,
    this._ai,
    this._session,
  );
  final FoodService _pantry;
  final MealService _meals;
  final ShoppingService _shopping;
  final AiService _ai;
  final SessionService _session;
  // Lấy userId từ session để load dữ liệu cá nhân.
  int userId = 1;
  FridgeSummary summary = const FridgeSummary();
  List<FridgeItem> expiring = MockData.getFridgeItemsExpiringSoon();
  List<MealPlan> todayMeals = [];
  List<ShoppingSession> myLists = [];
  List<AiSuggestion> suggestions = [];

  Future<void> load() => runLoad(() async {
    if (!_session.hasGroup) return;
    final today = DateTime.now();
    final results = await Future.wait([
      _pantry.fridge(expiringDays: 3),
      _meals.week(today),
      _shopping.sessions(assignedToMe: true),
      if (_session.isLeader) _ai.suggestions(),
    ]);
    final fridge = results[0] as FridgeResult;
    summary = fridge.summary;
    expiring = fridge.items.take(5).toList();
    todayMeals = (results[1] as List<MealPlan>)
        .where((m) => m.date == isoDate(today))
        .toList();
    myLists = (results[2] as Paged<ShoppingSession>).items;
    suggestions = results.length > 3 ? results[3] as List<AiSuggestion> : [];
  });

  Future<int> accept(AiSuggestion s) => runSave(() => _ai.acceptSuggestion(s));
  Future<void> dismiss(AiSuggestion s) => runSave(() async {
    await _ai.dismissSuggestion(s);
    suggestions.remove(s);
  });
}