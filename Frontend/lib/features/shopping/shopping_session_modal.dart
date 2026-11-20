import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../group/account_service.dart';
import '../auth/session_service.dart';
import 'shopping_service.dart';
import '../../core/utils/validators.dart';
import 'shopping.dart';
import '../user/user.dart';
import '../../core/api_client.dart';
import '../../core/widgets/widgets_common.dart';
import '../../core/utils/app_colors.dart';
import '../../core/widgets/buttons/primary_button.dart';
import '../../core/widgets/custom_text_form_field.dart';
import 'shopping_session_view_model.dart';

/// Tạo/sửa phiên mua sắm (trưởng nhóm). Người được giao chỉ chọn trong thành viên cùng nhóm.
/// Khi tạo mới, trả về id phiên để chuyển sang bước thêm mục.
class ShoppingSessionModal extends StatelessWidget {
  const ShoppingSessionModal({super.key, this.session});
  final ShoppingSession? session;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (c) => ShoppingSessionFormViewModel(
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
  late final TextEditingController _nameController = TextEditingController(
    text: widget.session?.name ?? '',
  );
  late final TextEditingController _noteController = TextEditingController(
    text: widget.session?.note ?? '',
  );
  late String? _assignee;
  bool saving = false;

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
    final vm = context.read<ShoppingSessionFormViewModel>();
    try {
      final l = await vm.submitForm(
        existing: widget.session,
        name: _nameController.text,
        assignee: _assignee,
        note: _noteController.text,
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
        Navigator.pop(context);
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
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ShoppingSessionFormViewModel>();
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

    return Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomTextFormField(
            labelText: 'Tên phiên mua sắm',
            hintText: 'Nhập tên phiên mua sắm',
            controller: _nameController,
            validator: (v) =>
                Validators.required(v, 'Tên phiên mua sắm') ??
                Validators.maxLength(v, 150, 'Tên phiên mua sắm'),
          ),
          const SizedBox(height: 16),
          _buildShoppingAssignmentSection(vm.members),
          const SizedBox(height: 16),
          CustomTextFormField(
            labelText: 'Ghi chú (tùy chọn)',
            hintText: 'Nhập ghi chú cho phiên mua sắm (nếu cần)',
            controller: _noteController,
            maxLines: 3,
            maxLength: 1000,
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            saving: vm.saving,
            onPressed: _submit,
            label: widget.session == null
                ? 'Tạo phiên mua sắm'
                : 'Lưu thay đổi',
          ),
        ],
      ),
    );
  }

  Widget _buildShoppingAssignmentSection(List<Member> members) {
    return Column(
      children: [
        const Row(
          children: [
            Text(
              'Phân công người mua',
              style: TextStyle(
                color: AppColor.gray600,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
            SizedBox(width: 4),
            Text(
              '*',
              style: TextStyle(
                color: AppColor.red500,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              return _buildMemberSelector(member);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMemberSelector(Member member) {
    final isSelected = member.username == _assignee;
    return GestureDetector(
      onTap: () {
        setState(() {
          _assignee = isSelected ? null : member.username;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? AppColor.emerald50 : AppColor.gray50,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? AppColor.emerald500 : AppColor.gray200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColor.gray200,
              child: Text(
                member.name.isNotEmpty ? member.name[0] : '',
                style: const TextStyle(
                  color: AppColor.gray500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              member.name,
              style: TextStyle(
                color: isSelected ? AppColor.emerald500 : AppColor.gray600,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              const Icon(
                LucideIcons.check,
                color: AppColor.emerald500,
                size: 24,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
