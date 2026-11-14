import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../utils/app_colors.dart';

class StatCard extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final String value;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const StatCard({
    super.key,
    required this.icon,
    required this.backgroundColor,
    required this.borderColor,
    required this.value,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: AppColor.gray800,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColor.gray600,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
          Divider(height: 17, thickness: 1, color: borderColor),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Xem chi tiết',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(LucideIcons.arrowRight, size: 16, color: color),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
