import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/shopping_service.dart';
import '../../application/validation/validators.dart';
import '../../data/models/food.dart';
import '../../data/models/shopping.dart';
import '../../data/remote/api_client.dart';
import '../shared/base_view_model.dart';
import '../shared/format.dart';
import '../shared/pickers.dart';
import '../shared/theme.dart';
import '../shared/widgets.dart';

class PurchaseViewModel extends BaseViewModel {
  PurchaseViewModel(this._shopping, this.list) {
    final defaultExpiry = isoDate(DateTime.now().add(const Duration(days: 3)));
    for (final t in list.pendingTasks) {
      drafts[t.id] = PurchaseItem(taskId: t.id, boughtQuantity: t.quantity, useWithin: defaultExpiry);
      selected.add(t.id);
    }
  }

  final ShoppingService _shopping;
  final ShoppingList list;
  final Map<int, PurchaseItem> drafts = {};
  final Set<int> selected = {};

  /// Khóa chống lặp sinh MỘT lần cho lượt xác nhận này; thử lại sau lỗi mạng dùng lại đúng khóa
  /// nên backend trả kết quả cũ thay vì cộng tồn kho lần 2 (NFR10). Đổi nội dung thì sinh khóa mới.
  String _key = newIdempotencyKey();

  void toggle(int taskId) {
    selected.contains(taskId) ? selected.remove(taskId) : selected.add(taskId);
    _key = newIdempotencyKey();
    notifyListeners();
  }

  void changed() {
    _key = newIdempotencyKey();
    notifyListeners();
  }

  Future<ShoppingList> submit() => runSave(() => _shopping.purchase(list, [for (final id in selected) drafts[id]!], _key));
}

/// UC04 - Hoàn thành mua sắm: đánh dấu đã mua, nhập số lượng thực mua, hạn dùng và vị trí,
/// xác nhận đưa vào tủ lạnh trong MỘT giao dịch ở backend.
class PurchasePage extends StatelessWidget {
  const PurchasePage({super.key, required this.list});
  final ShoppingList list;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(create: (c) => PurchaseViewModel(c.read<ShoppingService>(), list), child: const _PurchaseView());
}

class _PurchaseView extends StatelessWidget {
  const _PurchaseView();

  Future<void> _submit(BuildContext context) async {
    final vm = context.read<PurchaseViewModel>();
    if (vm.selected.isEmpty) return showMessage(context, 'Hãy chọn ít nhất một món đã mua', error: true);
    for (final id in vm.selected) {
      final d = vm.drafts[id]!;
      if (d.boughtQuantity <= 0) return showMessage(context, 'Số lượng thực mua phải lớn hơn 0', error: true);
      if (d.addToFridge && d.useWithin == null) return showMessage(context, 'Hãy chọn hạn sử dụng cho các món đưa vào tủ lạnh', error: true);
    }
    try {
      await vm.submit();
      if (!context.mounted) return;
      showMessage(context, 'Đã xác nhận mua ${vm.selected.length} món, tủ lạnh đã được cập nhật');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      showMessage(context, e.message, error: true, retry: e.network ? () => _submit(context) : null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PurchaseViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Xác nhận đã mua')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SaveButton(saving: vm.saving, onPressed: () => _submit(context), label: 'Xác nhận ${vm.selected.length} món', icon: Icons.done_all),
        ),
      ),
      body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('Chọn món đã mua, sửa số lượng thực mua và hạn dùng. Món được đưa vào tủ lạnh sẽ cộng dồn vào mục sẵn có.',
              style: TextStyle(color: AppTheme.muted)),
        ),
        for (final t in vm.list.pendingTasks) _taskCard(context, vm, t),
      ]),
    );
  }

  Widget _taskCard(BuildContext context, PurchaseViewModel vm, ShoppingTask t) {
    final d = vm.drafts[t.id]!;
    final on = vm.selected.contains(t.id);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 12),
        child: Column(children: [
          CheckboxListTile(
            value: on,
            onChanged: (_) => vm.toggle(t.id),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(t.food.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Cần mua ${fmtQtyUnit(t.quantity, t.food.unit.name)}'),
          ),
          if (on) ...[
            Row(children: [
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  initialValue: fmtQty(d.boughtQuantity).replaceAll(',', '.'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(labelText: 'Thực mua', suffixText: t.food.unit.name),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: Validators.quantity,
                  onChanged: (v) {
                    d.boughtQuantity = Validators.parseQuantity(v) ?? 0;
                    vm.changed();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Column(children: [
                const Text('Vào tủ lạnh', style: TextStyle(fontSize: 12)),
                Switch(
                  value: d.addToFridge,
                  onChanged: (v) {
                    d.addToFridge = v;
                    vm.changed();
                  },
                ),
              ]),
            ]),
            if (d.addToFridge) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Row(children: [
                  Expanded(
                    child: DateField(
                      label: 'Hạn sử dụng',
                      value: d.useWithin == null ? null : parseIsoDate(d.useWithin!),
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      onChanged: (v) {
                        d.useWithin = isoDate(v);
                        vm.changed();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<StorageLocation>(
                    value: d.location,
                    items: [for (final l in StorageLocation.values) DropdownMenuItem(value: l, child: Text(l.label))],
                    onChanged: (v) {
                      d.location = v ?? d.location;
                      vm.changed();
                    },
                  ),
                ]),
              ),
            ],
          ],
        ]),
      ),
    );
  }
}
