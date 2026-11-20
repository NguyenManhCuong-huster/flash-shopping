import '../group/account_service.dart';
import '../../core/base_view_model.dart';
/// Trạng thái của quy trình đặt lại mật khẩu (quên mật khẩu).
enum ResetStep { email, otp, newPassword, success }

/// ViewModel cho màn hình Quên mật khẩu (Reset Password).
/// Quản lý 3 bước: Nhập email → Nhập OTP → Đặt mật khẩu mới → Thành công.
class ResetPasswordViewModel extends BaseViewModel {
  ResetPasswordViewModel(this._account);

  final AccountService _account;

  ResetStep _step = ResetStep.email;
  String? _email;
  String? _confirmToken;

  ResetStep get step => _step;
  String? get email => _email;
  String? get confirmToken => _confirmToken;

  /// Bước 1: Gửi mã OTP tới email.
  Future<void> sendOtp(String email) async {
    _email = email.trim();
    final token = await runSave(() => _account.sendPasswordResetCode(_email!));
    if (token == null) {
      throw Exception('Email này đã được xác minh trước đó. Vui lòng đăng nhập.');
    }
    _confirmToken = token;
    _step = ResetStep.otp;
    notifyListeners();
  }

  /// Bước 2: Xác minh mã OTP.
  Future<void> verifyOtp(String code) async {
    if (_confirmToken == null) return;
    await runSave(() => _account.verifyPasswordResetCode(code.trim(), _confirmToken!));
    _step = ResetStep.newPassword;
    notifyListeners();
  }

  /// Bước 3: Đặt lại mật khẩu mới.
  Future<void> resetPassword(String newPassword) async {
    if (_email == null || _confirmToken == null) return;
    await runSave(() => _account.resetPassword(
      email: _email!,
      token: _confirmToken!,
      newPassword: newPassword,
    ));
    _step = ResetStep.success;
    notifyListeners();
  }

  /// Quay về bước trước hoặc reset về bước đầu.
  void goToStep(ResetStep step) {
    _step = step;
    notifyListeners();
  }

  void reset() {
    _step = ResetStep.email;
    _email = null;
    _confirmToken = null;
    notifyListeners();
  }
}