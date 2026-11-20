import 'package:flutter/material.dart';
import '../../core/utils/app_colors.dart';
import '../../core/widgets/buttons/soft_button.dart';

class ConfirmDialog extends StatefulWidget {
  final IconData icon;
  final String title;
  final String content;
  final String cancelText;
  final String confirmText;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  const ConfirmDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.content,
    required this.cancelText,
    required this.confirmText,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  State<ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<ConfirmDialog> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColor.white,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColor.red50,
              ),
              child: Icon(widget.icon, color: AppColor.red500, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: TextStyle(
                color: AppColor.gray800,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.content,
              style: TextStyle(
                color: AppColor.gray500,
                fontSize: 18,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: SoftButton(
                    onPressed: () {
                      widget.onCancel();
                      Navigator.pop(context);
                    },
                    label: widget.cancelText,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onConfirm();
                      Navigator.pop(context, true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColor.red500,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      widget.confirmText,
                      style: TextStyle(
                        color: AppColor.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> confirmDialog({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String message,
  String cancelText = 'Hủy',
  String confirmText = 'Xóa',
  bool danger = true,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => ConfirmDialog(
      icon: icon,
      title: title,
      content: message,
      cancelText: cancelText,
      confirmText: confirmText,
      onCancel: () {
        Navigator.pop(context, false);
      },
      onConfirm: () {
        Navigator.pop(context, true);
      },
    ),
  );
  return ok ?? false;
}
