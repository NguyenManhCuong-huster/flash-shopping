import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/pantry_service.dart';
import '../../application/validation/validators.dart';
import '../../data/models/food.dart';
import '../../data/remote/api_client.dart';
import '../shared/base_view_model.dart';
import '../shared/format.dart';
import '../shared/pickers.dart';
import '../shared/widgets.dart';

class FridgeFormViewModel extends BaseViewModel {
  FridgeFormViewModel(this._pantry);
  final PantryService _pantry;

  Future<void> add({required Food food, required double quantity, required DateTime expiry, required StorageLocation location, String? note}) =>
      runSave(() => _pantry.addToFridge(foodName: food.name, quantity: quantity, expiry: expiry, location: location, note: note));

  Future<void> update(FridgeItem item, {double? quantity, DateTime? expiry, StorageLocation? location, String? note}) =>
      runSave(() => _pantry.updateFridgeItem(item, quantity: quantity, expiry: expiry, location: location, note: note));
}

/// Thêm hoặc sửa mục tủ lạnh: thực phẩm, số lượng, hạn dùng, vị trí, ghi chú.
class FridgeFormPage extends StatelessWidget {
  const FridgeFormPage({super.key, this.item});
  final FridgeItem? item;

  @override
  Widget build(BuildContext context) =>
      ChangeNotifierProvider(create: (c) => FridgeFormViewModel(c.read<PantryService>()), child: _FridgeForm(item: item));
}

class _FridgeForm extends StatefulWidget {
  const _FridgeForm({this.item});
  final FridgeItem? item;
  @override
  State<_FridgeForm> createState() => _FridgeFormState();
}

class _FridgeFormState extends State<_FridgeForm> {
  final _form = GlobalKey<FormState>();
  Food? _food;
  late final TextEditingController _qty = TextEditingController(text: widget.item == null ? '' : fmtQty(widget.item!.quantity).replaceAll(',', '.'));
  late final TextEditingController _note = TextEditingController(text: widget.item?.note ?? '');
  DateTime? _expiry;
  StorageLocation _location = StorageLocation.cool;
  String? _foodError;

  bool get _editing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    if (it != null) {
      _food = it.food;
      _expiry = it.useWithin;
      _location = it.location;
    } else {
      _expiry = DateTime.now().add(const Duration(days: 3));
    }
  }

  Future<void> _submit() async {
    setState(() => _foodError = _food == null ? 'Hãy chọn thực phẩm' : null);
    if (!_form.currentState!.validate() || _food == null || _expiry == null) return;
    final vm = context.read<FridgeFormViewModel>();
    final qty = Validators.parseQuantity(_qty.text)!;
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    try {
      if (_editing) {
        final it = widget.item!;
        final expiryChanged = isoDate(_expiry!) != isoDate(it.useWithin);
        if (qty == it.quantity && !expiryChanged && _location == it.location && note == it.note) {
          Navigator.pop(context, false);
          return;
        }
        await vm.update(it, quantity: qty, expiry: expiryChanged ? _expiry : null, location: _location, note: note);
      } else {
        await vm.add(food: _food!, quantity: qty, expiry: _expiry!, location: _location, note: note);
      }
      if (!mounted) return;
      showMessage(context, _editing ? 'Đã cập nhật' : 'Đã thêm ${_food!.name} vào tủ lạnh');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = e.code == '00199' ? '${e.message} Hãy mở mục đó và sửa số lượng.' : e.message;
      showMessage(context, msg, error: true, retry: e.network ? _submit : null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FridgeFormViewModel>();
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Sửa mục tủ lạnh' : 'Thêm vào tủ lạnh')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          InkWell(
            onTap: _editing
                ? null
                : () async {
                    final f = await pickFood(context);
                    if (f != null) setState(() => _food = f);
                  },
            child: InputDecorator(
              decoration: InputDecoration(labelText: 'Thực phẩm', errorText: _foodError, suffixIcon: _editing ? null : const Icon(Icons.search)),
              child: Text(_food == null ? 'Chọn thực phẩm' : '${_food!.name} (${_food!.unit.name})'),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _qty,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Số lượng', suffixText: _food?.unit.name),
            validator: Validators.quantity,
          ),
          const SizedBox(height: 12),
          DateField(label: 'Hạn sử dụng', value: _expiry, onChanged: (d) => setState(() => _expiry = d)),
          const SizedBox(height: 12),
          SegmentedButton<StorageLocation>(
            segments: [for (final l in StorageLocation.values) ButtonSegment(value: l, label: Text(l.label))],
            selected: {_location},
            onSelectionChanged: (s) => setState(() => _location = s.first),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _note, maxLength: 500, decoration: const InputDecoration(labelText: 'Ghi chú (tùy chọn)')),
          const SizedBox(height: 12),
          SaveButton(saving: vm.saving, onPressed: _submit),
        ]),
      ),
    );
  }
}
