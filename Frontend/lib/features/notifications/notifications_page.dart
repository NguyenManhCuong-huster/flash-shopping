import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../stats/insight_service.dart';
import 'misc.dart';
import '../fridge/fridge_item_page.dart';
import '../../core/utils/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/base_view_model.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/widgets_common.dart';

class NotificationsViewModel extends BaseViewModel {
  NotificationsViewModel(this._insight);
  final InsightService _insight;

  List<AppNotification> items = [];
  int _page = 1;
  bool hasMore = false;

  Future<void> load() => runLoad(() async {
        _page = 1;
        final r = await _insight.notifications();
        items = r.items;
        hasMore = r.hasMore;
      });

  Future<void> loadMore() async {
    if (!hasMore || loading) return;
    final r = await _insight.notifications(page: ++_page);
    items = [...items, ...r.items];
    hasMore = r.hasMore;
    notifyListeners();
  }

  Future<void> markAllRead() => runSave(() async {
        await _insight.markAllRead();
        await load();
      });

  Future<void> open(AppNotification n) => _insight.markRead(n);
}

/// UC06 - hộp thư nhắc hạn sử dụng. Chạm vào thông báo => kiểm tra quyền & mở chi tiết thực phẩm.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(create: (c) => NotificationsViewModel(c.read<InsightService>())..load(), child: const _View());
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotificationsViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Thông báo'), actions: [
        TextButton(onPressed: vm.items.any((n) => !n.read) ? () => runAction(context, vm.markAllRead) : null, child: const Text('Đọc tất cả')),
      ]),
      body: AsyncSection(
        loading: vm.loading,
        error: vm.loadError,
        isEmpty: vm.items.isEmpty,
        onRetry: vm.load,
        emptyText: 'Chưa có thông báo. Ứng dụng sẽ nhắc trước khi thực phẩm hết hạn 3 ngày.',
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) vm.loadMore();
            return false;
          },
          child: ListView.builder(
            itemCount: vm.items.length,
            itemBuilder: (_, i) {
              final n = vm.items[i];
              final expired = n.type == 'food_expired';
              return Container(
                color: n.read ? null : AppColor.primary.withValues(alpha: 0.05),
                child: ListTile(
                  leading: Icon(expired ? Icons.report_gmailerrorred : Icons.timer_outlined, color: expired ? AppColor.danger : AppColor.warning),
                  title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.bold)),
                  subtitle: Text('${n.body}\n${FormatUtils.relativeTime(n.createdAt)}'),
                  isThreeLine: true,
                  onTap: () async {
                    await vm.open(n);
                    final id = n.fridgeItemId;
                    // if (id != null && context.mounted) await pushPage(context, FridgeItemPage(fridgeItemId: id, fridgeItem: n.fridgeItem)); // TEMP_MOCK_START
                    vm.load();
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
