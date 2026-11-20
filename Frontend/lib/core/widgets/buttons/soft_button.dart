import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class SoftButton extends StatelessWidget {
  const SoftButton({
    super.key,
    required this.onPressed,
    this.label = 'Lưu',
  });

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onPressed,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColor.gray50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: AppColor.primary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}
