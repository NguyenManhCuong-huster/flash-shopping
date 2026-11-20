import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import './meal_service.dart';
import '../auth/session_service.dart';
import '../shopping/shopping_service.dart';
import './meal_recipe.dart';
import '../shopping/shopping.dart';
import '../../core/utils/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/base_view_model.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/widgets_common.dart';
import '../../core/widgets/buttons/primary_button.dart';
import '../shopping/shopping_session_detail_page.dart';

class IngredientsViewModel extends BaseViewModel {
  IngredientsViewModel(this._meals, this._shopping, {this.plan, this.day});
  final MealService _meals;
  final ShoppingService _shopping;
  final MealPlan? plan;
  final DateTime? day;

  List<IngredientStatus> items = [];
  List<IngredientStatus> get missing => items.where((i) => !i.enough).toList();

  Future<void> load() => runLoad(
    () async => items = plan != null
        ? await _meals.ingredientsFor(plan!)
        : await _meals.ingredientsForDay(day!),
  );

  Future<List<ShoppingSession>> openLists() async =>
      (await _shopping.sessions()).items;

  Future<ShoppingSession?> addMissing({int? sessionId}) => runSave(
    () => _meals.addMissingToShopping(plan: plan, day: day, sessionId: sessionId),
  );
}

/// UC08 bước 3-4: nguyên liệu cần, đang có và còn thiếu; tùy chọn thêm phần thiếu vào danh sách mua.
class IngredientsPage extends StatelessWidget {
  const IngredientsPage({super.key, this.plan, this.day});
  final MealPlan? plan;
  final DateTime? day;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (c) => IngredientsViewModel(
      c.read<MealService>(),
      c.read<ShoppingService>(),
      plan: plan,
      day: day,
    )..load(),
    child: _View(
      title: plan != null
          ? (plan!.name)
          : 'Ngày ${FormatUtils.formatDate(day!)}',
    ),
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
                child: PrimaryButton(
                  saving: vm.saving,
                  onPressed: () => _addMissing(context, vm),
                  label:
                      'Thêm ${vm.missing.length} nguyên liệu thiếu vào danh sách mua',
                  icon: Icons.add_shopping_cart,
                ),
              ),
            )
          : null,
      body: AsyncSection(
        loading: vm.loading,
        error: vm.loadError,
        isEmpty: vm.items.isEmpty,
        onRetry: vm.load,
        emptyText: 'Không có nguyên liệu nào cần kiểm tra.',
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                vm.missing.isEmpty
                    ? 'Tủ lạnh đã đủ nguyên liệu.'
                    : 'Còn thiếu ${vm.missing.length}/${vm.items.length} nguyên liệu.',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: vm.missing.isEmpty
                      ? AppColor.primary
                      : AppColor.warning,
                ),
              ),
            ),
            for (final i in vm.items)
              Card(
                child: ListTile(
                  leading: Icon(
                    i.enough ? Icons.check_circle : Icons.error_outline,
                    color: i.enough ? AppColor.primary : AppColor.warning,
                  ),
                  title: Text(i.food.name),
                  subtitle: Text(
                    'Cần: ${i.requiredQty == null ? 'có trong tủ' : FormatUtils.formatQuantityUnit(i.requiredQty!, i.food.unit)} · Đang có: ${FormatUtils.formatQuantityUnit(i.available, i.food.unit)}'
                    '${i.expiringSoon ? ' · sắp hết hạn' : ''}',
                  ),
                  trailing: i.enough
                      ? null
                      : NumText(
                          'Thiếu ${FormatUtils.formatQuantityUnit(i.missing, i.food.unit)}',
                          style: const TextStyle(
                            color: AppColor.warning,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _addMissing(
    BuildContext context,
    IngredientsViewModel vm,
  ) async {
    final lists = await runAction(context, vm.openLists) ?? [];
    if (!context.mounted) return;
    final choice = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text(
                'Thêm vào danh sách nào?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Tạo danh sách mới'),
              onTap: () => Navigator.pop(ctx, 0),
            ),
            for (final l in lists)
              ListTile(
                leading: const Icon(Icons.shopping_cart_outlined),
                title: Text(l.name),
                subtitle: Text(FormatUtils.formatDateTime(l.createdAt)),
                onTap: () => Navigator.pop(ctx, l.id),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    final session = await runAction(
      context,
      () => vm.addMissing(sessionId: choice == 0 ? null : choice),
      success: 'Đã thêm nguyên liệu còn thiếu vào danh sách mua',
    );
    if (session != null && context.mounted)
      await pushPage(context, ShoppingSessionDetailPage(sessionId: session.id));
  }
}
