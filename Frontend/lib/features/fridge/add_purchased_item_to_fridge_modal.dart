import '../../core/utils/format.dart';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../food/food.dart';
import '../../core/widgets/buttons/primary_button.dart';
import '../../core/widgets/buttons/outline_button.dart';
import '../../core/utils/app_colors.dart';
import '../../core/widgets/custom_text_form_field.dart';
import '../../core/widgets/custom_dropdown_field.dart';
import '../../core/widgets/base_modal_bottom_sheet.dart';

typedef AddPurchasedItemCallback =
    Future<void> Function({
      required DateTime useWithin,
      required StorageLocation location,
      String? note,
    });

class AddPurchasedItemToFridgeModal extends StatefulWidget {
  final int shoppingItemId;
  final Food food;
  final double quantity;
  final DateTime? purchasedAt;
  final AddPurchasedItemCallback onSave;

  const AddPurchasedItemToFridgeModal({
    super.key,
    required this.shoppingItemId,
    required this.food,
    required this.quantity,
    this.purchasedAt,
    required this.onSave,
  });

  @override
  State<AddPurchasedItemToFridgeModal> createState() =>
      _AddPurchasedItemToFridgeModalState();
}

class _AddPurchasedItemToFridgeModalState
    extends State<AddPurchasedItemToFridgeModal> {
  final _form = GlobalKey<FormState>();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  DateTime? _useWithin;
  StorageLocation _selectedLocation = StorageLocation.cool;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _useWithin = null;
  }

  Future<void> _selectDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColor.primary),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _useWithin = pickedDate;
        _dateController.text =
            '${pickedDate.day}/${pickedDate.month}/${pickedDate.year}';
      });
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_useWithin == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Hãy chọn ngày hết hạn')));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(
        useWithin: _useWithin!,
        location: _selectedLocation,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thực phẩm',
                      style: TextStyle(
                        color: AppColor.gray600,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.food.name,
                      style: const TextStyle(
                        color: AppColor.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Định lượng thực tế',
                      style: TextStyle(
                        color: AppColor.gray600,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.quantity} ${widget.food.unit.name}',
                      style: const TextStyle(
                        color: AppColor.amber500,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 33, thickness: 1, color: AppColor.gray200),
            _buildLocationSeclector(),
            const SizedBox(height: 16),
            CustomTextFormField(
              labelText: 'Hạn sử dụng (Tùy chọn)',
              hintText: 'DD/MM/YYYY',
              controller: _dateController,
              readOnly: true,
              onTap: _selectDate,
              suffixIcon: LucideIcons.calendar,
            ),
            const SizedBox(height: 16),
            CustomTextFormField(
              labelText: 'Ghi chú (Tùy chọn)',
              hintText: 'Nhập ghi chú',
              controller: _noteController,
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              saving: _saving,
              onPressed: _submit,
              label: 'Lưu thông tin',
            ),
            const SizedBox(height: 8),
            OutlineButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              backgroundColor: AppColor.red50,
              label: 'Xóa khỏi danh sách',
              labelColor: AppColor.red500,
            ),
          ],
        ),
    );
  }

  Widget _buildLocationSeclector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Vị trí lưu trữ',
              style: TextStyle(
                color: AppColor.gray600,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              '*',
              style: TextStyle(
                color: AppColor.red500,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildLocationCard(StorageLocation.cool)),
            const SizedBox(width: 8),
            Expanded(child: _buildLocationCard(StorageLocation.freezer)),
            const SizedBox(width: 8),
            Expanded(child: _buildLocationCard(StorageLocation.other)),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationCard(StorageLocation location) {
    final isSelected = _selectedLocation == location;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedLocation = location);
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? AppColor.emerald50 : AppColor.gray50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColor.emerald500 : AppColor.gray200,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              location.icon,
              color: isSelected ? AppColor.emerald500 : AppColor.gray600,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              location.label,
              style: TextStyle(
                color: isSelected ? AppColor.emerald500 : AppColor.gray600,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
