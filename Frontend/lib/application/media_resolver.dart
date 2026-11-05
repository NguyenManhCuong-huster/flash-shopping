import '../data/remote/api_client.dart';

/// Ghép đường dẫn ảnh do server trả ("/uploads/...") với địa chỉ máy chủ hiện tại.
class MediaResolver {
  MediaResolver(this._api);
  final ApiClient _api;

  String? url(String? path) => _api.resolveUrl(path);
}
