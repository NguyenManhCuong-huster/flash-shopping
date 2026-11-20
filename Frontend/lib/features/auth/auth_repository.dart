import 'dart:io';

import '../../core/token_store.dart';
import '../../core/model_common.dart';
import '../user/user.dart';
import '../../core/api_client.dart';

/// UC01 + UC12: xác thực và tài khoản cá nhân.
class AuthRepository {
  AuthRepository(this._api, this._tokens);
  final ApiClient _api;
  final TokenStore _tokens;

  bool get hasSession => _tokens.hasSession;

  /// Trả về confirmToken dùng cho bước xác minh OTP.
  Future<String> register({required String username, required String password, required String email, required String name, String language = 'vi', String timezone = 'Asia/Ho_Chi_Minh'}) async {
    final r = await _api.post('/user', data: {'username': username, 'email': email, 'password': password, 'name': name, 'language': language, 'timezone': timezone});
    return r.map['confirmToken'] as String;
  }
  /// Trả về confirmToken mới (null nếu email đã được xác minh).
  Future<String?> sendVerificationCode(String email) async {
    final r = await _api.post('/user/send-verification-code', data: {'email': email});
    return r.map['confirmToken'] as String?;
  }
  /// Xác minh email bằng mã OTP.
  Future<String> verifyEmail(String code, String confirmToken) async {
    final r = await _api.post('/user/verify-email', data: {'code': code, 'token': confirmToken});
    return r.message;
  }

  /// Gửi mã OTP tới email để đặt lại mật khẩu.
  Future<String> sendPasswordResetCode(String email) async {
    final r = await _api.post('/user/send-password-reset-code', data: {'email': email});
    return r.map['confirmToken'] as String;
  }
  /// Xác minh mã OTP và trả về confirmToken dùng cho bước đặt lại mật khẩu.
  Future<String> verifyPasswordResetCode(String code, String resetToken) async {
    final r = await _api.post('/user/verify-password-reset-code', data: {'code': code, 'token': resetToken});
    return r.map['resetToken'] as String;
  }
  /// Đặt lại mật khẩu khi quên (dùng confirmToken từ gửi mã OTP).
  Future<String> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    final r = await _api.post('/user/reset-password', data: {
      'email': email.trim(),
      'token': token,
      'newPassword': newPassword,
    });
    return r.message;
  }

  Future<AuthTokens> login(String username, String password) async {
    final r = await _api.post('/user/login', data: {'username': username, 'password': password});
    final d = r.map;
    final tokens = AuthTokens(d['accessToken'] as String, d['refreshToken'] as String, User.fromJson(asJson(d['user'])));
    await _tokens.save(tokens.accessToken, tokens.refreshToken);
    return tokens;
  }

  Future<void> logout() async {
    try {
      await _api.post('/user/logout', data: {'refreshToken': _tokens.refreshToken});
    } on ApiException {
      // Đăng xuất phía client luôn thành công kể cả khi mất mạng
    } finally {
      await _tokens.clear();
    }
  }

  Future<User> me() async => User.fromJson(asJson((await _api.get('/user')).map['user']));

  Future<User> updateProfile({String? name, String? username, String? language, String? timezone, File? image}) async {
    final r = await _api.multipart('PUT', '/user', {'name': name, 'username': username, 'language': language, 'timezone': timezone}, image);
    return User.fromJson(asJson(r.map['user']));
  }

  Future<String> changePassword(String oldPassword, String newPassword) async =>
      (await _api.post('/user/change-password', data: {'oldPassword': oldPassword, 'newPassword': newPassword})).message;

  Future<void> deleteAccount() async {
    await _api.delete('/user');
    await _tokens.clear();
  }
}
