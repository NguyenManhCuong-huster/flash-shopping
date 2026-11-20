import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../features/group/account_service.dart';
import '../features/ai/admin_ai_service.dart';
import '../features/auth/reset_password_view_model.dart';
import '../features/stats/insight_service.dart';
import '../features/meal/meal_service.dart';
import '../features/notifications/media_resolver.dart';
import '../features/food/food_service.dart';
import '../features/auth/session_service.dart';
import '../features/shopping/shopping_service.dart';
import '../core/settings_store.dart';
import '../core/token_store.dart';
import '../core/api_client.dart';
import '../features/auth/auth_repository.dart';
import '../features/food/food_repository.dart';
import '../features/group/group_repository.dart';
import '../features/meal/meal_recipe_repository.dart';
import '../features/notifications/misc_repository.dart';
import '../features/shopping/shopping_repository.dart';

/// Điểm lắp ráp đối tượng: tạo ApiClient, kho lưu phiên, repository, service rồi cung cấp cho cây widget.
/// Không chứa quy tắc nghiệp vụ. View/ViewModel chỉ nhận Service (tầng nghiệp vụ), không nhận Repository.
Future<List<SingleChildWidget>> createDependencies() async {
  final settings = SettingsStore();
  try {
    await settings.load();
  } catch (e) {
    // Nếu không load được cài đặt (ví dụ shared_preferences lỗi), dùng giá trị mặc định
    debugPrint('SettingsStore.load error: $e');
  }
  final tokens = TokenStore();
  try {
    await tokens.load();
  } catch (e) {
    // Nếu không load được secure storage (ví dụ Android không có keystore), coi như chưa có session
    debugPrint('TokenStore.load error: $e');
  }

  final api = ApiClient(settings, tokens);

  final authRepo = AuthRepository(api, tokens);
  final session = SessionService(authRepo, api, settings);

  return [
    ChangeNotifierProvider<SessionService>.value(value: session),
    ChangeNotifierProvider<InsightService>(create: (_) => InsightService(InsightRepository(api))),
    Provider<MediaResolver>.value(value: MediaResolver(api)),
    Provider<AccountService>.value(value: AccountService(authRepo, GroupRepository(api), session)),
    ChangeNotifierProvider<ResetPasswordViewModel>.value(
      value: ResetPasswordViewModel(AccountService(authRepo, GroupRepository(api), session)),
    ),
    Provider<FoodService>.value(value: FoodService(FoodRepository(api))),
    Provider<ShoppingService>.value(value: ShoppingService(ShoppingRepository(api))),
    Provider<MealService>.value(value: MealService(MealRecipeRepository(api))),
    Provider<AdminService>.value(value: AdminService(AdminRepository(api))),
    Provider<AiService>.value(value: AiService(AiRepository(api))),
  ];
}
