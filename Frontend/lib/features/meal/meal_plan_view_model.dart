import './meal_service.dart';
import './meal_recipe.dart';
import '../../core/utils/format.dart';
import '../../core/base_view_model.dart';


class MealPlanViewModel extends BaseViewModel {
  MealPlanViewModel(this._meals);
  final MealService _meals;

  /// Thứ Hai của tuần đang xem
  DateTime weekStart = _monday(DateTime.now());
  DateTime selectedDate = FormatUtils.dateOnly(DateTime.now());
  List<MealPlan> plans = [];

  static DateTime _monday(DateTime d) =>
      FormatUtils.dateOnly(d).subtract(Duration(days: d.weekday - 1));

  List<DateTime> get days =>
      List.generate(7, (i) => weekStart.add(Duration(days: i)));
  List<MealPlan> plansOf(DateTime day) => plans
      .where((p) => p.date == FormatUtils.formatIsoDate(day.toString()))
      .toList();

  Future<void> load() =>
      runLoad(() async => plans = await _meals.week(weekStart));

  void select(DateTime d) {
    selectedDate = d;
    notifyListeners();
  }

  void shiftWeek(int delta) {
    weekStart = weekStart.add(Duration(days: 7 * delta));
    selectedDate = weekStart;
    load();
  }

  Future<void> delete(MealPlan p) => runSave(() async {
    await _meals.deleteMealPlan(p);
    plans.remove(p);
  });
}

class CreateMealPlanModalViewModel extends BaseViewModel {
  CreateMealPlanModalViewModel(this._meals);
  final MealService _meals;

  List<Recipe> recipes = [];

  Future<void> load() =>
      runLoad(() async => recipes = (await _meals.recipes()).items);

  Future<MealPlan> createMealPlan({
    required Recipe recipe,
    required DateTime date,
    required MealPeriod period,
  }) => runSave(
    () => _meals.createMealPlan(recipe: recipe, date: date, period: period),
  );
}