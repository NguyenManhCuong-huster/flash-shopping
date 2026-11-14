import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../widgets/text_field.dart';
import '../utils/app_colors.dart';
import '../widgets/submit_buttons.dart';

class InviteMemberModal extends StatefulWidget {
  final List<int> currentMemberIds;
  const InviteMemberModal({super.key, required this.currentMemberIds});

  @override
  State<InviteMemberModal> createState() => _InviteMemberModalState();
}

class _InviteMemberModalState extends State<InviteMemberModal> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  List<Map<String, dynamic>> _filteredUsers = [];
  Map<String, dynamic>? _selectedUser;

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredUsers = [];
        _selectedUser = null;
      });
      return;
    }

    // final results = .users.where((user) {
    //   final email = user['email'].toString().toLowerCase();
    //   return email.contains(query.toLowerCase());
    // }).toList();

    setState(() {
      // _filteredUsers = results;
      _selectedUser = null;
    });
  }

  void _sendInvite() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUser == null) return;

    // Lấy thông tin user ra để sử dụng
    final String invitedName = _selectedUser!['name'];
    final String invitedEmail = _selectedUser!['email'];

    // THÀNH CÔNG: Hiển thị widget thông báo (SnackBar)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.checkCircle2, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Đã gửi lời mời tham gia ví tới $invitedName ($invitedEmail)',
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
      _emailController.clear();
      _filteredUsers = [];
      _selectedUser = null;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Thêm thành viên',
              style: TextStyle(
                color: AppColor.gray800,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextFieldWidget(
              labelText: 'Email',
              hintText: 'member@example.com',
              controller: _emailController,
              onChanged: _onSearchChanged,
            ),
            if (_filteredUsers.isNotEmpty) _buildMemberListDropdown(),
            if (_selectedUser != null) ...[
              const SizedBox(height: 16),
              _buildMemberPreviewCard(
                _selectedUser?['name'],
                _selectedUser?['email'],
                _selectedUser?['avatarUrl'],
              ),
            ],
            const SizedBox(height: 16),
            SubmitButtons(
              submitText: 'Gửi lời mời',
              cancelText: 'Hủy',
              onSubmit: _sendInvite,
              onCancel: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberListDropdown() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppColor.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColor.gray200),
        boxShadow: [
          BoxShadow(
            color: AppColor.gray500.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: Offset(0, 4),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxHeight: 120), // Giới hạn chiều cao
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _filteredUsers.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final user = _filteredUsers[index];
          final bool isAlreadyMember = widget.currentMemberIds.contains(
            user['id'],
          );

          return ListTile(
            onTap: isAlreadyMember
                ? null
                : () {
                    setState(() {
                      _emailController.text = user['email'];
                      _selectedUser = user;
                      _filteredUsers = [];
                    });
                  },
            contentPadding: const EdgeInsets.all(8),
            leading: CircleAvatar(
              backgroundImage: NetworkImage(user['avatarUrl']),
            ),
            title: Text(
              user['name'],
              style: TextStyle(
                color: AppColor.gray800,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              user['email'],
              style: TextStyle(
                color: AppColor.gray500,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
            trailing: isAlreadyMember
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColor.gray200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Đã tham gia',
                      style: TextStyle(
                        color: AppColor.gray500,
                        fontSize: 16,
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
    String memberEmail,
    String memberAvatarUrl,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColor.blue50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColor.blue100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lời mời sẽ được gửi tới:',
            style: TextStyle(
              color: AppColor.blue500,
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
                backgroundImage: NetworkImage(memberAvatarUrl),
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
                    memberEmail,
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
