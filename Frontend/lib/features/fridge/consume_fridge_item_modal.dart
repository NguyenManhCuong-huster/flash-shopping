import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../food/food_service.dart';
import '../../core/utils/validators.dart';
import '../food/food.dart';
import '../../core/api_client.dart';
import '../../core/widgets/widgets_common.dart';
import '../../core/utils/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/buttons/primary_button.dart';
import '../../core/widgets/custom_text_form_field.dart';
import 'fridge_view_model.dart';

class ConsumeFridgeItemModal extends StatelessWidget {
  const ConsumeFridgeItemModal({super.key, required this.item, required this.discard});
  final FridgeItem item;
  final bool discard;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (c) => FridgeItemViewModel(c.read<FoodService>(), item.id)..load(),
    child: _ConsumeFridgeItemForm(item: item, discard: discard),
  );
}

class _ConsumeFridgeItemForm extends StatefulWidget {
  const _ConsumeFridgeItemForm({required this.item, required this.discard});
  final FridgeItem item;
  final bool discard;
  @override
  State<_ConsumeFridgeItemForm> createState() => _ConsumeFridgeItemFormState();
}

class _ConsumeFridgeItemFormState extends State<_ConsumeFridgeItemForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _quantityController = TextEditingController(
    text: FormatUtils.formatQuantity(widget.item.quantity).replaceAll(',', '.'),
  );
  late final TextEditingController _noteController = TextEditingController(
    text: widget.item.note ?? '',
  );
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final fridgeItem = widget.item;
    _quantityController.text = FormatUtils.formatQuantity(
      fridgeItem.quantity,
    ).replaceAll(',', '.');
    _noteController.text = fridgeItem.note ?? '';
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final vm = context.read<FridgeItemViewModel>();
    final quantity =
        double.tryParse(_quantityController.text.replaceAll(',', '.')) ?? 0;
    final discard = quantity == widget.item.quantity;
    final note = _noteController.text.trim();
    setState(() => _saving = true);
    try {
      await vm.consume(quantity, discard: discard, note: note);
      if (!mounted) return;
      showMessage(
        context,
        discard
            ? 'Đã bỏ ${widget.item.food.name}'
            : 'Đã tiêu thụ ${widget.item.food.name}',
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      final errorMessage = e.message ?? 'Đã xảy ra lỗi';
      showMessage(
        context,
        errorMessage,
        error: true,
        retry: e.network ? _submit : null,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
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
    final vm = context.watch<FridgeItemViewModel>();
    return Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomTextFormField(
            controller: _quantityController,
            labelText: widget.discard ? 'Số lượng vứt bỏ' : 'Số lượng đã dùng',
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Hãy nhập số lượng';
              }
              final quantity = double.tryParse(value.replaceAll(',', '.'));
              if (quantity == null || quantity <= 0) {
                return 'Số lượng không hợp lệ';
              }
              if (quantity > vm.fridgeItem!.quantity) {
                return 'Số lượng vượt quá số lượng hiện có';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          CustomTextFormField(
            controller: _noteController,
            labelText: 'Ghi chú (tùy chọn)',
            maxLines: 3,
            maxLength: 200,
          ),
          const SizedBox(height: 16),
          PrimaryButton(saving: _saving, onPressed: _submit, label: 'Xác nhận'),
        ],
      ),
    );
  }
}
