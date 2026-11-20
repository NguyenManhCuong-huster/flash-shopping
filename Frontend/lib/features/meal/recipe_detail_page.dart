import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import './meal_service.dart';
import '../auth/session_service.dart';
import './meal_recipe.dart';
import '../../core/utils/app_colors.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/base_view_model.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/widgets_common.dart';
import 'recipe_form_page.dart';

class RecipeDetailViewModel extends BaseViewModel {
  RecipeDetailViewModel(this._meals, this.recipeId);
  final MealService _meals;
  final int recipeId;
  Recipe? recipe;

  Future<void> load() =>
      runLoad(() async => recipe = await _meals.recipe(recipeId));
  Future<void> delete() => runSave(() => _meals.deleteRecipe(recipe!));
}

class RecipeDetailPage extends StatelessWidget {
  const RecipeDetailPage({super.key, required this.recipeId});
  final int recipeId;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (c) =>
        RecipeDetailViewModel(c.read<MealService>(), recipeId)..load(),
    child: const _View(),
  );
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RecipeDetailViewModel>();
    final session = context.watch<SessionService>();
    final r = vm.recipe;
    // Người tạo hoặc trưởng nhóm được sửa/xóa (backend kiểm tra lại)
    final canEdit =
        r != null && (r.createdById == session.user?.id || session.isLeader);
    return Scaffold(
      appBar: AppBar(
        title: Text(r?.name ?? 'Công thức'),
        actions: [
          if (canEdit && r != null) ...[
            IconButton(
              icon: Icon(LucideIcons.edit, size: 24, color: AppColor.primary),
              onPressed: () async {
                if (await pushPage<bool>(context, RecipeFormPage(recipe: r)) ==
                    true)
                  vm.load();
              },
            ),
            IconButton(
              icon: Icon(LucideIcons.trash2, size: 24, color: AppColor.danger),
              onPressed: () async {
                if (await confirmDialog(
                      context: context,
                      icon: LucideIcons.trash2,
                      title: 'Xóa công thức',
                      message: 'Xóa công thức "${r.name}"?',
                    ) &&
                    context.mounted) {
                  final ok = await runAction(context, () async {
                    await vm.delete();
                    return true;
                  }, success: 'Đã xóa công thức');
                  if (ok == true && context.mounted) Navigator.pop(context);
                }
              },
            ),
          ],
        ],
      ),
      body: vm.loading && r == null
          ? const Center(child: CircularProgressIndicator())
          : r == null
          ? ErrorStateWidget(
              message: vm.loadError ?? 'Không tìm thấy công thức',
              onRetry: vm.load,
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(r.description, style: const TextStyle(fontSize: 15)),
                if (r.createdByName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Người tạo: ${r.createdByName}',
                      style: const TextStyle(color: AppColor.muted),
                    ),
                  ),
                const SectionTitle('Nguyên liệu'),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.star, color: AppColor.warning),
                  title: Text('${r.food.name} (nguyên liệu chính)'),
                ),
                for (final i in r.ingredients)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.circle, size: 8),
                    title: Text(i.food.name),
                    trailing: i.quantity == null
                        ? null
                        : NumText(FormatUtils.formatQuantityUnit(i.quantity!, i.food.unit)),
                  ),
                const SectionTitle('Cách làm'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    MealService.htmlToText(r.htmlContent),
                    style: const TextStyle(height: 1.5),
                  ),
                ),
              ],
            ),
    );
  }
}
