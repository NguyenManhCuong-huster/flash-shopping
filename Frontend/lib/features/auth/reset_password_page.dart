import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/utils/validators.dart';
import '../../core/utils/app_colors.dart';
import 'auth_layout.dart';
import '../../core/widgets/custom_text_form_field.dart';
import '../../core/widgets/widgets_common.dart';
import '../../core/widgets/buttons/custom_text_button.dart';
import '../../core/widgets/buttons/primary_button.dart';
import '../../core/widgets/buttons/soft_button.dart';
import 'reset_password_view_model.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _cooldown = 0;
  Timer? _timer;

  ResetPasswordViewModel get _vm => context.read<ResetPasswordViewModel>();

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _sendOtp() async {
    debugPrint('_sendOtp called');
    if (!_form.currentState!.validate()) {
      debugPrint('Form validation failed');
      return;
    }
    try {
      await _vm.sendOtp(_emailController.text);
      debugPrint('_sendOtp completed');
    } catch (e) {
      debugPrint('_sendOtp error: $e');
      if (!mounted) return;
      showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _verifyOtp() async {
    debugPrint('_verifyOtp called');
    if (!_form.currentState!.validate()) {
      debugPrint('Form validation failed');
      return;
    }
    try {
      await _vm.verifyOtp(_codeController.text);
      debugPrint('_verifyOtp completed');
    } catch (e) {
      debugPrint('_verifyOtp error: $e');
      if (!mounted) return;
      showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _resetPassword() async {
    debugPrint('_resetPassword called');
    if (!_form.currentState!.validate()) {
      debugPrint('Form validation failed');
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      if (!mounted) return;
      showMessage(context, 'Mật khẩu nhập lại không khớp', error: true);
      return;
    }
    try {
      await _vm.resetPassword(_passwordController.text);
      debugPrint('_resetPassword completed');
    } catch (e) {
      debugPrint('_resetPassword error: $e');
      if (!mounted) return;
      showMessage(context, e.toString(), error: true);
    }
  }

  Widget _buildStepIndicator() {
    const steps = [
      {'label': 'Nhập email', 'index': 0},
      {'label': 'Nhập mã OTP', 'index': 1},
      {'label': 'Đặt mật khẩu', 'index': 2},
    ];
    final current = ResetStep.values.indexOf(_vm.step);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps.length, (i) {
        final done = i < current;
        final active = i == current;
        return Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: active || done
                      ? AppColor.emerald500
                      : AppColor.gray200,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: done
                      ? const Icon(
                          LucideIcons.check,
                          color: Colors.white,
                          size: 16,
                        )
                      : Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: active || done
                                ? AppColor.white
                                : AppColor.gray600,
                            fontSize: 16,
                            fontWeight: active
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                steps[i]['label'] as String,
                style: TextStyle(
                  color: active || done
                      ? AppColor.emerald500
                      : AppColor.gray600,
                  fontSize: 16,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ResetPasswordViewModel>();
    return AuthScaffoldLayout(
      icon: _stepSubtitle(vm.step).icon,
      title: 'Quên mật khẩu',
      subtitle: _stepSubtitle(vm.step).label,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStepIndicator(),
            const SizedBox(height: 24),
            _buildStepContent(vm),
          ],
        ),
      ),
    );
  }

  ({IconData icon, String label}) _stepSubtitle(ResetStep step) {
    switch (step) {
      case ResetStep.email:
        return (
          icon: LucideIcons.mailSearch,
          label: 'Vui lòng nhập email để nhận mã xác thực.',
        );
      case ResetStep.otp:
        return (
          icon: LucideIcons.shieldCheck,
          label: 'Vui lòng nhập mã 6 số đã gửi tới ${_vm.email ?? ''}.',
        );
      case ResetStep.newPassword:
        return (
          icon: LucideIcons.keyRound,
          label: 'Vui lòng nhập mật khẩu mới cho tài khoản.',
        );
      case ResetStep.success:
        return (
          icon: LucideIcons.circleCheckBig,
          label: 'Mật khẩu của bạn đã được đặt lại thành công.',
        );
    }
  }

  Widget _buildStepContent(ResetPasswordViewModel vm) {
    switch (vm.step) {
      case ResetStep.email:
        return _buildEmailStep();
      case ResetStep.otp:
        return _buildOtpStep();
      case ResetStep.newPassword:
        return _buildNewPasswordStep();
      case ResetStep.success:
        return _buildSuccessStep();
    }
  }

  Widget _buildEmailStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomTextFormField(
          controller: _emailController,
          labelText: 'Email',
          hintText: 'Nhập email của bạn',
          keyboardType: TextInputType.emailAddress,
          prefixIcon: LucideIcons.mail,
          validator: Validators.email,
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          saving: _vm.saving,
          onPressed: _sendOtp,
          label: 'Gửi mã xác thực',
        ),
        const SizedBox(height: 16),
        SoftButton(
          onPressed: () => Navigator.pop(context),
          label: 'Quay về trang đăng nhập',
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomTextFormField(
          controller: _codeController,
          labelText: '',
          hintText: '------',
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 26, letterSpacing: 10),
          counterText: '',
          validator: Validators.otp,
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          saving: _vm.saving,
          onPressed: _verifyOtp,
          label: 'Xác minh mã',
        ),
        const SizedBox(height: 12),
        CustomTextButton(
          onPressed: _cooldown > 0 || _vm.saving
              ? null
              : () {
                  _sendOtp();
                  _startCooldown();
                },
          label: _cooldown > 0
              ? 'Gửi lại mã sau $_cooldown giây'
              : 'Gửi lại mã',
        ),
        const SizedBox(height: 16),
        CustomTextButton(
          onPressed: () => Navigator.pop(context),
          label: 'Quay về trang đăng nhập',
        ),
      ],
    );
  }

  Widget _buildNewPasswordStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomTextFormField(
          controller: _passwordController,
          labelText: 'Mật khẩu mới',
          hintText: 'Nhập mật khẩu mới',
          obscureText: true,
          prefixIcon: LucideIcons.lock,
          validator: Validators.password,
        ),
        const SizedBox(height: 16),
        CustomTextFormField(
          controller: _confirmPasswordController,
          labelText: 'Nhập lại mật khẩu mới',
          hintText: 'Xác nhận lại mật khẩu',
          obscureText: true,
          prefixIcon: LucideIcons.lock,
          validator: Validators.password,
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          saving: _vm.saving,
          onPressed: _resetPassword,
          label: 'Đặt lại mật khẩu',
        ),
        const SizedBox(height: 16),
        CustomTextButton(
          onPressed: () => Navigator.pop(context),
          label: 'Quay về trang đăng nhập',
        ),
      ],
    );
  }

  Widget _buildSuccessStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(LucideIcons.checkCircle2, size: 80, color: AppColor.primary),
        const SizedBox(height: 24),
        const Text(
          'Đặt lại mật khẩu thành công',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColor.gray800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Bạn có thể đăng nhập bằng mật khẩu mới.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: AppColor.gray600),
        ),
        const SizedBox(height: 32),
        PrimaryButton(
          saving: false,
          onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
          label: 'Đăng nhập',
        ),
      ],
    );
  }
}
