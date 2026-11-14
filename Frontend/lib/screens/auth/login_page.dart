import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../application/account_service.dart';
import '../../application/session_service.dart';
import '../../application/validation/validators.dart';
import '../../data/remote/api_client.dart';
import '../../utils/app_colors.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/custom_text_form_field.dart';
import '../shared/widgets.dart';
import 'auth_layout.dart';
import 'auth_view_model.dart';
import 'register_page.dart';
import 'verify_page.dart';
import 'reset_password_page.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (c) =>
        AuthViewModel(c.read<SessionService>(), c.read<AccountService>()),
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
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => showMessage(context, expired, error: true),
      );
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final vm = context.read<AuthViewModel>();
    try {
      final r = await vm.login(_email.text, _password.text);
      if (r is LoginNeedsVerify && mounted) {
        showMessage(
          context,
          'Email chưa được xác minh. Mã mới đã được gửi tới ${r.email}.',
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: vm,
              child: VerifyPage(email: r.email, confirmToken: r.confirmToken),
            ),
          ),
        );
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
      validator: (v) => (v == null || !v.startsWith('http'))
          ? 'Địa chỉ phải bắt đầu bằng http:// hoặc https://'
          : null,
    );
    if (url != null) {
      await vm.setServerUrl(url);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    return AuthScaffoldLayout(
      title: 'Đăng nhập',
      subtitle: 'Vui lòng đăng nhập để tiếp tục',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomTextFormField(
              controller: _email,
              labelText: 'Email',
              prefixIcon: LucideIcons.mail,
              hintText: 'Nhập email của bạn',
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
            ),
            const SizedBox(height: 16),
            CustomTextFormField(
              controller: _password,
              labelText: 'Mật khẩu',
              prefixIcon: LucideIcons.lock,
              hintText: 'Nhập mật khẩu',
              obscureText: _obscure,
              suffixIcon: _obscure ? LucideIcons.eye : LucideIcons.eyeOff,
              suffixIconOnTap: () => setState(() => _obscure = !_obscure),
              validator: Validators.password,
              onFieldSubmitted: () => _submit(),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ResetPasswordPage(),
                  ),
                ),
                child: const Text(
                  'Quên mật khẩu?',
                  style: TextStyle(
                    color: AppColor.emerald500,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            PrimaryButton(
              saving: vm.saving,
              onPressed: _submit,
              label: 'Đăng nhập',
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Chưa có tài khoản?',
                  style: TextStyle(color: AppColor.gray500, fontSize: 16),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider.value(
                        value: vm,
                        child: const RegisterPage(),
                      ),
                    ),
                  ),
                  child: const Text(
                    'Đăng ký ngay',
                    style: TextStyle(
                      color: AppColor.emerald500,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            TextButton.icon(
              onPressed: _editServer,
              icon: const Icon(
                LucideIcons.server,
                size: 16,
                color: AppColor.emerald500,
              ),
              label: Text(
                'Máy chủ: ${vm.serverUrl}',
                style: const TextStyle(color: AppColor.gray400, fontSize: 16, fontWeight: FontWeight.w400),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
