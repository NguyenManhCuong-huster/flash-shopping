import 'package:di_cho_tien_loi/core/widgets/async_section.dart';

import '../../core/utils/format.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../auth/session_service.dart';
import './shopping_service.dart';
import '../../core/utils/validators.dart';
import './shopping.dart';
import '../../core/utils/app_colors.dart';
import '../../core/widgets/widgets_common.dart';
import '../../core/widgets/buttons/icon_button_widget.dart';
import '../../core/widgets/badge_widget.dart';
import '../../core/widgets/base_modal_bottom_sheet.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/info_row.dart';
import 'shopping_session_modal.dart';
import '../fridge/add_purchased_item_to_fridge_modal.dart';
import 'update_pending_item_modal.dart';
import 'shopping_session_view_model.dart';
import 'create_pending_item_modal.dart';

class ShoppingSessionDetailPage extends StatelessWidget {
  const ShoppingSessionDetailPage({
    super.key,
    required this.sessionId,
    this.openAddItems = false,
  });
  final int sessionId;
  final bool openAddItems;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (c) =>
        ShoppingSessionDetailViewModel(c.read<ShoppingService>(), sessionId)
          ..load(),
    child: _ShoppingDetailView(openAddItems: openAddItems),
  );
}

class _ShoppingDetailView extends StatefulWidget {
  const _ShoppingDetailView({required this.openAddItems});
  final bool openAddItems;
  @override
  State<_ShoppingDetailView> createState() => _ShoppingDetailViewState();
}

class _ShoppingDetailViewState extends State<_ShoppingDetailView> {
  @override
  void initState() {
    super.initState();
    if (widget.openAddItems) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => showBaseModalBottomSheet<void>(
          context: context,
          title: 'Thêm món cần mua',
          icon: LucideIcons.filePlusCorner,
          child: const CreatePendingItemModal(
            shoppingSessionId: 0,
          ), // TODO: pass the actual session ID
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ShoppingSessionDetailViewModel>();
    final session = context.watch<SessionService>();
    final shoppingSession = vm.shoppingSession;
    // final shoppingSession = MockData.getCurrentShoppingSession(vm.shoppingSessionId); // TEMP_MOCK: sử dụng dữ liệu mock để hiển thị UI
    final isLeader = session.isLeader;
    final canBuy =
        shoppingSession != null &&
        (isLeader || shoppingSession.assignedTo?.id == session.user?.id) &&
        shoppingSession.pendingItems.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColor.emerald50,
      floatingActionButton: shoppingSession != null && isLeader
          ? GestureDetector(
              onTap: () => showBaseModalBottomSheet<void>(
                context: context,
                title: 'Thêm món cần mua',
                icon: LucideIcons.shoppingBasket,
                subtitle: 'Phiên mua sắm: ${shoppingSession.name}',
                child: CreatePendingItemModal(
                  shoppingSessionId: shoppingSession.id,
                ),
              ),
              child: Container(
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
          child: Column(
            children: [
              const SizedBox(height: 16),
              _buildHeader(vm, shoppingSession, isLeader),
              const SizedBox(height: 16),
              _buildShoppingSessionInfo(shoppingSession),
              const SizedBox(height: 16),
              _buildPendingShoppingItemsSection(
                shoppingSession?.pendingItems,
                vm,
                canBuy,
                isLeader,
              ),
              const SizedBox(height: 16),
              _buildPurchasedShoppingItemsSection(
                shoppingSession?.purchasedItems,
                vm,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    ShoppingSessionDetailViewModel vm,
    ShoppingSession? session,
    bool isLeader,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButtonWidget(
            icon: LucideIcons.arrowLeft,
            onTap: () {
              Navigator.pop(context);
            },
          ),
          const Text(
            'Chi tiết phiên mua sắm',
            style: TextStyle(
              color: AppColor.gray800,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),

          if (session != null && isLeader)
            IconButtonWidget(
              icon: LucideIcons.ellipsisVertical,
              onTap: () async {
                final RenderBox button =
                    context.findRenderObject() as RenderBox;

                final RenderBox overlay =
                    Overlay.of(context).context.findRenderObject() as RenderBox;

                final position = RelativeRect.fromRect(
                  Rect.fromPoints(
                    button.localToGlobal(
                      Offset(button.size.width, 0),
                      ancestor: overlay,
                    ),
                    button.localToGlobal(
                      Offset(button.size.width, button.size.height),
                      ancestor: overlay,
                    ),
                  ),
                  Offset.zero & overlay.size,
                );

                final selected = await showMenu<String>(
                  context: context,
                  position: position,
                  items: const [
                    PopupMenuItem(value: 'edit', child: Text('Sửa danh sách')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Xóa danh sách'),
                    ),
                  ],
                );

                if (!context.mounted) return;

                if (selected == 'edit') {
                  final result = await showBaseModalBottomSheet<int>(
                    context: context,
                    title: 'Chinh sửa phiên mua sắm',
                    icon: LucideIcons.shoppingCart,
                    subtitle: 'Chỉnh sửa thông tin phiên mua sắm',
                    child: ShoppingSessionModal(session: session),
                  );

                  if (result != null && context.mounted) {
                    vm.load();
                  }
                } else if (selected == 'delete') {
                  final confirmed = await confirmDialog(
                    context: context,
                    icon: LucideIcons.trash2,
                    title: 'Xóa danh sách',
                    message:
                        'Xóa "${session.name}" và toàn bộ mục trong danh sách?',
                  );

                  if (!confirmed || !context.mounted) return;

                  final ok = await runAction(context, () async {
                    await vm.deleteSession();
                    return true;
                  }, success: 'Đã xóa danh sách');

                  if (ok == true && context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildShoppingSessionInfo(ShoppingSession? session) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColor.white,
        border: Border.all(color: AppColor.gray200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session?.name ?? 'Danh sách không tên',
                    style: const TextStyle(
                      color: AppColor.gray800,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (session != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Ngày tạo: ${FormatUtils.formatDateTime(session.createdAt)}',
                      style: TextStyle(
                        color: AppColor.gray600,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
              if (session != null)
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Người mua',
                    style: TextStyle(
                      color: AppColor.gray600,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    session?.assignedTo.name ?? 'Không xác định',
                    style: const TextStyle(
                      color: AppColor.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Tiến độ',
                    style: TextStyle(
                      color: AppColor.gray600,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${session?.purchasedItemsCount ?? 0}/${session?.totalItems ?? 0} món',
                    style: const TextStyle(
                      color: AppColor.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (session != null) ...[
            const SizedBox(height: 8),
            InfoRow(
              label: 'Hoàn thành',
              value: session.completedAt == null
                  ? 'Chưa hoàn thành'
                  : FormatUtils.formatDate(session.completedAt!),
            ),
          ],
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
                  session?.note ?? 'Không có ghi chú',
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
        ],
      ),
    );
  }

  Widget _buildPendingShoppingItemsSection(
    List<ShoppingItem>? pendingItems,
    ShoppingSessionDetailViewModel vm,
    bool canBuy,
    bool isLeader,
  ) {
    final items = pendingItems ?? [];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('Cần mua (${items.length})'),
          const SizedBox(height: 8),
          AsyncSection(
            loading: vm.loading,
            error: null,
            isEmpty: items.isEmpty,
            onRetry: vm.load,
            emptyText: 'Chưa có món hàng nào trong danh sách.',
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _buildShoppingItemCard(
                  context,
                  item,
                  vm,
                  canBuy: canBuy,
                  editable: isLeader,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchasedShoppingItemsSection(
    List<ShoppingItem>? purchasedItems,
    ShoppingSessionDetailViewModel vm,
  ) {
    final items = purchasedItems ?? [];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('Đã mua (${items.length})'),
          const SizedBox(height: 8),
          AsyncSection(
            loading: vm.loading,
            error: null,
            isEmpty: items.isEmpty,
            onRetry: vm.load,
            emptyText: 'Chưa có món hàng nào đã mua.',
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _buildShoppingItemCard(
                  context,
                  item,
                  vm,
                  canBuy: false,
                  editable: false,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShoppingItemCard(
    BuildContext context,
    ShoppingItem item,
    ShoppingSessionDetailViewModel vm, {
    required bool canBuy,
    required bool editable,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColor.white,
        border: Border.all(color: AppColor.gray200),
        borderRadius: BorderRadius.circular(8),
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
          if (item.status == ShoppingStatus.pending) ...[
            GestureDetector(
              onTap: item.status == ShoppingStatus.bought || !canBuy
                  ? null
                  : () => _markItemBought(context, vm, item),
              child: SizedBox(
                width: 32,
                height: 32,
                child: Icon(
                  item.status == ShoppingStatus.bought
                      ? LucideIcons.squareCheckBig
                      : LucideIcons.square,
                  color: item.status == ShoppingStatus.bought
                      ? AppColor.primary
                      : AppColor.gray500,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
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
                      'Ghi chú',
                      style: const TextStyle(
                        color: AppColor.gray600,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    // Text(
                    //   item.food.category.name,
                    //   style: const TextStyle(
                    //     color: AppColor.gray600,
                    //     fontSize: 12,
                    //     fontWeight: FontWeight.w600,
                    //     fontStyle: FontStyle.italic,
                    //   ),
                    // ),
                  ],
                ),
                Text(
                  '${item.status == ShoppingStatus.pending ? item.quantity : (item.purchasedQuantity ?? item.quantity)} ${item.food.unit.name}',
                  style: const TextStyle(
                    color: AppColor.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: item.status == ShoppingStatus.pending
                ? () async {
                    debugPrint('Edit pending item: ${item.food.name}');
                    await showBaseModalBottomSheet(
                      context: context,
                      title: 'Cập nhật mặt hàng',
                      icon: LucideIcons.edit,
                      subtitle:
                          'Cập nhật thông tin mặt hàng trong phiên mua sắm',
                      child: UpdatePendingItemModal(
                        shoppingItem: item,
                        shoppingSessionId: vm.shoppingSessionId,
                      ),
                    );
                  }
                : () async {
                    await showBaseModalBottomSheet(
                      context: context,
                      title: 'Thêm vào tủ lạnh',
                      icon: LucideIcons.calendarCheck,
                      subtitle:
                          'Ngày mua: ${FormatUtils.formatDate(item.purchasedAt!)}',
                      child: AddPurchasedItemToFridgeModal(
                        shoppingItemId: item.id,
                        food: item.food,
                        quantity: item.purchasedQuantity ?? item.quantity,
                        purchasedAt: item.purchasedAt,
                        onSave:
                            ({required useWithin, required location, note}) =>
                                vm.addItemToFridge(
                                  item,
                                  useWithin: useWithin,
                                  location: location,
                                  note: note,
                                ),
                      ),
                    );
                  },
            child: SizedBox(
              width: 32,
              height: 32,
              child: Icon(
                LucideIcons.moreVertical,
                color: AppColor.gray500,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markItemBought(
    BuildContext context,
    ShoppingSessionDetailViewModel vm,
    ShoppingItem item,
  ) async {
    final value = await promptText(
      context,
      title: 'Xác nhận mua ${item.food.name}',
      label: item.food.unit.name,
      initial: FormatUtils.formatQuantity(item.quantity).replaceAll(',', '.'),
      validator: Validators.quantity,
    );
    if (value == null || !context.mounted) return;
    await runAction(
      context,
      () => vm.purchaseItem(item, Validators.parseQuantity(value)!),
      success: 'Đã đánh dấu ${item.food.name} là đã mua',
    );
  }
}
