import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class FilterItem extends StatelessWidget {
  final String label;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool isSelected;
  final VoidCallback onSelected;

  const FilterItem({
    super.key,
    required this.label,
    this.backgroundColor,
    this.borderColor,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected ? AppColor.emerald500 : backgroundColor ?? AppColor.gray50,
          border: Border.all(
            color: isSelected ? AppColor.emerald500 : borderColor ?? AppColor.gray200,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColor.white : AppColor.gray600,
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}