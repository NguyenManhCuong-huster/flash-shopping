import 'dart:async';
import 'package:di_cho_tien_loi/widgets/info_row.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../application/pantry_service.dart';
import '../../application/session_service.dart';
import '../../data/models/food.dart';
import '../group_page.dart';
import '../../utils/app_colors.dart';
import '../../utils/date_time_utils.dart';
import '../../utils/mock_data.dart';
import '../shared/base_view_model.dart';
import '../shared/format.dart';
import '../../widgets/buttons/outline_button.dart';
import '../../widgets/buttons/icon_button_widget.dart';
import '../../widgets/badge_widget.dart';
import '../../widgets/filter_item.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/stat_card.dart';
import '../../utils/theme.dart';
import '../shared/widgets.dart';
import '../../modals/fridge_item_modal.dart';
import 'fridge_item_page.dart';

class FridgeViewModel extends BaseViewModel {
  FridgeViewModel(this._pantry);
  final PantryService _pantry;

  List<FridgeItem> items = [];
  FridgeSummary summary = const FridgeSummary();
  StorageLocation? location;
  bool onlyExpiring = false;
  String query = '';
  int _page = 1;
  int _totalPages = 1;

  Future<void> load() => runLoad(() async {
    _page = 1;
    final result = await _pantry.fridge(
      query: query,
      location: location,
      expiringDays: onlyExpiring ? 3 : null,
    );
    items = result.items;
    summary = result.summary;
    _totalPages = result.totalPages;
  });

  /// Tải cuộn: 50 mục mỗi lần (NFR08).
  Future<void> loadMore() async {
    if (_page >= _totalPages || loading) return;
    final result = await _pantry.fridge(
      query: query,
      location: location,
      expiringDays: onlyExpiring ? 3 : null,
      page: ++_page,
    );
    items = [...items, ...result.items];
    notifyListeners();
  }

  void setLocation(StorageLocation? l) {
    location = l;
    load();
  }

  void toggleExpiring() {
    onlyExpiring = !onlyExpiring;
    load();
  }
}

/// UC05 - Quản lý tủ lạnh.
class FridgePage extends StatelessWidget {
  const FridgePage({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (c) => FridgeViewModel(c.read<PantryService>())..load(),
    child: const _FridgeView(),
  );
}

class _FridgeView extends StatefulWidget {
  const _FridgeView();
  @override
  State<_FridgeView> createState() => _FridgeViewState();
}

class _FridgeViewState extends State<_FridgeView> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FridgeViewModel>();
    final session = context.watch<SessionService>();
    // if (!session.hasGroup) {
    //   return Scaffold(
    //     appBar: AppBar(title: const Text('Tủ lạnh')),
    //     body: NeedGroupView(
    //       onCreateGroup: () => pushPage(context, const GroupPage()),
    //     ),
    //   );
    // }
    return Scaffold(
      backgroundColor: AppColor.transparent,
      extendBody: true,
      // floatingActionButton: GestureDetector(
      //   onTap: () async {
      //     if (await pushPage<bool>(context, const FridgeItemModal()) == true)
      //       vm.load();
      //   },
      //   child: Container(
      //     margin: const EdgeInsets.only(bottom: 76),
      //     padding: const EdgeInsets.all(8),
      //     decoration: BoxDecoration(
      //       color: AppColor.emerald500,
      //       borderRadius: BorderRadius.circular(8),
      //       boxShadow: [
      //         BoxShadow(
      //           color: AppColor.gray400.withValues(alpha: 0.2),
      //           blurRadius: 4,
      //           offset: Offset(0, 4),
      //         ),
      //       ],
      //     ),
      //     child: Icon(
      //       LucideIcons.filePlusCorner,
      //       color: AppColor.white,
      //       size: 24,
      //     ),
      //   ),
      // ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 92),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildHeader(vm),
              const SizedBox(height: 16),
              _buildSearchField(vm),
              const SizedBox(height: 8),
              _buildFilterBar(vm),
              const SizedBox(height: 16),
              _buildStatsCardSection(),
              const SizedBox(height: 16),
              _buildFridgeListSection(vm, vm.items),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(FridgeViewModel vm) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Quản lý tủ lạnh',
            style: TextStyle(
              color: AppColor.emerald500,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButtonWidget(icon: LucideIcons.refreshCw, onTap: vm.load),
        ],
      ),
    );
  }

  Widget _buildSearchField(FridgeViewModel vm) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.all(8),
          hintText: 'Tìm danh sách mua sắm...',
          hintStyle: const TextStyle(
            color: AppColor.gray400,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: const Icon(
            LucideIcons.search,
            color: AppColor.gray600,
            size: 16,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColor.gray200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColor.emerald500),
          ),
          filled: true,
          fillColor: AppColor.gray50,
        ),
        style: const TextStyle(
          color: AppColor.gray800,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        onChanged: (query) {
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 400), () {
            vm.query = query;
            vm.load();
          });
        },
      ),
    );
  }

  Widget _buildFilterBar(FridgeViewModel vm) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColor.gray50,
        border: Border.all(color: AppColor.gray200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: FilterItem(
              label: 'Tất cả',
              backgroundColor: AppColor.transparent,
              borderColor: AppColor.transparent,
              isSelected: vm.location == null,
              onSelected: () {
                setState(() => vm.setLocation(null));
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilterItem(
              label: StorageLocation.cool.label,
              backgroundColor: AppColor.transparent,
              borderColor: AppColor.transparent,
              isSelected: vm.location == StorageLocation.cool,
              onSelected: () {
                setState(() => vm.setLocation(StorageLocation.cool));
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilterItem(
              label: StorageLocation.freezer.label,
              backgroundColor: AppColor.transparent,
              borderColor: AppColor.transparent,
              isSelected: vm.location == StorageLocation.freezer,
              onSelected: () =>
                  setState(() => vm.setLocation(StorageLocation.freezer)),
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
                      'Cảnh báo thực phẩm sắp hết hạn',
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
                      'thực phẩm sắp hết hạn. Sử dụng ngay!',
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
          // PrimaryButton(
          //   saving: false,
          //   onPressed: () => onNavigate(2),
          //   backgroundColor: AppColor.amber500,
          //   label: 'Xem ngay',
          //   icon: LucideIcons.arrowRight,
          // ),
        ],
      ),
    );
  }

  Widget _buildExpiredFoodWarningCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColor.red50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColor.red200),
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
                      color: AppColor.red500,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Cảnh báo thực phẩm đã hết hạn',
                      style: TextStyle(
                        color: AppColor.red500,
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
                      MockData.getFridgeItemsExpired().length.toString(),
                      style: const TextStyle(
                        color: AppColor.red500,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'thực phẩm đã hết hạn. Vui lòng loại bỏ ngay!',
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
          // PrimaryButton(
          //   saving: false,
          //   onPressed: () => onNavigate(2),
          //   backgroundColor: AppColor.amber500,
          //   label: 'Xem ngay',
          //   icon: LucideIcons.arrowRight,
          // ),
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
              icon: LucideIcons.calendarClock,
              backgroundColor: AppColor.amber50,
              borderColor: AppColor.amber200,
              value: '${MockData.getFridgeItemsExpiringSoon().length} món',
              title: 'Sắp hết hạn',
              subtitle: 'Cần sử dụng ngay',
              color: AppColor.amber500,
              onTap: () {},
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: StatCard(
              icon: LucideIcons.calendarX2,
              backgroundColor: AppColor.red50,
              borderColor: AppColor.red200,
              value: '${MockData.getFridgeItemsExpired().length} món',
              title: 'Đã hết hạn',
              subtitle: 'Vui lòng loại bỏ ngay',
              color: AppColor.red500,
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFridgeListSection(
    FridgeViewModel vm,
    List<FridgeItem> _fridgeItems,
  ) {
    final List<FridgeItem> fridgeItems = MockData.fridgeItems;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Danh sách thực phẩm',
                style: TextStyle(
                  color: AppColor.gray800,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${fridgeItems.length} món',
                style: const TextStyle(
                  color: AppColor.gray600,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (fridgeItems.isEmpty && vm.loading)
            const Center(child: CircularProgressIndicator())
          else if (fridgeItems.isEmpty)
            const EmptyStateWidget(message: 'Không có thực phẩm nào phù hợp.')
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              // itemCount: vm.lists.length,
              itemCount: fridgeItems.length,
              itemBuilder: (context, index) {
                final fridgeItem = fridgeItems[index];
                return _buildFridgeItemCard(fridgeItem);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFridgeItemCard(FridgeItem item) {
    final int activeCount = switch (item.status) {
      FridgeItemStatus.expired => 1,
      FridgeItemStatus.expiring => 2,
      FridgeItemStatus.fresh => 3,
    };
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColor.gray50,
        border: Border.all(color: AppColor.gray200),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.food.name,
                    style: const TextStyle(
                      color: AppColor.gray800,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.note != null && item.note!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.note!,
                      style: const TextStyle(
                        color: AppColor.gray600,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
              BadgeWidget(
                icon: item.location.icon,
                label: item.location.label,
                badgeColor: item.location == StorageLocation.cool
                    ? AppColor.green50
                    : AppColor.blue50,
                labelColor: item.location == StorageLocation.cool
                    ? AppColor.green500
                    : AppColor.blue500,
              ),
            ],
          ),
          const Divider(height: 17, thickness: 1, color: AppColor.gray200),
          InfoRow(
            label: 'Định lượng',
            value: '${item.quantity} ${item.food.unit.name}',
          ),
          const SizedBox(height: 8),
          InfoRow(
            label: 'Ngày mua',
            value: item.purchasedAt != null
                ? DateTimeUtils.formatDate(item.purchasedAt!)
                : 'Không xác định',
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              InfoRow(label: 'Độ tươi', value: '${item.daysLeft} ngày'),
              const SizedBox(height: 8),
              Row(
                children: List.generate(3, (index) {
                  final bool isActive = index < activeCount;
                  return Expanded(
                    child: Container(
                      height: 8,
                      margin: EdgeInsets.only(right: index < 2 ? 4.0 : 0.0),
                      decoration: BoxDecoration(
                        color: isActive
                            ? item.status.labelColor
                            : AppColor.gray200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          const Divider(height: 17, thickness: 1, color: AppColor.gray200),
          OutlineButton(
            onPressed: () async {
              await pushPage(
                context,
                FridgeItemPage(fridgeItemId: item.id, fridgeItem: item),
              ); // TEMP_MOCK_START
              context.read<FridgeViewModel>().load();
            },
            label: 'Xem chi tiết',
            icon: LucideIcons.arrowRight,
          ),
        ],
      ),
    );
  }
}
