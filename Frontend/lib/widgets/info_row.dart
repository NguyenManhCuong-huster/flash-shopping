import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../utils/app_colors.dart';

class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    this.icon,
    required this.label,
    required this.value,
  });
  final IconData? icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: AppColor.gray600, size: 16),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: const TextStyle(
                color: AppColor.gray600,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColor.gray800,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
