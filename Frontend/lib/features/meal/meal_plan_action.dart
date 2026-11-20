import '../../core/widgets/buttons/outline_button.dart';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'meal_recipe.dart';
import '../../core/utils/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/badge_widget.dart';
import '../../core/widgets/base_modal_bottom_sheet.dart';

class MealPlanAction extends StatefulWidget {
  final MealPlan meal;
  final bool isLeader;
  const MealPlanAction({super.key, required this.meal, required this.isLeader});

  @override
  State<MealPlanAction> createState() => _MealPlanActionState();
}

class _MealPlanActionState extends State<MealPlanAction> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tên món ăn',
                  style: TextStyle(
                    color: AppColor.gray600,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.meal.name,
                  style: const TextStyle(
                    color: AppColor.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Thời gian',
                  style: TextStyle(
                    color: AppColor.gray600,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                BadgeWidget(
                  label: widget.meal.mealPeriod.label,
                  badgeColor: widget.meal.mealPeriod.badgeColor,
                  labelColor: widget.meal.mealPeriod.labelColor,
                ),
              ],
            ),
          ],
        ),
        const Divider(height: 33, thickness: 1, color: AppColor.gray200),
        OutlineButton(
          onPressed: () {
            Navigator.pop(context, 'check_ingredients');
          },
          label: 'Kiểm tra nguyên liệu',
        ),
        const SizedBox(height: 16),
        OutlineButton(
          onPressed: () {
            Navigator.pop(context, 'view_recipe');
          },
          backgroundColor: AppColor.blue50,
          label: 'Xem công thức',
          labelColor: AppColor.blue500,
        ),
        if (widget.isLeader) ...[
          const SizedBox(height: 16),
          OutlineButton(
            onPressed: () {
              Navigator.pop(context, 'delete');
            },
            backgroundColor: AppColor.red50,
            label: 'Xóa kế hoạch',
            labelColor: AppColor.red500,
          ),
        ],
      ],
    );
  }
}
