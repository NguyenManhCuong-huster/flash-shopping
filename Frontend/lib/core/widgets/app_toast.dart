import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../core/utils/app_colors.dart';

/// Vị trí hiển thị toast trên màn hình.
enum ToastPosition { top, center, bottom }

/// Hiển thị toast (thông báo nhẹ) ở vị trí trên cùng màn hình,
/// tự động biến mất sau [duration] (mặc định 3 giây).
void showToast(
  BuildContext context, {
  required String message,
  bool error = false,
  ToastPosition position = ToastPosition.top,
  Duration duration = const Duration(seconds: 3),
}) {
  final overlay = Overlay.of(context);
  late final OverlayEntry entry;

  entry = OverlayEntry(
    builder: (ctx) {
      final bgColor = error ? AppColor.red500 : AppColor.green500;
      final icon = error ? LucideIcons.alertTriangle : LucideIcons.checkCircle;

      return Positioned(
        top: position == ToastPosition.top ? 48 : null,
        bottom: position == ToastPosition.bottom ? 48 : null,
        left: position == ToastPosition.center ? null : 16,
        right: position == ToastPosition.center ? null : 16,
        width: position == ToastPosition.center ? 320 : null,
        child: Material(
          color: AppColor.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColor.gray400.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppColor.white, size: 24),
                const SizedBox(width: 16),
                Flexible(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: AppColor.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    softWrap: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  overlay.insert(entry);

  Future.delayed(duration, () {
    entry.remove();
  });
}