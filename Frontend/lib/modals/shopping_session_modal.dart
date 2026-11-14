import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/account_service.dart';
import '../application/session_service.dart';
import '../application/shopping_service.dart';
import '../application/validation/validators.dart';
import '../data/models/shopping.dart';
import '../data/models/user.dart';
import '../data/remote/api_client.dart';
import '../screens/shared/base_view_model.dart';
import '../screens/shared/widgets.dart';
import '../utils/app_colors.dart';
import '../widgets/buttons/primary_button.dart';
import '../widgets/buttons/outline_button.dart';
import '../widgets/custom_text_form_field.dart';
import '../widgets/custom_dropdown_form_field.dart';

class ShoppingSessionViewModel extends BaseViewModel {
  ShoppingSessionViewModel(this._shopping, this._account);
  final ShoppingService _shopping;
  final AccountService _account;

  List<Member> members = [];

  Future<void> load() =>
      runLoad(() async => members = (await _account.group()).members);

  Future<ShoppingSession> save({
    ShoppingSession? existing,
    required String name,
    String? assignee,
    String? note,
  }) => runSave(
    () => existing == null
        ? _shopping.createSession(
            name: name,
            assignToUsername: assignee,
            note: note,
          )
        : _shopping.updateSession(
            existing,
            name: name,
            assignToUsername: assignee,
            note: note,
          ),
  );
}

/// Tạo/sửa phiên mua sắm (trưởng nhóm). Người được giao chỉ chọn trong thành viên cùng nhóm.
/// Khi tạo mới, trả về id phiên để chuyển sang bước thêm mục.
class ShoppingSessionModal extends StatelessWidget {
  const ShoppingSessionModal({super.key, this.session});
  final ShoppingSession? session;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (c) => ShoppingSessionViewModel(
      c.read<ShoppingService>(),
      c.read<AccountService>(),
    )..load(),
    child: _ShoppingSessionForm(session: session),
  );
}

class _ShoppingSessionForm extends StatefulWidget {
  const _ShoppingSessionForm({this.session});
  final ShoppingSession? session;
  @override
  State<_ShoppingSessionForm> createState() => _ShoppingSessionFormState();
}

class _ShoppingSessionFormState extends State<_ShoppingSessionForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.session?.name ?? '',
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.session?.note ?? '',
  );
  late String? _assignee;

  @override
  void initState() {
    super.initState();
    final currentUsername = context.read<SessionService>().user?.username;
    _assignee = widget.session?.assignedTo?.username ?? currentUsername;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_assignee == null || _assignee!.isEmpty) {
      showMessage(
        context,
        'Không xác định được người mua hiện tại.',
        error: true,
      );
      return;
    }
    final vm = context.read<ShoppingSessionViewModel>();
    try {
      final l = await vm.save(
        existing: widget.session,
        name: _name.text,
        assignee: _assignee,
        note: _note.text,
      );
      if (!mounted) return;
      showMessage(
        context,
        widget.session == null
            ? 'Đã tạo phiên mua sắm. Hãy thêm các món cần mua.'
            : 'Đã cập nhật phiên mua sắm',
      );
      Navigator.pop(context, l.id);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == '00005') {
        Navigator.pop(context); // Không có thay đổi
      } else {
        showMessage(
          context,
          e.message,
          error: true,
          retry: e.network ? _submit : null,
        );
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ShoppingSessionViewModel>();
    final withUsername = vm.members.where((m) => m.username != null).toList();
    final currentUser = context.read<SessionService>().user;
    final membersByUsername = {
      for (final member in withUsername) member.username!: member,
    };
    final usernames = [for (final member in withUsername) member.username!];
    if (_assignee != null && !usernames.contains(_assignee)) {
      usernames.insert(0, _assignee!);
      if (currentUser?.username == _assignee) {
        membersByUsername[_assignee!] = Member(
          id: currentUser!.id,
          name: currentUser.name,
          username: currentUser.username,
        );
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColor.gray300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.session == null
                  ? 'Tạo phiên mua sắm'
                  : 'Chỉnh sửa phiên mua sắm',
              style: TextStyle(
                color: AppColor.gray800,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            CustomTextFormField(
              labelText: 'Tên phiên mua sắm',
              hintText: 'Nhập tên phiên mua sắm',
              controller: _name,
              validator: (v) =>
                  Validators.required(v, 'Tên phiên mua sắm') ??
                  Validators.maxLength(v, 150, 'Tên phiên mua sắm'),
            ),
            const SizedBox(height: 16),
            CustomDropdownField<String>(
              key: ValueKey('${_assignee}_${usernames.length}'),
              labelText: 'Người mua',
              value: _assignee,
              items: usernames,
              itemLabel: (username) {
                final member = membersByUsername[username];
                return member == null
                    ? '@$username'
                    : '${member.name} (@$username)';
              },
              onChanged: (value) {
                setState(() => _assignee = value);
              },
            ),
            const SizedBox(height: 16),
            CustomTextFormField(
              labelText: 'Ghi chú (tùy chọn)',
              hintText: 'Nhập ghi chú cho phiên mua sắm',
              controller: _note,
              maxLines: 3,
              maxLength: 1000,
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              saving: vm.saving,
              onPressed: _submit,
              label: widget.session == null ? 'Tạo phiên mua sắm' : 'Lưu thay đổi',
            ),
            const SizedBox(height: 8),
            OutlineButton(
              onPressed: () => Navigator.pop(context),
              label: 'Hủy',
            ),
          ],
        ),
      ),
    );
  }
}
