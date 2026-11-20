import 'package:flutter/material.dart';

class BadgeWidget extends StatelessWidget {
  const BadgeWidget({
    super.key,
    required this.label,
    this.icon,
    required this.badgeColor,
    required this.labelColor,
  });
  final IconData? icon;
  final String label;
  final Color badgeColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: badgeColor,
      border: Border.all(color: labelColor),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: labelColor),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}
