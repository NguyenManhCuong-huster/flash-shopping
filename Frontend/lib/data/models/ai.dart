import 'common.dart';

class AiConversation {
  const AiConversation(this.id, this.title, this.updatedAt);
  final int id;
  final String title;
  final DateTime updatedAt;

  factory AiConversation.fromJson(Json j) =>
      AiConversation(toInt(j['id']), j['title']?.toString() ?? '', toDate(j['updatedAt']) ?? DateTime.now());
}

class AiMessage {
  const AiMessage({required this.id, required this.role, required this.text, this.toolCalls = const [], this.attachmentCount = 0});
  final int id;

  /// user | assistant | tool
  final String role;
  final String text;
  final List<String> toolCalls;
  final int attachmentCount;

  bool get isUser => role == 'user';

  factory AiMessage.fromJson(Json j) => AiMessage(
        id: toInt(j['id']),
        role: j['role']?.toString() ?? 'assistant',
        text: j['text']?.toString() ?? '',
        toolCalls: ((j['toolCalls'] as List?) ?? const []).map((e) => e.toString()).toList(),
        attachmentCount: ((j['attachmentIds'] as List?) ?? const []).length,
      );
}

/// Hành động AI đề xuất / đã thực hiện (bảng ai_actions).
class AiAction {
  const AiAction({required this.id, required this.tool, required this.riskLevel, required this.summary, required this.status, this.dependsOn, this.resultCode, this.expiresAt});
  final int id;
  final String tool;

  /// read | write | destructive
  final String riskLevel;
  final String summary;

  /// proposed | executing | executed | rejected | failed | expired
  final String status;
  final int? dependsOn;
  final String? resultCode;
  final DateTime? expiresAt;

  bool get isPending => status == 'proposed' && (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  factory AiAction.fromJson(Json j) => AiAction(
        id: toInt(j['actionId'] ?? j['id']),
        tool: j['tool']?.toString() ?? '',
        riskLevel: j['riskLevel']?.toString() ?? 'write',
        summary: j['summary']?.toString() ?? '',
        status: j['status']?.toString() ?? 'proposed',
        dependsOn: j['dependsOn'] == null ? null : toInt(j['dependsOn']),
        resultCode: j['resultCode']?.toString(),
        expiresAt: toDate(j['expiresAt']),
      );
}

class AiChatResult {
  const AiChatResult(this.conversationId, this.reply, this.pendingActions);
  final int conversationId;
  final String reply;
  final List<AiAction> pendingActions;
}

class AiConversationDetail {
  const AiConversationDetail(this.conversation, this.messages, this.actions);
  final AiConversation conversation;
  final List<AiMessage> messages;
  final List<AiAction> actions;
}

class AiSettings {
  const AiSettings({required this.enabled, required this.autoExecuteLevel, required this.dailyTokenLimit, required this.available});
  final bool enabled;

  /// read | write
  final String autoExecuteLevel;
  final int dailyTokenLimit;

  /// Máy chủ đã cấu hình LLM chưa
  final bool available;
}

class AiSuggestion {
  const AiSuggestion(this.id, this.type, this.title);
  final int id;
  final String type;
  final String title;

  factory AiSuggestion.fromJson(Json j) => AiSuggestion(toInt(j['id']), j['type']?.toString() ?? '', j['title']?.toString() ?? '');
}

class AiActionResult {
  const AiActionResult(this.actionId, this.status, this.message);
  final int actionId;
  final String status;
  final String message;

  factory AiActionResult.fromJson(Json j) =>
      AiActionResult(toInt(j['actionId']), j['status']?.toString() ?? '', j['message']?.toString() ?? '');
}
