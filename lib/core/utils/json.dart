/// Helper parsing JSON yang toleran: tipe yang tidak sesuai menjadi null/default
/// alih-alih membuat aplikasi crash. Data hasil scraping sering tidak konsisten.
typedef JsonMap = Map<String, dynamic>;

JsonMap asMap(Object? value) =>
    value is Map ? value.map((k, v) => MapEntry('$k', v)) : <String, dynamic>{};

List<Object?> asList(Object? value) => value is List ? value : const [];

String? asString(Object? value) {
  if (value == null) return null;
  final text = '$value'.trim();
  return text.isEmpty ? null : text;
}

int? asInt(Object? value) => switch (value) {
      final int v => v,
      final num v => v.toInt(),
      final String v => int.tryParse(v) ?? double.tryParse(v)?.toInt(),
      _ => null,
    };

double? asDouble(Object? value) => switch (value) {
      final num v => v.toDouble(),
      final String v => double.tryParse(v),
      _ => null,
    };

bool asBool(Object? value) => switch (value) {
      final bool v => v,
      final num v => v != 0,
      final String v => v == '1' || v.toLowerCase() == 'true',
      _ => false,
    };

DateTime? asDate(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;

List<String> asStringList(Object? value) =>
    asList(value).map(asString).whereType<String>().toList(growable: false);
