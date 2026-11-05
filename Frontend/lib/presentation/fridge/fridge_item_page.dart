import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/pantry_service.dart';
import '../../application/validation/validators.dart';
import '../../data/models/food.dart';
import '../../data/remote/api_client.dart';
import '../shared/base_view_model.dart';
import '../shared/format.dart';
import '../shared/theme.dart';
import '../shared/widgets.dart';
import 'fridge_form_page.dart';

class FridgeItemViewModel extends BaseViewModel {
  FridgeItemViewModel(this._pantry, this.itemId);
  final PantryService _pantry;
  final int itemId;

  FridgeItem? item;
  bool removed = false;

  Future<void> load() => runLoad(() async => item = await _pantry.fridgeItem(itemId));

  /// Trả về true nếu đã dùng hết (mục bị xóa khỏi tủ).
  Future<bool> consume(double quantity, {required bool discard, String? note}) => runSave(() async {
        final updated = await _pantry.consume(item!, quantity, discard: discard, note: note);
        if (updated == null) {
          removed = true;
          return true;
        }
        item = updated;
        return false;
      });

  Future<void> delete() => runSave(() async {
        await _pantry.removeFromFridge(item!);
        removed = true;
      });
}

/// Chi tiết mục tủ lạnh; cũng là đích mở từ thông báo nhắc hạn (UC06 bước 6).
class FridgeItemPage extends StatelessWidget {
  const FridgeItemPage({super.key, required this.itemId});
  final int itemId;

  @override
  Widget build(BuildContext context) =>
      ChangeNotifierProvider(create: (c) => FridgeItemViewModel(c.read<PantryService>(), itemId)..load(), child: const _FridgeItemView());
}

class _FridgeItemView extends StatelessWidget {
  const _FridgeItemView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FridgeItemViewModel>();
    final item = vm.item;
    return Scaffold(
      appBar: AppBar(
        title: Text(item?.food.name ?? 'Thực phẩm'),
        actions: [
          if (item != null) ...[
            IconButton(
              tooltip: 'Sửa',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                if (await pushPage<bool>(context, FridgeFormPage(item: item)) == true) vm.load();
              },
            ),
            IconButton(
              tooltip: 'Xóa khỏi tủ',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirmDialog(context, title: 'Xóa khỏi tủ lạnh', message: 'Xóa ${item.food.name} khỏi tủ lạnh? (Không tính là tiêu thụ)') && context.mounted) {
                  final ok = await runAction(context, () async {
                    await vm.delete();
                    return true;
                  }, success: 'Đã xóa');
                  if (ok == true && context.mounted) Navigator.pop(context);
                }
              },
            ),
          ],
        ],
      ),
      body: vm.loading && item == null
          ? const Center(child: CircularProgressIndicator())
          : item == null
              ? ErrorView(message: vm.loadError ?? 'Mục tủ lạnh không tồn tại hoặc đã được dùng hết.', onRetry: vm.load)
              : ListView(padding: const EdgeInsets.all(16), children: [
                  Row(children: [
                    NetImage(item.food.imageUrl, size: 72),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item.food.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text(item.food.category.name, style: const TextStyle(color: AppTheme.muted)),
                        const SizedBox(height: 4),
                        Pill(statusLabel(item.status, item.daysLeft), color: statusColor(item.status)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _row('Số lượng', fmtQtyUnit(item.quantity, item.food.unit.name)),
                  _row('Hạn sử dụng', fmtDateTime(item.useWithin)),
                  _row('Vị trí', item.location.label),
                  if (item.note != null) _row('Ghi chú', item.note!),
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: vm.saving ? null : () => _consume(context, vm, discard: false),
                        icon: const Icon(Icons.restaurant),
                        label: const Text('Đã dùng'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
                        onPressed: vm.saving ? null : () => _consume(context, vm, discard: true),
                        icon: const Icon(Icons.delete_sweep_outlined),
                        label: const Text('Bỏ đi / hỏng'),
                      ),
                    ),
                  ]),
                ]),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: AppTheme.muted))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );

  /// UC05: ghi nhận tiêu thụ/hủy bỏ. Lượng phải dương và không vượt tồn (backend kiểm tra lại trong giao dịch).
  Future<void> _consume(BuildContext context, FridgeItemViewModel vm, {required bool discard}) async {
    final item = vm.item!;
    final ctrl = TextEditingController(text: fmtQty(item.quantity).replaceAll(',', '.'));
    final note = TextEditingController();
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(discard ? 'Bỏ đi ${item.food.name}' : 'Đã dùng ${item.food.name}'),
        content: Form(
          key: key,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Lượng (${item.food.unit.name})', helperText: 'Còn ${fmtQtyUnit(item.quantity, item.food.unit.name)}'),
              validator: (v) {
                final err = Validators.quantity(v, field: 'Lượng');
                if (err != null) return err;
                if (Validators.parseQuantity(v)! > item.quantity) return 'Không được vượt quá lượng còn lại (${fmtQty(item.quantity)})';
                return null;
              },
            ),
            const SizedBox(height: 8),
            TextField(controller: note, decoration: const InputDecoration(labelText: 'Ghi chú (tùy chọn)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => key.currentState!.validate() ? Navigator.pop(ctx, true) : null, child: const Text('Ghi nhận')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final depleted = await vm.consume(Validators.parseQuantity(ctrl.text)!, discard: discard, note: note.text.trim().isEmpty ? null : note.text.trim());
      if (!context.mounted) return;
      showMessage(context, depleted ? 'Đã dùng hết ${item.food.name}, mục đã được xóa khỏi tủ lạnh.' : 'Đã ghi nhận');
      if (depleted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      if (e.code == '00523') {
        // Người khác vừa cập nhật: tải lại thay vì ghi đè (UC05 - 4b)
        showMessage(context, e.message, error: true);
        vm.load();
      } else {
        showMessage(context, e.message, error: true, retry: e.network ? () => _consume(context, vm, discard: discard) : null);
      }
    }
  }
}
