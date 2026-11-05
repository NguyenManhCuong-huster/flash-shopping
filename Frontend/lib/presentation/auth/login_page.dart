import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/account_service.dart';
import '../../application/session_service.dart';
import '../../application/validation/validators.dart';
import '../../data/remote/api_client.dart';
import '../shared/theme.dart';
import '../shared/widgets.dart';
import 'auth_view_model.dart';
import 'register_page.dart';
import 'verify_page.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (c) => AuthViewModel(c.read<SessionService>(), c.read<AccountService>()),
        child: const _LoginView(),
      );
}

class _LoginView extends StatefulWidget {
  const _LoginView();
  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final expired = context.read<SessionService>().expiredMessage;
    if (expired != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => showMessage(context, expired, error: true));
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final vm = context.read<AuthViewModel>();
    try {
      final r = await vm.login(_email.text, _password.text);
      if (r is LoginNeedsVerify && mounted) {
        showMessage(context, 'Email chưa được xác minh. Mã mới đã được gửi tới ${r.email}.');
        Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: vm, child: VerifyPage(email: r.email, confirmToken: r.confirmToken))));
      }
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> _editServer() async {
    final vm = context.read<AuthViewModel>();
    final url = await promptText(
      context,
      title: 'Địa chỉ máy chủ API',
      label: 'Ví dụ http://192.168.1.10:3001',
      initial: vm.serverUrl,
      validator: (v) => (v == null || !v.startsWith('http')) ? 'Địa chỉ phải bắt đầu bằng http:// hoặc https://' : null,
    );
    if (url != null) {
      await vm.setServerUrl(url);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _form,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Icon(Icons.shopping_basket, size: 72, color: AppTheme.primary),
                const SizedBox(height: 8),
                const Text('Đi chợ tiện lợi', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const Text('Mua sắm, tủ lạnh và bữa ăn cho cả nhà', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.muted)),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                  validator: Validators.email,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obscure = !_obscure)),
                  ),
                  validator: Validators.password,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 20),
                SaveButton(saving: vm.saving, onPressed: _submit, label: 'Đăng nhập', icon: Icons.login),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: vm, child: const RegisterPage()))),
                  child: const Text('Chưa có tài khoản? Đăng ký'),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _editServer,
                  icon: const Icon(Icons.dns_outlined, size: 18),
                  label: Text('Máy chủ: ${vm.serverUrl}', style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
