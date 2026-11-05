import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/insight_service.dart';
import '../../data/models/misc.dart';
import '../shared/base_view_model.dart';
import '../shared/format.dart';
import '../shared/pickers.dart';
import '../shared/theme.dart';
import '../shared/widgets.dart';

const eventLabels = {
  'purchase': 'Mua',
  'add': 'Nhập tay',
  'consume': 'Đã dùng',
  'discard': 'Bỏ đi',
  'adjust': 'Điều chỉnh',
  'remove': 'Xóa khỏi tủ',
};

class StatsViewModel extends BaseViewModel {
  StatsViewModel(this._insight);
  final InsightService _insight;

  DateTime from = dateOnly(DateTime.now()).subtract(const Duration(days: 29));
  DateTime to = dateOnly(DateTime.now());
  StatsReport? report;

  Future<void> load() => runLoad(() async => report = await _insight.stats(from, to));

  void setRange(DateTime f, DateTime t) {
    from = f;
    to = t;
    load();
  }
}

/// UC10 - Thống kê mua và tiêu thụ trong khoảng thời gian.
class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(create: (c) => StatsViewModel(c.read<InsightService>())..load(), child: const _View());
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StatsViewModel>();
    final r = vm.report;
    return Scaffold(
      appBar: AppBar(title: const Text('Thống kê'), actions: [
        IconButton(tooltip: 'Lịch sử biến động', icon: const Icon(Icons.history), onPressed: () => pushPage(context, EventsPage(from: vm.from, to: vm.to))),
      ]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(children: [
            Expanded(child: DateField(label: 'Từ ngày', value: vm.from, onChanged: (d) => vm.setRange(d, vm.to))),
            const SizedBox(width: 8),
            Expanded(child: DateField(label: 'Đến ngày', value: vm.to, onChanged: (d) => vm.setRange(vm.from, d))),
          ]),
        ),
        Wrap(spacing: 6, children: [
          for (final days in [7, 30, 90])
            ActionChip(
              label: Text('$days ngày'),
              onPressed: () => vm.setRange(dateOnly(DateTime.now()).subtract(Duration(days: days - 1)), dateOnly(DateTime.now())),
            ),
        ]),
        Expanded(
          child: AsyncBody(
            loading: vm.loading,
            error: vm.loadError,
            isEmpty: r == null,
            onRetry: vm.load,
            child: r == null
                ? const SizedBox()
                : ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Wrap(alignment: WrapAlignment.center, children: [
                        _tile('Lần mua', r.totals['purchase'] ?? 0, AppTheme.primary),
                        _tile('Nhập tay', r.totals['add'] ?? 0, AppTheme.primary),
                        _tile('Lần dùng', r.totals['consume'] ?? 0, Colors.blue),
                        _tile('Lần bỏ đi', r.totals['discard'] ?? 0, AppTheme.danger),
                      ]),
                    ),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.delete_sweep_outlined, color: AppTheme.danger),
                        title: const Text('Tỉ lệ lãng phí'),
                        subtitle: const Text('Số lần bỏ đi / (dùng + bỏ đi)'),
                        trailing: NumText('${(r.wasteRate * 100).toStringAsFixed(1)}%'),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.shopping_cart_checkout, color: AppTheme.primary),
                        title: const Text('Đi chợ'),
                        subtitle: Text('${r.lists} danh sách trong kỳ'),
                        trailing: NumText('${r.boughtTasks}/${r.tasks} món'),
                      ),
                    ),
                    if (r.byCategory.isNotEmpty) const SectionTitle('Theo danh mục (số lần)'),
                    for (final c in r.byCategory) _categoryBar(c, r.byCategory.map((x) => x.inEvents + x.consumeEvents + x.discardEvents).reduce((a, b) => a > b ? a : b)),
                    if (r.byFood.isNotEmpty) const SectionTitle('Theo thực phẩm'),
                    if (r.byFood.isNotEmpty)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 18,
                          columns: const [
                            DataColumn(label: Text('Thực phẩm')),
                            DataColumn(label: Text('Mua'), numeric: true),
                            DataColumn(label: Text('Dùng'), numeric: true),
                            DataColumn(label: Text('Bỏ'), numeric: true),
                          ],
                          rows: [
                            for (final f in r.byFood)
                              DataRow(cells: [
                                DataCell(Text('${f.foodName} (${f.unit})')),
                                DataCell(Text(fmtQty(f.purchased + f.added))),
                                DataCell(Text(fmtQty(f.consumed))),
                                DataCell(Text(fmtQty(f.discarded), style: TextStyle(color: f.discarded > 0 ? AppTheme.danger : null))),
                              ]),
                          ],
                        ),
                      ),
                    if (r.byFood.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Chưa có biến động kho trong khoảng thời gian này.', textAlign: TextAlign.center)),
                  ]),
          ),
        ),
      ]),
    );
  }

  Widget _tile(String label, int value, Color color) => SizedBox(
        width: 160,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Text('$value', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              Text(label),
            ]),
          ),
        ),
      );

  Widget _categoryBar(CategoryStat c, int max) {
    Widget seg(int v, Color color) => v == 0 ? const SizedBox() : Expanded(flex: v, child: Container(height: 12, color: color));
    final total = c.inEvents + c.consumeEvents + c.discardEvents;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        SizedBox(width: 110, child: Text(c.category, overflow: TextOverflow.ellipsis)),
        Expanded(
          child: Row(children: [
            Expanded(
              flex: total == 0 ? 1 : total,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Row(children: [seg(c.inEvents, AppTheme.primary), seg(c.consumeEvents, Colors.blue), seg(c.discardEvents, AppTheme.danger)]),
              ),
            ),
            if (max - total > 0) Expanded(flex: max - total, child: const SizedBox()),
          ]),
        ),
        SizedBox(width: 36, child: NumText('$total')),
      ]),
    );
  }
}

/// Lịch sử biến động kho, tải cuộn 50 bản ghi mỗi lần (NFR08).
class EventsPage extends StatefulWidget {
  const EventsPage({super.key, required this.from, required this.to});
  final DateTime from;
  final DateTime to;
  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final _events = <StockEvent>[];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;
  String? _type;

  @override
  void initState() {
    super.initState();
    _more();
  }

  Future<void> _reload() async {
    setState(() {
      _events.clear();
      _page = 0;
      _hasMore = true;
    });
    await _more();
  }

  Future<void> _more() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    final r = await runAction(context, () => context.read<InsightService>().events(widget.from, widget.to, type: _type, page: _page + 1));
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r == null) {
        _error = 'Không tải được lịch sử';
        return;
      }
      _error = null;
      _page = r.page;
      _hasMore = r.hasMore;
      _events.addAll(r.items);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Biến động kho ${fmtDate(widget.from)} - ${fmtDate(widget.to)}')),
      body: Column(children: [
        SizedBox(
          height: 48,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(4), children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(label: const Text('Tất cả'), selected: _type == null, onSelected: (_) {
                _type = null;
                _reload();
              }),
            ),
            for (final e in eventLabels.entries)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(label: Text(e.value), selected: _type == e.key, onSelected: (_) {
                  _type = e.key;
                  _reload();
                }),
              ),
          ]),
        ),
        Expanded(
          child: _error != null && _events.isEmpty
              ? ErrorView(message: _error!, onRetry: _reload)
              : NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) _more();
                    return false;
                  },
                  child: ListView.builder(
                    itemCount: _events.length + (_loading ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i >= _events.length) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                      final e = _events[i];
                      final sign = switch (e.type) { 'purchase' || 'add' => '+', 'adjust' => e.quantity >= 0 ? '+' : '', _ => '-' };
                      return ListTile(
                        title: Text('${eventLabels[e.type] ?? e.type}: ${e.foodName}'),
                        subtitle: Text('${fmtDateTime(e.occurredAt)}${e.actorName != null ? ' · ${e.actorName}' : ''}${e.note != null ? ' · ${e.note}' : ''}'),
                        trailing: NumText('$sign${fmtQtyUnit(e.quantity.abs(), e.unit)}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: sign == '+' ? AppTheme.primary : AppTheme.danger)),
                      );
                    },
                  ),
                ),
        ),
      ]),
    );
  }
}
