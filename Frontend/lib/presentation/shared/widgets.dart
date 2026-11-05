import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/media_resolver.dart';
import '../../data/remote/api_client.dart';
import 'theme.dart';

/// Thân màn hình có 4 trạng thái: đang tải / lỗi (kèm thử lại) / rỗng / có dữ liệu (NFR06).
class AsyncBody extends StatelessWidget {
  const AsyncBody({super.key, required this.loading, this.error, required this.isEmpty, required this.onRetry, required this.child, this.emptyText = 'Chưa có dữ liệu', this.emptyIcon = Icons.inbox_outlined});

  final bool loading;
  final String? error;
  final bool isEmpty;
  final Future<void> Function() onRetry;
  final Widget child;
  final String emptyText;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    if (loading && isEmpty) return const Center(child: CircularProgressIndicator());
    if (error != null && isEmpty) return ErrorView(message: error!, onRetry: onRetry);
    if (isEmpty) {
      return RefreshIndicator(
        onRefresh: onRetry,
        child: ListView(children: [
          const SizedBox(height: 120),
          Icon(emptyIcon, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(emptyText, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.muted)),
        ]),
      );
    }
    return RefreshIndicator(onRefresh: onRetry, child: child);
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off, size: 48, color: AppTheme.danger),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Thử lại')),
          ]),
        ),
      );
}

/// Thông báo kết quả thao tác. Lỗi mạng có nút "Thử lại" vì thao tác chưa được lưu (NFR11).
void showMessage(BuildContext context, String text, {bool error = false, VoidCallback? retry}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Text(text),
    backgroundColor: error ? AppTheme.danger : null,
    duration: Duration(seconds: error ? 5 : 2),
    action: retry == null ? null : SnackBarAction(label: 'Thử lại', textColor: Colors.white, onPressed: retry),
  ));
}

/// Chạy thao tác ghi, hiện thông báo thành công/thất bại. Trả về kết quả (null nếu lỗi).
Future<T?> runAction<T>(BuildContext context, Future<T> Function() action, {String? success, bool retryable = true}) async {
  try {
    final r = await action();
    if (success != null && context.mounted) showMessage(context, success);
    return r;
  } on ApiException catch (e) {
    if (context.mounted) {
      showMessage(context, e.message, error: true, retry: e.network && retryable ? () => runAction(context, action, success: success) : null);
    }
    return null;
  }
}

/// Bắt buộc xác nhận trước khi xóa dữ liệu quan trọng (NFR06).
Future<bool> confirmDialog(BuildContext context, {required String title, required String message, String confirmText = 'Xóa', bool danger = true}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: AppTheme.danger) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Hộp thoại nhập một dòng văn bản.
Future<String?> promptText(BuildContext context, {required String title, String? label, String? initial, String? Function(String?)? validator, String confirmText = 'Lưu'}) {
  final ctrl = TextEditingController(text: initial);
  final formKey = GlobalKey<FormState>();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: TextFormField(controller: ctrl, autofocus: true, decoration: InputDecoration(labelText: label), validator: validator),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) Navigator.pop(ctx, ctrl.text.trim());
          },
          child: Text(confirmText),
        ),
      ],
    ),
  );
}

/// Nút lưu hiển thị vòng quay khi đang gửi.
class SaveButton extends StatelessWidget {
  const SaveButton({super.key, required this.saving, required this.onPressed, this.label = 'Lưu', this.icon = Icons.check});
  final bool saving;
  final VoidCallback? onPressed;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 46,
        child: FilledButton.icon(
          onPressed: saving ? null : onPressed,
          icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(icon),
          label: Text(saving ? 'Đang lưu...' : label),
        ),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 6),
        child: Row(children: [
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          if (trailing != null) trailing!,
        ]),
      );
}

/// Ảnh từ server (đường dẫn tương đối /uploads/...) hoặc biểu tượng mặc định.
class NetImage extends StatelessWidget {
  const NetImage(this.path, {super.key, this.size = 44, this.icon = Icons.local_grocery_store_outlined, this.circle = false});
  final String? path;
  final double size;
  final IconData icon;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final url = context.read<MediaResolver>().url(path);
    final placeholder = Container(
      width: size,
      height: size,
      color: AppTheme.primary.withValues(alpha: 0.08),
      child: Icon(icon, color: AppTheme.primary, size: size * 0.55),
    );
    final img = url == null
        ? placeholder
        : Image.network(url, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder);
    return circle ? ClipOval(child: img) : ClipRRect(borderRadius: BorderRadius.circular(8), child: img);
  }
}

/// Số căn phải (NFR01).
class NumText extends StatelessWidget {
  const NumText(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text(text, textAlign: TextAlign.right, style: style ?? const TextStyle(fontWeight: FontWeight.w600));
}

/// Hiển thị khi tính năng yêu cầu thuộc một nhóm gia đình.
class NeedGroupView extends StatelessWidget {
  const NeedGroupView({super.key, required this.onCreateGroup});
  final VoidCallback onCreateGroup;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.family_restroom, size: 56, color: AppTheme.primary),
            const SizedBox(height: 12),
            const Text('Bạn chưa thuộc nhóm gia đình nào.\nHãy tạo nhóm hoặc nhờ trưởng nhóm thêm bạn bằng tên người dùng.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: onCreateGroup, icon: const Icon(Icons.group_add), label: const Text('Tạo / xem nhóm')),
          ]),
        ),
      );
}

Future<T?> pushPage<T>(BuildContext context, Widget page) => Navigator.push<T>(context, MaterialPageRoute(builder: (_) => page));

/// Nhãn nhỏ có màu (trạng thái, vai trò...).
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color = AppTheme.primary});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}
