import 'package:di_cho_tien_loi/core/widgets/buttons/outline_button.dart';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../core/utils/app_colors.dart';

class AsyncSection extends StatelessWidget {
  const AsyncSection({
    super.key,
    required this.loading,
    this.error,
    required this.isEmpty,
    required this.onRetry,
    required this.child,
    this.emptyText = 'Chưa có dữ liệu',
  });

  final bool loading;
  final String? error;
  final bool isEmpty;
  final Future<void> Function() onRetry;
  final Widget child;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (loading && isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null && isEmpty) {
      return ErrorStateWidget(message: error!, onRetry: onRetry);
    }
    if (isEmpty) {
      return EmptyStateWidget(message: emptyText);
    }
    return Container(child: child);
  }
}

class ErrorStateWidget extends StatelessWidget {
  const ErrorStateWidget({
    super.key,
    required this.message,
    required this.onRetry,
  });
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.cloudOff, size: 48, color: AppColor.red500),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              color: AppColor.gray400,
              fontSize: 16,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlineButton(
            onPressed: onRetry,
            backgroundColor: AppColor.red50,
            label: 'Thử lại',
            labelColor: AppColor.red500,
          ),
        ],
      ),
    ),
  );
}

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
              color: AppColor.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColor.gray400.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              LucideIcons.textSearch,
              size: 32,
              color: AppColor.gray400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
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
