import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/pantry_service.dart';
import '../../data/models/food.dart';
import '../../data/remote/api_client.dart';
import 'format.dart';
import 'widgets.dart';

/// Hộp thoại tìm và chọn thực phẩm của nhóm (tìm phía server, tối đa 50 kết quả mỗi lần).
Future<Food?> pickFood(BuildContext context, {String title = 'Chọn thực phẩm'}) {
  return showModalBottomSheet<Food>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FoodPicker(title: title, service: context.read<PantryService>()),
  );
}

class _FoodPicker extends StatefulWidget {
  const _FoodPicker({required this.title, required this.service});
  final String title;
  final PantryService service;

  @override
  State<_FoodPicker> createState() => _FoodPickerState();
}

class _FoodPickerState extends State<_FoodPicker> {
  List<Food> _foods = [];
  bool _loading = true;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final r = await widget.service.foods(q: q);
      if (!mounted) return;
      setState(() {
        _foods = r.items;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(children: [
          ListTile(title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Tìm theo tên thực phẩm'),
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 350), () => _search(v));
              },
            ),
          ),
          const SizedBox(height: 8),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) Padding(padding: const EdgeInsets.all(16), child: Text(_error!, style: const TextStyle(color: Colors.red))),
          Expanded(
            child: _foods.isEmpty && !_loading
                ? const Center(child: Text('Không có thực phẩm phù hợp.\nHãy thêm ở mục "Thực phẩm" trước.', textAlign: TextAlign.center))
                : ListView.builder(
                    itemCount: _foods.length,
                    itemBuilder: (_, i) {
                      final f = _foods[i];
                      return ListTile(
                        leading: NetImage(f.imageUrl, size: 36),
                        title: Text(f.name),
                        subtitle: Text('${f.category.name} · đơn vị ${f.unit.name}'),
                        onTap: () => Navigator.pop(context, f),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

/// Ô chọn ngày hiển thị dd/MM/yyyy.
class DateField extends StatelessWidget {
  const DateField({super.key, required this.label, required this.value, required this.onChanged, this.firstDate, this.lastDate});
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: firstDate ?? DateTime(now.year - 1),
          lastDate: lastDate ?? DateTime(now.year + 5),
        );
        if (d != null) onChanged(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today, size: 18)),
        child: Text(value == null ? 'Chọn ngày' : fmtDate(value!)),
      ),
    );
  }
}
