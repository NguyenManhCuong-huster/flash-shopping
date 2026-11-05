import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../local/settings_store.dart';
import '../local/token_store.dart';

/// Lỗi trả về từ API (mã phản hồi của hệ thống) hoặc lỗi mạng.
class ApiException implements Exception {
  ApiException(this.code, this.message, {this.status, this.data, this.network = false});

  final String code;
  final String message;
  final int? status;
  final dynamic data;

  /// Mất kết nối/timeout: thao tác CHƯA được lưu, cho phép thử lại (NFR11).
  final bool network;

  @override
  String toString() => message;
}

class ApiResponse {
  ApiResponse(this.code, this.message, this.data);
  final String code;
  final String message;
  final dynamic data;

  Map<String, dynamic> get map => (data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
}

/// HTTP client duy nhất của ứng dụng: gắn Bearer token, tự làm mới token khi hết hạn (mã 00011),
/// chuyển mọi lỗi thành [ApiException].
class ApiClient {
  ApiClient(this._settings, this._tokens) {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 90),
      contentType: Headers.jsonContentType,
      validateStatus: (_) => true,
    ));
  }

  final SettingsStore _settings;
  final TokenStore _tokens;
  late final Dio _dio;
  Future<bool>? _refreshing;

  /// Gọi khi phiên không thể khôi phục (refresh token hết hạn/bị thu hồi).
  void Function()? onSessionExpired;

  String get baseUrl => _settings.baseUrl;

  /// Ảnh do server trả dạng "/uploads/..." -> URL đầy đủ.
  String? resolveUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    return '$baseUrl$path';
  }

  Future<ApiResponse> get(String path, {Map<String, dynamic>? query}) => _request('GET', path, query: _clean(query));
  Future<ApiResponse> post(String path, {Object? data, Map<String, String>? headers}) =>
      _request('POST', path, data: () => data, headers: headers);
  Future<ApiResponse> put(String path, {Object? data}) => _request('PUT', path, data: () => data);
  Future<ApiResponse> delete(String path, {Object? data}) => _request('DELETE', path, data: () => data);

  /// Gửi multipart (trường text + một ảnh tùy chọn ở trường `image`).
  Future<ApiResponse> multipart(String method, String path, Map<String, dynamic> fields, File? image) {
    return _request(method, path, data: () {
      final map = <String, dynamic>{};
      fields.forEach((k, v) {
        if (v != null) map[k] = v.toString();
      });
      if (image != null) map['image'] = MultipartFile.fromFileSync(image.path, filename: image.path.split(Platform.pathSeparator).last);
      return FormData.fromMap(map);
    });
  }

  Map<String, dynamic>? _clean(Map<String, dynamic>? q) {
    if (q == null) return null;
    final out = <String, dynamic>{};
    q.forEach((k, v) {
      if (v != null && v.toString().isNotEmpty) out[k] = v.toString();
    });
    return out;
  }

  Future<ApiResponse> _request(
    String method,
    String path, {
    Object? Function()? data,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool retry = true,
  }) async {
    final token = _tokens.accessToken;
    Response<dynamic> res;
    try {
      res = await _dio.request<dynamic>(
        '$baseUrl$path',
        data: data?.call(),
        queryParameters: query,
        options: Options(method: method, headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          ...?headers,
        }),
      );
    } on DioException catch (e) {
      throw ApiException('NETWORK', _networkMessage(e), network: true);
    }

    final body = res.data is Map ? (res.data as Map).cast<String, dynamic>() : <String, dynamic>{};
    final code = body['code']?.toString() ?? '';
    final message = body['message']?.toString() ?? 'Lỗi không xác định (${res.statusCode})';
    final status = res.statusCode ?? 0;

    if (status == 401 && retry && token != null && (code == '00011' || code == '00012')) {
      if (await _refresh()) {
        return _request(method, path, data: data, query: query, headers: headers, retry: false);
      }
      onSessionExpired?.call();
    }
    if (status >= 200 && status < 300) return ApiResponse(code, message, body['data']);
    throw ApiException(code, message, status: status, data: body['data']);
  }

  /// Làm mới token một lần cho mọi request đang chờ (single-flight) vì refresh token chỉ dùng được một lần.
  Future<bool> _refresh() {
    return _refreshing ??= () async {
      try {
        final refresh = _tokens.refreshToken;
        if (refresh == null) return false;
        final res = await _dio.post<dynamic>('$baseUrl/user/refresh-token', data: {'refreshToken': refresh});
        final body = res.data is Map ? (res.data as Map).cast<String, dynamic>() : <String, dynamic>{};
        if (res.statusCode == 200 && body['data'] is Map) {
          final d = (body['data'] as Map).cast<String, dynamic>();
          await _tokens.save(d['accessToken'] as String, d['refreshToken'] as String);
          return true;
        }
        await _tokens.clear();
        return false;
      } on DioException {
        return false;
      } finally {
        _refreshing = null;
      }
    }();
  }

  String _networkMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Máy chủ phản hồi quá lâu. Thao tác có thể chưa được lưu, vui lòng thử lại.';
      default:
        return 'Không kết nối được máy chủ ($baseUrl). Thao tác chưa được lưu, vui lòng kiểm tra mạng và thử lại.';
    }
  }
}
