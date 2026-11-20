import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import './account_service.dart';
import '../../core/utils/validators.dart';
import '../user/user.dart';
import '../../core/api_client.dart';
import '../../core/base_view_model.dart';
import '../../core/widgets/widgets_common.dart';
import '../../core/widgets/buttons/primary_button.dart';
import '../../core/widgets/custom_text_form_field.dart';

class GroupViewModel extends BaseViewModel {
  GroupViewModel(this._account);
  final AccountService _account;

  Group? group;

  Future<void> load() async {
    group = await _account.group();
  }

  Future<Group> save({required String name}) => runSave(
        () => group == null
            ? _account.createGroup(name)
            : _account.renameGroup(name),
      );

  // Future<void> createGroup(String? name) =>
  //     runSave(() async => group = await _account.createGroup(name));

  // Future<void> rename(String name) =>
  //     runSave(() async => group = await _account.renameGroup(name));
}

class GroupModal extends StatelessWidget {
  const GroupModal({super.key, this.group});
  final Group? group;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (c) => GroupViewModel(c.read<AccountService>()),
    child: _GroupForm(group: group),
  );
}

class _GroupForm extends StatefulWidget {
  const _GroupForm({this.group});
  final Group? group;

  @override
  State<_GroupForm> createState() => _GroupFormState();
}

  class _GroupFormState extends State<_GroupForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nameController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.group?.name ?? '';
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final vm = context.read<GroupViewModel>();
    try {
      await vm.save(name: _nameController.text);
      if (!mounted) return;
      showMessage(
        context,
        'Đã tạo nhóm thành công.',
      );
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == '00005') {
        Navigator.pop(context);
      } else {
        showMessage(
          context,
          e.message,
          error: true,
          retry: e.network ? _submit : null,
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GroupViewModel>();
    return Form(key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          CustomTextFormField(
            labelText: 'Tên nhóm',
            required: true,
            hintText: 'Nhập tên nhóm',
            controller: _nameController,
            validator: (v) => Validators.required(v, 'Tên nhóm') ?? Validators.maxLength(v, 150, 'Tên nhóm'),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            saving: vm.saving,
            onPressed: _submit,
            label: widget.group == null ? 'Tạo nhóm' : 'Cập nhật',
          ),
        ],
      ),
    );
  }
}
