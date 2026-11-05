import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/insight_service.dart';
import '../fridge/fridge_page.dart';
import '../meal/meal_plan_page.dart';
import '../notification/notifications_page.dart';
import '../shopping/shopping_lists_page.dart';
import '../shared/widgets.dart';
import 'dashboard_page.dart';
import 'more_page.dart';

/// Khung chính: thanh điều hướng dưới, các tab giữ trạng thái (IndexedStack).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  late final InsightService _insight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _insight = context.read<InsightService>();
    _insight.newArrivals.addListener(_onNewNotifications);
    _insight.startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _insight.newArrivals.removeListener(_onNewNotifications);
    _insight.stopPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _insight.checkNow();
  }

  void _onNewNotifications() {
    final n = _insight.newArrivals.value;
    if (n <= 0 || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Bạn có $n thông báo nhắc hạn sử dụng mới'),
      action: SnackBarAction(label: 'Xem', onPressed: () => pushPage(context, const NotificationsPage())),
    ));
    _insight.newArrivals.value = 0;
  }

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: [
        DashboardPage(onNavigate: _go),
        const ShoppingListsPage(),
        const FridgePage(),
        const MealPlanPage(),
        const MorePage(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Trang chủ'),
          NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), selectedIcon: Icon(Icons.shopping_cart), label: 'Mua sắm'),
          NavigationDestination(icon: Icon(Icons.kitchen_outlined), selectedIcon: Icon(Icons.kitchen), label: 'Tủ lạnh'),
          NavigationDestination(icon: Icon(Icons.restaurant_menu_outlined), selectedIcon: Icon(Icons.restaurant_menu), label: 'Bữa ăn'),
          NavigationDestination(icon: Icon(Icons.menu), label: 'Thêm'),
        ],
      ),
    );
  }
}
