import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../utils/app_colors.dart';

class EmptyStateWidget extends StatelessWidget {
  final String message;

  const EmptyStateWidget({super.key, required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColor.gray100,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColor.gray400.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(LucideIcons.textSearch, size: 32, color: AppColor.gray400),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: AppColor.gray400,
              fontSize: 16,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
