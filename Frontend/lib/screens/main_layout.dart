import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/insight_service.dart';
import 'fridge/fridge_page.dart';
import 'meal/meal_plan_page.dart';
import 'notifications_page.dart';
import 'shopping/shopping_session_lists_page.dart';
import 'shared/widgets.dart';
import 'home_page.dart';
import 'setting_page.dart';
import '../utils/app_colors.dart';
import '../widgets/nav_bar.dart';

class MainScreenLayout extends StatefulWidget {
  const MainScreenLayout({super.key});
  @override
  State<MainScreenLayout> createState() => _MainScreenLayoutState();
}

class _MainScreenLayoutState extends State<MainScreenLayout> with WidgetsBindingObserver {
  int _selectedIndex = 0;
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

  void onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.emerald50,
      body: Stack(
        children: [
          // Nội dung các trang con lấp đầy màn hình
          IndexedStack(
            index: _selectedIndex,
            children: [
              HomePage(onNavigate: onItemTapped),
              const ShoppingSessionListPage(),
              const FridgePage(),
              const MealPlanPage(),
              const SettingPage(),
            ],
          ),
          // NavBar đè lên phần dưới của nội dung (overlay)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: NavBar(
              currentIndex: _selectedIndex,
              onTap: onItemTapped,
            ),
          ),
        ],
      ),
    );
  }
}
