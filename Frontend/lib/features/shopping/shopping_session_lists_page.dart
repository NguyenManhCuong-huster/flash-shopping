import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../auth/session_service.dart';
import './shopping_service.dart';
import './shopping.dart';
import '../../core/utils/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/utils/mock_data.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/base_modal_bottom_sheet.dart';
import '../../core/widgets/buttons/outline_button.dart';
import '../../core/widgets/buttons/icon_button_widget.dart';
import '../../core/widgets/badge_widget.dart';
import '../../core/widgets/filter_item.dart';
import '../../core/widgets/info_row.dart';
import '../../core/widgets/widgets_common.dart';
import 'shopping_session_detail_page.dart';
import 'shopping_session_modal.dart';
import 'shopping_session_view_model.dart';

class ShoppingSessionListPage extends StatelessWidget {
  const ShoppingSessionListPage({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (c) => ShoppingSessionViewModel(c.read<ShoppingService>())..load(),
    child: const _ShoppingSessionView(),
  );
}

class _ShoppingSessionView extends StatefulWidget {
  const _ShoppingSessionView();

  @override
  State<_ShoppingSessionView> createState() => _ShoppingSessionListViewState();
}

class _ShoppingSessionListViewState extends State<_ShoppingSessionView> {
  String _query = '';
  bool? _filterDone;
  bool _showMine = false;
  List<ShoppingSession> _filterSessions(
    List<ShoppingSession> shoppingSessions,
    int? userId,
  ) {
    final lowerCaseQuery = _query.toLowerCase();
    return shoppingSessions.where((session) {
      final matchesQuery =
          lowerCaseQuery.isEmpty ||
          session.name.toLowerCase().contains(lowerCaseQuery) ||
          (session.note?.toLowerCase().contains(lowerCaseQuery) ?? false) ||
          (session.assignedTo?.name.toLowerCase().contains(lowerCaseQuery) ??
              false);
      final matchesDone = _filterDone == null || session.done == _filterDone;
      final matchesMine = _showMine == null || session.assignedTo?.id == userId;
      return matchesQuery && matchesDone && matchesMine;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ShoppingSessionViewModel>();
    final session = context.watch<SessionService>();

    // final filteredShoppingSessions = _filterSessions(
    //   MockData.shoppingSessions,
    //   1,
    // );
    final filteredShoppingSessions = _filterSessions(
      vm.shoppingSessions,
      session.user?.id,
    );
    return Scaffold(
      backgroundColor: AppColor.transparent,
      extendBody: true,
      floatingActionButton: session.isLeader
          ? GestureDetector(
              onTap: () async {
                final id = await showBaseModalBottomSheet<int>(
                  context: context,
                  title: 'Tạo phiên mua sắm mới',
                  icon: LucideIcons.shoppingCart,
                  subtitle: 'Hãy tạo phiên mua sắm để thêm các món cần mua',
                  child: const ShoppingSessionModal(),
                );
                if (id != null && context.mounted) {
                  await pushPage(
                    context,
                    ShoppingSessionDetailPage(
                      sessionId: id,
                      openAddItems: true,
                    ),
                  );
                  vm.load();
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 76),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColor.primary,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: AppColor.gray400.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  LucideIcons.filePlusCorner,
                  color: AppColor.white,
                  size: 24,
                ),
              ),
            )
          : null,
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
              _buildSearchField(),
              const SizedBox(height: 8),
              _buildFilterBar(vm),
              const SizedBox(height: 16),
              _buildShoppingSessionSection(vm, filteredShoppingSessions),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ShoppingSessionViewModel vm) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Quản lý mua sắm',
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

  Widget _buildSearchField() {
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

  Widget _buildFilterBar(ShoppingSessionViewModel vm) {
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
              isSelected: _filterDone == null,
              onSelected: () {
                setState(() => _filterDone = null);
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: FilterItem(
              label: 'Chưa mua',
              isSelected: _filterDone == false,
              onSelected: () => setState(() => _filterDone = false),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: FilterItem(
              label: 'Đã mua',
              isSelected: _filterDone == true,
              onSelected: () => setState(() => _filterDone = true),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: FilterItem(
              label: 'Của tôi',
              isSelected: _showMine,
              onSelected: () {
                setState(() => _showMine = !_showMine);
                vm.toggleMine();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShoppingSessionSection(
    ShoppingSessionViewModel vm,
    List<ShoppingSession> shoppingSessions,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: AsyncSection(
        loading: vm.loading,
        error: vm.loadError,
        isEmpty: shoppingSessions.isEmpty,
        onRetry: () => vm.load(),
        emptyText: 'Bạn chưa có phiên mua sắm nào. Hãy tạo phiên mới để thêm các món cần mua.',
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemCount: shoppingSessions.length,
          itemBuilder: (context, index) {
            final session = shoppingSessions[index];
            return _buildShoppingSessionCard(session);
          },
        ),
      ),
    );
  }

  Widget _buildShoppingSessionCard(ShoppingSession session) {
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
                    session.name,
                    style: const TextStyle(
                      color: AppColor.gray800,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tạo ngày: ${FormatUtils.formatDateTime(session.createdAt)}',
                    style: const TextStyle(
                      color: AppColor.gray600,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              BadgeWidget(
                label: session.done
                    ? ShoppingStatus.bought.label
                    : ShoppingStatus.pending.label,
                badgeColor: session.done
                    ? ShoppingStatus.bought.badgeColor
                    : ShoppingStatus.pending.badgeColor,
                labelColor: session.done
                    ? ShoppingStatus.bought.labelColor
                    : ShoppingStatus.pending.labelColor,
              ),
            ],
          ),
          const Divider(height: 17, color: AppColor.gray200, thickness: 1),
          InfoRow(
            label: 'Người mua',
            value: session.assignedTo?.name ?? 'Chưa giao',
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              InfoRow(
                label: 'Tiến độ',
                value:
                    '${session.purchasedItemsCount}/${session.totalItems} món',
              ),
              const SizedBox(height: 8),
              Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColor.gray200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: session.totalItems == 0
                      ? 0
                      : (session.purchasedItemsCount / session.totalItems)
                            .clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColor.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColor.amber50,
              border: Border.all(color: AppColor.amber200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.filePenLine,
                      color: AppColor.gray600,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Ghi chú',
                      style: const TextStyle(
                        color: AppColor.gray600,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  session.note ?? 'Không có ghi chú',
                  style: const TextStyle(
                    color: AppColor.gray800,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (MockData.currentUser.groupRole == 'admin') ...[
                Expanded(
                  child: OutlineButton(
                    onPressed: () {},
                    backgroundColor: AppColor.amber50,
                    label: 'Tạo phiên mới',
                    labelColor: AppColor.amber500,
                    icon: LucideIcons.copyPlus,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: OutlineButton(
                  onPressed: () async {
                    await pushPage(
                      context,
                      ShoppingSessionDetailPage(sessionId: session.id),
                    );
                  },
                  label: 'Xem chi tiết',
                  icon: LucideIcons.arrowRight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
