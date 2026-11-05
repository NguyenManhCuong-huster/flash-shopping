import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/account_service.dart';
import '../../application/session_service.dart';
import '../../application/validation/validators.dart';
import '../../data/models/user.dart';
import '../../data/remote/api_client.dart';
import '../shared/base_view_model.dart';
import '../shared/theme.dart';
import '../shared/widgets.dart';

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

  Future<void> create(String? name) => runSave(() async => group = await _account.createGroup(name));
  Future<void> rename(String name) => runSave(() async => group = await _account.renameGroup(name));
  Future<void> add(String username) => runSave(() async => group = await _account.addMember(username));
  Future<void> remove(Member m) => runSave(() async => group = await _account.removeMember(m.username ?? ''));
  Future<void> transfer(Member m) => runSave(() async => group = await _account.transferLeader(m.username ?? ''));
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
        create: (c) => GroupViewModel(c.read<AccountService>(), c.read<SessionService>())..load(),
        child: const _GroupView(),
      );
}

class _GroupView extends StatelessWidget {
  const _GroupView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GroupViewModel>();
    final g = vm.group;
    return Scaffold(
      appBar: AppBar(
        title: Text(g?.name ?? 'Nhóm gia đình'),
        actions: [
          if (g != null && vm.isLeader)
            IconButton(
              tooltip: 'Đổi tên nhóm',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final name = await promptText(context, title: 'Đổi tên nhóm', initial: g.name, validator: (v) => Validators.required(v, 'Tên nhóm'));
                if (name != null && context.mounted) await runAction(context, () => vm.rename(name), success: 'Đã đổi tên nhóm');
              },
            ),
        ],
      ),
      floatingActionButton: g != null && vm.isLeader
          ? FloatingActionButton.extended(
              onPressed: () async {
                final u = await promptText(context, title: 'Thêm thành viên', label: 'Tên người dùng (username)', validator: Validators.username, confirmText: 'Thêm');
                if (u != null && context.mounted) await runAction(context, () => vm.add(u), success: 'Đã thêm $u vào nhóm');
              },
              icon: const Icon(Icons.person_add),
              label: const Text('Thêm thành viên'),
            )
          : null,
      body: vm.loading && g == null
          ? const Center(child: CircularProgressIndicator())
          : !vm.hasGroup
              ? _CreateGroup(vm: vm)
              : AsyncBody(
                  loading: vm.loading,
                  error: vm.loadError,
                  isEmpty: g == null,
                  onRetry: vm.load,
                  child: ListView(children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text('Thành viên chia sẻ chung danh sách mua sắm, tủ lạnh, công thức và kế hoạch bữa ăn.', style: TextStyle(color: AppTheme.muted)),
                    ),
                    for (final m in g?.members ?? const <Member>[]) _memberTile(context, vm, m),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
                        onPressed: () async {
                          final alone = (g?.members.length ?? 0) <= 1;
                          final ok = await confirmDialog(
                            context,
                            title: 'Rời nhóm',
                            message: alone
                                ? 'Bạn là thành viên cuối cùng. Rời nhóm sẽ GIẢI TÁN nhóm và xóa toàn bộ dữ liệu của nhóm.'
                                : 'Bạn sẽ không còn xem được dữ liệu của nhóm.',
                            confirmText: 'Rời nhóm',
                          );
                          if (ok && context.mounted) await runAction(context, vm.leave, success: 'Đã rời nhóm');
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('Rời nhóm'),
                      ),
                    ),
                    const SizedBox(height: 90),
                  ]),
                ),
    );
  }

  Widget _memberTile(BuildContext context, GroupViewModel vm, Member m) {
    final isMe = m.id == vm.myId;
    return Card(
      child: ListTile(
        leading: NetImage(m.imageUrl, circle: true, icon: Icons.person),
        title: Text(isMe ? '${m.name} (bạn)' : m.name),
        subtitle: Text(m.username != null ? '@${m.username}' : 'Chưa đặt username'),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (m.isLeader) const Pill('Trưởng nhóm'),
          if (vm.isLeader && !isMe)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'leader') {
                  if (await confirmDialog(context, title: 'Chuyển quyền trưởng nhóm', message: '${m.name} sẽ trở thành trưởng nhóm, bạn trở thành thành viên.', confirmText: 'Chuyển', danger: false) &&
                      context.mounted) {
                    await runAction(context, () => vm.transfer(m), success: 'Đã chuyển quyền trưởng nhóm');
                  }
                } else if (v == 'remove') {
                  if (await confirmDialog(context, title: 'Xóa thành viên', message: 'Xóa ${m.name} khỏi nhóm? Các danh sách giao cho người này sẽ chuyển về "chưa giao".') &&
                      context.mounted) {
                    await runAction(context, () => vm.remove(m), success: 'Đã xóa ${m.name} khỏi nhóm');
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'leader', child: Text('Chuyển quyền trưởng nhóm')),
                PopupMenuItem(value: 'remove', child: Text('Xóa khỏi nhóm')),
              ],
            ),
        ]),
      ),
    );
  }
}

class _CreateGroup extends StatefulWidget {
  const _CreateGroup({required this.vm});
  final GroupViewModel vm;
  @override
  State<_CreateGroup> createState() => _CreateGroupState();
}

class _CreateGroupState extends State<_CreateGroup> {
  final _name = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionService>().user;
    return ListView(padding: const EdgeInsets.all(24), children: [
      const Icon(Icons.family_restroom, size: 64, color: AppTheme.primary),
      const SizedBox(height: 12),
      const Text('Tạo nhóm gia đình mới', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('Người tạo nhóm trở thành trưởng nhóm và có thể thêm thành viên bằng tên người dùng.', textAlign: TextAlign.center),
      const SizedBox(height: 20),
      TextField(controller: _name, decoration: InputDecoration(labelText: 'Tên nhóm (tùy chọn)', hintText: 'Gia đình ${user?.name ?? ''}')),
      const SizedBox(height: 16),
      SaveButton(
        saving: widget.vm.saving,
        label: 'Tạo nhóm',
        icon: Icons.group_add,
        onPressed: () => runAction(context, () => widget.vm.create(_name.text), success: 'Đã tạo nhóm'),
      ),
      const SizedBox(height: 24),
      Text(
        user?.username == null
            ? 'Muốn tham gia nhóm có sẵn? Hãy đặt tên người dùng trong Hồ sơ rồi gửi cho trưởng nhóm.'
            : 'Muốn tham gia nhóm có sẵn? Gửi tên người dùng @${user!.username} cho trưởng nhóm.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.muted),
      ),
    ]);
  }
}
