import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../application/account_service.dart';
import '../application/admin_ai_service.dart';
import '../application/insight_service.dart';
import '../application/meal_service.dart';
import '../application/media_resolver.dart';
import '../application/pantry_service.dart';
import '../application/session_service.dart';
import '../application/shopping_service.dart';
import '../data/local/settings_store.dart';
import '../data/local/token_store.dart';
import '../data/remote/api_client.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/food_repository.dart';
import '../data/repositories/group_repository.dart';
import '../data/repositories/meal_recipe_repository.dart';
import '../data/repositories/misc_repository.dart';
import '../data/repositories/shopping_repository.dart';

/// Điểm lắp ráp đối tượng: tạo ApiClient, kho lưu phiên, repository, service rồi cung cấp cho cây widget.
/// Không chứa quy tắc nghiệp vụ. View/ViewModel chỉ nhận Service (tầng nghiệp vụ), không nhận Repository.
Future<List<SingleChildWidget>> createDependencies() async {
  final settings = SettingsStore();
  await settings.load();
  final tokens = TokenStore();
  await tokens.load();

  final api = ApiClient(settings, tokens);

  final authRepo = AuthRepository(api, tokens);
  final session = SessionService(authRepo, api, settings);

  return [
    ChangeNotifierProvider<SessionService>.value(value: session),
    ChangeNotifierProvider<InsightService>(create: (_) => InsightService(InsightRepository(api))),
    Provider<MediaResolver>.value(value: MediaResolver(api)),
    Provider<AccountService>.value(value: AccountService(authRepo, GroupRepository(api), session)),
    Provider<PantryService>.value(value: PantryService(FoodRepository(api))),
    Provider<ShoppingService>.value(value: ShoppingService(ShoppingRepository(api))),
    Provider<MealService>.value(value: MealService(MealRecipeRepository(api))),
    Provider<AdminService>.value(value: AdminService(AdminRepository(api))),
    Provider<AiService>.value(value: AiService(AiRepository(api))),
  ];
}
