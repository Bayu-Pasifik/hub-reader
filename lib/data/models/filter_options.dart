import '../../core/utils/json.dart';
import 'series.dart';

class TypeFilterOptions {
  const TypeFilterOptions({this.genres = const [], this.statuses = const []});

  final List<String> genres;
  final List<String> statuses;
}

/// Respons GET /api/v1/genres:
/// `{"data": {"novel": {"genres": [...], "statuses": [...]}, "comic": {...}}}`
class FilterOptions {
  const FilterOptions(this._byType);

  final Map<SeriesType, TypeFilterOptions> _byType;

  TypeFilterOptions forType(SeriesType type) =>
      _byType[type] ?? const TypeFilterOptions();

  factory FilterOptions.fromJson(JsonMap json) {
    final data = asMap(json['data']);
    return FilterOptions({
      for (final type in SeriesType.values)
        type: TypeFilterOptions(
          genres: asStringList(asMap(data[type.name])['genres']),
          statuses: asStringList(asMap(data[type.name])['statuses']),
        ),
    });
  }
}
