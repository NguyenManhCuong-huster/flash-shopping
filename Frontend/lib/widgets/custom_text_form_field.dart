import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../utils/app_colors.dart';

class CustomTextFormField extends StatelessWidget {
  final IconData? labelIcon;
  final String? labelText;
  final String? hintText;
  final TextEditingController? controller;
  final bool readOnly;
  final TextInputType? keyboardType;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFieldSubmitted;
  final IconData? suffixIcon;
  final VoidCallback? suffixIconOnTap;
  final IconData? prefixIcon;
  final int maxLines;
  final FocusNode? focusNode;
  final bool obscureText;
  final bool? hasError;
  final String? errorText;
  final String? Function(String?)? validator;
  final AutovalidateMode? autovalidateMode;
  final int? maxLength;
  final TextAlign? textAlign;
  final TextStyle? style;
  final String? counterText;

  const CustomTextFormField({
    super.key,
    this.labelIcon,
    this.labelText,
    this.hintText,
    this.controller,
    this.readOnly = false,
    this.keyboardType,
    this.onTap,
    this.onChanged,
    this.onFieldSubmitted,
    this.suffixIcon,
    this.suffixIconOnTap,
    this.prefixIcon,
    this.maxLines = 1,
    this.focusNode,
    this.obscureText = false,
    this.hasError,
    this.errorText,
    this.validator,
    this.autovalidateMode,
    this.maxLength,
    this.textAlign,
    this.style,
    this.counterText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hiển thị label nếu có
        if (labelText != null && labelText!.isNotEmpty) ...[
          Row(
            children: [
              if (labelIcon != null) ...[
                Icon(labelIcon, color: AppColor.gray600, size: 16),
                const SizedBox(width: 4),
              ],
              Text(
                labelText!,
                style: const TextStyle(
                  color: AppColor.gray600,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        // TextFormField với các thuộc tính được truyền vào
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          onTap: onTap,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted != null
              ? (_) => onFieldSubmitted!()
              : null,
          maxLines: maxLines,
          maxLength: maxLength,
          focusNode: focusNode,
          obscureText: obscureText,
          validator: validator,
          autovalidateMode: autovalidateMode,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.all(8),
            hintText: hintText,
            hintStyle: const TextStyle(
              color: AppColor.gray400,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
            counterText: counterText,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: AppColor.gray600, size: 16)
                : null,
            suffixIcon: suffixIcon != null
                ? (suffixIconOnTap != null
                      ? IconButton(
                          icon: Icon(
                            suffixIcon,
                            color: AppColor.gray600,
                            size: 16,
                          ),
                          onPressed: suffixIconOnTap,
                        )
                      : Icon(suffixIcon, color: AppColor.gray600, size: 16))
                : null,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: hasError == true ? AppColor.red500 : AppColor.gray200,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColor.emerald500),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColor.red500),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColor.red500),
            ),
            filled: true,
            fillColor: AppColor.gray50,
          ),
          textAlign: textAlign ?? TextAlign.start,
          style:
              style ??
              const TextStyle(
                color: AppColor.gray800,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
        ),
        if (hasError == true) ...[
          const SizedBox(height: 4),
          Text(
            errorText ?? 'Invalid input',
            style: const TextStyle(
              color: AppColor.red500,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
            softWrap: true,
          ),
        ],
      ],
    );
  }
}
