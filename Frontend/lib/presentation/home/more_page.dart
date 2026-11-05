import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/session_service.dart';
import '../admin/admin_page.dart';
import '../ai/ai_conversations_page.dart';
import '../food/foods_page.dart';
import '../group/group_page.dart';
import '../notification/notifications_page.dart';
import '../profile/profile_page.dart';
import '../recipe/recipes_page.dart';
import '../recipe/suggestions_page.dart';
import '../shared/theme.dart';
import '../shared/widgets.dart';
import '../stats/stats_page.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionService>();
    final user = session.user;
    Widget item(IconData icon, String title, Widget page, {String? subtitle}) => ListTile(
          leading: Icon(icon, color: AppTheme.primary),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => pushPage(context, page),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Thêm')),
      body: ListView(children: [
        ListTile(
          leading: NetImage(user?.imageUrl, circle: true, icon: Icons.person),
          title: Text(user?.name ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${user?.email ?? ''}${user?.username != null ? ' · @${user!.username}' : ''}'),
          onTap: () => pushPage(context, const ProfilePage()),
        ),
        const Divider(),
        item(Icons.menu_book_outlined, 'Công thức nấu ăn', const RecipesPage()),
        item(Icons.auto_awesome_outlined, 'Gợi ý món từ tủ lạnh', const SuggestionsPage()),
        item(Icons.egg_alt_outlined, 'Thực phẩm của nhóm', const FoodsPage(), subtitle: 'Danh mục, đơn vị, ảnh'),
        item(Icons.bar_chart, 'Thống kê mua & tiêu thụ', const StatsPage()),
        item(Icons.family_restroom, 'Nhóm gia đình', const GroupPage(),
            subtitle: session.hasGroup ? (session.isLeader ? 'Bạn là trưởng nhóm' : 'Bạn là thành viên') : 'Chưa có nhóm'),
        item(Icons.smart_toy_outlined, 'Trợ lý AI', const AiConversationsPage()),
        item(Icons.notifications_none, 'Thông báo', const NotificationsPage()),
        item(Icons.person_outline, 'Hồ sơ cá nhân', const ProfilePage()),
        if (session.isSystemAdmin) item(Icons.admin_panel_settings_outlined, 'Quản trị hệ thống', const AdminPage()),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: AppTheme.danger),
          title: const Text('Đăng xuất', style: TextStyle(color: AppTheme.danger)),
          onTap: () async {
            if (await confirmDialog(context, title: 'Đăng xuất', message: 'Bạn muốn đăng xuất khỏi thiết bị này?', confirmText: 'Đăng xuất')) {
              await session.logout();
            }
          },
        ),
      ]),
    );
  }
}
