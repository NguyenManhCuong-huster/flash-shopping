import 'dart:io';

import '../data/models/ai.dart';
import '../data/models/common.dart';
import '../data/models/misc.dart';
import '../data/models/user.dart';
import '../data/repositories/misc_repository.dart';

/// UC11 - Quản trị hệ thống (chỉ tài khoản system_role = admin).
class AdminService {
  AdminService(this._repo);
  final AdminRepository _repo;

  Future<Paged<User>> users({String? q, int page = 1}) => _repo.users(q: q, page: page);
  Future<void> setActive(User u, bool active) => _repo.updateUser(u.id, isActive: active);
  Future<void> setAdmin(User u, bool admin) => _repo.updateUser(u.id, systemRole: admin ? 'admin' : 'user');
  Future<Paged<AuditLog>> logs({String? action, String? source, int page = 1}) => _repo.logs(action: action, source: source, page: page);

  Future<List<NamedItem>> catalog(String kind) => _repo.catalog(kind);
  Future<void> createCatalog(String kind, String name) => _repo.createCatalog(kind, name.trim());
  Future<void> renameCatalog(String kind, String oldName, String newName) => _repo.renameCatalog(kind, oldName, newName.trim());
  Future<void> deleteCatalog(String kind, String name) => _repo.deleteCatalog(kind, name);
}

/// Trợ lý AI: hội thoại, xác nhận hành động, cài đặt, gợi ý chủ động.
class AiService {
  AiService(this._repo);
  final AiRepository _repo;

  Future<List<AiConversation>> conversations() => _repo.conversations();
  Future<AiConversationDetail> conversation(int id) => _repo.conversation(id);
  Future<void> deleteConversation(int id) => _repo.deleteConversation(id);

  Future<AiChatResult> send({int? conversationId, required String message, File? image}) async {
    final attachments = <int>[];
    if (image != null) attachments.add(await _repo.uploadAttachment(image));
    return _repo.chat(conversationId: conversationId, message: message.trim(), attachmentIds: attachments);
  }

  Future<({bool allOk, List<AiActionResult> results})> confirm(List<AiAction> actions) => _repo.confirm(actions.map((a) => a.id).toList());
  Future<void> reject(List<AiAction> actions) => _repo.reject(actions.map((a) => a.id).toList());

  Future<AiSettings> settings() => _repo.settings();
  Future<void> updateSettings({bool? enabled, String? autoExecuteLevel}) => _repo.updateSettings(enabled: enabled, autoExecuteLevel: autoExecuteLevel);

  Future<List<AiSuggestion>> suggestions() => _repo.suggestions();
  Future<List<AiSuggestion>> refreshSuggestions() => _repo.refreshSuggestions();
  Future<int> acceptSuggestion(AiSuggestion s) => _repo.acceptSuggestion(s.id);
  Future<void> dismissSuggestion(AiSuggestion s) => _repo.dismissSuggestion(s.id);
}
