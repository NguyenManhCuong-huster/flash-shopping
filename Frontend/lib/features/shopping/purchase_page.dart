import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import './shopping_service.dart';
import '../../core/utils/validators.dart';
import './shopping.dart';
import '../../core/api_client.dart';
import '../../core/base_view_model.dart';
import '../../core/utils/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets_common.dart';
import '../../core/widgets/buttons/primary_button.dart';

class PurchaseViewModel extends BaseViewModel {
  PurchaseViewModel(this._shopping, this.list) {
    for (final t in list.pendingItems) {
      drafts[t.id] = PurchaseItem(itemId: t.id, purchasedQuantity: t.quantity);
      selected.add(t.id);
    }
  }

  final ShoppingService _shopping;
  final ShoppingSession list;
  final Map<int, PurchaseItem> drafts = {};
  final Set<int> selected = {};

  /// Khóa chống lặp sinh MỘT lần cho lượt xác nhận này; thử lại sau lỗi mạng dùng lại đúng khóa
  /// nên backend trả kết quả cũ thay vì cộng tồn kho lần 2 (NFR10). Đổi nội dung thì sinh khóa mới.
  String _key = newIdempotencyKey();

  void toggle(int itemId) {
    selected.contains(itemId) ? selected.remove(itemId) : selected.add(itemId);
    _key = newIdempotencyKey();
    notifyListeners();
  }

  void changed() {
    _key = newIdempotencyKey();
    notifyListeners();
  }

  Future<ShoppingSession> submit() => runSave(
    () => _shopping.purchase(list, [
      for (final id in selected) drafts[id]!,
    ], _key),
  );
}

/// UC04 - Hoàn thành mua sắm: chỉ đánh dấu đã mua và ghi nhận số lượng thực tế.
class PurchasePage extends StatelessWidget {
  const PurchasePage({super.key, required this.list});
  final ShoppingSession list;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (c) => PurchaseViewModel(c.read<ShoppingService>(), list),
    child: const _PurchaseView(),
  );
}

class _PurchaseView extends StatelessWidget {
  const _PurchaseView();

  Future<void> _submit(BuildContext context) async {
    final vm = context.read<PurchaseViewModel>();
    if (vm.selected.isEmpty)
      return showMessage(
        context,
        'Hãy chọn ít nhất một món đã mua',
        error: true,
      );
    for (final id in vm.selected) {
      final d = vm.drafts[id]!;
      if (d.purchasedQuantity <= 0)
        return showMessage(
          context,
          'Số lượng thực mua phải lớn hơn 0',
          error: true,
        );
    }
    try {
      await vm.submit();
      if (!context.mounted) return;
      showMessage(
        context,
        'Đã xác nhận mua ${vm.selected.length} món. Về nhà hãy nhập từng món vào tủ lạnh.',
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      showMessage(
        context,
        e.message,
        error: true,
        retry: e.network ? () => _submit(context) : null,
      );
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
          child: PrimaryButton(
            saving: vm.saving,
            onPressed: () => _submit(context),
            label: 'Xác nhận ${vm.selected.length} món',
            icon: Icons.done_all,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Chọn món đã mua và sửa số lượng thực tế. Bạn có thể nhập từng món vào tủ lạnh sau khi về nhà.',
              style: TextStyle(color: AppColor.muted),
            ),
          ),
          for (final t in vm.list.pendingItems) _taskCard(context, vm, t),
        ],
      ),
    );
  }

  Widget _taskCard(BuildContext context, PurchaseViewModel vm, ShoppingItem t) {
    final d = vm.drafts[t.id]!;
    final on = vm.selected.contains(t.id);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 12),
        child: Column(
          children: [
            CheckboxListTile(
              value: on,
              onChanged: (_) => vm.toggle(t.id),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                t.food.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Cần mua ${FormatUtils.formatQuantityUnit(t.quantity, t.food.unit.name)}',
              ),
            ),
            if (on) ...[
              Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      initialValue: FormatUtils.formatQuantity(d.purchasedQuantity).replaceAll(',', '.'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        labelText: 'Thực mua',
                        suffixText: t.food.unit.name,
                      ),
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: Validators.quantity,
                      onChanged: (v) {
                        d.purchasedQuantity = Validators.parseQuantity(v) ?? 0;
                        vm.changed();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
