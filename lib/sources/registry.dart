import 'catalog.dart';
import 'id/komiku.dart';
import 'id/shinigami.dart';
import 'source.dart';

/// Sumber yang ditulis tangan (bukan template). Ditaruh di depan dan menang
/// bila ID-nya sama dengan entri katalog.
List<MangaSource> customSources() => [
      KomikuSource(),
      ShinigamiSource(),
    ];

/// Semua sumber: sumber kustom + katalog template (Madara, MangaThemesia)
/// yang dihasilkan dari keiyoushi/extensions-source.
///
/// Domain situs sering pindah; ganti lewat ikon gir di tab Sumber, atau
/// perbarui katalog dengan `tool/generate_source_catalog.mjs`.
List<MangaSource> builtInSources({SourceCatalog catalog = SourceCatalog.empty}) {
  final sources = customSources();
  final ids = sources.map((s) => s.id).toSet();
  for (final entry in catalog.entries) {
    if (!ids.add(entry.id)) continue;
    final source = entry.create();
    if (source != null) sources.add(source);
  }
  return sources;
}

class SourceRegistry {
  SourceRegistry(List<MangaSource> sources, {this.experimentalIds = const {}})
      : sources = List.unmodifiable(sources),
        _byId = {for (final s in sources) s.id: s};

  final List<MangaSource> sources;
  final Map<String, MangaSource> _byId;

  /// Sumber katalog yang di Kotlin punya logika khusus; port template bisa
  /// kurang pas (ditandai "eksperimental" di UI).
  final Set<String> experimentalIds;

  MangaSource? byId(String id) => _byId[id];
}
