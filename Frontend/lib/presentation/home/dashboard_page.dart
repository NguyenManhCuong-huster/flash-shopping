import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/admin_ai_service.dart';
import '../../application/insight_service.dart';
import '../../application/meal_service.dart';
import '../../application/pantry_service.dart';
import '../../application/session_service.dart';
import '../../application/shopping_service.dart';
import '../../data/models/ai.dart';
import '../../data/models/common.dart';
import '../../data/models/food.dart';
import '../../data/models/meal_recipe.dart';
import '../../data/models/shopping.dart';
import '../../application/validation/validators.dart';
import '../ai/ai_chat_page.dart';
import '../ai/ai_conversations_page.dart';
import '../fridge/fridge_item_page.dart';
import '../group/group_page.dart';
import '../notification/notifications_page.dart';
import '../shared/base_view_model.dart';
import '../shared/format.dart';
import '../shared/theme.dart';
import '../shared/widgets.dart';
import '../shopping/shopping_detail_page.dart';

class DashboardViewModel extends BaseViewModel {
  DashboardViewModel(this._pantry, this._meals, this._shopping, this._ai, this._session);
  final PantryService _pantry;
  final MealService _meals;
  final ShoppingService _shopping;
  final AiService _ai;
  final SessionService _session;

  FridgeSummary summary = const FridgeSummary();
  List<FridgeItem> expiring = [];
  List<MealPlan> todayMeals = [];
  List<ShoppingList> myLists = [];
  List<AiSuggestion> suggestions = [];

  Future<void> load() => runLoad(() async {
        if (!_session.hasGroup) return;
        final today = DateTime.now();
        final results = await Future.wait([
          _pantry.fridge(expiringDays: 3),
          _meals.week(today),
          _shopping.lists(assignedToMe: true),
          if (_session.isLeader) _ai.suggestions(),
        ]);
        final fridge = results[0] as FridgeResult;
        summary = fridge.summary;
        expiring = fridge.items.take(5).toList();
        todayMeals = (results[1] as List<MealPlan>).where((m) => m.date == isoDate(today)).toList();
        myLists = (results[2] as Paged<ShoppingList>).items;
        suggestions = results.length > 3 ? results[3] as List<AiSuggestion> : [];
      });

  Future<int> accept(AiSuggestion s) => runSave(() => _ai.acceptSuggestion(s));
  Future<void> dismiss(AiSuggestion s) => runSave(() async {
        await _ai.dismissSuggestion(s);
        suggestions.remove(s);
      });
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (c) => DashboardViewModel(c.read<PantryService>(), c.read<MealService>(), c.read<ShoppingService>(), c.read<AiService>(), c.read<SessionService>())..load(),
        child: _DashboardView(onNavigate: onNavigate),
      );
}

class _DashboardView extends StatelessWidget {
  const _DashboardView({required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionService>();
    final vm = context.watch<DashboardViewModel>();
    final unread = context.watch<InsightService>().unread;
    final user = session.user;

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Xin chào, ${user?.name ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
          if (user?.group != null) Text(user!.group!.name, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
        ]),
        actions: [
          IconButton(tooltip: 'Trợ lý AI', icon: const Icon(Icons.smart_toy_outlined), onPressed: () => pushPage(context, const AiConversationsPage())),
          IconButton(
            tooltip: 'Thông báo',
            icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.notifications_none)),
            onPressed: () async {
              await pushPage(context, const NotificationsPage());
              vm.load();
            },
          ),
        ],
      ),
      body: !session.hasGroup
          ? NeedGroupView(onCreateGroup: () async {
              await pushPage(context, const GroupPage());
              vm.load();
            })
          : AsyncBody(
              loading: vm.loading,
              error: vm.loadError,
              isEmpty: false,
              onRetry: vm.load,
              child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                _summaryRow(context, vm),
                if (vm.suggestions.isNotEmpty) ...[
                  const SectionTitle('Gợi ý từ trợ lý AI'),
                  for (final s in vm.suggestions) _suggestionCard(context, vm, s),
                ],
                SectionTitle('Sắp hết hạn', trailing: TextButton(onPressed: () => onNavigate(2), child: const Text('Tủ lạnh'))),
                if (vm.expiring.isEmpty) const _Hint('Không có thực phẩm nào sắp hết hạn trong 3 ngày tới.'),
                for (final item in vm.expiring)
                  Card(
                    child: ListTile(
                      leading: NetImage(item.food.imageUrl),
                      title: Text(item.food.name),
                      subtitle: Text('${fmtQtyUnit(item.quantity, item.food.unit.name)} · HSD ${fmtDate(item.useWithin)}'),
                      trailing: Pill(statusLabel(item.status, item.daysLeft), color: statusColor(item.status)),
                      onTap: () async {
                        await pushPage(context, FridgeItemPage(itemId: item.id));
                        vm.load();
                      },
                    ),
                  ),
                SectionTitle('Bữa ăn hôm nay', trailing: TextButton(onPressed: () => onNavigate(3), child: const Text('Lịch bữa ăn'))),
                if (vm.todayMeals.isEmpty) const _Hint('Chưa lên kế hoạch cho hôm nay.'),
                for (final m in vm.todayMeals)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.restaurant, color: AppTheme.primary),
                      title: Text(m.recipeName ?? m.food.name),
                      subtitle: Text(m.meal.label),
                    ),
                  ),
                SectionTitle('Danh sách được giao cho tôi', trailing: TextButton(onPressed: () => onNavigate(1), child: const Text('Mua sắm'))),
                if (vm.myLists.isEmpty) const _Hint('Bạn không có danh sách mua sắm nào đang mở.'),
                for (final l in vm.myLists)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.shopping_cart, color: AppTheme.primary),
                      title: Text(l.name),
                      subtitle: Text('Ngày ${fmtIsoDate(l.date)} · đã mua ${l.bought}/${l.total}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await pushPage(context, ShoppingDetailPage(listId: l.id));
                        vm.load();
                      },
                    ),
                  ),
              ]),
            ),
    );
  }

  Widget _summaryRow(BuildContext context, DashboardViewModel vm) {
    Widget tile(String label, int value, Color color, IconData icon) => Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Icon(icon, color: color),
                const SizedBox(height: 4),
                Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                Text(label, style: const TextStyle(fontSize: 12)),
              ]),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(children: [
        tile('Trong tủ lạnh', vm.summary.total, AppTheme.primary, Icons.kitchen),
        tile('Sắp hết hạn', vm.summary.expiring, AppTheme.warning, Icons.timer_outlined),
        tile('Đã hết hạn', vm.summary.expired, AppTheme.danger, Icons.report_gmailerrorred),
      ]),
    );
  }

  Widget _suggestionCard(BuildContext context, DashboardViewModel vm, AiSuggestion s) => Card(
        child: ListTile(
          leading: const Icon(Icons.lightbulb_outline, color: AppTheme.warning),
          title: Text(s.title),
          subtitle: Row(children: [
            TextButton(
              onPressed: () async {
                final convId = await runAction(context, () => vm.accept(s));
                if (convId != null && context.mounted) {
                  await pushPage(context, AiChatPage(conversationId: convId));
                  vm.load();
                }
              },
              child: const Text('Xem & xác nhận'),
            ),
            TextButton(onPressed: () => runAction(context, () => vm.dismiss(s)), child: const Text('Bỏ qua')),
          ]),
        ),
      );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Text(text, style: const TextStyle(color: AppTheme.muted)));
}
