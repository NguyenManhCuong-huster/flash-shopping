import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class OutlineButton extends StatelessWidget {
  const OutlineButton({
    super.key,
    required this.onPressed,
    this.backgroundColor,
    this.label,
    this.labelColor,
    this.icon,
  });

  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final String? label;
  final Color? labelColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onPressed,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColor.emerald50,
        border: Border.all(color: labelColor ?? AppColor.primary),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label ?? 'Lưu',
              style: TextStyle(
                color: labelColor ?? AppColor.primary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 8),
              Icon(icon, color: labelColor ?? AppColor.primary, size: 16),
            ],
          ],
        ),
      ),
    ),
  );
}
