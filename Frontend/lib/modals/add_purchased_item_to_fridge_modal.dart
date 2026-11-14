import 'package:di_cho_tien_loi/utils/date_time_utils.dart';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../data/models/food.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/buttons/outline_button.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_text_form_field.dart';
import '../../widgets/custom_dropdown_form_field.dart';

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
  final _formKey = GlobalKey<FormState>();
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
            colorScheme: const ColorScheme.light(primary: AppColor.emerald500),
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
    if (!_formKey.currentState!.validate()) return;
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
    return Container(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColor.gray300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Thêm thực phẩm vào tủ lạnh',
              style: TextStyle(
                color: AppColor.gray800,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.purchasedAt == null
                  ? 'Ngày mua: chưa xác định'
                  : 'Ngày mua: ${DateTimeUtils.formatDate(widget.purchasedAt!)}',
              style: const TextStyle(
                color: AppColor.gray600,
                fontSize: 16,
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
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
                        color: AppColor.emerald500,
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

            CustomDropdownField<StorageLocation>(
              labelText: 'Vị trí lưu trữ',
              hintText: 'Chọn vị trí lưu trữ thực phẩm',
              prefixIcon: _selectedLocation.icon,
              value: _selectedLocation,
              items: StorageLocation.values,
              itemLabel: (location) => location.label,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedLocation = value);
                }
              },
            ),

            const SizedBox(height: 16),
            CustomTextFormField(
              labelText: 'Ngày hết hạn (Tùy chọn)',
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
      ),
    );
  }
}
