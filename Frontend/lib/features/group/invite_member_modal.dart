import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../user/user.dart';
import '../../core/utils/app_colors.dart';
import '../../core/utils/mock_data.dart';
import '../../core/widgets/buttons/primary_button.dart';
import '../../core/widgets/custom_text_form_field.dart';

class InviteMemberModal extends StatefulWidget {
  final List<int> currentMemberIds;
  const InviteMemberModal({super.key, required this.currentMemberIds});

  @override
  State<InviteMemberModal> createState() => _InviteMemberModalState();
}

class _InviteMemberModalState extends State<InviteMemberModal> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _userNameController = TextEditingController();
  List<User> _filteredUsers = [];
  User? _selectedUser = null;

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredUsers = [];
        _selectedUser = null;
      });
      return;
    }

    final results = MockData.users.where((user) {
      final username = user.username.toString().toLowerCase();
      return username.contains(query.toLowerCase());
    }).toList();

    setState(() {
      _filteredUsers = results;
      _selectedUser = null;
    });
  }

  void _sendInvite() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUser == null) return;

    // Lấy thông tin user ra để sử dụng
    final String invitedName = _selectedUser!.name;
    final String invitedUsername = _selectedUser!.username ?? '';

    // THÀNH CÔNG: Hiển thị widget thông báo (SnackBar)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.checkCircle2, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Đã gửi lời mời tham gia nhóm tới $invitedName (@$invitedUsername)',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        backgroundColor: AppColor.green500,
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Reset lại giao diện sau khi gửi thành công
    setState(() {
      _userNameController.clear();
      _filteredUsers = [];
      _selectedUser = null;
    });
  }

  @override
  void dispose() {
    _userNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomTextFormField(
            labelText: 'Tên người dùng',
            hintText: 'Nhập tên người dùng',
            controller: _userNameController,
            onChanged: _onSearchChanged,
            // validator: (v) => Validators.required(v, 'Tên người dùng'),
          ),
          if (_filteredUsers.isNotEmpty) _buildMemberListDropdown(),
          if (_selectedUser != null) ...[
            const SizedBox(height: 16),
            _buildMemberPreviewCard(
              _selectedUser!.name,
              _selectedUser!.username,
              _selectedUser!.imageUrl ?? '',
            ),
          ],
          const SizedBox(height: 16),
          PrimaryButton(
            saving: false,
            label: 'Gửi lời mời',
            onPressed: _sendInvite,
          ),
        ],
      ),
    );
  }

  Widget _buildMemberListDropdown() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppColor.gray50,
        border: Border.all(color: AppColor.gray200),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColor.gray400.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: Offset(0, 4),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxHeight: 240),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _filteredUsers.length,
        separatorBuilder: (context, index) => const Divider(height: 1, color: AppColor.gray200),
        itemBuilder: (context, index) {
          final user = _filteredUsers[index];
          final bool isAlreadyMember = widget.currentMemberIds.contains(user.id);
          return ListTile(
            onTap: isAlreadyMember
                ? null
                : () {
                    setState(() {
                      _userNameController.text = user.username;
                      _selectedUser = user;
                      _filteredUsers = [];
                    });
                  },
            contentPadding: const EdgeInsets.all(8),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: AppColor.gray200,
              child: Text(
                user.name.isNotEmpty ? user.name[0] : '',
                style: const TextStyle(
                  color: AppColor.gray500,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            title: Text(
              user.name,
              style: TextStyle(
                color: AppColor.gray800,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '@${user.username}',
              style: TextStyle(
                color: AppColor.gray500,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
            trailing: isAlreadyMember
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColor.amber50,
                      border: Border.all(color: AppColor.amber500),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Đã tham gia',
                      style: TextStyle(
                        color: AppColor.amber500,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }

  Widget _buildMemberPreviewCard(
    String memberName,
    String memberUsername,
    String memberAvatarUrl,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColor.emerald50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColor.emerald200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lời mời sẽ được gửi tới:',
            style: TextStyle(
              color: AppColor.emerald500,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColor.gray200,
                child: memberAvatarUrl.isEmpty
                    ? Text(
                        memberName.isNotEmpty ? memberName[0] : '',
                        style: const TextStyle(
                          color: AppColor.gray500,
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    memberName,
                    style: TextStyle(
                      color: AppColor.gray800,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '@$memberUsername',
                    style: TextStyle(
                      color: AppColor.gray500,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
