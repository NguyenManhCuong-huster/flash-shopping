import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.saving,
    required this.onPressed,
    this.backgroundColor,
    this.label = 'Lưu',
    this.icon,
  });

  final bool saving;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: saving ? null : onPressed,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: saving
            ? backgroundColor?.withValues(alpha: 0.5)
            : backgroundColor ?? AppColor.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              saving ? 'Đang xử lý...' : label,
              style: const TextStyle(
                color: AppColor.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),

            if (!saving && icon != null) ...[
              const SizedBox(width: 4),
              Icon(icon, color: AppColor.white, size: 16),
            ],
          ],
        ),
      ),
    ),
  );
}