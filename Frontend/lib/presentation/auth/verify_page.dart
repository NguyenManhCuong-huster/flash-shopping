import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/validation/validators.dart';
import '../../data/remote/api_client.dart';
import '../shared/widgets.dart';
import 'auth_view_model.dart';

/// Nhập mã OTP 6 số gửi qua email.
class VerifyPage extends StatefulWidget {
  const VerifyPage({super.key, required this.email, this.confirmToken});
  final String email;
  final String? confirmToken;

  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  String? _token;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _token = widget.confirmToken;
    _startCooldown();
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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_form.currentState!.validate()) return;
    if (_token == null) return _resend();
    try {
      final msg = await context.read<AuthViewModel>().verify(_code.text, _token!);
      if (!mounted) return;
      showMessage(context, '$msg Hãy đăng nhập.');
      Navigator.popUntil(context, (r) => r.isFirst);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> _resend() async {
    try {
      final t = await context.read<AuthViewModel>().resend(widget.email);
      if (!mounted) return;
      if (t == null) {
        showMessage(context, 'Email đã được xác minh, hãy đăng nhập.');
        Navigator.popUntil(context, (r) => r.isFirst);
        return;
      }
      setState(() => _token = t);
      _startCooldown();
      showMessage(context, 'Đã gửi mã mới tới ${widget.email}');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Xác minh email')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const Icon(Icons.mark_email_read_outlined, size: 64),
          const SizedBox(height: 12),
          Text('Nhập mã 6 số đã gửi tới\n${widget.email}', textAlign: TextAlign.center),
          const SizedBox(height: 20),
          TextFormField(
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, letterSpacing: 10),
            decoration: const InputDecoration(counterText: '', hintText: '------'),
            validator: Validators.otp,
          ),
          const SizedBox(height: 16),
          SaveButton(saving: vm.saving, onPressed: _verify, label: 'Xác minh', icon: Icons.verified_outlined),
          TextButton(
            onPressed: _cooldown > 0 || vm.saving ? null : _resend,
            child: Text(_cooldown > 0 ? 'Gửi lại mã sau $_cooldown giây' : 'Gửi lại mã'),
          ),
        ]),
      ),
    );
  }
}
