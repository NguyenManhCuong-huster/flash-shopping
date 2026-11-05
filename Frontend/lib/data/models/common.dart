/// Kiểu dữ liệu dùng chung giữa các model.
typedef Json = Map<String, dynamic>;

double toDouble(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
double? toDoubleOrNull(dynamic v) => v == null ? null : toDouble(v);
int toInt(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);
DateTime? toDate(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
Json asJson(dynamic v) => (v as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
List<Json> asList(dynamic v) => ((v as List?) ?? const []).map((e) => asJson(e)).toList();

/// Danh mục / đơn vị: chỉ có id + tên.
class NamedItem {
  const NamedItem(this.id, this.name);
  final int id;
  final String name;

  factory NamedItem.fromJson(Json j) => NamedItem(toInt(j['id']), j['name']?.toString() ?? '');

  @override
  bool operator ==(Object other) => other is NamedItem && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

/// Kết quả phân trang (tối đa 50 bản ghi mỗi lần tải - NFR08).
class Paged<T> {
  const Paged(this.items, {this.page = 1, this.totalPages = 1, this.total = 0});
  final List<T> items;
  final int page;
  final int totalPages;
  final int total;

  bool get hasMore => page < totalPages;

  factory Paged.fromJson(Json j, String key, T Function(Json) parse) => Paged(
        asList(j[key]).map(parse).toList(),
        page: toInt(j['page'] ?? 1),
        totalPages: toInt(j['totalPages'] ?? 1),
        total: toInt(j['total'] ?? 0),
      );
}
