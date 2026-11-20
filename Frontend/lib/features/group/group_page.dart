import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import './account_service.dart';
import '../auth/session_service.dart';
import '../../core/utils/validators.dart';
import '../user/user.dart';
import './group_modal.dart';
import './invite_member_modal.dart';

import '../../core/api_client.dart';
import '../../core/utils/app_colors.dart';
import '../../core/utils/mock_data.dart';
import '../../core/base_view_model.dart';
import '../../core/widgets/widgets_common.dart';
import '../../core/widgets/badge_widget.dart';
import '../../core/widgets/base_modal_bottom_sheet.dart';
import '../../core/widgets/buttons/primary_button.dart';
import '../../core/widgets/buttons/outline_button.dart';
import '../../core/widgets/buttons/icon_button_widget.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/info_row.dart';

class GroupViewModel extends BaseViewModel {
  GroupViewModel(this._account, this._session);
  final AccountService _account;
  final SessionService _session;

  Group? group;
  bool get hasGroup => _session.hasGroup;
  bool get isLeader => _session.isLeader;
  int? get myId => _session.user?.id;

  Future<void> load() => runLoad(() async {
    if (!_session.hasGroup) {
      group = null;
      return;
    }
    try {
      group = await _account.group();
    } on ApiException catch (e) {
      if (e.code == '00096') {
        // Đã bị xóa khỏi nhóm ở thiết bị khác
        await _session.refreshProfile();
        group = null;
      } else {
        rethrow;
      }
    }
  });

  Future<void> add(String username) =>
      runSave(() async => group = await _account.addMember(username));
  Future<void> remove(Member m) => runSave(
    () async => group = await _account.removeMember(m.username ?? ''),
  );
  Future<void> transfer(Member m) => runSave(
    () async => group = await _account.transferLeader(m.username ?? ''),
  );
  Future<void> leave() => runSave(() async {
    await _account.leaveGroup();
    group = null;
  });
}

/// UC02 - Quản lý nhóm gia đình.
class GroupPage extends StatelessWidget {
  const GroupPage({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (c) =>
        GroupViewModel(c.read<AccountService>(), c.read<SessionService>())
          ..load(),
    child: const _GroupView(),
  );
}

class _GroupView extends StatelessWidget {
  const _GroupView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GroupViewModel>();
    final group = vm.group;
    return Scaffold(
      backgroundColor: AppColor.emerald50,
      extendBody: true,
      // floatingActionButton: group != null && vm.isLeader
      //     ? GestureDetector(
      //         onTap: () async {
      //           await promptText(
      //             context,
      //             title: 'Thêm thành viên',
      //             label: 'Tên người dùng (username)',
      //             validator: Validators.username,
      //             confirmText: 'Thêm',
      //           );
      //         },
      //         child: Container(
      //           padding: const EdgeInsets.all(8),
      //           decoration: BoxDecoration(
      //             color: AppColor.primary,
      //             borderRadius: BorderRadius.circular(8),
      //             boxShadow: [
      //               BoxShadow(
      //                 color: AppColor.gray400.withValues(alpha: 0.2),
      //                 blurRadius: 4,
      //                 offset: Offset(0, 4),
      //               ),
      //             ],
      //           ),
      //           child: Icon(
      //             LucideIcons.userPlus,
      //             color: AppColor.white,
      //             size: 24,
      //           ),
      //         ),
      //       )
      //     : null,
      body: vm.loading && group == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildHeader(context, vm),
                    const SizedBox(height: 16),
                    if (!vm.hasGroup)
                      _buildCreateOrJoinGroupSection(context, vm)
                    else ...[
                      const SizedBox(height: 16),
                      _buildGroupCard(context),
                      const SizedBox(height: 16),
                      _buildMemberSection(context, vm),
                    ],
                  ],
                ),
                // : AsyncSection(
                //     loading: vm.loading,
                //     error: vm.loadError,
                //     isEmpty: g == null,
                //     onRetry: vm.load,
                //     child: ListView(
                //       children: [
                //         const Padding(
                //           padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                //           child: Text(
                //             'Thành viên chia sẻ chung danh sách mua sắm, tủ lạnh, công thức và kế hoạch bữa ăn.',
                //             style: TextStyle(color: AppColor.muted),
                //           ),
                //         ),
                //         for (final m in g?.members ?? const <Member>[])
                //           _memberTile(context, vm, m),
                //         const SizedBox(height: 16),
                //         Padding(
                //           padding: const EdgeInsets.symmetric(horizontal: 16),
                //           child: OutlinedButton.icon(
                //             style: OutlinedButton.styleFrom(
                //               foregroundColor: AppColor.danger,
                //             ),
                //             onPressed: () async {
                //               final alone = (g?.members.length ?? 0) <= 1;
                //               final ok = await confirmDialog(
                //                 context,
                //                 title: 'Rời nhóm',
                //                 message: alone
                //                     ? 'Bạn là thành viên cuối cùng. Rời nhóm sẽ GIẢI TÁN nhóm và xóa toàn bộ dữ liệu của nhóm.'
                //                     : 'Bạn sẽ không còn xem được dữ liệu của nhóm.',
                //                 confirmText: 'Rời nhóm',
                //               );
                //               if (ok && context.mounted)
                //                 await runAction(
                //                   context,
                //                   vm.leave,
                //                   success: 'Đã rời nhóm',
                //                 );
                //             },
                //             icon: const Icon(Icons.logout),
                //             label: const Text('Rời nhóm'),
                //           ),
                //         ),
                //         const SizedBox(height: 90),
                //       ],
                //     ),
                //   ),
              ),
            ),
    );
  }

  Widget _buildHeader(BuildContext context, GroupViewModel vm) {
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
            'Nhóm gia đình',
            style: TextStyle(
              color: AppColor.gray800,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (vm.hasGroup)
            IconButtonWidget(
              icon: LucideIcons.edit3,
              onTap: () async {
                final result = await showBaseModalBottomSheet<String>(
                  context: context,
                  title: 'Đổi tên nhóm',
                  icon: LucideIcons.penLine,
                  subtitle: 'Tên nhóm mới sẽ hiển thị với các thành viên khác.',
                  child: GroupModal(group: vm.group),
                );
                if (result != null && context.mounted) {
                  vm.load();
                }
              },
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildCreateOrJoinGroupSection(
    BuildContext context,
    GroupViewModel vm,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColor.gray50,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColor.gray400.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              LucideIcons.usersCollaboration,
              size: 32,
              color: AppColor.gray400,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Bạn chưa có nhóm gia đình',
            style: TextStyle(
              color: AppColor.emerald500,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tạo nhóm mới hoặc tham gia nhóm bằng mã để chia sẻ danh sách mua sắm, tủ lạnh, công thức và kế hoạch bữa ăn',
            style: TextStyle(
              color: AppColor.gray600,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),
          PrimaryButton(
            saving: vm.saving,
            onPressed: () async {
              final result = await showBaseModalBottomSheet<int>(
                context: context,
                title: 'Tạo nhóm mới',
                icon: LucideIcons.userStar,
                subtitle: 'Người tạo nhóm trở thành trưởng nhóm.',
                child: GroupModal(),
              );

              if (result != null && context.mounted) {
                vm.load();
              }
            },
            label: 'Tạo nhóm mới',
          ),
          const SizedBox(height: 8),
          OutlineButton(
            onPressed: () {},
            backgroundColor: AppColor.amber50,
            labelColor: AppColor.amber500,
            label: 'Tham gia nhóm bằng mã',
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(BuildContext context) {
    final Group group = MockData.getCurrentGroup();
    final Member leader = group.members.firstWhere((m) => m.role == 'admin');
    final User currentUser = MockData.getCurrentUser();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColor.primary,
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
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            child: Text(
              group.name,
              style: const TextStyle(
                color: AppColor.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(16)),
              color: AppColor.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          height: 36,
                          width: group.members.length > 5
                              ? 5 * 24.0 + 12
                              : (group.members.isEmpty
                                    ? 0
                                    : (group.members.length - 1) * 24.0 + 36),
                          child: Stack(
                            children: List.generate(
                              group.members.length > 5
                                  ? 5
                                  : group.members.length,
                              (index) {
                                return Positioned(
                                  left: index * 24.0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppColor.gray200,
                                      child: Text(
                                        group.members.isNotEmpty
                                            ? group.members[0].name[0]
                                            : '',
                                        style: const TextStyle(
                                          color: AppColor.gray500,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        if (group.members.length > 5) ...[
                          const SizedBox(width: 8),
                          Text(
                            '+${group.members.length - 5} thành viên',
                            style: const TextStyle(
                              color: AppColor.gray600,
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${group.members.length.toString()} thành viên',
                      style: const TextStyle(
                        color: AppColor.gray600,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const Divider(
                  height: 17,
                  color: AppColor.gray200,
                  thickness: 1,
                ),
                InfoRow(label: 'Trưởng nhóm', value: leader.name),
                const SizedBox(height: 8),
                InfoRow(label: 'Mã nhóm', value: '1A2B3C4D'),
                const SizedBox(height: 8),
                InfoRow(label: 'Ngày tạo', value: '11/11/2026'),
                const SizedBox(height: 8),
                if (currentUser.groupRole == 'admin') ...[
                  OutlineButton(
                    onPressed: () {
                      showBaseModalBottomSheet(
                        context: context,
                        title: 'Mời thành viên mới',
                        icon: LucideIcons.userPlus,
                        subtitle: 'Nhập tên người dùng của người bạn muốn mời.',
                        child: InviteMemberModal(
                          currentMemberIds: group.members
                              .map((m) => m.id)
                              .toList(),
                        ),
                      );
                    },
                    label: 'Thêm thành viên',
                  ),
                  const SizedBox(height: 8),
                  OutlineButton(
                    onPressed: () async {
                      // 1. Lưu mã nhóm vào bộ nhớ tạm
                      await Clipboard.setData(ClipboardData(text: '1A2B3C4D'));

                      // 2. Kiểm tra context còn tồn tại trước khi hiện thông báo
                      if (!context.mounted) return;

                      // 3. Hiển thị thông báo xác nhận cho người dùng[cite: 5]
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Đã sao chép mã nhóm: 1A2B3C4D'),
                          duration: const Duration(seconds: 3),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    backgroundColor: AppColor.amber50,
                    label: 'Sao chép mã nhóm',
                    labelColor: AppColor.amber500,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberSection(BuildContext context, GroupViewModel vm) {
    // final group = vm.group;
    final group = MockData.getCurrentGroup();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Danh sách thành viên',
            style: TextStyle(
              color: AppColor.gray800,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (group.members.isEmpty)
            const EmptyStateWidget(
              message: 'Chưa có thành viên nào trong nhóm.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: group.members.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final member = group.members[index];
                return _buildMemberItemCard(member);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMemberItemCard(Member member) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColor.white,
        border: Border.all(color: AppColor.gray200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColor.gray200,
            child: Text(
              member.name.isNotEmpty ? member.name[0] : '',
              style: const TextStyle(
                color: AppColor.gray500,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  member.name,
                  style: const TextStyle(
                    color: AppColor.gray600,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (member.isLeader)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColor.amber100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.crown,
                      color: AppColor.amber500,
                      size: 16,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _memberTile(BuildContext context, GroupViewModel vm, Member m) {
    final isMe = m.id == vm.myId;
    return Card(
      child: ListTile(
        leading: NetImage(m.imageUrl, circle: true, icon: Icons.person),
        title: Text(isMe ? '${m.name} (bạn)' : m.name),
        subtitle: Text(
          m.username != null ? '@${m.username}' : 'Chưa đặt username',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (m.isLeader)
              const BadgeWidget(
                label: 'Trưởng nhóm',
                badgeColor: AppColor.primary,
                labelColor: AppColor.white,
              ),
            if (vm.isLeader && !isMe)
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'leader') {
                    if (await confirmDialog(
                          context: context,
                          icon: LucideIcons.crown,
                          title: 'Chuyển quyền trưởng nhóm',
                          message:
                              '${m.name} sẽ trở thành trưởng nhóm, bạn trở thành thành viên.',
                          confirmText: 'Chuyển',
                          danger: false,
                        ) &&
                        context.mounted) {
                      await runAction(
                        context,
                        () => vm.transfer(m),
                        success: 'Đã chuyển quyền trưởng nhóm',
                      );
                    }
                  } else if (v == 'remove') {
                    if (await confirmDialog(
                          context: context,
                          icon: LucideIcons.trash2,
                          title: 'Xóa thành viên',
                          message:
                              'Xóa ${m.name} khỏi nhóm? Các danh sách giao cho người này sẽ chuyển về "chưa giao".',
                        ) &&
                        context.mounted) {
                      await runAction(
                        context,
                        () => vm.remove(m),
                        success: 'Đã xóa ${m.name} khỏi nhóm',
                      );
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'leader',
                    child: Text('Chuyển quyền trưởng nhóm'),
                  ),
                  PopupMenuItem(value: 'remove', child: Text('Xóa khỏi nhóm')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
