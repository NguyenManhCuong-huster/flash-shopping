import 'package:shared_preferences/shared_preferences.dart';

/// Cấu hình cục bộ không nhạy cảm (địa chỉ máy chủ API).
class SettingsStore {
  static const _baseUrlKey = 'api_base_url';

  /// Điện thoại thật cắm USB + `adb reverse tcp:3001 tcp:3001` => localhost của điện thoại trỏ về máy tính.
  /// Qua Wi-Fi: đổi ở màn hình đăng nhập thành http://<IP máy tính>:3001. Máy ảo: http://10.0.2.2:3001.
  /// Có thể đặt sẵn khi build: --dart-define=API_BASE_URL=...
  static const defaultBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3001');

  SharedPreferences? _prefs;
  String _baseUrl = defaultBaseUrl;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _baseUrl = _prefs!.getString(_baseUrlKey) ?? defaultBaseUrl;
  }

  String get baseUrl => _baseUrl;

  Future<void> setBaseUrl(String url) async {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    _baseUrl = u.isEmpty ? defaultBaseUrl : u;
    await _prefs?.setString(_baseUrlKey, _baseUrl);
  }
}
