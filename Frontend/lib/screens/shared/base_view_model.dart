import 'package:flutter/foundation.dart';

import '../../data/remote/api_client.dart';

/// Nền cho mọi ViewModel: trạng thái tải lần đầu, lỗi tải, và trạng thái đang lưu.
abstract class BaseViewModel extends ChangeNotifier {
  bool _loading = false;
  bool _saving = false;
  String? _loadError;
  bool _disposed = false;

  bool get loading => _loading;
  bool get saving => _saving;
  String? get loadError => _loadError;

  /// Tải dữ liệu cho màn hình; lỗi được giữ lại để hiển thị kèm nút thử lại.
  @protected
  Future<void> runLoad(Future<void> Function() action) async {
    _loading = true;
    _loadError = null;
    notifyListeners();
    try {
      await action();
    } on ApiException catch (e) {
      _loadError = e.message;
    } catch (e) {
      _loadError = 'Đã xảy ra lỗi: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Thao tác ghi. Ném lại ApiException để màn hình hiện thông báo; chỉ báo thành công khi backend đã lưu (NFR03).
  @protected
  Future<T> runSave<T>(Future<T> Function() action) async {
    _saving = true;
    notifyListeners();
    try {
      return await action();
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
