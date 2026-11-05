import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/admin_ai_service.dart';
import '../../application/session_service.dart';
import '../../application/validation/validators.dart';
import '../../data/models/common.dart';
import '../../data/models/misc.dart';
import '../../data/models/user.dart';
import '../../data/remote/api_client.dart';
import '../shared/format.dart';
import '../shared/theme.dart';
import '../shared/widgets.dart';

/// UC11 - Quản trị hệ thống: người dùng, danh mục, đơn vị, nhật ký.
/// Quản trị viên không xem được dữ liệu riêng của từng gia đình.
class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quản trị hệ thống'),
          bottom: const TabBar(isScrollable: true, tabs: [Tab(text: 'Người dùng'), Tab(text: 'Danh mục'), Tab(text: 'Đơn vị'), Tab(text: 'Nhật ký')]),
        ),
        body: const TabBarView(children: [_UsersTab(), _CatalogTab(kind: 'category'), _CatalogTab(kind: 'unit'), _LogsTab()]),
      ),
    );
  }
}

class _UsersTab extends StatefulWidget {
  const _UsersTab();
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  List<User> _users = [];
  bool _loading = true;
  String? _error;
  String _q = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await context.read<AdminService>().users(q: _q);
      if (!mounted) return;
      setState(() {
        _users = r.items;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.read<AdminService>();
    final myId = context.read<SessionService>().user?.id;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Tìm email, tên, username'),
          onChanged: (v) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 400), () {
              _q = v;
              _load();
            });
          },
        ),
      ),
      Expanded(
        child: AsyncBody(
          loading: _loading,
          error: _error,
          isEmpty: _users.isEmpty,
          onRetry: _load,
          child: ListView.builder(
            itemCount: _users.length,
            itemBuilder: (_, i) {
              final u = _users[i];
              final me = u.id == myId;
              return Card(
                child: ListTile(
                  leading: NetImage(u.imageUrl, circle: true, icon: Icons.person),
                  title: Text('${u.name}${me ? ' (bạn)' : ''}'),
                  subtitle: Text('${u.email}${u.username != null ? ' · @${u.username}' : ''}\n${u.groupId != null ? 'Thuộc nhóm #${u.groupId}' : 'Chưa có nhóm'}'),
                  isThreeLine: true,
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    if (u.isSystemAdmin) const Pill('Admin', color: AppTheme.warning),
                    if (!u.isActive) const Pill('Đã khóa', color: AppTheme.danger),
                  ]),
                  onTap: me
                      ? null
                      : () async {
                          final v = await showModalBottomSheet<String>(
                            context: context,
                            builder: (ctx) => SafeArea(
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                ListTile(
                                  leading: Icon(u.isActive ? Icons.lock_outline : Icons.lock_open),
                                  title: Text(u.isActive ? 'Khóa tài khoản' : 'Mở khóa tài khoản'),
                                  onTap: () => Navigator.pop(ctx, 'active'),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.admin_panel_settings_outlined),
                                  title: Text(u.isSystemAdmin ? 'Thu hồi quyền quản trị' : 'Cấp quyền quản trị'),
                                  onTap: () => Navigator.pop(ctx, 'admin'),
                                ),
                              ]),
                            ),
                          );
                          if (!context.mounted || v == null) return;
                          if (v == 'active') {
                            if (u.isActive &&
                                !await confirmDialog(context, title: 'Khóa tài khoản', message: 'Khóa ${u.email}? Người dùng bị đăng xuất khỏi mọi thiết bị.', confirmText: 'Khóa')) {
                              return;
                            }
                            if (context.mounted) await runAction(context, () => admin.setActive(u, !u.isActive), success: 'Đã cập nhật');
                          } else {
                            await runAction(context, () => admin.setAdmin(u, !u.isSystemAdmin), success: 'Đã cập nhật quyền');
                          }
                          _load();
                        },
                ),
              );
            },
          ),
        ),
      ),
    ]);
  }
}

class _CatalogTab extends StatefulWidget {
  const _CatalogTab({required this.kind});
  final String kind;
  @override
  State<_CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends State<_CatalogTab> {
  List<NamedItem> _items = [];
  bool _loading = true;
  String? _error;

  String get _label => widget.kind == 'category' ? 'danh mục' : 'đơn vị';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await context.read<AdminService>().catalog(widget.kind);
      if (!mounted) return;
      setState(() {
        _items = r;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.read<AdminService>();
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: widget.kind,
        onPressed: () async {
          final name = await promptText(context, title: 'Thêm $_label', validator: (v) => Validators.required(v, 'Tên'));
          if (name != null && context.mounted) {
            await runAction(context, () => admin.createCatalog(widget.kind, name), success: 'Đã thêm');
            _load();
          }
        },
        child: const Icon(Icons.add),
      ),
      body: AsyncBody(
        loading: _loading,
        error: _error,
        isEmpty: _items.isEmpty,
        onRetry: _load,
        child: ListView(children: [
          for (final it in _items)
            ListTile(
              title: Text(it.name),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    final name = await promptText(context, title: 'Đổi tên $_label', initial: it.name, validator: (v) => Validators.required(v, 'Tên'));
                    if (name != null && name != it.name && context.mounted) {
                      await runAction(context, () => admin.renameCatalog(widget.kind, it.name, name), success: 'Đã đổi tên');
                      _load();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await confirmDialog(context, title: 'Xóa $_label', message: 'Xóa "${it.name}"? Không thể xóa nếu đang được thực phẩm sử dụng.') && context.mounted) {
                      await runAction(context, () => admin.deleteCatalog(widget.kind, it.name), success: 'Đã xóa');
                      _load();
                    }
                  },
                ),
              ]),
            ),
          const SizedBox(height: 80),
        ]),
      ),
    );
  }
}

class _LogsTab extends StatefulWidget {
  const _LogsTab();
  @override
  State<_LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends State<_LogsTab> {
  final _logs = <AuditLog>[];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  String? _source;

  @override
  void initState() {
    super.initState();
    _more();
  }

  Future<void> _reset(String? source) async {
    setState(() {
      _source = source;
      _logs.clear();
      _page = 0;
      _hasMore = true;
    });
    await _more();
  }

  Future<void> _more() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    final r = await runAction(context, () => context.read<AdminService>().logs(source: _source, page: _page + 1));
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r != null) {
        _page = r.page;
        _hasMore = r.hasMore;
        _logs.addAll(r.items);
      } else {
        _hasMore = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Wrap(spacing: 6, children: [
        for (final s in [null, 'app', 'ai', 'system'])
          ChoiceChip(label: Text(s ?? 'Tất cả'), selected: _source == s, onSelected: (_) => _reset(s)),
      ]),
      Expanded(
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) _more();
            return false;
          },
          child: ListView.builder(
            itemCount: _logs.length + (_loading ? 1 : 0),
            itemBuilder: (_, i) {
              if (i >= _logs.length) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
              final l = _logs[i];
              return ListTile(
                dense: true,
                leading: Icon(l.source == 'ai' ? Icons.smart_toy_outlined : Icons.person_outline, size: 20),
                title: Text(l.action),
                subtitle: Text('${fmtDateTime(l.occurredAt)} · ${l.actorEmail ?? 'hệ thống'}${l.entityType != null ? ' · ${l.entityType} #${l.entityId}' : ''}'),
              );
            },
          ),
        ),
      ),
    ]);
  }
}
