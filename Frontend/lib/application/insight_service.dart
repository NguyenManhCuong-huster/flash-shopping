import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models/common.dart';
import '../data/models/misc.dart';
import '../data/remote/api_client.dart';
import '../data/repositories/misc_repository.dart';
import 'validation/validators.dart';

/// UC06 - nhận nhắc hạn sử dụng (hộp thư trong ứng dụng + đếm chưa đọc) và UC10 - thống kê.
/// Không có Firebase trong bản này nên ứng dụng tự kiểm tra định kỳ khi đang mở; backend vẫn
/// gửi push qua FCM khi được cấu hình.
class InsightService extends ChangeNotifier {
  InsightService(this._repo);
  final InsightRepository _repo;

  int _unread = 0;
  int get unread => _unread;
  Timer? _timer;

  /// Số thông báo mới phát hiện ở lần kiểm tra gần nhất (để hiện banner).
  final ValueNotifier<int> newArrivals = ValueNotifier(0);

  void startPolling() {
    _timer?.cancel();
    checkNow();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => checkNow());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
    _unread = 0;
  }

  Future<void> checkNow() async {
    try {
      final r = await _repo.notifications(unreadOnly: true);
      if (r.unread > _unread) newArrivals.value = r.unread - _unread;
      _unread = r.unread;
      notifyListeners();
    } on ApiException {
      // Bỏ qua lỗi khi kiểm tra ngầm (không làm phiền người dùng)
    }
  }

  Future<({List<AppNotification> items, bool hasMore})> notifications({int page = 1}) async {
    final r = await _repo.notifications(page: page);
    _unread = r.unread;
    notifyListeners();
    return (items: r.items, hasMore: r.hasMore);
  }

  Future<void> markRead(AppNotification n) async {
    if (n.read) return;
    await _repo.markRead(ids: [n.id]);
    _unread = _unread > 0 ? _unread - 1 : 0;
    notifyListeners();
  }

  Future<void> markAllRead() async {
    await _repo.markRead();
    _unread = 0;
    notifyListeners();
  }

  Future<StatsReport> stats(DateTime from, DateTime to) => _repo.stats(isoDate(from), isoDate(to));
  Future<Paged<StockEvent>> events(DateTime from, DateTime to, {String? type, int page = 1}) =>
      _repo.events(isoDate(from), isoDate(to), type: type, page: page);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
