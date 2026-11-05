import 'dart:io';

import '../models/ai.dart';
import '../models/common.dart';
import '../models/misc.dart';
import '../models/user.dart';
import '../remote/api_client.dart';

/// UC06 thông báo + UC10 thống kê.
class InsightRepository {
  InsightRepository(this._api);
  final ApiClient _api;

  Future<({List<AppNotification> items, int unread, bool hasMore})> notifications({int page = 1, bool unreadOnly = false}) async {
    final r = await _api.get('/notification', query: {'page': page, 'limit': 30, 'unreadOnly': unreadOnly ? 'true' : null});
    final p = Paged.fromJson(r.map, 'notifications', AppNotification.fromJson);
    return (items: p.items, unread: toInt(r.map['unreadCount']), hasMore: p.hasMore);
  }

  Future<void> markRead({List<int>? ids}) => _api.put('/notification/read', data: ids == null ? {'all': true} : {'ids': ids});

  Future<StatsReport> stats(String from, String to) async => StatsReport.fromJson((await _api.get('/stats', query: {'from': from, 'to': to})).map);

  Future<Paged<StockEvent>> events(String from, String to, {String? type, int page = 1}) async {
    final r = await _api.get('/stats/events', query: {'from': from, 'to': to, 'type': type, 'page': page, 'limit': 50});
    return Paged.fromJson(r.map, 'events', StockEvent.fromJson);
  }
}

/// UC11 quản trị hệ thống.
class AdminRepository {
  AdminRepository(this._api);
  final ApiClient _api;

  Future<Paged<User>> users({String? q, int page = 1}) async =>
      Paged.fromJson((await _api.get('/admin/users', query: {'q': q, 'page': page})).map, 'users', User.fromJson);

  Future<void> updateUser(int userId, {bool? isActive, String? systemRole}) =>
      _api.put('/admin/users', data: {'userId': userId, if (isActive != null) 'isActive': isActive, if (systemRole != null) 'systemRole': systemRole});

  Future<Paged<AuditLog>> logs({String? action, String? source, int page = 1}) async =>
      Paged.fromJson((await _api.get('/admin/logs', query: {'action': action, 'source': source, 'page': page})).map, 'logs', AuditLog.fromJson);

  /// kind = category | unit
  Future<List<NamedItem>> catalog(String kind) async {
    final r = await _api.get('/admin/$kind');
    return asList(r.map[kind == 'category' ? 'categories' : 'units']).map(NamedItem.fromJson).toList();
  }

  Future<void> createCatalog(String kind, String name) => _api.post('/admin/$kind', data: kind == 'category' ? {'name': name} : {'unitName': name});
  Future<void> renameCatalog(String kind, String oldName, String newName) => _api.put('/admin/$kind', data: {'oldName': oldName, 'newName': newName});
  Future<void> deleteCatalog(String kind, String name) => _api.delete('/admin/$kind', data: kind == 'category' ? {'name': name} : {'unitName': name});
}

/// Trợ lý AI.
class AiRepository {
  AiRepository(this._api);
  final ApiClient _api;

  Future<List<AiConversation>> conversations() async =>
      asList((await _api.get('/ai/conversation', query: {'limit': 50})).map['conversations']).map(AiConversation.fromJson).toList();

  Future<AiConversationDetail> conversation(int id) async {
    final d = (await _api.get('/ai/conversation/$id', query: {'limit': 100})).map;
    return AiConversationDetail(
      AiConversation.fromJson(asJson(d['conversation'])),
      asList(d['messages']).map(AiMessage.fromJson).toList(),
      asList(d['actions']).map(AiAction.fromJson).toList(),
    );
  }

  Future<void> deleteConversation(int id) => _api.delete('/ai/conversation', data: {'conversationId': id});

  Future<AiChatResult> chat({int? conversationId, required String message, List<int> attachmentIds = const [], String? screen}) async {
    final r = await _api.post('/ai/chat', data: {
      'conversationId': conversationId,
      'message': message,
      'attachmentIds': attachmentIds,
      'stream': false,
      'clientContext': {'screen': screen ?? 'ai_chat'},
    });
    final d = r.map;
    return AiChatResult(toInt(d['conversationId']), asJson(d['message'])['content']?.toString() ?? '', asList(d['pendingActions']).map(AiAction.fromJson).toList());
  }

  Future<int> uploadAttachment(File file) async => toInt((await _api.multipart('POST', '/ai/attachment', {}, file)).map['attachmentId']);

  Future<({bool allOk, List<AiActionResult> results})> confirm(List<int> actionIds) async {
    final r = await _api.post('/ai/action/confirm', data: {'actionIds': actionIds});
    return (allOk: r.code == '00423', results: asList(r.map['results']).map(AiActionResult.fromJson).toList());
  }

  Future<void> reject(List<int> actionIds, {String? reason}) => _api.post('/ai/action/reject', data: {'actionIds': actionIds, 'reason': reason});

  Future<AiSettings> settings() async {
    final d = (await _api.get('/ai/settings')).map;
    final s = asJson(d['settings']);
    return AiSettings(
      enabled: s['enabled'] == true,
      autoExecuteLevel: s['autoExecuteLevel']?.toString() ?? 'read',
      dailyTokenLimit: toInt(s['dailyTokenLimit']),
      available: d['aiAvailable'] == true,
    );
  }

  Future<void> updateSettings({bool? enabled, String? autoExecuteLevel}) =>
      _api.put('/ai/settings', data: {if (enabled != null) 'enabled': enabled, if (autoExecuteLevel != null) 'autoExecuteLevel': autoExecuteLevel});

  Future<List<AiSuggestion>> suggestions() async => asList((await _api.get('/ai/suggestion')).map['suggestions']).map(AiSuggestion.fromJson).toList();

  Future<List<AiSuggestion>> refreshSuggestions() async =>
      asList((await _api.post('/ai/suggestion/refresh')).map['suggestions']).map(AiSuggestion.fromJson).toList();

  Future<int> acceptSuggestion(int id) async => toInt((await _api.post('/ai/suggestion/accept', data: {'suggestionId': id})).map['conversationId']);

  Future<void> dismissSuggestion(int id) => _api.post('/ai/suggestion/dismiss', data: {'suggestionId': id});
}
