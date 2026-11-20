import 'package:di_cho_tien_loi/core/widgets/buttons/outline_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../ai/admin_ai_service.dart';
import '../stats/insight_service.dart';
import '../meal/meal_service.dart';
import '../food/food_service.dart';
import '../auth/session_service.dart';
import '../shopping/shopping_service.dart';
import '../ai/ai.dart';
import '../food/food.dart';
import '../meal/meal_recipe.dart';
import '../shopping/shopping.dart';
import '../user/user.dart';
import '../ai/ai_chat_page.dart';
import '../ai/ai_conversations_page.dart';
import '../notifications/notifications_page.dart';
import '../../core/utils/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/utils/mock_data.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/badge_widget.dart';
import '../../core/widgets/buttons/icon_button_widget.dart';
import '../../core/widgets/buttons/primary_button.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/stat_card.dart';
import '../../core/widgets/widgets_common.dart';
import 'home_view_model.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (c) => HomeViewModel(
      c.read<FoodService>(),
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
    final user = session.user;
    final suggestions = MockData.getAiSuggestions();
    final todayMeals = MockData.getMealPlansByDate(DateTime.now());
    final shoppingItems = MockData.getPendingShoppingItems();
    // final user = MockData.getCurrentUser();
    return Scaffold(
      // extendBody: true,
      backgroundColor: AppColor.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 92),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildHeader(context, unread, vm),
              const SizedBox(height: 16),
              _buildWelcomeCard(context, user),
              const SizedBox(height: 16),
              _buildExpiringFoodWarningCard(),
              const SizedBox(height: 16),
              _buildStatsCardSection(),
              const SizedBox(height: 16),
              _buildAiSuggestionsSection(vm, suggestions),
              // _buildExpiringFoodsSection(),
              const SizedBox(height: 16),
              _buildTodayMealsSection(vm, todayMeals),
              const SizedBox(height: 16),
              _buildShoppingItemsSection(vm, shoppingItems),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int unread, HomeViewModel vm) {
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

  Widget _buildWelcomeCard(BuildContext context, User? user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: user?.imageUrl != null
                ? NetworkImage(user!.imageUrl!)
                : null,
            backgroundColor: AppColor.gray200,
            child: user?.imageUrl == null
                ? Text(
                    user != null && user.name.isNotEmpty ? user.name[0] : '',
                    style: const TextStyle(
                      color: AppColor.gray500,
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  FormatUtils.formatWeekdayWithDate(DateTime.now()),
                  style: TextStyle(
                    color: AppColor.gray600,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user != null ? 'Xin chào, ${user.name}' : 'Xin chào, bạn',
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

  Widget _buildStatsCardSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: StatCard(
              icon: LucideIcons.shoppingCart,
              value: '${MockData.getPendingShoppingItems().length} món',
              title: 'Cần mua',
              subtitle: 'Vui lòng mua ngay',
              color: AppColor.blue500,
              onTap: () => onNavigate(1),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: StatCard(
              icon: LucideIcons.cookingPot,
              value:
                  '${MockData.getMealPlansByDate(DateTime.now()).length} món',
              title: 'Bữa ăn hôm nay',
              subtitle: 'Xem chi tiết bữa ăn dự kiến',
              color: AppColor.amber500,
              onTap: () => onNavigate(3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiSuggestionsSection(
    HomeViewModel vm,
    List<AiSuggestion> suggestions,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Gợi ý từ trợ lý AI'),
          const SizedBox(height: 8),
          AsyncSection(
            loading: vm.loading,
            error: null,
            isEmpty: suggestions.isEmpty,
            onRetry: () => vm.load(),
            emptyText: 'Bạn chưa có gợi ý nào từ trợ lý AI.',
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              scrollDirection: Axis.vertical,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemCount: suggestions.length > 5 ? 5 : suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = suggestions[index];
                return _buildAiSuggestionItem(context, vm, suggestion);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiSuggestionItem(
    BuildContext context,
    HomeViewModel vm,
    AiSuggestion suggestion,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColor.blue50,
        border: Border.all(color: AppColor.blue200),
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
          Row(
            children: [
              const Icon(
                LucideIcons.sparkles,
                color: AppColor.blue500,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  suggestion.title,
                  style: const TextStyle(
                    color: AppColor.gray800,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              BadgeWidget(
                label: suggestion.type.label,
                badgeColor: suggestion.type.badgeColor,
                labelColor: suggestion.type.color,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlineButton(
                  onPressed: () => runAction(context, () => vm.dismiss(suggestion)),
                  backgroundColor: AppColor.red50,
                  label: 'Bỏ qua',
                  labelColor: AppColor.red500,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlineButton(
                  onPressed: () async {
                    final convId = await runAction(
                      context,
                      () => vm.accept(suggestion),
                    );
                    if (convId != null && context.mounted) {
                      await pushPage(
                        context,
                        AiChatPage(conversationId: convId),
                      );
                      vm.load();
                    }
                  },
                  backgroundColor: AppColor.blue500,
                  label: 'Xem & xác nhận',
                  labelColor: AppColor.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayMealsSection(HomeViewModel vm, List<MealPlan> todayMeals) {
    final List<MealPlan> todayMeals = MockData.getMealPlansByDate(
      DateTime.now(),
    );
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('Bữa ăn hôm nay', onPress: () => onNavigate(3)),
          const SizedBox(height: 8),
          AsyncSection(
            loading: vm.loading,
            error: vm.loadError,
            isEmpty: todayMeals.isEmpty,
            onRetry: () => vm.load(),
            emptyText: 'Bạn chưa lên kế hoạch bữa ăn hôm nay.',
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              scrollDirection: Axis.vertical,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemCount: todayMeals.length,
              itemBuilder: (context, index) {
                final meal = todayMeals[index];
                return _buildTodayMealItemCard(meal);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayMealItemCard(MealPlan meal) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColor.white,
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
                  meal.name,
                  style: TextStyle(
                    color: AppColor.gray800,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                BadgeWidget(
                  label: meal.mealPeriod.label,
                  badgeColor: meal.mealPeriod.badgeColor,
                  labelColor: meal.mealPeriod.labelColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShoppingItemsSection(
    HomeViewModel vm,
    List<ShoppingItem> shoppingItems,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('Thực phẩm cần mua', onPress: () => onNavigate(1)),
          const SizedBox(height: 8),
          AsyncSection(
            loading: vm.loading,
            error: null,
            isEmpty: shoppingItems.isEmpty,
            onRetry: () => vm.load(),
            emptyText:
                'Bạn chưa có thực phẩm cần mua. Hãy thêm vào danh sách mua sắm.',
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              scrollDirection: Axis.vertical,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemCount: shoppingItems.length > 5 ? 5 : shoppingItems.length,
              itemBuilder: (context, index) {
                final item = shoppingItems[index];
                return _buildShoppingItemCard(item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShoppingItemCard(ShoppingItem item) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColor.white,
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
}
