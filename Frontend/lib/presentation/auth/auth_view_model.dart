import '../../application/account_service.dart';
import '../../application/session_service.dart';
import '../../data/remote/api_client.dart';
import '../shared/base_view_model.dart';

/// Kết quả đăng nhập: thành công, hoặc cần xác minh email trước.
sealed class LoginOutcome {}

class LoginOk extends LoginOutcome {}

class LoginNeedsVerify extends LoginOutcome {
  LoginNeedsVerify(this.email, this.confirmToken);
  final String email;
  final String? confirmToken;
}

class AuthViewModel extends BaseViewModel {
  AuthViewModel(this._session, this._account);
  final SessionService _session;
  final AccountService _account;

  String get serverUrl => _session.serverUrl;
  Future<void> setServerUrl(String url) => _session.setServerUrl(url);

  Future<LoginOutcome> login(String email, String password) => runSave(() async {
        try {
          await _session.login(email, password);
          return LoginOk();
        } on ApiException catch (e) {
          if (e.code == '00044') {
            // Email chưa xác minh: gửi mã mới rồi chuyển sang màn nhập OTP
            String? token;
            try {
              token = await _account.resendCode(email);
            } on ApiException {
              token = null;
            }
            return LoginNeedsVerify(email.trim(), token);
          }
          rethrow;
        }
      });

  Future<String> register(String email, String password, String name) => runSave(() => _account.register(email, password, name));
  Future<String> verify(String code, String token) => runSave(() => _account.verify(code, token));
  Future<String?> resend(String email) => runSave(() => _account.resendCode(email));
}
