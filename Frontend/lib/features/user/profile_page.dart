import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../group/account_service.dart';
import '../auth/session_service.dart';
import '../../core//utils/validators.dart';
import 'user.dart';
import '../../core/utils/app_colors.dart';
import '../../core/base_view_model.dart';
import '../../core/widgets/widgets_common.dart';
import '../../core/widgets/buttons/primary_button.dart';
import '../../core/widgets/buttons/outline_button.dart';
import '../../core/widgets/buttons/icon_button_widget.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/custom_text_form_field.dart';
import '../../core/widgets/custom_dropdown_field.dart';

class ProfileViewModel extends BaseViewModel {
  ProfileViewModel(this._account);
  final AccountService _account;

  Future<void> save({
    String? name,
    String? username,
    String? language,
    String? timezone,
    File? image,
  }) => runSave(
    () => _account.updateProfile(
      name: name,
      username: username,
      language: language,
      timezone: timezone,
      image: image,
    ),
  );
  Future<String> changePassword(String oldP, String newP) =>
      runSave(() => _account.changePassword(oldP, newP));
  Future<void> deleteAccount() => runSave(_account.deleteAccount);
}

const _timezones = [
  'Asia/Ho_Chi_Minh',
  'Asia/Bangkok',
  'Asia/Singapore',
  'Asia/Tokyo',
  'Asia/Seoul',
  'Europe/London',
  'Europe/Paris',
  'America/New_York',
  'Australia/Sydney',
  'UTC',
];

/// UC12 - Quản lý tài khoản cá nhân.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (c) => ProfileViewModel(c.read<AccountService>()),
    child: const _ProfileView(),
  );
}

class _ProfileView extends StatefulWidget {
  const _ProfileView();
  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _username;
  late String _selectedLanguage;
  late String _selectedTimezone;
  File? _image;

  @override
  void initState() {
    super.initState();
    final u = context.read<SessionService>().user!;
    _name = TextEditingController(text: u.name);
    _username = TextEditingController(text: u.username ?? '');
    _selectedLanguage = u.language.code;
    _selectedTimezone = u.timezone;
  }

  Future<void> _pick() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (x != null) setState(() => _image = File(x.path));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final u = context.read<SessionService>().user!;
    final vm = context.read<ProfileViewModel>();
    final name = _name.text.trim() != u.name ? _name.text.trim() : null;
    final username = _username.text.trim() != (u.username ?? '')
        ? _username.text.trim()
        : null;
    final language = _selectedLanguage != u.language ? _selectedLanguage : null;
    final timezone = _selectedTimezone != u.timezone ? _selectedTimezone : null;
    if (name == null &&
        username == null &&
        language == null &&
        timezone == null &&
        _image == null) {
      return showMessage(context, 'Không có thay đổi nào để lưu');
    }
    await runAction(
      context,
      () => vm.save(
        name: name,
        username: username,
        language: language,
        timezone: timezone,
        image: _image,
      ),
      success: 'Đã lưu hồ sơ',
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfileViewModel>();
    final user = context.watch<SessionService>().user!;
    return Scaffold(
      backgroundColor: AppColor.emerald50,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 16),
              _buildHeader(),
              const SizedBox(height: 16),
              _buildForm(context, user, vm),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
            'Chỉnh sửa hồ sơ',
            style: TextStyle(
              color: AppColor.gray800,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButtonWidget(
            icon: LucideIcons.rotateCcwKey,
            onTap: () => _changePassword(context),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context, user, ProfileViewModel vm) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Form(
        key: _form,
        child: Column(
          children: [
            Center(
              child: GestureDetector(
                onTap: _pick,
                child: Stack(
                  children: [
                    _image != null
                        ? ClipOval(
                            child: Image.file(
                              _image!,
                              width: 96,
                              height: 96,
                              fit: BoxFit.cover,
                            ),
                          )
                        : CircleAvatar(
                            radius: 48,
                            backgroundColor: AppColor.gray200,
                            child: Text(
                              user.name.isNotEmpty ? user.name[0] : '',
                              style: const TextStyle(
                                color: AppColor.gray500,
                                fontSize: 48,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                    const Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColor.emerald500,
                        child: Icon(
                          LucideIcons.camera,
                          color: AppColor.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user.name,
              style: const TextStyle(
                color: AppColor.gray800,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              user.email,
              style: const TextStyle(
                color: AppColor.gray600,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 24),
            CustomTextFormField(
              controller: _name,
              labelText: 'Họ và tên',
              validator: Validators.name,
            ),
            const SizedBox(height: 16),
            CustomTextFormField(
              controller: _username,
              labelText: 'Tên người dùng (để được thêm vào nhóm)',
              prefixIcon: LucideIcons.atSign,
              validator: (v) =>
                  (v == null || v.isEmpty) && user.username == null
                  ? null
                  : Validators.username(v),
            ),
            const SizedBox(height: 16),
            CustomDropdownField(
              labelText: 'Ngôn ngữ',
              hintText: 'Lựa chọn ngôn ngữ hiển thị',
              value: _selectedLanguage,
              items: Language.values.map((e) => e.code).toList(),
              itemLabel: (value) => Language.of(value).label,
              onChanged: (value) =>
                  setState(() => _selectedLanguage = value ?? 'vi'),
            ),
            const SizedBox(height: 16),
            CustomDropdownField(
              labelText: 'Múi giờ',
              hintText: 'Lựa chọn múi giờ',
              value: _selectedTimezone,
              items: _timezones,
              itemLabel: (value) => value,
              onChanged: (value) => setState(
                () => _selectedTimezone = value ?? 'Asia/Ho_Chi_Minh',
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              saving: vm.saving,
              onPressed: _save,
              label: 'Lưu thay đổi',
            ),
            const SizedBox(height: 16),
            OutlineButton(
              onPressed: () async {
                if (await confirmDialog(
                      context: context,
                      icon: LucideIcons.trash2,
                      title: 'Xóa tài khoản',
                      message:
                          'Tài khoản và lịch sử trò chuyện AI sẽ bị xóa vĩnh viễn. Nếu bạn là trưởng nhóm, quyền sẽ được chuyển cho thành viên khác.',
                      confirmText: 'Xóa vĩnh viễn',
                    ) &&
                    context.mounted) {
                  await runAction(context, vm.deleteAccount);
                }
              },
              backgroundColor: AppColor.red500,
              label: 'Xóa tài khoản',
              labelColor: AppColor.white,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePassword(BuildContext context) async {
    final vm = context.read<ProfileViewModel>();
    final oldC = TextEditingController();
    final newC = TextEditingController();
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi mật khẩu'),
        content: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: oldC,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu hiện tại',
                ),
                validator: Validators.password,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: newC,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
                validator: (v) =>
                    Validators.password(v) ??
                    (v == oldC.text
                        ? 'Mật khẩu mới phải khác mật khẩu cũ'
                        : null),
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
            child: const Text('Đổi'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await runAction(
        context,
        () => vm.changePassword(oldC.text, newC.text),
        success: 'Đã đổi mật khẩu. Các thiết bị khác đã bị đăng xuất.',
      );
    }
  }
}
