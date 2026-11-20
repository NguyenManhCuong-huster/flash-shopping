import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'meal_service.dart';
import 'meal_recipe.dart';
import '../../core/api_client.dart';
import '../../core/widgets/widgets_common.dart';
import '../../core/utils/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/utils/mock_data.dart';
import '../../core/widgets/buttons/primary_button.dart';
import '../../core/widgets/buttons/outline_button.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/filter_item.dart';
import 'meal_plan_view_model.dart';

class CreateMealPlanModal extends StatelessWidget {
  const CreateMealPlanModal({super.key, required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (c) => CreateMealPlanModalViewModel(c.read<MealService>())..load(),
    child: _MealPlanForm(date: date),
  );
}

class _MealPlanForm extends StatefulWidget {
  const _MealPlanForm({required this.date});
  final DateTime date;
  @override
  State<_MealPlanForm> createState() => _MealPlanFormState();
}

class _MealPlanFormState extends State<_MealPlanForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nameController = TextEditingController();
  late final TextEditingController _dateController = TextEditingController(
    text: FormatUtils.formatDate(widget.date),
  );
  DateTime _date = DateTime.now();
  MealPeriod _mealPeriod = MealPeriod.breakfast;
  Recipe _recipe = MockData.recipes.first;
  bool _saving = false;

  Future<void> _submit() async {
    setState(() => _saving = true);
    if (_nameController.text.trim().isEmpty) {
      return showMessage(context, 'Hãy nhập tên bữa ăn', error: true);
    }

    final vm = context.read<CreateMealPlanModalViewModel>();
    try {
      await vm.createMealPlan(
        recipe: _recipe,
        date: _date,
        period: _mealPeriod,
      );
      if (!mounted) return;
      showMessage(
        context,
        'Đã thêm vào kế hoạch. Có thể kiểm tra nguyên liệu từ lịch bữa ăn.',
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == '00005') {
        Navigator.pop(context);
      } else {
        showMessage(
          context,
          e.message,
          error: true,
          retry: e.network ? _submit : null,
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CreateMealPlanModalViewModel>();
    return Form(
      key: _form,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildMealPeriodSelector(),
          const SizedBox(height: 16),
          _buildRecipeSection(vm),
          const SizedBox(height: 16),
          PrimaryButton(
            saving: vm.saving,
            onPressed: _submit,
            label: 'Tạo kế hoạch bữa ăn',
          ),
          const SizedBox(height: 8),
          const Text(
            'Lập lịch bữa ăn không đồng nghĩa với việc mua nguyên liệu. Hãy kiểm tra nguyên liệu trong tủ lạnh và danh sách mua sắm.',
            style: TextStyle(
              color: AppColor.gray600,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMealPeriodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chọn bữa ăn',
          style: TextStyle(
            color: AppColor.gray600,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColor.white,
            border: Border.all(color: AppColor.gray200),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: FilterItem(
                  label: MealPeriod.breakfast.label,
                  isSelected: _mealPeriod == MealPeriod.breakfast,
                  onSelected: () {
                    setState(() => _mealPeriod = MealPeriod.breakfast);
                  },
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: FilterItem(
                  label: MealPeriod.lunch.label,
                  isSelected: _mealPeriod == MealPeriod.lunch,
                  onSelected: () {
                    setState(() => _mealPeriod = MealPeriod.lunch);
                  },
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: FilterItem(
                  label: MealPeriod.dinner.label,
                  isSelected: _mealPeriod == MealPeriod.dinner,
                  onSelected: () {
                    setState(() => _mealPeriod = MealPeriod.dinner);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecipeSection(CreateMealPlanModalViewModel vm) {
    // final List<Recipe> recipes = vm.recipes;
    final List<Recipe> recipes = MockData.recipes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chọn món ăn',
          style: TextStyle(
            color: AppColor.gray600,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        if (vm.loading)
          const Center(child: CircularProgressIndicator())
        else if (vm.loadError != null)
          Column(
            children: [
              Text(
                'Không tải được công thức. ${vm.loadError}',
                style: const TextStyle(color: AppColor.red500),
              ),
              const SizedBox(height: 8),
              OutlineButton(onPressed: vm.load, label: 'Thử lại'),
            ],
          )
        else if (recipes.isEmpty)
          const EmptyStateWidget(
            message: 'Chưa có công thức nào. Hãy tạo công thức trước.',
          )
        else
          // Expanded(
          //   child: 
            ListView.separated(
              padding: EdgeInsets.zero,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemCount: recipes.length,
              itemBuilder: (context, index) {
                final recipe = recipes[index];
                return _buildRecipeCard(recipe);
              },
            ),
          // ),
      ],
    );
  }

  Widget _buildRecipeCard(Recipe recipe) {
    final isSelected = _recipe == recipe;
    return GestureDetector(
      onTap: () {
        setState(() {
          _recipe = recipe;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColor.white,
          border: isSelected
              ? Border.all(color: AppColor.primary)
              : Border.all(color: AppColor.gray200),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe.name,
                  style: const TextStyle(
                    color: AppColor.gray800,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  recipe.description,
                  style: const TextStyle(
                    color: AppColor.gray600,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected ? LucideIcons.circleCheck : LucideIcons.circle,
              color: isSelected ? AppColor.primary : AppColor.gray400,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
