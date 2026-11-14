import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../application/session_service.dart';
import '../../application/shopping_service.dart';
import '../../data/models/shopping.dart';
import '../group_page.dart';
import '../shared/base_view_model.dart';
import '../../utils/app_colors.dart';
import '../../utils/date_time_utils.dart';
import '../../utils/mock_data.dart';
import '../../widgets/buttons/outline_button.dart';
import '../../widgets/buttons/icon_button_widget.dart';
import '../shared/widgets.dart';
import 'shopping_session_detail_page.dart';
import '../../modals/shopping_session_modal.dart';
import '../../widgets/badge_widget.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/filter_item.dart';
import '../../widgets/info_row.dart';

class ShoppingSessionListViewModel extends BaseViewModel {
  ShoppingSessionListViewModel(this._shopping);
  final ShoppingService _shopping;

  List<ShoppingSession> sessions = [];
  bool done = false;
  bool mine = false;
  int _page = 1;
  bool hasMore = false;

  Future<void> load() => runLoad(() async {
    _page = 1;
    final r = await _shopping.sessions(done: done, assignedToMe: mine);
    sessions = r.items;
    hasMore = r.hasMore;
  });

  Future<void> loadMore() async {
    if (!hasMore || loading) return;
    final r = await _shopping.sessions(
      done: done,
      assignedToMe: mine,
      page: ++_page,
    );
    sessions = [...sessions, ...r.items];
    hasMore = r.hasMore;
    notifyListeners();
  }

  void setDone(bool v) {
    done = v;
    load();
  }

  void toggleMine() {
    mine = !mine;
    load();
  }
}

/// UC03 - danh sách mua sắm của nhóm.
class ShoppingSessionListPage extends StatelessWidget {
  const ShoppingSessionListPage({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (c) =>
        ShoppingSessionListViewModel(c.read<ShoppingService>())..load(),
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
  List<ShoppingSession> _filterLists(List<ShoppingSession> lists) {
    final lowerCaseQuery = _query.toLowerCase();
    return lists.where((list) {
      final matchesQuery =
          lowerCaseQuery.isEmpty ||
          list.name.toLowerCase().contains(lowerCaseQuery) ||
          (list.note?.toLowerCase().contains(lowerCaseQuery) ?? false) ||
          (list.assignedTo?.name.toLowerCase().contains(lowerCaseQuery) ??
              false);
      final matchesDone = _filterDone == null || list.done == _filterDone;
      return matchesQuery && matchesDone;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ShoppingSessionListViewModel>();
    final session = context.watch<SessionService>();

    final filteredShoppingSessions = _filterLists(MockData.shoppingSessions);

    if (!session.hasGroup) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mua sắm')),
        body: NeedGroupView(
          onCreateGroup: () => pushPage(context, const GroupPage()),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColor.transparent,
      extendBody: true,
      floatingActionButton: session.isLeader
          ? GestureDetector(
              onTap: () async {
                final id = await showModalBottomSheet<int>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  backgroundColor: AppColor.gray50,
                  builder: (_) => const ShoppingSessionModal(),
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
                  color: AppColor.emerald500,
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
              _buildShoppingSessionSection(filteredShoppingSessions),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ShoppingSessionListViewModel vm) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [  
          const Text(
            'Quản lý mua sắm',
            style: TextStyle(
              color: AppColor.emerald500,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButtonWidget(
            icon: LucideIcons.refreshCw,
            onTap: vm.load,
          ),
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
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColor.gray200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
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
        onChanged: (query) => setState(() {
          _query = query;
        }),
      ),
    );
  }

  Widget _buildFilterBar(ShoppingSessionListViewModel vm) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          FilterItem(
            label: 'Tất cả',
            isSelected: _filterDone == null,
            onSelected: () {
              setState(() => _filterDone = null);
            },
          ),
          const SizedBox(width: 8),
          FilterItem(
            label: 'Chưa mua',
            isSelected: _filterDone == false,
            onSelected: () => setState(() => _filterDone = false),
          ),
          const SizedBox(width: 8),
          FilterItem(
            label: 'Đã mua',
            isSelected: _filterDone == true,
            onSelected: () => setState(() => _filterDone = true),
          ),
          const SizedBox(width: 8),
          // FilterItem(
          //   label: 'Giao cho tôi',
          //   isSelected: vm.mine,
          //   onSelected: () => vm.toggleMine(),
          // ),
        ],
      ),
    );
  }

  Widget _buildShoppingSessionSection(List<ShoppingSession> shoppingSessions) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // if (filteredShoppingSessions.isEmpty && !vm.loading)
          //   const Center(child: CircularProgressIndicator())
          // else
          if (shoppingSessions.isEmpty)
            const EmptyStateWidget(message: 'Không có phiên mua sắm nào phù hợp.')
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              // itemCount: vm.lists.length,
              itemCount: shoppingSessions.length,
              itemBuilder: (context, index) {
                final session = shoppingSessions[index];
                return _buildShoppingSessionCard(session);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildShoppingSessionCard(ShoppingSession session) {
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
                    'Tạo ngày: ${DateTimeUtils.formatDateTime(session.createdAt)}',
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
                value: '${session.purchasedItemsCount}/${session.totalItems} món',
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
                      : (session.purchasedItemsCount / session.totalItems).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColor.emerald500,
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
                      ShoppingSessionDetailPage(
                        sessionId: session.id,
                        session: session,
                      ), // TEMP_MOCK_START: truyền đối tượng ShoppingSession từ MockData vào trang chi tiết
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
