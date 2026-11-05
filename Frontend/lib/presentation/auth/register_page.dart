import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/validation/validators.dart';
import '../../data/remote/api_client.dart';
import '../shared/widgets.dart';
import 'auth_view_model.dart';
import 'verify_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final vm = context.read<AuthViewModel>();
    try {
      final token = await vm.register(_email.text, _password.text, _name.text);
      if (!mounted) return;
      showMessage(context, 'Đăng ký thành công. Mã xác minh đã được gửi tới email.');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: vm, child: VerifyPage(email: _email.text.trim(), confirmToken: token))),
      );
    } on ApiException catch (e) {
      // Giữ nguyên dữ liệu đã nhập để người dùng sửa (NFR05)
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký tài khoản')),
      body: Form(
        key: _form,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Họ tên', prefixIcon: Icon(Icons.person_outline)), validator: Validators.name),
          const SizedBox(height: 12),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
            validator: Validators.email,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Mật khẩu (6-20 ký tự)', prefixIcon: Icon(Icons.lock_outline)),
            validator: Validators.password,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirm,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Nhập lại mật khẩu', prefixIcon: Icon(Icons.lock_outline)),
            validator: (v) => v != _password.text ? 'Mật khẩu nhập lại không khớp' : null,
          ),
          const SizedBox(height: 24),
          SaveButton(saving: vm.saving, onPressed: _submit, label: 'Đăng ký', icon: Icons.person_add_alt),
        ]),
      ),
    );
  }
}
