import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/notifications/media_resolver.dart';
import '../api_client.dart';
import '../../core/utils/app_colors.dart';
import 'app_toast.dart';
import 'buttons/custom_text_button.dart';

/// Thông báo toast sau mỗi hành động. Hiển thị ở vị trí trên cùng, tự biến mất sau 3 giây.
/// Giữ nguyên tên hàm showMessage để các trang đang gọi không bị lỗi,
/// nhưng nội dung hiện đại đã chuyển sang widget toast.
void showMessage(
  BuildContext context,
  String text, {
  bool error = false,
  VoidCallback? retry,
}) {
  showToast(
    context,
    message: text,
    error: error,
    position: ToastPosition.top,
    duration: const Duration(seconds: 3),
  );
}

/// Chạy thao tác ghi, hiện thông báo thành công/thất bại. Trả về kết quả (null nếu lỗi).
Future<T?> runAction<T>(
  BuildContext context,
  Future<T> Function() action, {
  String? success,
  bool retryable = true,
}) async {
  try {
    final r = await action();
    if (success != null && context.mounted) showMessage(context, success);
    return r;
  } on ApiException catch (e) {
    if (context.mounted) {
      showMessage(
        context,
        e.message,
        error: true,
        retry: e.network && retryable
            ? () => runAction(context, action, success: success)
            : null,
      );
    }
    return null;
  }
}

/// Hộp thoại nhập một dòng văn bản.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String? label,
  String? initial,
  String? Function(String?)? validator,
  String confirmText = 'Lưu',
}) {
  final ctrl = TextEditingController(text: initial);
  final formKey = GlobalKey<FormState>();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
          validator: validator,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate())
              Navigator.pop(ctx, ctrl.text.trim());
          },
          child: Text(confirmText),
        ),
      ],
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.onPress, this.subtitle});
  final String title;
  final VoidCallback? onPress;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColor.emerald800,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (onPress != null)
          CustomTextButton(
            onPressed: onPress,
            label: subtitle ?? 'Xem tất cả',
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: const TextStyle(
                color: AppColor.gray600,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
      ],
    );
  }
}

/// Ảnh từ server (đường dẫn tương đối /uploads/...) hoặc biểu tượng mặc định.
class NetImage extends StatelessWidget {
  const NetImage(
    this.path, {
    super.key,
    this.size = 44,
    this.icon = Icons.local_grocery_store_outlined,
    this.circle = false,
  });
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
      color: AppColor.primary.withValues(alpha: 0.08),
      child: Icon(icon, color: AppColor.primary, size: size * 0.55),
    );
    final img = url == null
        ? placeholder
        : Image.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => placeholder,
          );
    return circle
        ? ClipOval(child: img)
        : ClipRRect(borderRadius: BorderRadius.circular(8), child: img);
  }
}

/// Số căn phải (NFR01).
class NumText extends StatelessWidget {
  const NumText(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.right,
    style: style ?? const TextStyle(fontWeight: FontWeight.w600),
  );
}

/// Hiển thị khi tính năng yêu cầu thuộc một nhóm gia đình.
class NeedGroupView extends StatelessWidget {
  const NeedGroupView({super.key, required this.onCreateGroup});
  final VoidCallback onCreateGroup;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.family_restroom, size: 56, color: AppColor.primary),
          const SizedBox(height: 12),
          const Text(
            'Bạn chưa thuộc nhóm gia đình nào.\nHãy tạo nhóm hoặc nhờ trưởng nhóm thêm bạn bằng tên người dùng.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCreateGroup,
            icon: const Icon(Icons.group_add),
            label: const Text('Tạo / xem nhóm'),
          ),
        ],
      ),
    ),
  );
}

Future<T?> pushPage<T>(BuildContext context, Widget page) =>
    Navigator.push<T>(context, MaterialPageRoute(builder: (_) => page));
