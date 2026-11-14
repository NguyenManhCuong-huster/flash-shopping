import 'package:di_cho_tien_loi/utils/date_time_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../application/session_service.dart';
import '../../application/shopping_service.dart';
import '../../application/validation/validators.dart';
import '../../data/models/food.dart';
import '../../data/models/shopping.dart';
import '../../data/remote/api_client.dart';
import '../shared/base_view_model.dart';
import '../../utils/app_colors.dart';
import '../shared/format.dart';
import '../shared/pickers.dart';
import '../shared/widgets.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/buttons/icon_button_widget.dart';
import '../../widgets/badge_widget.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/info_row.dart';
import '../../modals/shopping_session_modal.dart';
import '../../modals/add_purchased_item_to_fridge_modal.dart';
import '../../modals/update_pending_item_modal.dart';

class ShoppingSessionDetailViewModel extends BaseViewModel {
  ShoppingSessionDetailViewModel(
    this._shopping,
    this.sessionId, {
    this.session, // TEMP_MOCK: dữ liệu mock được truyền vào
  }); // TEMP_MOCK: thêm tham số list tùy chọn
  final ShoppingService _shopping;
  final int sessionId;
  final ShoppingSession? session; // TEMP_MOCK: dữ liệu mock được truyền vào

  ShoppingSession? _session; // TEMP_MOCK: trạng thái nội bộ (mock hoặc từ API)

  /// Trả về dữ liệu hiển thị: ưu tiên _list, fallback về mock list nếu chưa load
  ShoppingSession? get sessionData => _session ?? session; // TEMP_MOCK

  Future<void> load() => runLoad(() async {
    if (session != null) {
      // TEMP_MOCK: nếu có mock data, dùng luôn, không gọi API
      _session = session;
      return;
    }
    _session = await _shopping.session(sessionId);
  });

  Future<ItemBatchResult> addItem(
    List<({String foodName, double quantity})> item,
  ) => runSave(() async {
    final r = await _shopping.addItem(sessionId, item);
    if (r.session != null) _session = r.session;
    return r;
  });

  Future<void> updateItem(
    ShoppingItem i, {
    String? foodName,
    double? quantity,
  }) => runSave(() async {
    await _shopping.updateItem(i, foodName: foodName, quantity: quantity);
    _session = await _shopping.session(sessionId);
  });

  Future<void> deleteItem(ShoppingItem i) => runSave(() async {
    await _shopping.deleteItem(i);
    _session = await _shopping.session(sessionId);
  });

  Future<void> purchaseItem(ShoppingItem item, double purchasedQuantity) =>
      runSave(() async {
        _session = await _shopping.purchase(sessionData!, [
          PurchaseItem(itemId: item.id, purchasedQuantity: purchasedQuantity),
        ], newIdempotencyKey());
      });

  Future<void> addItemToFridge(
    ShoppingItem item, {
    required DateTime useWithin,
    required StorageLocation location,
    String? note,
  }) => runSave(() async {
    _session = await _shopping.addPurchasedToFridge(sessionData!, [
      {
        'itemId': item.id,
        'useWithin': useWithin.toIso8601String(),
        'location': location.code,
        'note': note,
      },
    ], newIdempotencyKey());
  });

  Future<void> deleteSession() =>
      runSave(() => _shopping.deleteSession(_session!));
}

/// Chi tiết danh sách: mục mua và trạng thái từng mục; trưởng nhóm thêm/sửa/xóa;
/// người được giao hoặc trưởng nhóm xác nhận mua.
class ShoppingSessionDetailPage extends StatelessWidget {
  const ShoppingSessionDetailPage({
    super.key,
    required this.sessionId,
    this.session, // TEMP_MOCK: truyền ShoppingSession từ MockData để bỏ qua gọi API
    this.openAddItems = false,
  });
  final int sessionId;
  final ShoppingSession? session; // TEMP_MOCK
  final bool openAddItems;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (c) => ShoppingSessionDetailViewModel(
      c.read<ShoppingService>(),
      sessionId,
      session: session, // TEMP_MOCK: truyền mock session vào ViewModel
    )..load(),
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _addItems(context));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ShoppingSessionDetailViewModel>();
    final session = context.watch<SessionService>();
    final sessionData = vm.sessionData; // TEMP_MOCK: dùng getter listData
    final isLeader = session.isLeader;
    final canBuy =
        sessionData != null &&
        (isLeader || sessionData.assignedTo?.id == session.user?.id) &&
        sessionData.pendingItems.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColor.emerald50,
      floatingActionButton: sessionData != null && isLeader
          ? GestureDetector(
              onTap: () => _addItems(context),
              child: Container(
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
          child: Column(
            children: [
              const SizedBox(height: 16),
              _buildHeader(sessionData!, isLeader, vm),
              const SizedBox(height: 16),
              _buildShoppingSessionInfo(sessionData),
              const SizedBox(height: 16),
              _buildPendingShoppingItemsSection(
                sessionData.pendingItems,
                vm,
                canBuy,
                isLeader,
              ),
              const SizedBox(height: 16),
              _buildPurchasedShoppingItemsSection(
                sessionData.purchasedItems,
                vm,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    ShoppingSession session,
    bool isLeader,
    ShoppingSessionDetailViewModel vm,
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
            'Chi tiết danh sách',
            style: TextStyle(
              color: AppColor.gray800,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),

          if (isLeader)
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
                  final result = await showModalBottomSheet<int>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    backgroundColor: AppColor.gray50,
                    builder: (_) => ShoppingSessionModal(session: session),
                  );

                  if (result != null && context.mounted) {
                    vm.load();
                  }
                } else if (selected == 'delete') {
                  final confirmed = await confirmDialog(
                    context,
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

  Widget _buildShoppingSessionInfo(ShoppingSession session) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColor.gray50,
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
                    'Ngày tạo: ${DateTimeUtils.formatDateTime(session.createdAt)}',
                    style: TextStyle(
                      color: AppColor.gray600,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      fontStyle: FontStyle.italic,
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
                    session.assignedTo?.name ?? 'Chưa giao cho ai',
                    style: const TextStyle(
                      color: AppColor.emerald500,
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
                    '${session.purchasedItemsCount}/${session.totalItems} món',
                    style: const TextStyle(
                      color: AppColor.emerald500,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          InfoRow(
            label: 'Hoàn thành',
            value: session.completedAt == null
                ? 'Chưa hoàn thành'
                : DateTimeUtils.formatDate(session.completedAt!),
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
        ],
      ),
    );
  }

  Widget _buildPendingShoppingItemsSection(
    List<ShoppingItem> pendingItems,
    ShoppingSessionDetailViewModel vm,
    bool canBuy,
    bool isLeader,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cần mua (${pendingItems.length})',
            style: TextStyle(
              color: AppColor.gray800,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (pendingItems.isEmpty)
            const EmptyStateWidget(
              message: 'Chưa có món hàng nào trong danh sách.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              // itemCount: vm.lists.length,
              itemCount: pendingItems.length,
              itemBuilder: (context, index) {
                final item = pendingItems[index];
                return _buildShoppingItem(
                  context,
                  item,
                  vm,
                  canBuy: canBuy,
                  editable: isLeader,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPurchasedShoppingItemsSection(
    List<ShoppingItem> purchasedItems,
    ShoppingSessionDetailViewModel vm,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Đã mua (${purchasedItems.length})',
            style: TextStyle(
              color: AppColor.gray800,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (purchasedItems.isEmpty)
            const EmptyStateWidget(
              message: 'Chưa có món hàng nào được đánh dấu là đã mua.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              // itemCount: vm.lists.length,
              itemCount: purchasedItems.length,
              itemBuilder: (context, index) {
                final item = purchasedItems[index];
                return _buildShoppingItem(
                  context,
                  item,
                  vm,
                  canBuy: false,
                  editable: false,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildShoppingItem(
    BuildContext context,
    ShoppingItem item,
    ShoppingSessionDetailViewModel vm, {
    required bool canBuy,
    required bool editable,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColor.gray50,
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
                      ? AppColor.emerald500
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
                    color: AppColor.emerald500,
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
                    await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      backgroundColor: AppColor.gray50,
                      builder: (context) => UpdatePendingItemModal(
                        shoppingItemId: item.id,
                        food: item.food,
                        quantity: item.quantity,
                      ),
                    );
                  }
                : () async {
                    await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      backgroundColor: AppColor.gray50,
                      builder: (context) => AddPurchasedItemToFridgeModal(
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
      initial: fmtQty(item.quantity).replaceAll(',', '.'),
      validator: Validators.quantity,
    );
    if (value == null || !context.mounted) return;
    await runAction(
      context,
      () => vm.purchaseItem(item, Validators.parseQuantity(value)!),
      success: 'Đã đánh dấu ${item.food.name} là đã mua',
    );
  }

  Future<void> _editPendingItem(
    BuildContext context,
    ShoppingSessionDetailViewModel vm,
    ShoppingItem item,
    String action,
  ) async {
    if (action == 'quantity') {
      final value = await promptText(
        context,
        title: 'Số lượng ${item.food.name}',
        label: item.food.unit.name,
        initial: fmtQty(item.quantity).replaceAll(',', '.'),
        validator: Validators.quantity,
      );
      if (value != null && context.mounted) {
        await runAction(
          context,
          () => vm.updateItem(item, quantity: Validators.parseQuantity(value)),
          success: 'Đã cập nhật số lượng',
        );
      }
    } else if (action == 'food') {
      final food = await pickFood(context, title: 'Đổi thực phẩm');
      if (food != null && context.mounted) {
        await runAction(
          context,
          () => vm.updateItem(item, foodName: food.name),
          success: 'Đã cập nhật thực phẩm',
        );
      }
    } else if (await confirmDialog(
          context,
          title: 'Xóa món',
          message: 'Xóa ${item.food.name} khỏi danh sách?',
        ) &&
        context.mounted) {
      await runAction(
        context,
        () => vm.deleteItem(item),
        success: 'Đã xóa món',
      );
    }
  }

  /// Thêm nhiều món một lần. Mục lỗi (không tồn tại, trùng, số lượng sai) được giữ lại để sửa (UC03 - 5a).
  Future<void> _addItems(BuildContext context) async {
    final vm = context.read<ShoppingSessionDetailViewModel>();
    final rows = <_Row>[_Row()];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> submit() async {
            final valid = rows
                .where(
                  (r) =>
                      r.food != null && Validators.quantity(r.qty.text) == null,
                )
                .toList();
            if (valid.isEmpty) {
              showMessage(
                ctx,
                'Hãy chọn thực phẩm và nhập số lượng > 0 cho ít nhất một dòng',
                error: true,
              );
              return;
            }
            try {
              final r = await vm.addItem([
                for (final row in valid)
                  (
                    foodName: row.food!.name,
                    quantity: Validators.parseQuantity(row.qty.text)!,
                  ),
              ]);
              if (!ctx.mounted) return;
              if (r.failed.isEmpty) {
                Navigator.pop(sheetCtx);
                showMessage(context, 'Đã thêm ${r.createdCount} món');
              } else {
                // Giữ lại các dòng lỗi để người dùng sửa
                final failedNames = r.failed
                    .map((f) => f.foodName.toLowerCase())
                    .toSet();
                setSheet(
                  () => rows.removeWhere(
                    (row) =>
                        row.food != null &&
                        !failedNames.contains(row.food!.name.toLowerCase()),
                  ),
                );
                showMessage(
                  ctx,
                  'Đã thêm ${r.createdCount} món. Chưa thêm được:\n${r.failed.map((f) => '• ${f.foodName}: ${f.message}').join('\n')}',
                  error: true,
                );
              }
            } on ApiException catch (e) {
              if (ctx.mounted) showMessage(ctx, e.message, error: true);
            }
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Thêm món cần mua',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final row in rows)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: OutlinedButton(
                                  onPressed: () async {
                                    final f = await pickFood(ctx);
                                    if (f != null) setSheet(() => row.food = f);
                                  },
                                  child: Text(
                                    row.food?.name ?? 'Chọn thực phẩm',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: row.qty,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  textAlign: TextAlign.right,
                                  decoration: InputDecoration(
                                    hintText: 'SL',
                                    suffixText: row.food?.unit.name,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: rows.length > 1
                                    ? () => setSheet(() => rows.remove(row))
                                    : null,
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setSheet(() => rows.add(_Row())),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm dòng'),
                ),
                const SizedBox(height: 8),
                ListenableBuilder(
                  listenable: vm,
                  builder: (_, __) => PrimaryButton(
                    saving: vm.saving,
                    onPressed: submit,
                    label: 'Thêm vào danh sách',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Row {
  Food? food;
  final TextEditingController qty = TextEditingController(text: '1');
}
