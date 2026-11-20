import 'package:di_cho_tien_loi/core/widgets/custom_dropdown_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../core/model_common.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/app_colors.dart';
import '../../core/widgets/widgets_common.dart';
import '../../core/widgets/buttons/primary_button.dart';
import '../../core/widgets/custom_text_form_field.dart';
import '../food/food.dart';
import 'shopping_service.dart';
import 'shopping_session_view_model.dart';
import '../../core/utils/mock_data.dart';

class CreatePendingItemModal extends StatelessWidget {
  const CreatePendingItemModal({super.key, required this.shoppingSessionId});

  final int shoppingSessionId;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (c) => ShoppingSessionDetailViewModel(
      c.read<ShoppingService>(),
      shoppingSessionId,
    ),
    child: _CreatePendingItemForm(shoppingSessionId: shoppingSessionId),
  );
}

class _CreatePendingItemForm extends StatefulWidget {
  const _CreatePendingItemForm({super.key, required this.shoppingSessionId});
  final int shoppingSessionId;

  @override
  State<_CreatePendingItemForm> createState() => _CreatePendingItemFormState();
}

class _CreatePendingItemFormState extends State<_CreatePendingItemForm> {
  final _form = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _noteController = TextEditingController();
  NamedItem? _selectedCategory;
  NamedItem? _selectedUnit;
  Food? _selectedFood;
  List<Food> _searchResults = [];

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _onCategoryChanged(NamedItem? category) {
    setState(() {
      _selectedCategory = category;
      _selectedUnit = null;
    });
  }

  void _onNameChanged(String value) {
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _selectedFood = null;
      });
      return;
    }
    final results = MockData.foods
        .where((f) => f.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    setState(() {
      _searchResults = results.take(8).toList();
    });
  }

  void _selectFood(Food food) {
    setState(() {
      _selectedFood = food;
      _nameController.text = food.name;
      _searchResults = [];
      _selectedUnit = MockData.units.firstWhere(
        (u) => u.name == food.unit.name,
        orElse: () => MockData.units.first,
      );
    });
  }

  Future<void> _submit() async {
    final foodName = _nameController.text.trim();
    final quantity = double.tryParse(_quantityController.text) ?? 1;
    final note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();
    if (foodName.isEmpty) return;

    final vm = context.read<ShoppingSessionDetailViewModel>();
    final r = await vm.addItem(
      sessionId: vm.shoppingSessionId,
      foodId: _selectedFood?.id,
      foodName: foodName,
      categoryId: _selectedCategory?.id,
      unitId: _selectedUnit?.id,
      quantity: quantity,
      note: note,
    );

    if (!mounted) return;
    Navigator.pop(context);

    if (r.failed.isEmpty) {
      showMessage(context, 'Đã thêm $foodName');
    } else {
      showMessage(
        context,
        'Không thêm được: ${r.failed.map((f) => f.message).join(', ')}',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ShoppingSessionDetailViewModel>();
    return Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFoodSearchSection(),
          const SizedBox(height: 16),
          _buildCategorySection(MockData.categories),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 3,
                child: CustomTextFormField(
                  labelText: 'Số lượng & đơn vị',
                  hintText: 'Nhập số lượng',
                  controller: _quantityController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],

                  validator: (v) => Validators.quantity(v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: CustomDropdownField<NamedItem>(
                  hintText: 'Chọn đơn vị',
                  value: _selectedUnit,
                  items: MockData.units,
                  itemLabel: (unit) => unit.name,
                  onChanged: (unit) => setState(() => _selectedUnit = unit),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          CustomTextFormField(
            labelText: 'Ghi chú (tùy chọn)',
            hintText: 'Nhập ghi chú cho phiên mua sắm (nếu cần)',
            controller: _noteController,
            maxLines: 3,
            maxLength: 1000,
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            saving: vm.saving,
            onPressed: _submit,
            label: 'Thêm vào danh sách',
          ),
        ],
      ),
    );
  }

  Widget _buildFoodSearchSection() {
    return Column(
      children: [
        CustomTextFormField(
          labelText: 'Tên món hàng',
          hintText: 'Nhập tên món hàng cần mua',
          controller: _nameController,
          prefixIcon: LucideIcons.search,
          onChanged: _onNameChanged,
          validator: (v) => Validators.required(v, 'Tên món ăn'),
        ),
        if (_searchResults.isEmpty &&
            _nameController.text.isNotEmpty &&
            _selectedFood == null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Món hay mua',
                style: TextStyle(
                  color: AppColor.gray600,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final food in MockData.foods.take(6))
                    ChoiceChip(
                      label: Text(food.name),
                      selected: _selectedFood?.id == food.id,
                      onSelected: (selected) =>
                          selected ? _selectFood(food) : null,
                    ),
                ],
              ),
            ],
          ),
        ],
        if (_searchResults.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _searchResults.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final food = _searchResults[index];
                return ListTile(
                  leading: const Icon(LucideIcons.circle, size: 16),
                  title: Text(food.name),
                  subtitle: Text('${food.category.name} • ${food.unit.name}'),
                  onTap: () => _selectFood(food),
                );
              },
            ),
          ),
        if (_searchResults.isEmpty &&
            _nameController.text.isNotEmpty &&
            _selectedFood == null)
          const Text(
            'Chưa có trong danh sách. Nhập tiếp để tạo món mới.',
            style: TextStyle(
              color: AppColor.gray600,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
      ],
    );
  }

  

  Widget _buildCategorySection(List<NamedItem> categories) {
    return Column(
      children: [
        const Row(
          children: [
            Text(
              'Danh mục thực phẩm',
              style: TextStyle(
                color: AppColor.gray600,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
            SizedBox(width: 4),
            Text(
              '*',
              style: TextStyle(
                color: AppColor.red500,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemCount: MockData.categories.length,
            itemBuilder: (context, index) {
              final category = MockData.categories[index];
              return _buildCategorySelector(category);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector(NamedItem category) {
    final isSelected = _selectedCategory?.name == category.name;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = isSelected ? null : category;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? AppColor.emerald50 : AppColor.gray50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColor.emerald500 : AppColor.gray200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              category.name,
              style: TextStyle(
                color: isSelected ? AppColor.emerald500 : AppColor.gray600,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              const Icon(
                LucideIcons.check,
                color: AppColor.emerald500,
                size: 16,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
