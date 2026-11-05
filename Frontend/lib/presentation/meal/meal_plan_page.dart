import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/meal_service.dart';
import '../../application/session_service.dart';
import '../../application/validation/validators.dart';
import '../../data/models/meal_recipe.dart';
import '../group/group_page.dart';
import '../recipe/recipe_detail_page.dart';
import '../shared/base_view_model.dart';
import '../shared/format.dart';
import '../shared/theme.dart';
import '../shared/widgets.dart';
import 'ingredients_page.dart';
import 'meal_form_page.dart';

class MealPlanViewModel extends BaseViewModel {
  MealPlanViewModel(this._meals);
  final MealService _meals;

  /// Thứ Hai của tuần đang xem
  DateTime weekStart = _monday(DateTime.now());
  DateTime selected = dateOnly(DateTime.now());
  List<MealPlan> plans = [];

  static DateTime _monday(DateTime d) => dateOnly(d).subtract(Duration(days: d.weekday - 1));

  List<DateTime> get days => List.generate(7, (i) => weekStart.add(Duration(days: i)));
  List<MealPlan> plansOf(DateTime day) => plans.where((p) => p.date == isoDate(day)).toList();

  Future<void> load() => runLoad(() async => plans = await _meals.week(weekStart));

  void select(DateTime d) {
    selected = d;
    notifyListeners();
  }

  void shiftWeek(int delta) {
    weekStart = weekStart.add(Duration(days: 7 * delta));
    selected = weekStart;
    load();
  }

  Future<void> delete(MealPlan p) => runSave(() async {
        await _meals.deletePlan(p);
        plans.remove(p);
      });
}

/// UC08 - Lập kế hoạch bữa ăn: xem lịch theo ngày/tuần; trưởng nhóm thêm/xóa.
class MealPlanPage extends StatelessWidget {
  const MealPlanPage({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(create: (c) => MealPlanViewModel(c.read<MealService>())..load(), child: const _MealView());
}

class _MealView extends StatelessWidget {
  const _MealView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MealPlanViewModel>();
    final session = context.watch<SessionService>();
    if (!session.hasGroup) {
      return Scaffold(appBar: AppBar(title: const Text('Bữa ăn')), body: NeedGroupView(onCreateGroup: () => pushPage(context, const GroupPage())));
    }
    final dayPlans = vm.plansOf(vm.selected);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kế hoạch bữa ăn'),
        actions: [
          IconButton(
            tooltip: 'Nguyên liệu cả ngày',
            icon: const Icon(Icons.checklist),
            onPressed: dayPlans.isEmpty ? null : () => pushPage(context, IngredientsPage(day: vm.selected)),
          ),
        ],
      ),
      floatingActionButton: session.isLeader
          ? FloatingActionButton.extended(
              onPressed: () async {
                if (await pushPage<bool>(context, MealFormPage(date: vm.selected)) == true) vm.load();
              },
              icon: const Icon(Icons.add),
              label: const Text('Thêm bữa'),
            )
          : null,
      body: Column(children: [
        Row(children: [
          IconButton(onPressed: () => vm.shiftWeek(-1), icon: const Icon(Icons.chevron_left)),
          Expanded(
            child: Text('Tuần ${fmtDate(vm.weekStart)} - ${fmtDate(vm.weekStart.add(const Duration(days: 6)))}',
                textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          IconButton(onPressed: () => vm.shiftWeek(1), icon: const Icon(Icons.chevron_right)),
        ]),
        SizedBox(
          height: 72,
          child: Row(children: [
            for (final d in vm.days)
              Expanded(
                child: GestureDetector(
                  onTap: () => vm.select(d),
                  child: Container(
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: d == vm.selected ? AppTheme.primary : (d == dateOnly(DateTime.now()) ? AppTheme.primary.withValues(alpha: 0.1) : null),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(fmtWeekday(d), style: TextStyle(fontSize: 11, color: d == vm.selected ? Colors.white : AppTheme.muted)),
                      Text('${d.day}', style: TextStyle(fontWeight: FontWeight.bold, color: d == vm.selected ? Colors.white : Colors.black)),
                      if (vm.plansOf(d).isNotEmpty)
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: d == vm.selected ? Colors.white : AppTheme.primary, shape: BoxShape.circle)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
        const Divider(),
        Expanded(
          child: AsyncBody(
            loading: vm.loading,
            error: vm.loadError,
            isEmpty: false,
            onRetry: vm.load,
            child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
              for (final slot in MealSlot.values) ...[
                SectionTitle('${slot.label} · ${fmtDate(vm.selected)}'),
                ...dayPlans.where((p) => p.meal == slot).map((p) => _planTile(context, vm, p, session.isLeader)),
                if (!dayPlans.any((p) => p.meal == slot))
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Text('Chưa có món', style: TextStyle(color: AppTheme.muted))),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _planTile(BuildContext context, MealPlanViewModel vm, MealPlan p, bool isLeader) => Card(
        child: ListTile(
          leading: NetImage(p.food.imageUrl, icon: Icons.restaurant),
          title: Text(p.recipeName ?? p.food.name),
          subtitle: Text(p.recipeName != null ? 'Công thức · nguyên liệu chính: ${p.food.name}' : 'Thực phẩm'),
          onTap: () => _actions(context, vm, p, isLeader),
          trailing: const Icon(Icons.more_vert),
        ),
      );

  Future<void> _actions(BuildContext context, MealPlanViewModel vm, MealPlan p, bool isLeader) async {
    final v = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(p.recipeName ?? p.food.name, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(p.meal.label)),
          ListTile(leading: const Icon(Icons.checklist), title: const Text('Kiểm tra nguyên liệu'), onTap: () => Navigator.pop(ctx, 'ing')),
          if (p.recipeId != null) ListTile(leading: const Icon(Icons.menu_book), title: const Text('Xem công thức'), onTap: () => Navigator.pop(ctx, 'recipe')),
          if (isLeader) ListTile(leading: const Icon(Icons.delete_outline, color: AppTheme.danger), title: const Text('Xóa khỏi kế hoạch'), onTap: () => Navigator.pop(ctx, 'del')),
        ]),
      ),
    );
    if (!context.mounted) return;
    switch (v) {
      case 'ing':
        await pushPage(context, IngredientsPage(plan: p));
      case 'recipe':
        await pushPage(context, RecipeDetailPage(recipeId: p.recipeId!));
      case 'del':
        if (await confirmDialog(context, title: 'Xóa bữa ăn', message: 'Xóa ${p.recipeName ?? p.food.name} khỏi ${p.meal.label.toLowerCase()}?') && context.mounted) {
          await runAction(context, () => vm.delete(p), success: 'Đã xóa');
        }
    }
  }
}
