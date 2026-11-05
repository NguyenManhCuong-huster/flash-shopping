import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../application/account_service.dart';
import '../../application/session_service.dart';
import '../../application/validation/validators.dart';
import '../shared/base_view_model.dart';
import '../shared/theme.dart';
import '../shared/widgets.dart';

class ProfileViewModel extends BaseViewModel {
  ProfileViewModel(this._account);
  final AccountService _account;

  Future<void> save({String? name, String? username, String? language, String? timezone, File? image}) =>
      runSave(() => _account.updateProfile(name: name, username: username, language: language, timezone: timezone, image: image));
  Future<String> changePassword(String oldP, String newP) => runSave(() => _account.changePassword(oldP, newP));
  Future<void> deleteAccount() => runSave(_account.deleteAccount);
}

const _timezones = ['Asia/Ho_Chi_Minh', 'Asia/Bangkok', 'Asia/Singapore', 'Asia/Tokyo', 'Asia/Seoul', 'Europe/London', 'Europe/Paris', 'America/New_York', 'Australia/Sydney', 'UTC'];

/// UC12 - Quản lý tài khoản cá nhân.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(create: (c) => ProfileViewModel(c.read<AccountService>()), child: const _ProfileView());
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
  late String _language;
  late String _timezone;
  File? _image;

  @override
  void initState() {
    super.initState();
    final u = context.read<SessionService>().user!;
    _name = TextEditingController(text: u.name);
    _username = TextEditingController(text: u.username ?? '');
    _language = u.language;
    _timezone = u.timezone;
  }

  Future<void> _pick() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (x != null) setState(() => _image = File(x.path));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final u = context.read<SessionService>().user!;
    final vm = context.read<ProfileViewModel>();
    final name = _name.text.trim() != u.name ? _name.text.trim() : null;
    final username = _username.text.trim() != (u.username ?? '') ? _username.text.trim() : null;
    final language = _language != u.language ? _language : null;
    final timezone = _timezone != u.timezone ? _timezone : null;
    if (name == null && username == null && language == null && timezone == null && _image == null) {
      return showMessage(context, 'Không có thay đổi nào để lưu');
    }
    await runAction(
      context,
      () => vm.save(name: name, username: username, language: language, timezone: timezone, image: _image),
      success: 'Đã lưu hồ sơ',
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfileViewModel>();
    final user = context.watch<SessionService>().user!;
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ cá nhân')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Center(
            child: GestureDetector(
              onTap: _pick,
              child: Stack(children: [
                _image != null
                    ? ClipOval(child: Image.file(_image!, width: 96, height: 96, fit: BoxFit.cover))
                    : NetImage(user.imageUrl, size: 96, circle: true, icon: Icons.person),
                const Positioned(right: 0, bottom: 0, child: CircleAvatar(radius: 16, child: Icon(Icons.camera_alt, size: 16))),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Text(user.email, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.muted)),
          const SizedBox(height: 20),
          TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Họ tên'), validator: Validators.name),
          const SizedBox(height: 12),
          TextFormField(
            controller: _username,
            decoration: const InputDecoration(labelText: 'Tên người dùng (để được thêm vào nhóm)', prefixText: '@'),
            validator: (v) => (v == null || v.isEmpty) && user.username == null ? null : Validators.username(v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _language,
            decoration: const InputDecoration(labelText: 'Ngôn ngữ'),
            items: const [DropdownMenuItem(value: 'vi', child: Text('Tiếng Việt')), DropdownMenuItem(value: 'en', child: Text('English'))],
            onChanged: (v) => setState(() => _language = v ?? 'vi'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _timezones.contains(_timezone) ? _timezone : null,
            decoration: const InputDecoration(labelText: 'Múi giờ'),
            items: [for (final tz in _timezones) DropdownMenuItem(value: tz, child: Text(tz))],
            onChanged: (v) => setState(() => _timezone = v ?? _timezone),
          ),
          const SizedBox(height: 20),
          SaveButton(saving: vm.saving, onPressed: _save),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: () => _changePassword(context), icon: const Icon(Icons.password), label: const Text('Đổi mật khẩu')),
          const SizedBox(height: 32),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            onPressed: () async {
              if (await confirmDialog(context,
                      title: 'Xóa tài khoản',
                      message: 'Tài khoản và lịch sử trò chuyện AI sẽ bị xóa vĩnh viễn. Nếu bạn là trưởng nhóm, quyền sẽ được chuyển cho thành viên khác.',
                      confirmText: 'Xóa vĩnh viễn') &&
                  context.mounted) {
                await runAction(context, vm.deleteAccount);
              }
            },
            icon: const Icon(Icons.delete_forever),
            label: const Text('Xóa tài khoản'),
          ),
        ]),
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
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: oldC, obscureText: true, decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại'), validator: Validators.password),
            const SizedBox(height: 10),
            TextFormField(
              controller: newC,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
              validator: (v) => Validators.password(v) ?? (v == oldC.text ? 'Mật khẩu mới phải khác mật khẩu cũ' : null),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => key.currentState!.validate() ? Navigator.pop(ctx, true) : null, child: const Text('Đổi')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await runAction(context, () => vm.changePassword(oldC.text, newC.text), success: 'Đã đổi mật khẩu. Các thiết bị khác đã bị đăng xuất.');
    }
  }
}
