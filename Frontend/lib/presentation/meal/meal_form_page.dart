import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/meal_service.dart';
import '../../data/models/food.dart';
import '../../data/models/meal_recipe.dart';
import '../../data/remote/api_client.dart';
import '../shared/base_view_model.dart';
import '../shared/pickers.dart';
import '../shared/widgets.dart';

class MealFormViewModel extends BaseViewModel {
  MealFormViewModel(this._meals);
  final MealService _meals;

  List<Recipe> recipes = [];

  Future<void> load() => runLoad(() async => recipes = (await _meals.recipes()).items);

  Future<MealPlan> save({Food? food, Recipe? recipe, required DateTime date, required MealSlot meal}) =>
      runSave(() => _meals.createPlan(foodName: food?.name, recipe: recipe, date: date, meal: meal));
}

/// Thêm bữa ăn: chọn ngày, bữa (sáng/trưa/tối) và món theo công thức hoặc theo thực phẩm.
class MealFormPage extends StatelessWidget {
  const MealFormPage({super.key, required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) =>
      ChangeNotifierProvider(create: (c) => MealFormViewModel(c.read<MealService>())..load(), child: _MealForm(date: date));
}

class _MealForm extends StatefulWidget {
  const _MealForm({required this.date});
  final DateTime date;
  @override
  State<_MealForm> createState() => _MealFormState();
}

class _MealFormState extends State<_MealForm> {
  late DateTime _date = widget.date;
  MealSlot _meal = MealSlot.dinner;
  bool _byRecipe = true;
  Recipe? _recipe;
  Food? _food;

  Future<void> _submit() async {
    if (_byRecipe ? _recipe == null : _food == null) {
      return showMessage(context, _byRecipe ? 'Hãy chọn một công thức' : 'Hãy chọn thực phẩm', error: true);
    }
    final vm = context.read<MealFormViewModel>();
    try {
      await vm.save(food: _byRecipe ? null : _food, recipe: _byRecipe ? _recipe : null, date: _date, meal: _meal);
      if (!mounted) return;
      showMessage(context, 'Đã thêm vào kế hoạch. Có thể kiểm tra nguyên liệu từ lịch bữa ăn.');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true, retry: e.network ? _submit : null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MealFormViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Thêm bữa ăn')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        DateField(label: 'Ngày', value: _date, onChanged: (d) => setState(() => _date = d)),
        const SizedBox(height: 12),
        SegmentedButton<MealSlot>(
          segments: [for (final m in MealSlot.values) ButtonSegment(value: m, label: Text(m.label))],
          selected: {_meal},
          onSelectionChanged: (s) => setState(() => _meal = s.first),
        ),
        const SizedBox(height: 16),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Theo công thức'), icon: Icon(Icons.menu_book)),
            ButtonSegment(value: false, label: Text('Theo thực phẩm'), icon: Icon(Icons.egg_alt)),
          ],
          selected: {_byRecipe},
          onSelectionChanged: (s) => setState(() => _byRecipe = s.first),
        ),
        const SizedBox(height: 12),
        if (_byRecipe)
          vm.loading
              ? const LinearProgressIndicator()
              : vm.recipes.isEmpty
                  ? const Text('Nhóm chưa có công thức nào. Hãy thêm ở mục Công thức hoặc chọn "Theo thực phẩm".')
                  : DropdownButtonFormField<Recipe>(
                      initialValue: _recipe,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Công thức'),
                      items: [for (final r in vm.recipes) DropdownMenuItem(value: r, child: Text('${r.name} (${r.food.name})', overflow: TextOverflow.ellipsis))],
                      onChanged: (r) => setState(() => _recipe = r),
                    )
        else
          InkWell(
            onTap: () async {
              final f = await pickFood(context);
              if (f != null) setState(() => _food = f);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Thực phẩm / món', suffixIcon: Icon(Icons.search)),
              child: Text(_food?.name ?? 'Chọn thực phẩm'),
            ),
          ),
        const SizedBox(height: 8),
        const Text('Lập kế hoạch không tự trừ tồn kho. Sau khi nấu, hãy ghi nhận "Đã dùng" trong tủ lạnh.', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 20),
        SaveButton(saving: vm.saving, onPressed: _submit),
      ]),
    );
  }
}
