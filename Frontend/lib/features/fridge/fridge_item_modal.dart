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


/// Sửa thực phẩm trong tủ lạnh: thực phẩm, số lượng, hạn dùng, vị trí, ghi chú.
class FridgeItemModal extends StatelessWidget {
  const FridgeItemModal({super.key, required this.item});
  final FridgeItem item;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (c) => FridgeItemViewModel(c.read<FoodService>(), item.id)..load(),
    child: _FridgeItemForm(item: item),
  );
}

class _FridgeItemForm extends StatefulWidget {
  const _FridgeItemForm({required this.item});
  final FridgeItem item;
  @override
  State<_FridgeItemForm> createState() => _FridgeItemFormState();
}

class _FridgeItemFormState extends State<_FridgeItemForm> {
  final _form = GlobalKey<FormState>();
  Food? _food;
  late final TextEditingController _dateController = TextEditingController(
    text: FormatUtils.formatDate(widget.item.useWithin),
  );
  late final TextEditingController _noteController = TextEditingController(
    text: widget.item.note ?? '',
  );
  DateTime? _useWithin;
  StorageLocation _selectedLocation = StorageLocation.cool;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final fridgeItem = widget.item;
    _food = fridgeItem.food;
    _useWithin = fridgeItem.useWithin;
    _selectedLocation = fridgeItem.location;
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
    setState(() => _saving = true);
    if (!_form.currentState!.validate() || _food == null || _useWithin == null)
      return;
    final vm = context.read<FridgeItemViewModel>();
    final note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();
    try {
      final fridgeItem = widget.item;
      final useWithinChanged =
          isoDate(_useWithin!) != isoDate(fridgeItem.useWithin);
      if (!useWithinChanged &&
          _selectedLocation == fridgeItem.location &&
          note == fridgeItem.note) {
        Navigator.pop(context, false);
        return;
      }
      await vm.update(
        fridgeItem,
        useWithin: useWithinChanged ? _useWithin : null,
        location: _selectedLocation,
        note: note,
      );
      if (!mounted) return;
      showMessage(context, 'Đã cập nhật thông tin thực phẩm trong tủ lạnh');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = e.code == '00199'
          ? '${e.message} Hãy mở mục đó và sửa số lượng.'
          : e.message;
      showMessage(context, msg, error: true, retry: e.network ? _submit : null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FridgeItemViewModel>();
    return Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
