import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class SubmitButtons extends StatefulWidget {
  final String submitText;
  final String cancelText;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  const SubmitButtons({
    super.key,
    required this.submitText,
    required this.cancelText,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  State<SubmitButtons> createState() => _SubmitButtonsState();
}

class _SubmitButtonsState extends State<SubmitButtons> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        InkWell(
          onTap: widget.onSubmit,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColor.emerald500,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColor.gray500.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                widget.submitText,
                style: TextStyle(
                  color: AppColor.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: widget.onCancel,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              widget.cancelText,
              style: TextStyle(
                color: AppColor.blue500,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
