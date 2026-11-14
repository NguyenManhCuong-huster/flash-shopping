import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../application/pantry_service.dart';
import '../application/validation/validators.dart';
import '../data/models/food.dart';
import '../data/remote/api_client.dart';
import '../screens/shared/base_view_model.dart';
import '../screens/shared/widgets.dart';
import '../utils/app_colors.dart';
import '../utils/date_time_utils.dart';
import '../widgets/buttons/primary_button.dart';
import '../widgets/buttons/outline_button.dart';
import '../widgets/custom_dropdown_form_field.dart';
import '../widgets/custom_text_form_field.dart';

class FridgeItemViewModel extends BaseViewModel {
  FridgeItemViewModel(this._pantry);
  final PantryService _pantry;

  // Future<void> add({
  //   required Food food,
  //   required double quantity,
  //   required DateTime expiry,
  //   required StorageLocation location,
  //   String? note,
  // }) => runSave(
  //   () => _pantry.addToFridge(
  //     foodName: food.name,
  //     quantity: quantity,
  //     expiry: expiry,
  //     location: location,
  //     note: note,
  //   ),
  // );

  Future<void> update(
    FridgeItem item, {
    DateTime? useWithin,
    StorageLocation? location,
    String? note,
  }) => runSave(
    () => _pantry.updateFridgeItem(
      item,
      useWithin: useWithin,
      location: location,
      note: note,
    ),
  );
}

/// Sửa thực phẩm trong tủ lạnh: thực phẩm, số lượng, hạn dùng, vị trí, ghi chú.
class FridgeItemModal extends StatelessWidget {
  const FridgeItemModal({super.key, required this.item});
  final FridgeItem item;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (c) => FridgeItemViewModel(c.read<PantryService>()),
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
    text: DateTimeUtils.formatDate(widget.item!.useWithin),
  );
  late final TextEditingController _noteController = TextEditingController(
    text: widget.item.note ?? '',
  );
  DateTime? _useWithin;
  StorageLocation _location = StorageLocation.cool;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final fridgeItem = widget.item;
    _food = fridgeItem.food;
    _useWithin = fridgeItem.useWithin;
    _location = fridgeItem.location;
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
          _location == fridgeItem.location &&
          note == fridgeItem.note) {
        Navigator.pop(context, false);
        return;
      }
      await vm.update(
        fridgeItem,
        useWithin: useWithinChanged ? _useWithin : null,
        location: _location,
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
    return Container(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              'Chỉnh sửa thực phẩm trong tủ lạnh',
              style: TextStyle(
                color: AppColor.gray800,
                fontSize: 24,
                fontWeight: FontWeight.w700,
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
                      widget.item.food.name,
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
                      '${widget.item.quantity} ${widget.item.food.unit.name}',
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
              prefixIcon: _location.icon,
              value: _location,
              items: StorageLocation.values,
              itemLabel: (location) => location.label,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _location = value);
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
              label: 'Hủy',
            ),
          ],
        ),
        // ListView(
        //   padding: const EdgeInsets.all(20),
        //   children: [
        //     InkWell(
        //       onTap: _editing
        //           ? null
        //           : () async {
        //               final f = await pickFood(context);
        //               if (f != null) setState(() => _food = f);
        //             },
        //       child: InputDecorator(
        //         decoration: InputDecoration(
        //           labelText: 'Thực phẩm',
        //           errorText: _foodError,
        //           suffixIcon: _editing ? null : const Icon(Icons.search),
        //         ),
        //         child: Text(
        //           _food == null
        //               ? 'Chọn thực phẩm'
        //               : '${_food!.name} (${_food!.unit.name})',
        //         ),
        //       ),
        //     ),
        //     const SizedBox(height: 12),
        //     TextFormField(
        //       controller: _qty,
        //       keyboardType: const TextInputType.numberWithOptions(
        //         decimal: true,
        //       ),
        //       decoration: InputDecoration(
        //         labelText: 'Số lượng',
        //         suffixText: _food?.unit.name,
        //       ),
        //       validator: Validators.quantity,
        //     ),
        //     const SizedBox(height: 12),
        //     DateField(
        //       label: 'Hạn sử dụng',
        //       value: _expiry,
        //       onChanged: (d) => setState(() => _expiry = d),
        //     ),
        //     const SizedBox(height: 12),
        //     SegmentedButton<StorageLocation>(
        //       segments: [
        //         for (final l in StorageLocation.values)
        //           ButtonSegment(value: l, label: Text(l.label)),
        //       ],
        //       selected: {_location},
        //       onSelectionChanged: (s) => setState(() => _location = s.first),
        //     ),
        //     const SizedBox(height: 12),
        //     TextFormField(
        //       controller: _note,
        //       maxLength: 500,
        //       decoration: const InputDecoration(
        //         labelText: 'Ghi chú (tùy chọn)',
        //       ),
        //     ),
        //     const SizedBox(height: 12),
        //     PrimaryButton(saving: vm.saving, onPressed: _submit),
        //   ],
        // ),
      ),
    );
  }
}
