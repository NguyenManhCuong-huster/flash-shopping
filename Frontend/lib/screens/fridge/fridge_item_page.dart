import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../application/pantry_service.dart';
import '../../application/validation/validators.dart';
import '../../data/models/food.dart';
import '../../data/remote/api_client.dart';
import '../../utils/app_colors.dart';
import '../../utils/date_time_utils.dart';
import '../shared/base_view_model.dart';
import '../shared/format.dart';
import '../../utils/theme.dart';
import '../shared/widgets.dart';
import '../../modals/fridge_item_modal.dart';
import '../../widgets/badge_widget.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/buttons/outline_button.dart';
import '../../widgets/buttons/icon_button_widget.dart';
import '../../widgets/info_row.dart';

class FridgeItemViewModel extends BaseViewModel {
  FridgeItemViewModel(
    this._pantry,
    this.fridgeItemId, {
    this.fridgeItem,
  }); // TEMP_MOCK_START
  final PantryService _pantry;
  final int fridgeItemId;
  final FridgeItem? fridgeItem; // TEMP_MOCK_START

  FridgeItem? _fridgeItem;
  bool removed = false;

  /// Trả về dữ liệu hiển thị: ưu tiên _fridgeItem, fallback về mock fridgeItem nếu chưa load
  FridgeItem? get fridgeItemData =>
      _fridgeItem ?? fridgeItem; // TEMP_MOCK_START

  Future<void> load() =>
      runLoad(() async => _fridgeItem = await _pantry.fridgeItem(fridgeItemId));

  /// Trả về true nếu đã dùng hết (mục bị xóa khỏi tủ).
  Future<bool> consume(
    double quantity, {
    required bool discard,
    String? note,
  }) => runSave(() async {
    final updated = await _pantry.consume(
      fridgeItemData!,
      quantity,
      discard: discard,
      note: note,
    );
    if (updated == null) {
      removed = true;
      return true;
    }
    _fridgeItem = updated;
    return false;
  });

  Future<void> delete() => runSave(() async {
    await _pantry.removeFromFridge(fridgeItemData!);
    removed = true;
  });
}

/// Chi tiết mục tủ lạnh; cũng là đích mở từ thông báo nhắc hạn (UC06 bước 6).
class FridgeItemPage extends StatelessWidget {
  const FridgeItemPage({
    super.key,
    required this.fridgeItemId,
    this.fridgeItem,
  });
  final int fridgeItemId;
  final FridgeItem? fridgeItem; // TEMP_MOCK_START

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (c) => FridgeItemViewModel(
      c.read<PantryService>(),
      fridgeItemId,
      fridgeItem: fridgeItem, // TEMP_MOCK_START
    )..load(),
    child: const _FridgeItemView(),
  );
}

class _FridgeItemView extends StatelessWidget {
  const _FridgeItemView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FridgeItemViewModel>();
    final fridgeItemData = vm.fridgeItemData;
    return Scaffold(
      backgroundColor: AppColor.emerald50,
      body:
          // vm.loading && fridgeItemData == null
          //     ? const Center(child: CircularProgressIndicator())
          //     : fridgeItemData == null
          //     ? ErrorView(
          //         message:
          //             vm.loadError ??
          //             'Mục tủ lạnh không tồn tại hoặc đã được dùng hết.',
          //         onRetry: vm.load,
          //       )
          //       :
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildHeader(context, fridgeItemData!, vm),
                  const SizedBox(height: 16),
                  _buildFridgeItemInfo(context, fridgeItemData, vm),
                ],
              ),
            ),
          ),
      // : ListView(
      //     padding: const EdgeInsets.all(16),
      //     children: [
      //       Row(
      //         children: [
      //           NetImage(item.food.imageUrl, size: 72),
      //           const SizedBox(width: 16),
      //           Expanded(
      //             child: Column(
      //               crossAxisAlignment: CrossAxisAlignment.start,
      //               children: [
      //                 Text(
      //                   item.food.name,
      //                   style: const TextStyle(
      //                     fontSize: 20,
      //                     fontWeight: FontWeight.bold,
      //                   ),
      //                 ),
      //                 Text(
      //                   item.food.category.name,
      //                   style: const TextStyle(color: AppColor.muted),
      //                 ),
      //                 const SizedBox(height: 4),
      //                 BadgeWidget(
      //                   label: item.status.label,
      //                   badgeColor: item.status.badgeColor,
      //                   labelColor: item.status.labelColor,
      //                 ),
      //               ],
      //             ),
      //           ),
      //         ],
      //       ),
      //       const SizedBox(height: 16),
      //       _row(
      //         'Số lượng',
      //         fmtQtyUnit(item.quantity, item.food.unit.name),
      //       ),
      //       _row('Hạn sử dụng', DateTimeUtils.formatDate(item.useWithin)),
      //       _row('Vị trí', item.location.label),
      //       if (item.note != null) _row('Ghi chú', item.note!),
      //       const SizedBox(height: 24),
      //       Row(
      //         children: [
      //           Expanded(
      //             child: FilledButton.icon(
      //               onPressed: vm.saving
      //                   ? null
      //                   : () => _consume(context, vm, discard: false),
      //               icon: const Icon(Icons.restaurant),
      //               label: const Text('Đã dùng'),
      //             ),
      //           ),
      //           const SizedBox(width: 12),
      //           Expanded(
      //             child: OutlinedButton.icon(
      //               style: OutlinedButton.styleFrom(
      //                 foregroundColor: AppColor.danger,
      //               ),
      //               onPressed: vm.saving
      //                   ? null
      //                   : () => _consume(context, vm, discard: true),
      //               icon: const Icon(Icons.delete_sweep_outlined),
      //               label: const Text('Bỏ đi / hỏng'),
      //             ),
      //           ),
      //         ],
      //       ),
      //     ],
      //   ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    FridgeItem fridgeItem,
    FridgeItemViewModel vm,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButtonWidget(
            icon: LucideIcons.arrowLeft,
            onTap: () {
              Navigator.pop(context);
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: const Text(
              'Chi tiết món đồ',
              style: TextStyle(
                color: AppColor.gray800,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 16),
          IconButtonWidget(
            icon: LucideIcons.edit,
            onTap: () async {
              await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                backgroundColor: AppColor.gray50,
                builder: (context) => FridgeItemModal(item: fridgeItem),
              );
            },
          ),
          const SizedBox(width: 8),
          IconButtonWidget(
            icon: LucideIcons.trash2,
            onTap: () async {
              if (await confirmDialog(
                    context,
                    title: 'Xóa khỏi tủ lạnh',
                    message:
                        'Xóa ${fridgeItem.food.name} khỏi tủ lạnh? (Không tính là tiêu thụ)',
                  ) &&
                  context.mounted) {
                final ok = await runAction(context, () async {
                  await vm.delete();
                  return true;
                }, success: 'Đã xóa');
                if (ok == true && context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFridgeItemInfo(
    BuildContext context,
    FridgeItem fridgeItem,
    FridgeItemViewModel vm,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColor.gray50,
              border: Border.all(color: AppColor.gray200),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NetImage(fridgeItem.food.imageUrl, size: 48),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fridgeItem.food.name,
                                style: const TextStyle(
                                  color: AppColor.gray800,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                fridgeItem.food.category.name,
                                style: const TextStyle(
                                  color: AppColor.gray600,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                          ),
                          const SizedBox(width: 8),
                          BadgeWidget(
                            label: fridgeItem.status.label,
                            badgeColor: fridgeItem.status.badgeColor,
                            labelColor: fridgeItem.status.labelColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(
                  height: 17,
                  thickness: 1,
                  color: AppColor.gray200,
                ),
                InfoRow(
                  label: 'Định lượng',
                  value: '${fridgeItem.quantity} ${fridgeItem.food.unit.name}',
                ),
                const SizedBox(height: 8),
                InfoRow(
                  label: 'Hạn sử dụng',
                  value: DateTimeUtils.formatDate(fridgeItem.useWithin),
                ),
                const SizedBox(height: 8),
                InfoRow(label: 'Vị trí', value: fridgeItem.location.label),

                if (fridgeItem.note != null) ...[
                  const SizedBox(height: 8),
                  InfoRow(label: 'Ghi chú', value: fridgeItem.note!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            saving: vm.saving,
            onPressed: vm.saving
                ? null
                : () => _consume(context, vm, discard: false),
            label: 'Đã dùng',
            icon: LucideIcons.circleCheckBig,
          ),
          const SizedBox(height: 8),
          OutlineButton(
            onPressed: vm.saving
                ? null
                : () => _consume(context, vm, discard: true),
            backgroundColor: AppColor.red50,
            label: 'Vứt bỏ / hỏng',
            labelColor: AppColor.red500,
            icon: LucideIcons.trash2,
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(color: AppColor.muted)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  /// UC05: ghi nhận tiêu thụ/hủy bỏ. Lượng phải dương và không vượt tồn (backend kiểm tra lại trong giao dịch).
  Future<void> _consume(
    BuildContext context,
    FridgeItemViewModel vm, {
    required bool discard,
  }) async {
    final item = vm.fridgeItemData!;
    final ctrl = TextEditingController(
      text: fmtQty(item.quantity).replaceAll(',', '.'),
    );
    final note = TextEditingController();
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          discard ? 'Bỏ đi ${item.food.name}' : 'Đã dùng ${item.food.name}',
        ),
        content: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: ctrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Lượng (${item.food.unit.name})',
                  helperText:
                      'Còn ${fmtQtyUnit(item.quantity, item.food.unit.name)}',
                ),
                validator: (v) {
                  final err = Validators.quantity(v, field: 'Lượng');
                  if (err != null) return err;
                  if (Validators.parseQuantity(v)! > item.quantity)
                    return 'Không được vượt quá lượng còn lại (${fmtQty(item.quantity)})';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: note,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú (tùy chọn)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () =>
                key.currentState!.validate() ? Navigator.pop(ctx, true) : null,
            child: const Text('Ghi nhận'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final depleted = await vm.consume(
        Validators.parseQuantity(ctrl.text)!,
        discard: discard,
        note: note.text.trim().isEmpty ? null : note.text.trim(),
      );
      if (!context.mounted) return;
      showMessage(
        context,
        depleted
            ? 'Đã dùng hết ${item.food.name}, mục đã được xóa khỏi tủ lạnh.'
            : 'Đã ghi nhận',
      );
      if (depleted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      if (e.code == '00523') {
        // Người khác vừa cập nhật: tải lại thay vì ghi đè (UC05 - 4b)
        showMessage(context, e.message, error: true);
        vm.load();
      } else {
        showMessage(
          context,
          e.message,
          error: true,
          retry: e.network
              ? () => _consume(context, vm, discard: discard)
              : null,
        );
      }
    }
  }
}
