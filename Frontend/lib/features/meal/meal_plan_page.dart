import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import './meal_service.dart';
import '../auth/session_service.dart';
import './meal_recipe.dart';
import 'recipe_detail_page.dart';
import '../../core/utils/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/utils/mock_data.dart';
import '../../core/widgets/widgets_common.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/buttons/icon_button_widget.dart';
import '../../core/widgets/base_modal_bottom_sheet.dart';
import '../../core/widgets/confirm_dialog.dart';
import 'ingredients_page.dart';
import 'create_meal_plan_modal.dart';
import 'meal_plan_action.dart';
import 'meal_plan_view_model.dart';

class MealPlanPage extends StatelessWidget {
  const MealPlanPage({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (c) => MealPlanViewModel(c.read<MealService>())..load(),
    child: const _MealView(),
  );
}

class _MealView extends StatelessWidget {
  const _MealView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MealPlanViewModel>();
    final session = context.watch<SessionService>();
    // final dayPlans = vm.plansOf(vm.selectedDate);
    final mealPlans = MockData.getMealPlansByDate(
      vm.selectedDate,
    ); // Sử dụng dữ liệu giả lập
    return Scaffold(
      backgroundColor: AppColor.transparent,
      extendBody: true,
      floatingActionButton: session.isLeader
          ? GestureDetector(
              onTap: () async {
                await showBaseModalBottomSheet(
                  context: context,
                  title: 'Lên lịch bữa ăn',
                  icon: LucideIcons.calendar,
                  subtitle: FormatUtils.formatWeekdayWithDate(vm.selectedDate),
                  child: CreateMealPlanModal(date: vm.selectedDate),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 76),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColor.primary,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: AppColor.gray400.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  LucideIcons.filePlusCorner,
                  color: AppColor.white,
                  size: 24,
                ),
              ),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 92),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildHeader(context, vm, mealPlans),
              const SizedBox(height: 16),
              _buildWeeklyDateSelector(vm),
              const SizedBox(height: 16),
              _buildDailyMealSection(context, vm, mealPlans),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    MealPlanViewModel vm,
    List<MealPlan> mealPlans,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Quản lý bữa ăn',
            style: TextStyle(
              color: AppColor.primary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (mealPlans.isNotEmpty)
            IconButtonWidget(
              icon: LucideIcons.listTodo,
              onTap: mealPlans.isEmpty
                  ? null
                  : () => pushPage(
                      context,
                      IngredientsPage(day: vm.selectedDate),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildWeeklyDateSelector(MealPlanViewModel vm) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              IconButtonWidget(
                icon: LucideIcons.chevronLeft,
                onTap: () => vm.shiftWeek(-1),
              ),
              Expanded(
                child: Text(
                  '${FormatUtils.formatDate(vm.weekStart)} - ${FormatUtils.formatDate(vm.weekStart.add(const Duration(days: 6)))}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColor.gray800,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButtonWidget(
                icon: LucideIcons.chevronRight,
                onTap: () => vm.shiftWeek(1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: vm.days.length,
              crossAxisSpacing: 8,
              mainAxisSpacing: 0,
              childAspectRatio: 0.8,
            ),
            itemCount: vm.days.length,
            itemBuilder: (context, index) {
              final day = vm.days[index];
              final isSelected = day == vm.selectedDate;
              final isToday = day == FormatUtils.dateOnly(DateTime.now());
              final hasPlan = vm.plansOf(day).isNotEmpty;
              return GestureDetector(
                onTap: () => vm.select(day),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColor.primary
                        : isToday
                        ? AppColor.emerald100
                        : AppColor.white,
                    border: Border.all(
                      color: isSelected || isToday
                          ? AppColor.primary
                          : AppColor.gray200,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        FormatUtils.formatWeekday(day),
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? AppColor.white : AppColor.gray600,
                        ),
                      ),
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? AppColor.white : AppColor.gray800,
                        ),
                      ),
                      if (hasPlan)
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColor.white
                                : AppColor.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDailyMealSection(
    BuildContext context,
    MealPlanViewModel vm,
    List<MealPlan> mealPlans,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final period in MealPeriod.values) ...[
            SectionTitle(
              period.label,
              subtitle:
                  '${mealPlans.where((meal) => meal.mealPeriod == period).length} món',
            ),
            const SizedBox(height: 8),
            AsyncSection(
              loading: vm.loading,
              error: vm.loadError,
              isEmpty: mealPlans
                  .where((meal) => meal.mealPeriod == period)
                  .isEmpty,
              onRetry: vm.load,
              emptyText: 'Không có món ăn nào được lập kế hoạch cho bữa này.',
              child: Column(
                children: mealPlans
                    .where((meal) => meal.mealPeriod == period)
                    .map(
                      (meal) => _buildMealPlanCard(
                        meal,
                        context.read<SessionService>().isLeader,
                        context,
                        vm,
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildMealPlanCard(
    MealPlan meal,
    bool isLeader,
    BuildContext context,
    MealPlanViewModel vm,
  ) {
    return GestureDetector(
      onTap: () async {
        final action = await showBaseModalBottomSheet<String>(
          context: context,
          title: 'Thông tin bữa ăn',
          icon: LucideIcons.calendar,
          subtitle: 'Ngày áp dụng: ${FormatUtils.formatDate(meal.date)}',
          child: MealPlanAction(meal: meal, isLeader: isLeader),
        );

        if (!context.mounted) return;

        switch (action) {
          case 'check_ingredients':
            await pushPage(context, IngredientsPage(plan: meal));

          case 'view_recipe':
            if (meal.recipeId != null) {
              await pushPage(
                context,
                RecipeDetailPage(recipeId: meal.recipeId!),
              );
            }

          case 'delete':
            if (await confirmDialog(
                  context: context,
                  icon: LucideIcons.trash2,
                  title: 'Xóa bữa ăn',
                  message:
                      'Xóa ${meal.name} khỏi ${meal.mealPeriod.label.toLowerCase()}?',
                ) &&
                context.mounted) {
              await runAction(
                context,
                () => vm.delete(meal),
                success: 'Đã xóa',
              );
            }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColor.white,
          border: Border.all(color: AppColor.gray200),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColor.gray400.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColor.amber100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    LucideIcons.utensils,
                    color: AppColor.amber500,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.name,
                        style: const TextStyle(
                          color: AppColor.gray800,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Nguyên liệu chính: ${meal.food.name}',
                        style: const TextStyle(
                          color: AppColor.gray600,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  LucideIcons.moreVertical,
                  color: AppColor.gray600,
                  size: 24,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
