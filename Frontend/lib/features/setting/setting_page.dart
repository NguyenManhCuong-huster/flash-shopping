import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../user/user.dart';
import '../auth/session_service.dart';
import '../admin/admin_page.dart';
import '../ai/ai_conversations_page.dart';
import '../food/foods_page.dart';
import '../group/group_page.dart';
import '../meal/recipes_page.dart';
import '../meal/suggestions_page.dart';
import '../../core/utils/app_colors.dart';
import '../../core/widgets/buttons/outline_button.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../user/profile_page.dart';
import '../../core/widgets/widgets_common.dart';
import '../stats/stats_page.dart';
import '../auth/login_page.dart';

class SettingPage extends StatelessWidget {
  const SettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionService>();
    final user = session.user;
    if (user == null) {
      return const LoginPage();
    }

    return Scaffold(
      backgroundColor: AppColor.transparent,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 92),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildHeader(),
              const SizedBox(height: 16),
              _buildProfileSection(context, user),
              const SizedBox(height: 16),
              _buildSettingsSection1(context),
              const SizedBox(height: 16),
              _buildSettingsSection2(context),
              const SizedBox(height: 16),
              _buildSettingsSection3(context),
              if (session.isSystemAdmin) ...[
                const SizedBox(height: 16),
                _buildSettingItem(
                  context,
                  Icons.admin_panel_settings_outlined,
                  'Quản trị hệ thống',
                  const AdminPage(),
                ),
              ],
              const SizedBox(height: 16),
              _buildLogoutButton(context, session),
              // Container(
              //   margin: const EdgeInsets.symmetric(horizontal: 16),
              //   child: Column(
              //     children: [
              //       const Divider(
              //         height: 33,
              //         thickness: 1,
              //         color: AppColor.gray200,
              //       ),
              //       OutlineButton(
              //         onPressed: () async {
              //           if (await confirmDialog(
              //             context: context,
              //             icon: LucideIcons.logOut,
              //             title: 'Đăng xuất',
              //             message: 'Bạn muốn đăng xuất khỏi thiết bị này?',
              //             confirmText: 'Đăng xuất',
              //           )) {
              //             await session.logout();
              //           }
              //         },
              //         backgroundColor: AppColor.red500,
              //         label: 'Đăng xuất',
              //         labelColor: AppColor.white,
              //       ),
              //     ],
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: const Text(
        'Cài đặt',
        style: TextStyle(
          color: AppColor.primary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context, User user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => pushPage(context, const ProfilePage()),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColor.white,
            border: Border.all(color: AppColor.gray200),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColor.gray400.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColor.gray200,
                child: Text(
                  user.name.isNotEmpty ? user.name[0] : '',
                  style: const TextStyle(
                    color: AppColor.gray500,
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        color: AppColor.gray800,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      user.email,
                      style: const TextStyle(
                        color: AppColor.gray600,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.penLine,
                color: AppColor.gray400,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSection1(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nhóm và dữ liệu',
            style: TextStyle(
              color: AppColor.gray600,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColor.white,
              border: Border.all(color: AppColor.gray200),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColor.gray400.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildSettingItem(
                  context,
                  LucideIcons.userGroup,
                  'Nhóm gia đình',
                  const GroupPage(),
                ),
                const Divider(
                  height: 17,
                  thickness: 1,
                  color: AppColor.gray200,
                ),
                _buildSettingItem(
                  context,
                  LucideIcons.chartPie,
                  'Thống kê & báo cáo',
                  const StatsPage(),
                ),
                const Divider(
                  height: 17,
                  thickness: 1,
                  color: AppColor.gray200,
                ),
                _buildSettingItem(
                  context,
                  LucideIcons.bot,
                  'Trợ lý AI',
                  const AiConversationsPage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection2(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mua sắm và bữa ăn',
            style: TextStyle(
              color: AppColor.gray600,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColor.white,
              border: Border.all(color: AppColor.gray200),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColor.gray400.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildSettingItem(
                  context,
                  LucideIcons.groceries,
                  'Thực phẩm của nhóm',
                  const FoodsPage(),
                ),
                const Divider(
                  height: 17,
                  thickness: 1,
                  color: AppColor.gray200,
                ),
                _buildSettingItem(
                  context,
                  LucideIcons.bookOpenText,
                  'Công thức nấu ăn',
                  const RecipesPage(),
                ),
                const Divider(
                  height: 17,
                  thickness: 1,
                  color: AppColor.gray200,
                ),
                _buildSettingItem(
                  context,
                  LucideIcons.squareSparkles,
                  'Gợi ý món từ tủ lạnh',
                  const SuggestionsPage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection3(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cài đặt khác',
            style: TextStyle(
              color: AppColor.gray600,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColor.white,
              border: Border.all(color: AppColor.gray200),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColor.gray400.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildSettingItem(
                  context,
                  LucideIcons.palette,
                  'Giao diện',
                  const GroupPage(),
                ),
                const Divider(
                  height: 17,
                  thickness: 1,
                  color: AppColor.gray200,
                ),
                _buildSettingItem(
                  context,
                  LucideIcons.bell,
                  'Thông báo',
                  const GroupPage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context,
    IconData icon,
    String title,
    Widget page,
  ) {
    return Row(
      children: [
        Icon(icon, size: 24, color: AppColor.emerald500),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: AppColor.gray800,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        IconButton(
          icon: Icon(
            LucideIcons.chevronRight,
            size: 24,
            color: AppColor.gray400,
          ),
          onPressed: () => pushPage(context, page),
        ),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context, SessionService session) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: OutlineButton(
        onPressed: () async {
          if (await confirmDialog(
            context: context,
            icon: LucideIcons.logOut,
            title: 'Đăng xuất',
            message: 'Bạn muốn đăng xuất khỏi thiết bị này?',
            confirmText: 'Đăng xuất',
          )) {
            await session.logout();
            if (context.mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            }
          }
        },
        backgroundColor: AppColor.red500,
        label: 'Đăng xuất',
        labelColor: AppColor.white,
      ),
    );
  }
}
