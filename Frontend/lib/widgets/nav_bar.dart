import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../utils/app_colors.dart';

class NavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const NavBar({super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColor.white.withValues(alpha: 0.8),
        border: Border.all(color: AppColor.white, width: 2),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColor.gray400.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Row(
            children: [
              Expanded(
                child: _buildNavItem(LucideIcons.house, 'Trang chủ', 0),
              ),
              Expanded(
                child: _buildNavItem(LucideIcons.shoppingBasket, 'Mua sắm', 1),
              ),
              Expanded(
                child: _buildNavItem(LucideIcons.refrigerator, 'Tủ lạnh', 2),
              ),
              Expanded(
                child: _buildNavItem(LucideIcons.utensils, 'Bữa ăn', 3),
              ),
              Expanded(
                child: _buildNavItem(LucideIcons.settings, 'Cài đặt', 4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    bool isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColor.emerald100 : AppColor.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColor.emerald500 : AppColor.gray400,
              size: 24,
            ),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColor.emerald500 : AppColor.gray400,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
