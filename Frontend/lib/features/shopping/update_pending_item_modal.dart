import 'package:di_cho_tien_loi/features/shopping/shopping_session_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'shopping_service.dart';
import 'shopping.dart';
import '../../core/api_client.dart';
import '../../core/widgets/buttons/primary_button.dart';
import '../../core/utils/app_colors.dart';
import '../../core/widgets/custom_text_form_field.dart';
import '../../core/widgets/widgets_common.dart';

class UpdatePendingItemModal extends StatelessWidget {
  const UpdatePendingItemModal({
    super.key,
    required this.shoppingItem,
    required this.shoppingSessionId,
  });
  final ShoppingItem shoppingItem;
  final int shoppingSessionId;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (c) => ShoppingSessionDetailViewModel(
      c.read<ShoppingService>(),
      shoppingSessionId,
    ),
    child: UpdatePendingItemForm(
      shoppingItem: shoppingItem,
      shoppingSessionId: shoppingSessionId,
    ),
  );
}

class UpdatePendingItemForm extends StatefulWidget {
  const UpdatePendingItemForm({
    super.key,
    required this.shoppingItem,
    required this.shoppingSessionId,
  });
  final ShoppingItem shoppingItem;
  final int shoppingSessionId;

  @override
  State<UpdatePendingItemForm> createState() => _UpdatePendingItemFormState();
}

class _UpdatePendingItemFormState extends State<UpdatePendingItemForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _quantityController = TextEditingController(
    text: widget.shoppingItem.quantity.toString(),
  );
  late final TextEditingController _noteController = TextEditingController(
    text: widget.shoppingItem.note ?? '',
  );
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _quantityController.text = widget.shoppingItem.quantity.toString();
    _noteController.text = widget.shoppingItem.note ?? '';
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final vm = context.read<ShoppingSessionDetailViewModel>();
    try {
      await vm.updateItem(
        shoppingItemId: widget.shoppingItem.id,
        quantity: double.tryParse(_quantityController.text),
        note: _noteController.text.isNotEmpty ? _noteController.text : null,
      );
      if (!mounted) return;
      showMessage(context, 'Cập nhật mặt hàng thành công.');
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == '00005') {
        Navigator.pop(context);
      } else {}
      showMessage(
        context,
        e.message,
        error: true,
        retry: e.network ? _submit : null,
      );
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ShoppingSessionDetailViewModel>();
    return Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                    widget.shoppingItem.food.name,
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
                    'Định lượng ban đầu',
                    style: TextStyle(
                      color: AppColor.gray600,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.shoppingItem.quantity} ${widget.shoppingItem.food.unit.name}',
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
                  controller: _quantityController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: CustomTextFormField(
                  labelText: 'Đơn vị',
                  hintText: widget.shoppingItem.food.unit.name,
                  controller: TextEditingController(
                    text: widget.shoppingItem.food.unit.name,
                  ),
                  readOnly: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          CustomTextFormField(
            labelText: 'Ghi chú (tùy chọn)',
            hintText: 'Nhập ghi chú cho mặt hàng (nếu cần)',
            controller: _noteController,
            maxLines: 3,
            maxLength: 1000,
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            saving: vm.saving,
            onPressed: _submit,
            label: 'Lưu thông tin',
          ),
        ],
      ),
    );
  }
}
