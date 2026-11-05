import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/meal_service.dart';
import '../../data/models/meal_recipe.dart';
import '../shared/base_view_model.dart';
import '../shared/format.dart';
import '../shared/theme.dart';
import '../shared/widgets.dart';
import 'recipe_detail_page.dart';

class SuggestionsViewModel extends BaseViewModel {
  SuggestionsViewModel(this._meals);
  final MealService _meals;

  List<RecipeSuggestion> items = [];
  bool onlyCookable = false;

  Future<void> load() => runLoad(() async => items = await _meals.suggestions(onlyCookable: onlyCookable));

  void toggle() {
    onlyCookable = !onlyCookable;
    load();
  }
}

/// UC09 - Gợi ý món ăn: phân tích tủ lạnh, ưu tiên món nấu được ngay và dùng đồ sắp hết hạn, hiển thị phần thiếu.
class SuggestionsPage extends StatelessWidget {
  const SuggestionsPage({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(create: (c) => SuggestionsViewModel(c.read<MealService>())..load(), child: const _View());
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SuggestionsViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Gợi ý món từ tủ lạnh')),
      body: Column(children: [
        SwitchListTile(title: const Text('Chỉ món nấu được ngay'), value: vm.onlyCookable, onChanged: (_) => vm.toggle()),
        Expanded(
          child: AsyncBody(
            loading: vm.loading,
            error: vm.loadError,
            isEmpty: vm.items.isEmpty,
            onRetry: vm.load,
            emptyIcon: Icons.auto_awesome_outlined,
            emptyText: vm.onlyCookable ? 'Chưa có món nào đủ nguyên liệu.' : 'Hãy thêm công thức để nhận gợi ý.',
            child: ListView.builder(
              itemCount: vm.items.length,
              itemBuilder: (_, i) {
                final s = vm.items[i];
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => pushPage(context, RecipeDetailPage(recipeId: s.recipe.id)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(s.recipe.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                          s.canCook ? const Pill('Nấu được ngay') : Pill('Có ${s.available}/${s.total}', color: AppTheme.warning),
                        ]),
                        if (s.expiring.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('Dùng đồ sắp hết hạn: ${s.expiring.join(', ')}', style: const TextStyle(color: AppTheme.warning)),
                          ),
                        if (s.missing.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Còn thiếu: ${s.missing.map((m) => m.requiredQty == null ? m.food.name : '${m.food.name} ${fmtQtyUnit(m.missing, m.food.unit)}').join(', ')}',
                              style: const TextStyle(color: AppTheme.muted),
                            ),
                          ),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }
}
