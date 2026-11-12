import '../../core/utils/json.dart';

/// Paginator standar Laravel API Resource:
/// `{"data": [...], "links": {...}, "meta": {"current_page", "last_page", "per_page", "total", ...}}`
class Paginated<T> {
  const Paginated({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  bool get hasMore => currentPage < lastPage;

  factory Paginated.fromJson(JsonMap json, T? Function(JsonMap) parseItem) {
    final meta = asMap(json['meta']);
    final items = asList(json['data'])
        .map((e) => parseItem(asMap(e)))
        .whereType<T>()
        .toList(growable: false);
    final currentPage = asInt(meta['current_page']) ?? 1;
    return Paginated(
      items: items,
      currentPage: currentPage,
      lastPage: asInt(meta['last_page']) ?? currentPage,
      perPage: asInt(meta['per_page']) ?? items.length,
      total: asInt(meta['total']) ?? items.length,
    );
  }
}
