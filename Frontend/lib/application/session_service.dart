import 'package:flutter/foundation.dart';

import '../data/local/settings_store.dart';
import '../data/models/user.dart';
import '../data/remote/api_client.dart';
import '../data/repositories/auth_repository.dart';

enum SessionStatus { unknown, loggedOut, loggedIn }

/// Trạng thái phiên đăng nhập và vai trò hiện tại (dùng để ẩn/hiện thao tác theo quyền).
/// Giao diện chỉ ẩn thao tác không phù hợp; backend vẫn kiểm tra quyền cho mọi yêu cầu.
class SessionService extends ChangeNotifier {
  SessionService(this._auth, ApiClient api, this._settings) {
    api.onSessionExpired = () {
      if (_status == SessionStatus.loggedIn) {
        expiredMessage = 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.';
        _setLoggedOut();
      }
    };
  }

  final AuthRepository _auth;
  final SettingsStore _settings;
  SessionStatus _status = SessionStatus.unknown;
  User? _user;
  String? expiredMessage;

  /// Địa chỉ máy chủ API (đổi được ở màn hình đăng nhập).
  String get serverUrl => _settings.baseUrl;
  Future<void> setServerUrl(String url) => _settings.setBaseUrl(url);

  SessionStatus get status => _status;
  User? get user => _user;
  bool get hasGroup => _user?.group != null;
  bool get isLeader => _user?.group?.isLeader ?? false;
  bool get isSystemAdmin => _user?.isSystemAdmin ?? false;

  /// Khôi phục phiên khi mở ứng dụng.
  Future<void> restore() async {
    if (!_auth.hasSession) return _setLoggedOut();
    try {
      _user = await _auth.me();
      _status = SessionStatus.loggedIn;
      notifyListeners();
    } on ApiException catch (e) {
      if (e.network) {
        // Mất mạng: vẫn giữ phiên, thử lại sau
        _status = SessionStatus.loggedIn;
        notifyListeners();
      } else {
        _setLoggedOut();
      }
    }
  }

  Future<void> login(String email, String password) async {
    final tokens = await _auth.login(email.trim(), password);
    _user = tokens.user;
    _status = SessionStatus.loggedIn;
    expiredMessage = null;
    await refreshProfile();
  }

  /// Tải lại hồ sơ + nhóm + vai trò (sau khi tạo/rời nhóm, đổi trưởng nhóm...).
  Future<void> refreshProfile() async {
    _user = await _auth.me();
    notifyListeners();
  }

  void updateUser(User u) {
    _user = u;
    notifyListeners();
  }

  Future<void> logout() async {
    await _auth.logout();
    _setLoggedOut();
  }

  void _setLoggedOut() {
    _user = null;
    _status = SessionStatus.loggedOut;
    notifyListeners();
  }
}
