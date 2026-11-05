import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/meal_service.dart';
import '../../application/session_service.dart';
import '../../application/shopping_service.dart';
import '../../data/models/meal_recipe.dart';
import '../../data/models/shopping.dart';
import '../shared/base_view_model.dart';
import '../shared/format.dart';
import '../shared/theme.dart';
import '../shared/widgets.dart';
import '../shopping/shopping_detail_page.dart';

class IngredientsViewModel extends BaseViewModel {
  IngredientsViewModel(this._meals, this._shopping, {this.plan, this.day});
  final MealService _meals;
  final ShoppingService _shopping;
  final MealPlan? plan;
  final DateTime? day;

  List<IngredientStatus> items = [];
  List<IngredientStatus> get missing => items.where((i) => !i.enough).toList();

  Future<void> load() => runLoad(() async => items = plan != null ? await _meals.ingredientsFor(plan!) : await _meals.ingredientsForDay(day!));

  Future<List<ShoppingList>> openLists() async => (await _shopping.lists()).items;

  Future<ShoppingList?> addMissing({int? listId}) => runSave(() => _meals.addMissingToShopping(plan: plan, day: day, listId: listId));
}

/// UC08 bước 3-4: nguyên liệu cần, đang có và còn thiếu; tùy chọn thêm phần thiếu vào danh sách mua.
class IngredientsPage extends StatelessWidget {
  const IngredientsPage({super.key, this.plan, this.day});
  final MealPlan? plan;
  final DateTime? day;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (c) => IngredientsViewModel(c.read<MealService>(), c.read<ShoppingService>(), plan: plan, day: day)..load(),
        child: _View(title: plan != null ? (plan!.recipeName ?? plan!.food.name) : 'Ngày ${fmtDate(day!)}'),
      );
}

class _View extends StatelessWidget {
  const _View({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<IngredientsViewModel>();
    final isLeader = context.watch<SessionService>().isLeader;
    return Scaffold(
      appBar: AppBar(title: Text('Nguyên liệu: $title')),
      bottomNavigationBar: vm.missing.isNotEmpty && isLeader
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SaveButton(saving: vm.saving, onPressed: () => _addMissing(context, vm), label: 'Thêm ${vm.missing.length} nguyên liệu thiếu vào danh sách mua', icon: Icons.add_shopping_cart),
              ),
            )
          : null,
      body: AsyncBody(
        loading: vm.loading,
        error: vm.loadError,
        isEmpty: vm.items.isEmpty,
        onRetry: vm.load,
        emptyText: 'Không có nguyên liệu nào cần kiểm tra.',
        child: ListView(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              vm.missing.isEmpty ? 'Tủ lạnh đã đủ nguyên liệu.' : 'Còn thiếu ${vm.missing.length}/${vm.items.length} nguyên liệu.',
              style: TextStyle(fontWeight: FontWeight.bold, color: vm.missing.isEmpty ? AppTheme.primary : AppTheme.warning),
            ),
          ),
          for (final i in vm.items)
            Card(
              child: ListTile(
                leading: Icon(i.enough ? Icons.check_circle : Icons.error_outline, color: i.enough ? AppTheme.primary : AppTheme.warning),
                title: Text(i.food.name),
                subtitle: Text('Cần: ${i.requiredQty == null ? 'có trong tủ' : fmtQtyUnit(i.requiredQty!, i.food.unit)} · Đang có: ${fmtQtyUnit(i.available, i.food.unit)}'
                    '${i.expiringSoon ? ' · sắp hết hạn' : ''}'),
                trailing: i.enough ? null : NumText('Thiếu ${fmtQtyUnit(i.missing, i.food.unit)}', style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.bold)),
              ),
            ),
        ]),
      ),
    );
  }

  Future<void> _addMissing(BuildContext context, IngredientsViewModel vm) async {
    final lists = await runAction(context, vm.openLists) ?? [];
    if (!context.mounted) return;
    final choice = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const ListTile(title: Text('Thêm vào danh sách nào?', style: TextStyle(fontWeight: FontWeight.bold))),
          ListTile(leading: const Icon(Icons.add), title: const Text('Tạo danh sách mới'), onTap: () => Navigator.pop(ctx, 0)),
          for (final l in lists)
            ListTile(leading: const Icon(Icons.shopping_cart_outlined), title: Text(l.name), subtitle: Text(fmtIsoDate(l.date)), onTap: () => Navigator.pop(ctx, l.id)),
        ]),
      ),
    );
    if (choice == null || !context.mounted) return;
    final list = await runAction(context, () => vm.addMissing(listId: choice == 0 ? null : choice), success: 'Đã thêm nguyên liệu còn thiếu vào danh sách mua');
    if (list != null && context.mounted) await pushPage(context, ShoppingDetailPage(listId: list.id));
  }
}
