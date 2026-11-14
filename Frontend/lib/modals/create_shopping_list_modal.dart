import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../data/models/food.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/buttons/outline_button.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_text_form_field.dart';

class CreateShoppingSessionModal extends StatefulWidget {
  final int shoppingItemId;
  final Food food;
  final double? quantity;
  final String? note;

  const CreateShoppingSessionModal({
    super.key,
    required this.shoppingItemId,
    required this.food,
    this.quantity,
    this.note,
  });

  @override
  State<CreateShoppingSessionModal> createState() =>
      _CreateShoppingSessionModalState();
}

class _CreateShoppingSessionModalState
    extends State<CreateShoppingSessionModal> {
  final _formKey = GlobalKey<FormState>();
  double? _quantity;
  String? _note;

  @override
  void initState() {
    super.initState();
    _quantity = widget.quantity;
    _note = widget.note;
  }

  void onPressed() {
    if (!_formKey.currentState!.validate()) return;
    // Handle the button press action here
  }

  void onSaving() {
    // Handle the saving action here
  }
  void onCancel() {
    // Handle the cancel action here
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
            Text(
              'Tạo danh sách mua sắm',
              style: TextStyle(
                color: AppColor.gray800,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            CustomTextFormField(
              labelText: 'Tên danh sách',
              hintText: 'Nhập tên danh sách mua sắm',
              controller: TextEditingController(text: 'Đi chợ'),
            ),
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
                      'Định lượng ban đầu',
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: CustomTextFormField(
                    labelText: 'Định lượng mới (Tùy chọn)',
                    hintText: 'Nhập định lượng mới',
                    controller: TextEditingController(
                      text: _quantity?.toString() ?? '',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: CustomTextFormField(
                    hintText: widget.food.unit.name,
                    controller: TextEditingController(
                      text: widget.food.unit.name,
                    ),
                    readOnly: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CustomTextFormField(
              labelText: 'Ghi chú (Tùy chọn)',
              hintText: 'Thêm ghi chú cho mặt hàng (nếu cần)',
              controller: TextEditingController(text: widget.note ?? ''),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              saving: false,
              onPressed: onPressed,
              label: 'Lưu thông tin',
            ),
            const SizedBox(height: 8),
            OutlineButton(
              onPressed: onCancel,
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
