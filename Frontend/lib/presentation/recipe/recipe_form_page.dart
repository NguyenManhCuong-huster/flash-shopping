import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/meal_service.dart';
import '../../application/validation/validators.dart';
import '../../data/models/meal_recipe.dart';
import '../../data/remote/api_client.dart';
import '../shared/base_view_model.dart';
import '../shared/format.dart';
import '../shared/pickers.dart';
import '../shared/widgets.dart';

class RecipeFormViewModel extends BaseViewModel {
  RecipeFormViewModel(this._meals);
  final MealService _meals;

  Future<Recipe> save({Recipe? existing, required String foodName, required String name, required String description, required String instructions, required List<({String foodName, double? quantity})> ingredients}) =>
      runSave(() => _meals.saveRecipe(existing: existing, foodName: foodName, name: name, description: description, instructions: instructions, ingredients: ingredients));
}

class _Ing {
  _Ing(this.name, this.unit, String qty) : qty = TextEditingController(text: qty);
  String name;
  String unit;
  final TextEditingController qty;
}

/// Tạo/sửa công thức: nguyên liệu chính, mô tả, cách làm (mỗi dòng một bước) và nguyên liệu phụ có định lượng.
class RecipeFormPage extends StatelessWidget {
  const RecipeFormPage({super.key, this.recipe});
  final Recipe? recipe;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(create: (c) => RecipeFormViewModel(c.read<MealService>()), child: _Form(recipe: recipe));
}

class _Form extends StatefulWidget {
  const _Form({this.recipe});
  final Recipe? recipe;
  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.recipe?.name);
  late final _desc = TextEditingController(text: widget.recipe?.description);
  late final _steps = TextEditingController(text: MealService.htmlToText(widget.recipe?.htmlContent));
  late String? _mainFood = widget.recipe?.food.name;
  late final List<_Ing> _ings = [
    for (final i in widget.recipe?.ingredients ?? const <RecipeIngredient>[])
      _Ing(i.food.name, i.food.unit, i.quantity == null ? '' : fmtQty(i.quantity!).replaceAll(',', '.')),
  ];
  String? _foodError;

  Future<void> _submit() async {
    setState(() => _foodError = _mainFood == null ? 'Hãy chọn nguyên liệu chính' : null);
    if (!_form.currentState!.validate() || _mainFood == null) return;
    final vm = context.read<RecipeFormViewModel>();
    try {
      await vm.save(
        existing: widget.recipe,
        foodName: _mainFood!,
        name: _name.text,
        description: _desc.text,
        instructions: _steps.text,
        ingredients: [for (final i in _ings) (foodName: i.name, quantity: i.qty.text.trim().isEmpty ? null : Validators.parseQuantity(i.qty.text))],
      );
      if (!mounted) return;
      showMessage(context, 'Đã lưu công thức');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.data is Map && e.data['reason'] != null ? '${e.message}: ${e.data['foodName'] ?? ''} ${e.data['reason']}' : e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RecipeFormViewModel>();
    return Scaffold(
      appBar: AppBar(title: Text(widget.recipe == null ? 'Thêm công thức' : 'Sửa công thức')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Tên món'), validator: (v) => Validators.required(v, 'Tên món') ?? Validators.maxLength(v, 150, 'Tên món')),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final f = await pickFood(context, title: 'Nguyên liệu chính');
              if (f != null) setState(() => _mainFood = f.name);
            },
            child: InputDecorator(
              decoration: InputDecoration(labelText: 'Nguyên liệu chính', errorText: _foodError, suffixIcon: const Icon(Icons.search)),
              child: Text(_mainFood ?? 'Chọn thực phẩm'),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Mô tả ngắn'), validator: (v) => Validators.required(v, 'Mô tả')),
          const SizedBox(height: 12),
          TextFormField(
            controller: _steps,
            minLines: 5,
            maxLines: 12,
            decoration: const InputDecoration(labelText: 'Cách làm (mỗi dòng một bước)', alignLabelWithHint: true),
            validator: (v) => Validators.required(v, 'Cách làm'),
          ),
          SectionTitle('Nguyên liệu khác (${_ings.length})',
              trailing: TextButton.icon(
                onPressed: () async {
                  final f = await pickFood(context, title: 'Thêm nguyên liệu');
                  if (f == null) return;
                  if (_ings.any((i) => i.name.toLowerCase() == f.name.toLowerCase()) && context.mounted) {
                    return showMessage(context, '${f.name} đã có trong danh sách', error: true);
                  }
                  setState(() => _ings.add(_Ing(f.name, f.unit.name, '')));
                },
                icon: const Icon(Icons.add),
                label: const Text('Thêm'),
              )),
          for (final i in _ings)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(flex: 3, child: Text(i.name)),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: i.qty,
                    textAlign: TextAlign.right,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(hintText: 'tùy ý', suffixText: i.unit),
                    validator: (v) => (v == null || v.trim().isEmpty) ? null : Validators.quantity(v),
                  ),
                ),
                IconButton(onPressed: () => setState(() => _ings.remove(i)), icon: const Icon(Icons.close)),
              ]),
            ),
          const SizedBox(height: 16),
          SaveButton(saving: vm.saving, onPressed: _submit),
        ]),
      ),
    );
  }
}
