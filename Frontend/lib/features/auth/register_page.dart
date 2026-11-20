import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../core/utils/validators.dart';
import '../../core/api_client.dart';
import '../../core/utils/app_colors.dart';
import '../../core/widgets/widgets_common.dart';
import '../../core/widgets/custom_text_form_field.dart';
import '../../core/widgets/buttons/primary_button.dart';
import '../../core/widgets/buttons/custom_text_button.dart';
import 'auth_layout.dart';
import 'auth_view_model.dart';
import 'login_page.dart';
import 'verify_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final vm = context.read<AuthViewModel>();
    try {
      final token = await vm.register(_email.text, _username.text, _password.text, _name.text);
      if (!mounted) return;
      showMessage(
        context,
        'Đăng ký thành công. Mã xác minh đã được gửi tới email.',
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: vm,
            child: VerifyPage(email: _email.text.trim(), confirmToken: token),
          ),
        ),
      );
    } on ApiException catch (e) {
      // Giữ nguyên dữ liệu đã nhập để người dùng sửa (NFR05)
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    return AuthScaffoldLayout(
      title: 'Đăng ký tài khoản',
      subtitle: 'Vui lòng đăng ký để sử dụng các tính năng của ứng dụng.',
      child: Form(
        key: _form,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomTextFormField(
              controller: _name,
              labelText: 'Họ và tên',
              prefixIcon: LucideIcons.idCard,
              hintText: 'Nhập họ và tên của bạn',
              validator: Validators.name,
            ),

            const SizedBox(height: 8),
            CustomTextFormField(
              controller: _email,
              labelText: 'Email',
              prefixIcon: LucideIcons.mail,
              hintText: 'Nhập email của bạn',
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
            ),

            const SizedBox(height: 8),

            CustomTextFormField(
              controller: _username,
              labelText: 'Tên đăng nhập',
              prefixIcon: LucideIcons.user,
              hintText: 'Nhập tên đăng nhập của bạn',
              validator: Validators.username,
            ),

            CustomTextFormField(
              controller: _password,
              labelText: 'Mật khẩu',
              prefixIcon: LucideIcons.lock,
              hintText: 'Tối thiểu 6 ký tự, bao gồm chữ, số và ký tự đặc biệt',
              obscureText: true,
              validator: Validators.password,
            ),

            const SizedBox(height: 8),

            CustomTextFormField(
              controller: _confirm,
              labelText: 'Nhập lại mật khẩu',
              prefixIcon: LucideIcons.lock,
              hintText: 'Xác nhận lại mật khẩu',
              obscureText: true,
              validator: (v) =>
                  v != _password.text ? 'Mật khẩu nhập lại không khớp' : null,
            ),


            const SizedBox(height: 16),

            PrimaryButton(
              saving: vm.saving,
              onPressed: _submit,
              label: 'Đăng ký',
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Đã có tài khoản?',
                  style: TextStyle(color: AppColor.gray600, fontSize: 16),
                ),
                CustomTextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider.value(
                        value: vm,
                        child: const LoginPage(),
                      ),
                    ),
                  ),
                  label: 'Đăng nhập ngay',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
