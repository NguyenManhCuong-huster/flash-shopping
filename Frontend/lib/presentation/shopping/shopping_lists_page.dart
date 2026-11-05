import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/session_service.dart';
import '../../application/shopping_service.dart';
import '../../data/models/shopping.dart';
import '../group/group_page.dart';
import '../shared/base_view_model.dart';
import '../shared/format.dart';
import '../shared/theme.dart';
import '../shared/widgets.dart';
import 'shopping_detail_page.dart';
import 'shopping_form_page.dart';

class ShoppingListsViewModel extends BaseViewModel {
  ShoppingListsViewModel(this._shopping);
  final ShoppingService _shopping;

  List<ShoppingList> lists = [];
  bool done = false;
  bool mine = false;
  int _page = 1;
  bool hasMore = false;

  Future<void> load() => runLoad(() async {
        _page = 1;
        final r = await _shopping.lists(done: done, assignedToMe: mine);
        lists = r.items;
        hasMore = r.hasMore;
      });

  Future<void> loadMore() async {
    if (!hasMore || loading) return;
    final r = await _shopping.lists(done: done, assignedToMe: mine, page: ++_page);
    lists = [...lists, ...r.items];
    hasMore = r.hasMore;
    notifyListeners();
  }

  void setDone(bool v) {
    done = v;
    load();
  }

  void toggleMine() {
    mine = !mine;
    load();
  }
}

/// UC03 - danh sách mua sắm của nhóm.
class ShoppingListsPage extends StatelessWidget {
  const ShoppingListsPage({super.key});

  @override
  Widget build(BuildContext context) =>
      ChangeNotifierProvider(create: (c) => ShoppingListsViewModel(c.read<ShoppingService>())..load(), child: const _ListsView());
}

class _ListsView extends StatelessWidget {
  const _ListsView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ShoppingListsViewModel>();
    final session = context.watch<SessionService>();
    if (!session.hasGroup) {
      return Scaffold(appBar: AppBar(title: const Text('Mua sắm')), body: NeedGroupView(onCreateGroup: () => pushPage(context, const GroupPage())));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Danh sách mua sắm'), actions: [IconButton(onPressed: vm.load, icon: const Icon(Icons.refresh))]),
      floatingActionButton: session.isLeader
          ? FloatingActionButton.extended(
              onPressed: () async {
                final id = await pushPage<int>(context, const ShoppingFormPage());
                if (id != null && context.mounted) {
                  await pushPage(context, ShoppingDetailPage(listId: id, openAddTasks: true));
                  vm.load();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Tạo danh sách'),
            )
          : null,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(children: [
            Expanded(
              child: SegmentedButton<bool>(
                segments: const [ButtonSegment(value: false, label: Text('Đang mở')), ButtonSegment(value: true, label: Text('Đã xong'))],
                selected: {vm.done},
                onSelectionChanged: (s) => vm.setDone(s.first),
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(label: const Text('Của tôi'), selected: vm.mine, onSelected: (_) => vm.toggleMine()),
          ]),
        ),
        Expanded(
          child: AsyncBody(
            loading: vm.loading,
            error: vm.loadError,
            isEmpty: vm.lists.isEmpty,
            onRetry: vm.load,
            emptyIcon: Icons.shopping_cart_outlined,
            emptyText: session.isLeader ? 'Chưa có danh sách. Bấm "Tạo danh sách" để bắt đầu.' : 'Chưa có danh sách nào. Trưởng nhóm sẽ tạo và phân công.',
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) vm.loadMore();
                return false;
              },
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 90),
                itemCount: vm.lists.length,
                itemBuilder: (_, i) => _card(context, vm, vm.lists[i], session),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _card(BuildContext context, ShoppingListsViewModel vm, ShoppingList l, SessionService session) {
    final mine = l.assignedTo?.id == session.user?.id;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await pushPage(context, ShoppingDetailPage(listId: l.id));
          vm.load();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(l.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              if (mine) const Pill('Giao cho tôi', color: AppTheme.warning),
            ]),
            const SizedBox(height: 4),
            Text('Ngày ${fmtIsoDate(l.date)} · ${l.assignedTo == null ? 'Chưa giao' : 'Người mua: ${l.assignedTo!.name}'}', style: const TextStyle(color: AppTheme.muted)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: LinearProgressIndicator(value: l.total == 0 ? 0 : l.bought / l.total, minHeight: 6, borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 10),
              NumText('${l.bought}/${l.total}'),
            ]),
          ]),
        ),
      ),
    );
  }
}
