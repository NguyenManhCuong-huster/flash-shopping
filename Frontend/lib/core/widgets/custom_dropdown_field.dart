import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../core/utils/app_colors.dart';

class CustomDropdownField<T> extends StatelessWidget {
  final String? labelText;
  final IconData? labelIcon;
  final bool? required;
  final String? hintText;
  final IconData? prefixIcon;

  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;

  final ValueChanged<T?>? onChanged;
  final String? Function(T?)? validator;

  const CustomDropdownField({
    super.key,
    this.labelText,
    required this.items,
    required this.itemLabel,
    this.labelIcon,
    this.hintText,
    this.prefixIcon,
    this.value,
    this.required,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    // Chỉ giữ value nếu nó tồn tại trong danh sách items.
    final selectedValue = items.any((item) => item == value) ? value : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelText != null && labelText!.isNotEmpty) ...[
          Row(
            children: [
              if (labelIcon != null) ...[
                Icon(labelIcon, size: 16, color: AppColor.gray600),
                const SizedBox(width: 6),
              ],
              Text(
                labelText!,
                style: const TextStyle(
                  color: AppColor.gray800,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (required == true) ...[
                const SizedBox(width: 4),
                const Text(
                  '*',
                  style: TextStyle(
                    color: AppColor.red500,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
        ],

        // Dropdown
        DropdownButtonFormField<T>(
          initialValue: selectedValue,
          isExpanded: true,
          icon: const Icon(
            LucideIcons.chevronDown,
            color: AppColor.gray600,
            size: 16,
          ),
          hint: Text(
            hintText ?? 'Chọn $labelText',
            style: const TextStyle(
              color: AppColor.gray400,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.all(8),

            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: AppColor.gray600, size: 16)
                : null,

            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColor.gray200),
            ),

            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColor.primary),
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

          style: const TextStyle(
            color: AppColor.gray800,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),

          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
            );
          }).toList(),

          onChanged: onChanged,
          validator: validator,
        ),
      ],
    );
  }
}
