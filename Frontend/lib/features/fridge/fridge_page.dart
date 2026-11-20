import 'dart:async';
import '../../core/widgets/info_row.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../food/food_service.dart';
import '../auth/session_service.dart';
import '../food/food.dart';
import '../../core/utils/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/utils/mock_data.dart';
import '../../core/base_view_model.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/buttons/outline_button.dart';
import '../../core/widgets/buttons/icon_button_widget.dart';
import '../../core/widgets/badge_widget.dart';
import '../../core/widgets/filter_item.dart';
import '../../core/widgets/stat_card.dart';
import '../../core/widgets/widgets_common.dart';
import 'fridge_item_page.dart';
import 'fridge_view_model.dart';

class FridgePage extends StatelessWidget {
  const FridgePage({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (c) => FridgeViewModel(c.read<FoodService>())..load(),
    child: const _FridgeView(),
  );
}

class _FridgeView extends StatefulWidget {
  const _FridgeView();
  @override
  State<_FridgeView> createState() => _FridgeViewState();
}

class _FridgeViewState extends State<_FridgeView> {
  String _query = '';
  String _filterLocation = 'all';
  List<FridgeItem> _filterItems(List<FridgeItem> fridgeItems) {
    final lowerCaseQuery = _query.toLowerCase();
    return fridgeItems.where((item) {
      final matchesQuery =
          lowerCaseQuery.isEmpty ||
          item.food.name.toLowerCase().contains(lowerCaseQuery) ||
          (item.note?.toLowerCase().contains(lowerCaseQuery) ?? false);
      final matchesFilter = switch (_filterLocation) {
        'all' => true,
        'cool' => item.location == StorageLocation.cool,
        'freezer' => item.location == StorageLocation.freezer,
        'other' => item.location == StorageLocation.other,
        _ => true,
      };
      return matchesQuery && matchesFilter;
    }).toList()..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
  }

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
    // final fridgeItems = vm.items;
    final fridgeItems = MockData.fridgeItems;
    final filteredFridgeItems = _filterItems(fridgeItems);
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
      //       color: AppColor.primary,
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
              _buildFridgeListSection(vm, filteredFridgeItems),
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
              color: AppColor.primary,
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
            borderSide: BorderSide(color: AppColor.primary),
          ),
          filled: true,
          fillColor: AppColor.white,
        ),
        style: const TextStyle(
          color: AppColor.gray800,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        onChanged: (query) => setState(() {
          _query = query;
        }),
      ),
    );
  }

  Widget _buildFilterBar(FridgeViewModel vm) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColor.white,
        border: Border.all(color: AppColor.gray200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: FilterItem(
              label: 'Tất cả',
              isSelected: _filterLocation == 'all',
              onSelected: () {
                setState(() => _filterLocation = 'all');
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: FilterItem(
              label: StorageLocation.cool.label,
              isSelected: _filterLocation == 'cool',
              onSelected: () {
                setState(() => _filterLocation = 'cool');
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: FilterItem(
              label: StorageLocation.freezer.label,
              isSelected: _filterLocation == 'freezer',
              onSelected: () => setState(() => _filterLocation = 'freezer'),
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
    List<FridgeItem> fridgeItems,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('Danh sách thực phẩm', subtitle: '${fridgeItems.length} món'),
          const SizedBox(height: 8),
          AsyncSection(
            loading: vm.loading,
            error: vm.loadError,
            isEmpty: fridgeItems.isEmpty,
            onRetry: vm.load,
            emptyText:
                'Chưa có thực phẩm nào trong tủ lạnh. Hãy thêm thực phẩm từ phiên mua sắm để quản lý.',
            child: ListView.separated(
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
        color: AppColor.white,
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
                ? FormatUtils.formatDate(item.purchasedAt!)
                : 'Không xác định',
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              InfoRow(label: 'Hạn sử dụng', value: '${item.daysLeft} ngày'),
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
                FridgeItemPage(fridgeItemId: item.id),
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
