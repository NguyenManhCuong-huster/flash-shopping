import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/pantry_service.dart';
import '../../application/session_service.dart';
import '../../data/models/food.dart';
import '../group/group_page.dart';
import '../shared/base_view_model.dart';
import '../shared/format.dart';
import '../shared/theme.dart';
import '../shared/widgets.dart';
import 'fridge_form_page.dart';
import 'fridge_item_page.dart';

class FridgeViewModel extends BaseViewModel {
  FridgeViewModel(this._pantry);
  final PantryService _pantry;

  List<FridgeItem> items = [];
  FridgeSummary summary = const FridgeSummary();
  StorageLocation? location;
  bool onlyExpiring = false;
  String query = '';
  int _page = 1;
  int _totalPages = 1;

  Future<void> load() => runLoad(() async {
        _page = 1;
        final r = await _pantry.fridge(q: query, location: location, expiringDays: onlyExpiring ? 3 : null);
        items = r.items;
        summary = r.summary;
        _totalPages = r.totalPages;
      });

  /// Tải cuộn: 50 mục mỗi lần (NFR08).
  Future<void> loadMore() async {
    if (_page >= _totalPages || loading) return;
    final r = await _pantry.fridge(q: query, location: location, expiringDays: onlyExpiring ? 3 : null, page: ++_page);
    items = [...items, ...r.items];
    notifyListeners();
  }

  void setLocation(StorageLocation? l) {
    location = l;
    load();
  }

  void toggleExpiring() {
    onlyExpiring = !onlyExpiring;
    load();
  }
}

/// UC05 - Quản lý tủ lạnh.
class FridgePage extends StatelessWidget {
  const FridgePage({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(create: (c) => FridgeViewModel(c.read<PantryService>())..load(), child: const _FridgeView());
}

class _FridgeView extends StatefulWidget {
  const _FridgeView();
  @override
  State<_FridgeView> createState() => _FridgeViewState();
}

class _FridgeViewState extends State<_FridgeView> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FridgeViewModel>();
    final session = context.watch<SessionService>();
    if (!session.hasGroup) {
      return Scaffold(appBar: AppBar(title: const Text('Tủ lạnh')), body: NeedGroupView(onCreateGroup: () => pushPage(context, const GroupPage())));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tủ lạnh'),
        actions: [IconButton(onPressed: vm.load, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (await pushPage<bool>(context, const FridgeFormPage()) == true) vm.load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Thêm vào tủ'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Tìm trong tủ lạnh'),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400), () {
                vm.query = v;
                vm.load();
              });
            },
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), children: [
            _chip('Tất cả (${vm.summary.total})', vm.location == null, () => vm.setLocation(null)),
            for (final l in StorageLocation.values) _chip(l.label, vm.location == l, () => vm.setLocation(l)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                label: Text('Sắp hết hạn (${vm.summary.expiring + vm.summary.expired})'),
                selected: vm.onlyExpiring,
                selectedColor: AppTheme.warning.withValues(alpha: 0.2),
                onSelected: (_) => vm.toggleExpiring(),
              ),
            ),
          ]),
        ),
        Expanded(
          child: AsyncBody(
            loading: vm.loading,
            error: vm.loadError,
            isEmpty: vm.items.isEmpty,
            onRetry: vm.load,
            emptyIcon: Icons.kitchen_outlined,
            emptyText: 'Tủ lạnh trống. Thêm thực phẩm hoặc xác nhận mua từ danh sách đi chợ.',
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) vm.loadMore();
                return false;
              },
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 90),
                itemCount: vm.items.length,
                itemBuilder: (_, i) => _itemTile(context, vm, vm.items[i]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()));

  Widget _itemTile(BuildContext context, FridgeViewModel vm, FridgeItem item) {
    final color = statusColor(item.status);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: item.status == 'fresh' ? Colors.grey.shade300 : color)),
      child: ListTile(
        leading: NetImage(item.food.imageUrl),
        title: Text(item.food.name),
        subtitle: Text('${item.location.label} · HSD ${fmtDate(item.useWithin)}'),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          NumText(fmtQtyUnit(item.quantity, item.food.unit.name)),
          const SizedBox(height: 2),
          Text(statusLabel(item.status, item.daysLeft), style: TextStyle(color: color, fontSize: 12)),
        ]),
        onTap: () async {
          await pushPage(context, FridgeItemPage(itemId: item.id));
          vm.load();
        },
      ),
    );
  }
}
