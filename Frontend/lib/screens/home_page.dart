import 'package:di_cho_tien_loi/widgets/buttons/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../application/admin_ai_service.dart';
import '../application/insight_service.dart';
import '../application/meal_service.dart';
import '../application/pantry_service.dart';
import '../application/session_service.dart';
import '../application/shopping_service.dart';
import '../data/models/ai.dart';
import '../data/models/common.dart';
import '../data/models/food.dart';
import '../data/models/meal_recipe.dart';
import '../data/models/shopping.dart';
import '../data/models/user.dart';
import '../application/validation/validators.dart';
import 'ai/ai_chat_page.dart';
import 'ai/ai_conversations_page.dart';
import 'notifications_page.dart';
import 'group_page.dart';
import '../utils/app_colors.dart';
import '../utils/date_time_utils.dart';
import 'shared/base_view_model.dart';
import '../utils/theme.dart';
import '../utils/mock_data.dart';
import 'shared/widgets.dart';
import '../widgets/badge_widget.dart';
import '../widgets/buttons/outline_button.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/buttons/icon_button_widget.dart';
import '../modals/invite_member_modal.dart';

class HomeViewModel extends BaseViewModel {
  HomeViewModel(
    this._pantry,
    this._meals,
    this._shopping,
    this._ai,
    this._session,
  );
  final PantryService _pantry;
  final MealService _meals;
  final ShoppingService _shopping;
  final AiService _ai;
  final SessionService _session;
  // Lấy userId từ session để load dữ liệu cá nhân.
  int userId = 1;
  FridgeSummary summary = const FridgeSummary();
  List<FridgeItem> expiring = MockData.getFridgeItemsExpiringSoon();
  List<MealPlan> todayMeals = [];
  List<ShoppingSession> myLists = [];
  List<AiSuggestion> suggestions = [];

  Future<void> load() => runLoad(() async {
    if (!_session.hasGroup) return;
    final today = DateTime.now();
    final results = await Future.wait([
      _pantry.fridge(expiringDays: 3),
      _meals.week(today),
      _shopping.sessions(assignedToMe: true),
      if (_session.isLeader) _ai.suggestions(),
    ]);
    final fridge = results[0] as FridgeResult;
    summary = fridge.summary;
    expiring = fridge.items.take(5).toList();
    todayMeals = (results[1] as List<MealPlan>)
        .where((m) => m.date == isoDate(today))
        .toList();
    myLists = (results[2] as Paged<ShoppingSession>).items;
    suggestions = results.length > 3 ? results[3] as List<AiSuggestion> : [];
  });

  Future<int> accept(AiSuggestion s) => runSave(() => _ai.acceptSuggestion(s));
  Future<void> dismiss(AiSuggestion s) => runSave(() async {
    await _ai.dismissSuggestion(s);
    suggestions.remove(s);
  });
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (c) => HomeViewModel(
      c.read<PantryService>(),
      c.read<MealService>(),
      c.read<ShoppingService>(),
      c.read<AiService>(),
      c.read<SessionService>(),
    )..load(),
    child: _HomeView(onNavigate: onNavigate),
  );
}

class _HomeView extends StatelessWidget {
  const _HomeView({required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionService>();
    final vm = context.watch<HomeViewModel>();
    final unread = context.watch<InsightService>().unread;
    // final user = session.user;
    final user = MockData.getCurrentUser();
    return Scaffold(
      // extendBody: true,
      backgroundColor: AppColor.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 92),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, user, unread, vm),
              const SizedBox(height: 16),
              _buildWelcomeCard(context, user),
              const SizedBox(height: 16),
              _buildExpiringFoodWarningCard(),
              const SizedBox(height: 16),
              // if (session.hasGroup) ...[
              //   _buildMembersSection(context),
              //   const SizedBox(height: 16),
              // ],
              _buildStatsCardSection(),
              if (vm.suggestions.isNotEmpty) ...[
                const SectionTitle('Gợi ý từ trợ lý AI'),
                for (final s in vm.suggestions) _suggestionCard(context, vm, s),
              ],
              // _buildExpiringFoodsSection(),
              const SizedBox(height: 16),
              _buildTodayMealsSection(),
              const SizedBox(height: 16),
              _buildShoppingSessionsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    User? user,
    int unread,
    HomeViewModel vm,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Image.asset(
            'assets/images/logo.png',
            height: 48,
            fit: BoxFit.contain,
          ),
          Row(
            children: [
              IconButtonWidget(
                icon: LucideIcons.botMessageSquare,
                onTap: () => pushPage(context, const AiConversationsPage()),
              ),
              const SizedBox(width: 8),
              IconButtonWidget(
                icon: LucideIcons.bell,
                onTap: () async {
                  await pushPage(context, const NotificationsPage());
                  vm.load();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context, User user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColor.gray300,
            // backgroundImage: NetworkImage(user.imageUrl),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateTimeUtils.formatWeekdayWithDate(DateTime.now()),
                  style: TextStyle(
                    color: AppColor.gray600,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Xin chào, ${user.name}',
                  style: const TextStyle(
                    color: AppColor.gray800,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiringFoodWarningCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColor.amber50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColor.amber200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.alertTriangle,
                      size: 16,
                      color: AppColor.amber500,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Lưu ý tủ lạnh',
                      style: TextStyle(
                        color: AppColor.amber500,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text(
                      'Có',
                      style: TextStyle(
                        color: AppColor.gray800,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      MockData.getFridgeItemsExpiringSoon().length.toString(),
                      style: const TextStyle(
                        color: AppColor.amber500,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'thực phẩm sắp hết hạn.',
                      style: TextStyle(
                        color: AppColor.gray800,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PrimaryButton(
            saving: false,
            onPressed: () => onNavigate(2),
            backgroundColor: AppColor.amber500,
            label: 'Xem ngay',
            icon: LucideIcons.arrowRight,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final Group group = MockData.getCurrentGroup();
    final Member leader = group.members.firstWhere((m) => m.role == 'admin');
    final User currentUser = MockData.getCurrentUser();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColor.emerald500,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColor.gray400.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  group.name,
                  style: const TextStyle(
                    color: AppColor.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => pushPage(context, const GroupPage()),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Quản lý nhóm',
                    style: TextStyle(
                      color: AppColor.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(16)),
              color: AppColor.gray50,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          height: 36,
                          width: group.members.length > 5
                              ? 5 * 24.0 + 12
                              : (group.members.isEmpty
                                    ? 0
                                    : (group.members.length - 1) * 24.0 + 36),
                          child: Stack(
                            children: List.generate(
                              group.members.length > 5
                                  ? 5
                                  : group.members.length,
                              (index) {
                                return Positioned(
                                  left: index * 24.0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppColor.gray200,
                                      // backgroundImage: NetworkImage(member.imageUrl),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        if (group.members.length > 5) ...[
                          const SizedBox(width: 8),
                          Text(
                            '+${group.members.length - 5} thành viên',
                            style: const TextStyle(
                              color: AppColor.gray600,
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${group.members.length.toString()} thành viên',
                      style: const TextStyle(
                        color: AppColor.gray600,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const Divider(
                  height: 17,
                  color: AppColor.gray200,
                  thickness: 1,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Trưởng nhóm: ',
                      style: TextStyle(
                        color: AppColor.gray600,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      leader.name,
                      style: TextStyle(
                        color: AppColor.gray800,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Ngày tạo: ',
                      style: TextStyle(
                        color: AppColor.gray600,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      '11/11/2026',
                      style: TextStyle(
                        color: AppColor.gray800,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (currentUser.groupId == null) ...[
                  PrimaryButton(
                    saving: false,
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => InviteMemberModal(
                          currentMemberIds: group.members
                              .map((m) => m.id)
                              .toList(),
                        ),
                        backgroundColor: AppColor.gray100,
                      );
                    },
                    backgroundColor: AppColor.amber500,
                    label: 'Tạo nhóm mới',
                  ),
                  const SizedBox(height: 8),
                  OutlineButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => InviteMemberModal(
                          currentMemberIds: group.members
                              .map((m) => m.id)
                              .toList(),
                        ),
                        backgroundColor: AppColor.gray100,
                      );
                    },
                    backgroundColor: AppColor.amber50,
                    label: 'Tham gia nhóm bằng mã',
                    labelColor: AppColor.amber500,
                  ),
                ] else if (currentUser.groupRole == 'admin')
                  OutlineButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => InviteMemberModal(
                          currentMemberIds: group.members
                              .map((m) => m.id)
                              .toList(),
                        ),
                        backgroundColor: AppColor.gray100,
                      );
                    },
                    backgroundColor: AppColor.amber50,
                    label: 'Thêm thành viên',
                    labelColor: AppColor.amber500,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCardSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildStatCard(
            LucideIcons.shoppingBag,
            AppColor.emerald100,
            'Thực phẩm cần mua',
            MockData.getPendingShoppingItems().length,
            AppColor.emerald500,
            () {},
          ),
          const SizedBox(width: 8),
          _buildStatCard(
            LucideIcons.cookingPot,
            AppColor.amber100,
            'Bữa ăn hôm nay',
            MockData.getMealPlansByDate(DateTime.now().toString()).length,
            AppColor.amber500,
            () {},
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    IconData icon,
    Color backgroundColor,
    String title,
    int value,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: AppColor.gray50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColor.gray200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                color: AppColor.gray600,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Xem chi tiết',
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(LucideIcons.arrowRight, size: 16, color: color),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberItem(Member member) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          // backgroundImage: NetworkImage(memberAvatarUrl),
          backgroundColor: AppColor.gray300,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                member.name,
                style: const TextStyle(
                  color: AppColor.gray600,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
              if (member.isLeader)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColor.amber100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.crown,
                    color: AppColor.amber500,
                    size: 16,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExpiringFoodsSection() {
    // final List<FridgeItem> items = vm.expiring;
    List<FridgeItem> items = MockData.getFridgeItemsExpiringSoon();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sắp hết hạn',
                style: TextStyle(
                  color: AppColor.gray800,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () => onNavigate(2),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Xem tất cả',
                  style: TextStyle(
                    color: AppColor.emerald500,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // if (vm.expiring.isEmpty)
          if (items.isEmpty)
            const EmptyStateWidget(
              message: 'Không có thực phẩm nào sắp hết hạn trong 3 ngày tới.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              scrollDirection: Axis.vertical,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemCount: items.length > 5 ? 5 : items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _buildExpiringFoodItem(item);
              },
            ),
          // vm.expiring.isEmpty
          //     ? const EmptyStateWidget(
          //         message:
          //             'Không có thực phẩm nào sắp hết hạn trong 3 ngày tới.',
          //       )
          //     : ListView.separated(
          //         scrollDirection: Axis.vertical,
          //         separatorBuilder: (context, index) =>
          //             const SizedBox(height: 16),
          //         itemCount: items.length,
          //         itemBuilder: (context, index) {
          //           final item = items[index];
          //           return _buildExpiringFoodItem(item);
          //         },
          //       ),
          // for (final item in vm.expiring)
          //   Card(
          //     child: ListTile(
          //       leading: NetImage(item.food.imageUrl),
          //       title: Text(item.food.name),
          //       subtitle: Text(
          //         '${fmtQtyUnit(item.quantity, item.food.unit.name)} · HSD ${fmtDate(item.useWithin)}',
          //       ),
          //       trailing: Pill(
          //         statusLabel(item.status, item.daysLeft),
          //         color: statusColor(item.status),
          //       ),
          //       onTap: () async {
          //         await pushPage(context, FridgeItemPage(itemId: item.id));
          //         vm.load();
          //       },
          //     ),
          //   ),
        ],
      ),
    );
  }

  Widget _buildExpiringFoodItem(FridgeItem item) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColor.gray50,
        border: Border.all(color: AppColor.gray200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColor.gray100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(LucideIcons.info, size: 24, color: AppColor.gray400),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.food.name,
                      style: const TextStyle(
                        color: AppColor.gray800,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${item.quantity.toString()} ${item.food.unit.name} · HSD ${DateTimeUtils.formatDate(item.useWithin)}',
                      style: const TextStyle(
                        color: AppColor.gray500,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                BadgeWidget(
                  label: item.status.label,
                  badgeColor: item.status.badgeColor,
                  labelColor: item.status.labelColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayMealsSection() {
    final List<MealPlan> todayMeals = MockData.getMealPlansByDate(
      DateTime.now().toString().split(' ')[0],
    );
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Bữa ăn hôm nay',
                style: TextStyle(
                  color: AppColor.gray800,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () => onNavigate(3),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Lịch bữa ăn',
                  style: TextStyle(
                    color: AppColor.emerald500,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (todayMeals.isEmpty)
            const EmptyStateWidget(message: 'Chưa lên kế hoạch cho hôm nay.')
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              scrollDirection: Axis.vertical,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemCount: todayMeals.length,
              itemBuilder: (context, index) {
                final meal = todayMeals[index];
                return _buildTodayMealItem(meal);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTodayMealItem(MealPlan meal) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColor.gray50,
        border: Border.all(color: AppColor.gray200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColor.gray100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(LucideIcons.info, size: 24, color: AppColor.gray400),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  meal.recipeName ?? meal.food.name,
                  style: TextStyle(
                    color: AppColor.gray800,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                BadgeWidget(
                  label: meal.meal.label,
                  badgeColor: meal.meal.badgeColor,
                  labelColor: meal.meal.labelColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShoppingSessionsSection() {
    final ShoppingSession myLists = MockData.getShoppingSessionById(1);
    final List<ShoppingItem> shoppingItems = myLists.shoppingItems;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Danh sách mua sắm',
                style: TextStyle(
                  color: AppColor.gray800,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () => onNavigate(1),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Xem tất cả',
                  style: TextStyle(
                    color: AppColor.emerald500,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (shoppingItems.isEmpty)
            const EmptyStateWidget(
              message: 'Bạn không có danh sách mua sắm nào đang mở.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              scrollDirection: Axis.vertical,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemCount: shoppingItems.length > 5 ? 5 : shoppingItems.length,
              itemBuilder: (context, index) {
                final item = shoppingItems[index];
                return _buildShoppingItem(item);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildShoppingItem(ShoppingItem item) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColor.gray50,
        border: Border.all(color: AppColor.gray200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColor.gray100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(LucideIcons.info, size: 24, color: AppColor.gray400),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item.food.name,
                  style: TextStyle(
                    color: AppColor.gray800,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${item.quantity.toString()} ${item.food.unit.name}',
                  style: TextStyle(
                    color: AppColor.gray500,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _suggestionCard(
    BuildContext context,
    HomeViewModel vm,
    AiSuggestion s,
  ) => Card(
    child: ListTile(
      leading: const Icon(Icons.lightbulb_outline, color: AppColor.warning),
      title: Text(s.title),
      subtitle: Row(
        children: [
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
          TextButton(
            onPressed: () => runAction(context, () => vm.dismiss(s)),
            child: const Text('Bỏ qua'),
          ),
        ],
      ),
    ),
  );
}
