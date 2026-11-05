import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../application/admin_ai_service.dart';
import '../../data/models/ai.dart';
import '../../data/remote/api_client.dart';
import '../shared/base_view_model.dart';
import '../shared/theme.dart';
import '../shared/widgets.dart';

class AiChatViewModel extends BaseViewModel {
  AiChatViewModel(this._ai, this.conversationId);
  final AiService _ai;
  int? conversationId;

  List<AiMessage> messages = [];
  List<AiAction> actions = [];
  String title = 'Trợ lý AI';
  bool thinking = false;

  List<AiAction> get pending => actions.where((a) => a.isPending).toList();

  Future<void> load() => runLoad(() async {
        if (conversationId == null) return;
        final d = await _ai.conversation(conversationId!);
        title = d.conversation.title;
        messages = d.messages.where((m) => m.role != 'tool').toList();
        actions = d.actions;
      });

  Future<void> send(String text, File? image) async {
    messages = [...messages, AiMessage(id: -1, role: 'user', text: text, attachmentCount: image == null ? 0 : 1)];
    thinking = true;
    notifyListeners();
    try {
      final r = await _ai.send(conversationId: conversationId, message: text, image: image);
      conversationId = r.conversationId;
      await load();
    } finally {
      thinking = false;
      notifyListeners();
    }
  }

  Future<({bool allOk, List<AiActionResult> results})> confirm(List<AiAction> list) => runSave(() async {
        final r = await _ai.confirm(list);
        await load();
        return r;
      });

  Future<void> reject(List<AiAction> list) => runSave(() async {
        await _ai.reject(list);
        await load();
      });
}

/// Cuộc hội thoại với trợ lý AI. Thao tác ghi do AI đề xuất hiện dạng thẻ chờ xác nhận.
class AiChatPage extends StatelessWidget {
  const AiChatPage({super.key, this.conversationId});
  final int? conversationId;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(create: (c) => AiChatViewModel(c.read<AiService>(), conversationId)..load(), child: const _ChatView());
}

class _ChatView extends StatefulWidget {
  const _ChatView();
  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  File? _image;

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final vm = context.read<AiChatViewModel>();
    final image = _image;
    _input.clear();
    setState(() => _image = null);
    _toBottom();
    try {
      await vm.send(text, image);
      _toBottom();
    } on ApiException catch (e) {
      if (!mounted) return;
      _input.text = text; // giữ lại nội dung để gửi lại
      setState(() => _image = image);
      showMessage(context, e.message, error: true);
      vm.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AiChatViewModel>();
    return Scaffold(
      appBar: AppBar(title: Text(vm.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: Column(children: [
        Expanded(
          child: vm.loading && vm.messages.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView(controller: _scroll, padding: const EdgeInsets.all(12), children: [
                  if (vm.messages.isEmpty && !vm.thinking)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Ví dụ: "Tối nay nấu gì từ đồ sắp hết hạn? Thiếu gì thì tạo danh sách đi chợ."', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.muted)),
                    ),
                  for (final m in vm.messages) _bubble(m),
                  if (vm.thinking)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Row(children: [SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 8), Text('Trợ lý đang xử lý...')]),
                    ),
                  if (vm.pending.isNotEmpty) _pendingCard(context, vm),
                ]),
        ),
        if (_image != null)
          ListTile(
            dense: true,
            leading: ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.file(_image!, width: 40, height: 40, fit: BoxFit.cover)),
            title: const Text('Ảnh đính kèm'),
            trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _image = null)),
          ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(children: [
              IconButton(
                tooltip: 'Gửi ảnh hóa đơn / tủ lạnh',
                icon: const Icon(Icons.photo_camera_outlined),
                onPressed: vm.thinking
                    ? null
                    : () async {
                        final src = await showModalBottomSheet<ImageSource>(
                          context: context,
                          builder: (ctx) => SafeArea(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Chụp ảnh'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
                              ListTile(leading: const Icon(Icons.photo), title: const Text('Chọn từ thư viện'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
                            ]),
                          ),
                        );
                        if (src == null) return;
                        final x = await ImagePicker().pickImage(source: src, maxWidth: 1600, imageQuality: 80);
                        if (x != null) setState(() => _image = File(x.path));
                      },
              ),
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 4000,
                  decoration: const InputDecoration(hintText: 'Nhắn cho trợ lý...', counterText: ''),
                ),
              ),
              IconButton.filled(onPressed: vm.thinking ? null : _send, icon: const Icon(Icons.send)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _bubble(AiMessage m) {
    if (m.text.isEmpty) return const SizedBox();
    final user = m.isUser;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: user ? AppTheme.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (m.attachmentCount > 0) Text('[${m.attachmentCount} ảnh]', style: TextStyle(fontSize: 12, color: user ? Colors.white70 : AppTheme.muted)),
          Text(m.text, style: TextStyle(color: user ? Colors.white : Colors.black)),
        ]),
      ),
    );
  }

  /// Thẻ xác nhận: thao tác ghi/xóa AI đề xuất chỉ chạy khi người dùng đồng ý (hết hạn sau 15 phút).
  Widget _pendingCard(BuildContext context, AiChatViewModel vm) {
    final pending = vm.pending;
    return Card(
      color: AppTheme.warning.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppTheme.warning)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Hành động chờ bạn xác nhận', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          for (final a in pending)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(a.riskLevel == 'destructive' ? Icons.delete_outline : Icons.edit_note, size: 18, color: a.riskLevel == 'destructive' ? AppTheme.danger : AppTheme.primary),
                const SizedBox(width: 6),
                Expanded(child: Text('${a.summary}${a.dependsOn != null ? ' (sau #${a.dependsOn})' : ''}')),
              ]),
            ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: vm.saving ? null : () => runAction(context, () => vm.reject(pending), success: 'Đã từ chối'), child: const Text('Từ chối')),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: vm.saving
                  ? null
                  : () async {
                      final r = await runAction(context, () => vm.confirm(pending));
                      if (r == null || !context.mounted) return;
                      if (r.allOk) {
                        showMessage(context, 'Đã thực hiện ${r.results.length} hành động');
                      } else {
                        final failed = r.results.where((x) => x.status != 'executed').map((x) => '#${x.actionId}: ${x.message}').join('\n');
                        showMessage(context, 'Một số hành động chưa thực hiện được:\n$failed', error: true);
                      }
                    },
              child: Text('Đồng ý tất cả (${pending.length})'),
            ),
          ]),
        ]),
      ),
    );
  }
}
