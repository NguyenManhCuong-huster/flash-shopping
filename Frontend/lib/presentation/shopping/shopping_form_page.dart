import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/account_service.dart';
import '../../application/shopping_service.dart';
import '../../application/validation/validators.dart';
import '../../data/models/shopping.dart';
import '../../data/models/user.dart';
import '../../data/remote/api_client.dart';
import '../shared/base_view_model.dart';
import '../shared/pickers.dart';
import '../shared/widgets.dart';

class ShoppingFormViewModel extends BaseViewModel {
  ShoppingFormViewModel(this._shopping, this._account);
  final ShoppingService _shopping;
  final AccountService _account;

  List<Member> members = [];

  Future<void> load() => runLoad(() async => members = (await _account.group()).members);

  Future<ShoppingList> save({ShoppingList? existing, required String name, required DateTime date, String? assignee, String? note}) => runSave(() =>
      existing == null
          ? _shopping.createList(name: name, date: date, assignToUsername: assignee, note: note)
          : _shopping.updateList(existing, name: name, date: date, assignToUsername: assignee, note: note));
}

/// Tạo/sửa danh sách mua sắm (trưởng nhóm). Người được giao chỉ chọn trong thành viên cùng nhóm.
/// Khi tạo mới, trả về id danh sách để chuyển sang bước thêm mục.
class ShoppingFormPage extends StatelessWidget {
  const ShoppingFormPage({super.key, this.list});
  final ShoppingList? list;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (c) => ShoppingFormViewModel(c.read<ShoppingService>(), c.read<AccountService>())..load(),
        child: _Form(list: list),
      );
}

class _Form extends StatefulWidget {
  const _Form({this.list});
  final ShoppingList? list;
  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.list?.name ?? 'Đi chợ');
  late final TextEditingController _note = TextEditingController(text: widget.list?.note ?? '');
  late DateTime _date = widget.list == null ? DateTime.now() : parseIsoDate(widget.list!.date);
  late String? _assignee = widget.list?.assignedTo?.username;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final vm = context.read<ShoppingFormViewModel>();
    try {
      final l = await vm.save(existing: widget.list, name: _name.text, date: _date, assignee: _assignee, note: _note.text);
      if (!mounted) return;
      showMessage(context, widget.list == null ? 'Đã tạo danh sách. Hãy thêm các món cần mua.' : 'Đã cập nhật danh sách');
      Navigator.pop(context, l.id);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == '00252') {
        Navigator.pop(context); // Không có thay đổi
      } else {
        showMessage(context, e.message, error: true, retry: e.network ? _submit : null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ShoppingFormViewModel>();
    final withUsername = vm.members.where((m) => m.username != null).toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.list == null ? 'Tạo danh sách mua sắm' : 'Sửa danh sách')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Tên danh sách'),
            validator: (v) => Validators.required(v, 'Tên danh sách') ?? Validators.maxLength(v, 150, 'Tên danh sách'),
          ),
          const SizedBox(height: 12),
          DateField(label: 'Ngày đi chợ', value: _date, onChanged: (d) => setState(() => _date = d)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: withUsername.any((m) => m.username == _assignee) ? _assignee : null,
            decoration: InputDecoration(labelText: 'Giao cho', helperText: vm.loading ? 'Đang tải thành viên...' : 'Chỉ chọn được thành viên cùng nhóm'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Chưa giao')),
              for (final m in withUsername) DropdownMenuItem<String?>(value: m.username, child: Text('${m.name} (@${m.username})')),
            ],
            onChanged: (v) => setState(() => _assignee = v),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _note, maxLines: 3, maxLength: 1000, decoration: const InputDecoration(labelText: 'Ghi chú (tùy chọn)')),
          const SizedBox(height: 12),
          SaveButton(saving: vm.saving, onPressed: _submit, label: widget.list == null ? 'Tạo và thêm món' : 'Lưu'),
        ]),
      ),
    );
  }
}
