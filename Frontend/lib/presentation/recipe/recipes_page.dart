import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/meal_service.dart';
import '../../data/models/meal_recipe.dart';
import '../shared/base_view_model.dart';
import '../shared/widgets.dart';
import 'recipe_detail_page.dart';
import 'recipe_form_page.dart';
import 'suggestions_page.dart';

class RecipesViewModel extends BaseViewModel {
  RecipesViewModel(this._meals);
  final MealService _meals;

  List<Recipe> recipes = [];
  String query = '';
  int _page = 1;
  bool hasMore = false;

  Future<void> load() => runLoad(() async {
        _page = 1;
        final r = await _meals.recipes(q: query);
        recipes = r.items;
        hasMore = r.hasMore;
      });

  Future<void> loadMore() async {
    if (!hasMore || loading) return;
    final r = await _meals.recipes(q: query, page: ++_page);
    recipes = [...recipes, ...r.items];
    hasMore = r.hasMore;
    notifyListeners();
  }
}

/// UC07 - danh sách và tìm kiếm công thức của nhóm.
class RecipesPage extends StatelessWidget {
  const RecipesPage({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(create: (c) => RecipesViewModel(c.read<MealService>())..load(), child: const _RecipesView());
}

class _RecipesView extends StatefulWidget {
  const _RecipesView();
  @override
  State<_RecipesView> createState() => _RecipesViewState();
}

class _RecipesViewState extends State<_RecipesView> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RecipesViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Công thức nấu ăn'), actions: [
        IconButton(tooltip: 'Gợi ý từ tủ lạnh', icon: const Icon(Icons.auto_awesome), onPressed: () => pushPage(context, const SuggestionsPage())),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (await pushPage<bool>(context, const RecipeFormPage()) == true) vm.load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Thêm công thức'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Tìm theo tên món, mô tả, nguyên liệu chính'),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400), () {
                vm.query = v;
                vm.load();
              });
            },
          ),
        ),
        Expanded(
          child: AsyncBody(
            loading: vm.loading,
            error: vm.loadError,
            isEmpty: vm.recipes.isEmpty,
            onRetry: vm.load,
            emptyIcon: Icons.menu_book_outlined,
            emptyText: 'Chưa có công thức nào.',
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) vm.loadMore();
                return false;
              },
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 90),
                itemCount: vm.recipes.length,
                itemBuilder: (_, i) {
                  final r = vm.recipes[i];
                  return Card(
                    child: ListTile(
                      leading: NetImage(r.food.imageUrl, icon: Icons.menu_book),
                      title: Text(r.name),
                      subtitle: Text('${r.description}\nNguyên liệu chính: ${r.food.name}${r.ingredients.isNotEmpty ? ' + ${r.ingredients.length} nguyên liệu' : ''}',
                          maxLines: 3, overflow: TextOverflow.ellipsis),
                      isThreeLine: true,
                      onTap: () async {
                        await pushPage(context, RecipeDetailPage(recipeId: r.id));
                        vm.load();
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
