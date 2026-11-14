import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../utils/app_colors.dart';

class TextFieldWidget extends StatefulWidget {
  final IconData? labelIcon;
  final String labelText;
  final String hintText;
  final TextEditingController? controller;
  final bool readOnly;
  final TextInputType? keyboardType;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final IconData? suffixIcon;
  final IconData? prefixIcon;
  final int maxLines;
  final FocusNode? focusNode;
  final bool? hasError;
  final String? errorText;
  const TextFieldWidget({
    super.key,
    this.labelIcon,
    required this.labelText,
    required this.hintText,
    this.controller,
    this.readOnly = false,
    this.keyboardType,
    this.onTap,
    this.onChanged,
    this.suffixIcon,
    this.prefixIcon,
    this.maxLines = 1,
    this.focusNode,
    this.hasError,
    this.errorText,
  });

  @override
  State<TextFieldWidget> createState() => _TextFieldWidgetState();
}

class _TextFieldWidgetState extends State<TextFieldWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.labelText.isNotEmpty) ...[
          Row(
            children: [
              if (widget.labelIcon != null) ...[
                Icon(widget.labelIcon, color: AppColor.gray500, size: 16),
                const SizedBox(width: 4),
              ],
              Text(
                widget.labelText,
                style: const TextStyle(
                  color: AppColor.gray500,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        TextField(
          controller: widget.controller,
          readOnly: widget.readOnly,
          keyboardType: widget.keyboardType,
          onTap: widget.onTap,
          onChanged: widget.onChanged,
          maxLines: widget.maxLines,
          focusNode: widget.focusNode,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.all(8),
            hintText: widget.hintText,
            hintStyle: const TextStyle(
              color: AppColor.gray500,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
            suffixIcon: widget.suffixIcon != null
                ? Icon(widget.suffixIcon, color: AppColor.gray500, size: 16)
                : null,
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon, color: AppColor.gray500, size: 16)
                : null,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: widget.hasError == true ? AppColor.red500 : AppColor.gray200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColor.blue500),
            ),
            filled: true,
            fillColor: AppColor.gray100,
          ),
          style: const TextStyle(
            color: AppColor.gray800,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (widget.hasError == true) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                LucideIcons.circleAlert,
                color: AppColor.red500,
                size: 16,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.errorText ?? 'Invalid input',
                  style: TextStyle(
                    color: AppColor.red500,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                  softWrap: true,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
