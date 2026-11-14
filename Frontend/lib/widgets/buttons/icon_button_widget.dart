import 'dart:ui';
import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class IconButtonWidget extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const IconButtonWidget({super.key, required this.icon, required this.onTap});

  @override
  State<IconButtonWidget> createState() => _IconButtonWidgetState();
}

class _IconButtonWidgetState extends State<IconButtonWidget> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColor.white.withValues(alpha: 0.8),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColor.gray500.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Icon(
              widget.icon,
              color: AppColor.emerald500,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}