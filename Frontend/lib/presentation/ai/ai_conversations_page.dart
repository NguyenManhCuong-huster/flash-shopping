import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/admin_ai_service.dart';
import '../../data/models/ai.dart';
import '../shared/base_view_model.dart';
import '../shared/format.dart';
import '../shared/theme.dart';
import '../shared/widgets.dart';
import 'ai_chat_page.dart';

class AiConversationsViewModel extends BaseViewModel {
  AiConversationsViewModel(this._ai);
  final AiService _ai;

  List<AiConversation> items = [];
  AiSettings? settings;

  Future<void> load() => runLoad(() async {
        settings = await _ai.settings();
        items = await _ai.conversations();
      });

  Future<void> delete(AiConversation c) => runSave(() async {
        await _ai.deleteConversation(c.id);
        items.remove(c);
      });

  Future<void> updateSettings({bool? enabled, String? level}) => runSave(() async {
        await _ai.updateSettings(enabled: enabled, autoExecuteLevel: level);
        settings = await _ai.settings();
      });
}

/// Trợ lý AI: danh sách cuộc hội thoại + cài đặt mức tự thực thi.
class AiConversationsPage extends StatelessWidget {
  const AiConversationsPage({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(create: (c) => AiConversationsViewModel(c.read<AiService>())..load(), child: const _View());
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AiConversationsViewModel>();
    final s = vm.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Trợ lý AI'), actions: [
        IconButton(icon: const Icon(Icons.tune), tooltip: 'Cài đặt', onPressed: s == null ? null : () => _settings(context, vm)),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await pushPage(context, const AiChatPage());
          vm.load();
        },
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('Hỏi trợ lý'),
      ),
      body: Column(children: [
        if (s != null && !s.available)
          const MaterialBanner(
            content: Text('Máy chủ chưa cấu hình khóa API cho trợ lý AI (AI_API_KEY). Gợi ý chủ động và xác nhận hành động vẫn dùng được.'),
            leading: Icon(Icons.info_outline, color: AppTheme.warning),
            actions: [SizedBox()],
          ),
        Expanded(
          child: AsyncBody(
            loading: vm.loading,
            error: vm.loadError,
            isEmpty: vm.items.isEmpty,
            onRetry: vm.load,
            emptyIcon: Icons.smart_toy_outlined,
            emptyText: 'Hỏi trợ lý: "Tủ lạnh còn gì sắp hết hạn?", "Tối nay nấu gì?", hoặc gửi ảnh hóa đơn để nhập tủ lạnh.',
            child: ListView.builder(
              itemCount: vm.items.length,
              itemBuilder: (_, i) {
                final c = vm.items[i];
                return Dismissible(
                  key: ValueKey(c.id),
                  direction: DismissDirection.endToStart,
                  background: Container(color: AppTheme.danger, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                  confirmDismiss: (_) => confirmDialog(context, title: 'Xóa cuộc hội thoại', message: 'Xóa "${c.title}"?'),
                  onDismissed: (_) => runAction(context, () => vm.delete(c)),
                  child: ListTile(
                    leading: const Icon(Icons.chat_outlined),
                    title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(relativeTime(c.updatedAt)),
                    onTap: () async {
                      await pushPage(context, AiChatPage(conversationId: c.id));
                      vm.load();
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> _settings(BuildContext context, AiConversationsViewModel vm) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => ChangeNotifierProvider.value(
        value: vm,
        child: Consumer<AiConversationsViewModel>(builder: (ctx, vm, _) {
          final s = vm.settings!;
          return SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const ListTile(title: Text('Cài đặt trợ lý AI', style: TextStyle(fontWeight: FontWeight.bold))),
              SwitchListTile(title: const Text('Bật trợ lý AI'), value: s.enabled, onChanged: (v) => runAction(ctx, () => vm.updateSettings(enabled: v))),
              SwitchListTile(
                title: const Text('Tự thực hiện thao tác tạo/sửa'),
                subtitle: const Text('Tắt: mọi thao tác tạo/sửa cần bạn bấm xác nhận. Thao tác xóa luôn cần xác nhận.'),
                value: s.autoExecuteLevel == 'write',
                onChanged: (v) => runAction(ctx, () => vm.updateSettings(level: v ? 'write' : 'read')),
              ),
              ListTile(title: const Text('Hạn mức token mỗi ngày'), trailing: NumText('${s.dailyTokenLimit}')),
            ]),
          );
        }),
      ),
    );
  }
}
