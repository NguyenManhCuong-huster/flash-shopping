import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../application/pantry_service.dart';
import '../../application/session_service.dart';
import '../../application/validation/validators.dart';
import '../../data/models/common.dart';
import '../../data/models/food.dart';
import '../shared/base_view_model.dart';
import '../shared/widgets.dart';

class FoodsViewModel extends BaseViewModel {
  FoodsViewModel(this._pantry);
  final PantryService _pantry;

  List<Food> foods = [];
  List<NamedItem> categories = [];
  List<NamedItem> units = [];
  NamedItem? category;
  String query = '';
  int _page = 1;
  bool hasMore = false;

  Future<void> load() => runLoad(() async {
        categories = await _pantry.categories();
        units = await _pantry.units();
        _page = 1;
        final r = await _pantry.foods(q: query, categoryId: category?.id);
        foods = r.items;
        hasMore = r.hasMore;
      });

  Future<void> loadMore() async {
    if (!hasMore || loading) return;
    final r = await _pantry.foods(q: query, categoryId: category?.id, page: ++_page);
    foods = [...foods, ...r.items];
    hasMore = r.hasMore;
    notifyListeners();
  }

  void setCategory(NamedItem? c) {
    category = c;
    load();
  }

  Future<void> save({Food? existing, required String name, required String category, required String unit, File? image}) => runSave(() async {
        if (existing == null) {
          await _pantry.createFood(name: name, category: category, unit: unit, image: image);
        } else {
          await _pantry.updateFood(existing, newName: name, newCategory: category, newUnit: unit, image: image);
        }
      });

  Future<void> delete(Food f) => runSave(() async {
        await _pantry.deleteFood(f);
        foods.remove(f);
      });
}

/// Danh sách thực phẩm của nhóm: thành viên được thêm, trưởng nhóm được sửa/xóa.
class FoodsPage extends StatelessWidget {
  const FoodsPage({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(create: (c) => FoodsViewModel(c.read<PantryService>())..load(), child: const _FoodsView());
}

class _FoodsView extends StatefulWidget {
  const _FoodsView();
  @override
  State<_FoodsView> createState() => _FoodsViewState();
}

class _FoodsViewState extends State<_FoodsView> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FoodsViewModel>();
    final isLeader = context.watch<SessionService>().isLeader;
    return Scaffold(
      appBar: AppBar(title: const Text('Thực phẩm của nhóm')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, vm, null),
        icon: const Icon(Icons.add),
        label: const Text('Thêm thực phẩm'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Tìm thực phẩm'),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400), () {
                vm.query = v;
                vm.load();
              });
            },
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), children: [
            Padding(
              padding: const EdgeInsets.all(4),
              child: ChoiceChip(label: const Text('Tất cả'), selected: vm.category == null, onSelected: (_) => vm.setCategory(null)),
            ),
            for (final c in vm.categories)
              Padding(
                padding: const EdgeInsets.all(4),
                child: ChoiceChip(label: Text(c.name), selected: vm.category == c, onSelected: (_) => vm.setCategory(c)),
              ),
          ]),
        ),
        Expanded(
          child: AsyncBody(
            loading: vm.loading,
            error: vm.loadError,
            isEmpty: vm.foods.isEmpty,
            onRetry: vm.load,
            emptyText: 'Chưa có thực phẩm nào. Thêm thực phẩm để dùng cho tủ lạnh, danh sách mua và công thức.',
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) vm.loadMore();
                return false;
              },
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 90),
                itemCount: vm.foods.length,
                itemBuilder: (_, i) {
                  final f = vm.foods[i];
                  return Card(
                    child: ListTile(
                      leading: NetImage(f.imageUrl),
                      title: Text(f.name),
                      subtitle: Text('${f.category.name} · đơn vị: ${f.unit.name}'),
                      trailing: isLeader
                          ? PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'edit') {
                                  _openForm(context, vm, f);
                                } else if (await confirmDialog(context,
                                        title: 'Xóa thực phẩm', message: 'Xóa "${f.name}" sẽ xóa luôn mục tủ lạnh, nhiệm vụ mua, kế hoạch và công thức liên quan.') &&
                                    context.mounted) {
                                  await runAction(context, () => vm.delete(f), success: 'Đã xóa ${f.name}');
                                }
                              },
                              itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Sửa')), PopupMenuItem(value: 'delete', child: Text('Xóa'))],
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> _openForm(BuildContext context, FoodsViewModel vm, Food? food) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ChangeNotifierProvider.value(value: vm, child: _FoodForm(food: food)),
    );
    if (saved == true) vm.load();
  }
}

class _FoodForm extends StatefulWidget {
  const _FoodForm({this.food});
  final Food? food;
  @override
  State<_FoodForm> createState() => _FoodFormState();
}

class _FoodFormState extends State<_FoodForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.food?.name);
  String? _category;
  String? _unit;
  File? _image;

  @override
  void initState() {
    super.initState();
    _category = widget.food?.category.name;
    _unit = widget.food?.unit.name;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final vm = context.read<FoodsViewModel>();
    final f = widget.food;
    if (f != null && _name.text.trim() == f.name && _category == f.category.name && _unit == f.unit.name && _image == null) {
      Navigator.pop(context, false);
      return;
    }
    final ok = await runAction(context, () async {
      await vm.save(existing: f, name: _name.text, category: _category!, unit: _unit!, image: _image);
      return true;
    }, success: f == null ? 'Đã thêm thực phẩm' : 'Đã cập nhật');
    if (ok == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FoodsViewModel>();
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.food == null ? 'Thêm thực phẩm' : 'Sửa thực phẩm', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(children: [
            GestureDetector(
              onTap: () async {
                final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
                if (x != null) setState(() => _image = File(x.path));
              },
              child: _image != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_image!, width: 64, height: 64, fit: BoxFit.cover))
                  : NetImage(widget.food?.imageUrl, size: 64, icon: Icons.add_a_photo_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Tên thực phẩm'),
                validator: (v) => Validators.required(v, 'Tên thực phẩm') ?? Validators.maxLength(v, 150, 'Tên thực phẩm'),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Danh mục'),
            items: [for (final c in vm.categories) DropdownMenuItem(value: c.name, child: Text(c.name))],
            onChanged: (v) => setState(() => _category = v),
            validator: (v) => v == null ? 'Hãy chọn danh mục' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _unit,
            decoration: const InputDecoration(labelText: 'Đơn vị đo'),
            items: [for (final u in vm.units) DropdownMenuItem(value: u.name, child: Text(u.name))],
            onChanged: (v) => setState(() => _unit = v),
            validator: (v) => v == null ? 'Hãy chọn đơn vị đo' : null,
          ),
          const SizedBox(height: 20),
          SaveButton(saving: vm.saving, onPressed: _submit),
        ]),
      ),
    );
  }
}
