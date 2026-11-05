import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/session_service.dart';
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
import 'purchase_page.dart';
import 'shopping_form_page.dart';

class ShoppingDetailViewModel extends BaseViewModel {
  ShoppingDetailViewModel(this._shopping, this.listId);
  final ShoppingService _shopping;
  final int listId;

  ShoppingList? list;

  Future<void> load() => runLoad(() async => list = await _shopping.list(listId));

  Future<TaskBatchResult> addTasks(List<({String foodName, double quantity})> tasks) => runSave(() async {
        final r = await _shopping.addTasks(listId, tasks);
        if (r.list != null) list = r.list;
        return r;
      });

  Future<void> updateTask(ShoppingTask t, {String? foodName, double? quantity}) => runSave(() async {
        await _shopping.updateTask(t, foodName: foodName, quantity: quantity);
        list = await _shopping.list(listId);
      });

  Future<void> deleteTask(ShoppingTask t) => runSave(() async {
        await _shopping.deleteTask(t);
        list = await _shopping.list(listId);
      });

  Future<void> deleteList() => runSave(() => _shopping.deleteList(list!));
}

/// Chi tiết danh sách: mục mua và trạng thái từng mục; trưởng nhóm thêm/sửa/xóa;
/// người được giao hoặc trưởng nhóm xác nhận mua.
class ShoppingDetailPage extends StatelessWidget {
  const ShoppingDetailPage({super.key, required this.listId, this.openAddTasks = false});
  final int listId;
  final bool openAddTasks;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (c) => ShoppingDetailViewModel(c.read<ShoppingService>(), listId)..load(),
        child: _DetailView(openAddTasks: openAddTasks),
      );
}

class _DetailView extends StatefulWidget {
  const _DetailView({required this.openAddTasks});
  final bool openAddTasks;
  @override
  State<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends State<_DetailView> {
  @override
  void initState() {
    super.initState();
    if (widget.openAddTasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _addTasks(context));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ShoppingDetailViewModel>();
    final session = context.watch<SessionService>();
    final l = vm.list;
    final isLeader = session.isLeader;
    final canBuy = l != null && (isLeader || l.assignedTo?.id == session.user?.id) && l.pendingTasks.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l?.name ?? 'Danh sách mua sắm'),
        actions: [
          if (l != null && isLeader)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'edit') {
                  if (await pushPage<int>(context, ShoppingFormPage(list: l)) != null) vm.load();
                } else if (v == 'delete') {
                  if (await confirmDialog(context, title: 'Xóa danh sách', message: 'Xóa "${l.name}" và toàn bộ mục trong danh sách?') && context.mounted) {
                    final ok = await runAction(context, () async {
                      await vm.deleteList();
                      return true;
                    }, success: 'Đã xóa danh sách');
                    if (ok == true && context.mounted) Navigator.pop(context);
                  }
                }
              },
              itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Sửa danh sách')), PopupMenuItem(value: 'delete', child: Text('Xóa danh sách'))],
            ),
        ],
      ),
      bottomNavigationBar: canBuy
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () async {
                    if (await pushPage<bool>(context, PurchasePage(list: l!)) == true) vm.load();
                  },
                  icon: const Icon(Icons.shopping_bag),
                  label: Text('Xác nhận đã mua (${l!.pendingTasks.length} món)'),
                ),
              ),
            )
          : null,
      floatingActionButton: l != null && isLeader
          ? FloatingActionButton(onPressed: () => _addTasks(context), tooltip: 'Thêm món', child: const Icon(Icons.add))
          : null,
      body: AsyncBody(
        loading: vm.loading,
        error: vm.loadError,
        isEmpty: l == null,
        onRetry: vm.load,
        child: l == null
            ? const SizedBox()
            : ListView(padding: const EdgeInsets.only(bottom: 100), children: [
                ListTile(
                  leading: const Icon(Icons.event, color: AppTheme.primary),
                  title: Text('Ngày đi chợ: ${fmtIsoDate(l.date)}'),
                  subtitle: Text(l.assignedTo == null ? 'Chưa giao cho ai' : 'Người mua: ${l.assignedTo!.name} (@${l.assignedTo!.username})'),
                ),
                if (l.note != null && l.note!.isNotEmpty) ListTile(leading: const Icon(Icons.notes), title: Text(l.note!)),
                SectionTitle('Cần mua (${l.pendingTasks.length})'),
                if (l.tasks.isEmpty)
                  const Padding(padding: EdgeInsets.all(16), child: Text('Danh sách đang trống.', style: TextStyle(color: AppTheme.muted))),
                for (final t in l.pendingTasks) _taskTile(context, vm, t, isLeader),
                if (l.tasks.any((t) => t.isBought)) SectionTitle('Đã mua (${l.bought})'),
                for (final t in l.tasks.where((t) => t.isBought)) _taskTile(context, vm, t, false),
              ]),
      ),
    );
  }

  Widget _taskTile(BuildContext context, ShoppingDetailViewModel vm, ShoppingTask t, bool editable) => Card(
        child: ListTile(
          leading: Icon(t.isBought ? Icons.check_circle : Icons.radio_button_unchecked, color: t.isBought ? AppTheme.primary : Colors.grey),
          title: Text(t.food.name, style: TextStyle(decoration: t.isBought ? TextDecoration.lineThrough : null)),
          subtitle: t.isBought
              ? Text('Đã mua ${fmtQtyUnit(t.boughtQuantity ?? t.quantity, t.food.unit.name)}${t.boughtByName != null ? ' · ${t.boughtByName}' : ''}')
              : Text(t.food.category.name),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            NumText(fmtQtyUnit(t.quantity, t.food.unit.name)),
            if (editable)
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'qty') {
                    final q = await promptText(context,
                        title: 'Số lượng ${t.food.name}', label: t.food.unit.name, initial: fmtQty(t.quantity).replaceAll(',', '.'), validator: Validators.quantity);
                    if (q != null && context.mounted) await runAction(context, () => vm.updateTask(t, quantity: Validators.parseQuantity(q)), success: 'Đã cập nhật');
                  } else if (v == 'food') {
                    final f = await pickFood(context, title: 'Đổi thực phẩm');
                    if (f != null && context.mounted) await runAction(context, () => vm.updateTask(t, foodName: f.name), success: 'Đã cập nhật');
                  } else if (await confirmDialog(context, title: 'Xóa món', message: 'Xóa ${t.food.name} khỏi danh sách?') && context.mounted) {
                    await runAction(context, () => vm.deleteTask(t), success: 'Đã xóa');
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'qty', child: Text('Sửa số lượng')),
                  PopupMenuItem(value: 'food', child: Text('Đổi thực phẩm')),
                  PopupMenuItem(value: 'delete', child: Text('Xóa')),
                ],
              ),
          ]),
        ),
      );

  /// Thêm nhiều món một lần. Mục lỗi (không tồn tại, trùng, số lượng sai) được giữ lại để sửa (UC03 - 5a).
  Future<void> _addTasks(BuildContext context) async {
    final vm = context.read<ShoppingDetailViewModel>();
    final rows = <_Row>[_Row()];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetCtx) => StatefulBuilder(builder: (ctx, setSheet) {
        Future<void> submit() async {
          final valid = rows.where((r) => r.food != null && Validators.quantity(r.qty.text) == null).toList();
          if (valid.isEmpty) {
            showMessage(ctx, 'Hãy chọn thực phẩm và nhập số lượng > 0 cho ít nhất một dòng', error: true);
            return;
          }
          try {
            final r = await vm.addTasks([for (final row in valid) (foodName: row.food!.name, quantity: Validators.parseQuantity(row.qty.text)!)]);
            if (!ctx.mounted) return;
            if (r.failed.isEmpty) {
              Navigator.pop(sheetCtx);
              showMessage(context, 'Đã thêm ${r.createdCount} món');
            } else {
              // Giữ lại các dòng lỗi để người dùng sửa
              final failedNames = r.failed.map((f) => f.foodName.toLowerCase()).toSet();
              setSheet(() => rows.removeWhere((row) => row.food != null && !failedNames.contains(row.food!.name.toLowerCase())));
              showMessage(ctx, 'Đã thêm ${r.createdCount} món. Chưa thêm được:\n${r.failed.map((f) => '• ${f.foodName}: ${f.message}').join('\n')}', error: true);
            }
          } on ApiException catch (e) {
            if (ctx.mounted) showMessage(ctx, e.message, error: true);
          }
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Thêm món cần mua', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Expanded(
                        flex: 3,
                        child: OutlinedButton(
                          onPressed: () async {
                            final f = await pickFood(ctx);
                            if (f != null) setSheet(() => row.food = f);
                          },
                          child: Text(row.food?.name ?? 'Chọn thực phẩm', overflow: TextOverflow.ellipsis),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: row.qty,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.right,
                          decoration: InputDecoration(hintText: 'SL', suffixText: row.food?.unit.name),
                        ),
                      ),
                      IconButton(onPressed: rows.length > 1 ? () => setSheet(() => rows.remove(row)) : null, icon: const Icon(Icons.close)),
                    ]),
                  ),
              ]),
            ),
            TextButton.icon(onPressed: () => setSheet(() => rows.add(_Row())), icon: const Icon(Icons.add), label: const Text('Thêm dòng')),
            const SizedBox(height: 8),
            ListenableBuilder(listenable: vm, builder: (_, __) => SaveButton(saving: vm.saving, onPressed: submit, label: 'Thêm vào danh sách')),
          ]),
        );
      }),
    );
  }
}

class _Row {
  Food? food;
  final TextEditingController qty = TextEditingController(text: '1');
}
