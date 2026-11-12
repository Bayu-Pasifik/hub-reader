/// Model untuk sumber novel (plugin LNReader).
///
/// Struktur mengikuti `Plugin.NovelItem`, `Plugin.SourceNovel`,
/// `Plugin.ChapterItem` di lnreader-plugins (src/types/plugin.ts). Path novel
/// & bab disimpan apa adanya (relatif ke situs plugin), karena plugin sendiri
/// yang tahu cara memakainya.
library;

import '../core/utils/json.dart';

/// Satu entri `plugins.min.json` dari repo lnreader-plugins.
class NovelPluginInfo {
  const NovelPluginInfo({
    required this.id,
    required this.name,
    required this.site,
    required this.lang,
    required this.version,
    required this.url,
    this.iconUrl,
  });

  final String id;
  final String name;
  final String site;

  /// Kode bahasa (lihat [langCodeOf]); `multi` untuk plugin multi-bahasa.
  final String lang;
  final String version;

  /// URL kode plugin (JS hasil compile).
  final String url;
  final String? iconUrl;

  static NovelPluginInfo? tryParse(JsonMap json) {
    final id = asString(json['id']);
    final url = asString(json['url']);
    if (id == null || url == null) return null;
    return NovelPluginInfo(
      id: id,
      name: asString(json['name']) ?? id,
      site: asString(json['site']) ?? '',
      lang: langCodeOf(asString(json['lang']) ?? ''),
      version: asString(json['version']) ?? '0.0.0',
      url: url,
      iconUrl: asString(json['iconUrl']),
    );
  }

  /// Host situs untuk ditampilkan.
  String get host => Uri.tryParse(site)?.host ?? site;
}

/// Nama bahasa di manifest LNReader (nama asli) → kode ISO.
String langCodeOf(String name) {
  final n = name.replaceAll('‎', '').trim();
  return switch (n) {
    'English' => 'en',
    'Bahasa Indonesia' => 'id',
    'العربية' => 'ar',
    'বাংলা' => 'bn',
    '中文, 汉语, 漢語' => 'zh',
    'Français' => 'fr',
    '日本語' => 'ja',
    '조선말, 한국어' => 'ko',
    'Polski' => 'pl',
    'Português' => 'pt',
    'Русский' => 'ru',
    'Español' => 'es',
    'ไทย' => 'th',
    'Türkçe' => 'tr',
    'Українська' => 'uk',
    'Tiếng Việt' => 'vi',
    'Multi' => 'all',
    _ => n.isEmpty ? 'all' : n.toLowerCase(),
  };
}

class NovelItem {
  const NovelItem({required this.path, required this.name, this.cover});

  final String path;
  final String name;
  final String? cover;

  static NovelItem? tryParse(Object? raw) {
    final json = asMap(raw);
    final path = asString(json['path']);
    if (path == null) return null;
    return NovelItem(path: path, name: asString(json['name'])?.trim() ?? 'Tanpa judul', cover: _cover(json['cover']));
  }

  @override
  bool operator ==(Object other) => other is NovelItem && other.path == path;

  @override
  int get hashCode => path.hashCode;
}

class NovelChapter {
  const NovelChapter({
    required this.path,
    required this.name,
    this.releaseTime,
    this.number,
    this.page,
  });

  final String path;
  final String name;
  final String? releaseTime;
  final double? number;

  /// Halaman daftar bab (plugin berhalaman / `parsePage`).
  final String? page;

  static NovelChapter? tryParse(Object? raw) {
    final json = asMap(raw);
    final path = asString(json['path']);
    if (path == null) return null;
    return NovelChapter(
      path: path,
      name: asString(json['name'])?.trim() ?? 'Bab',
      releaseTime: asString(json['releaseTime']),
      number: (json['chapterNumber'] as num?)?.toDouble(),
      page: json['page']?.toString(),
    );
  }

  @override
  bool operator ==(Object other) => other is NovelChapter && other.path == path;

  @override
  int get hashCode => path.hashCode;
}

class NovelDetails {
  const NovelDetails({
    required this.path,
    required this.name,
    this.cover,
    this.author,
    this.artist,
    this.status,
    this.summary,
    this.genres = const [],
    this.rating,
    this.chapters = const [],
    this.totalPages = 1,
  });

  final String path;
  final String name;
  final String? cover;
  final String? author;
  final String? artist;
  final String? status;
  final String? summary;
  final List<String> genres;
  final double? rating;

  /// Urutan dari plugin (umumnya bab 1 → terbaru).
  final List<NovelChapter> chapters;

  /// > 1 bila daftar bab dibagi per halaman (`PagePlugin.parsePage`).
  final int totalPages;

  static NovelDetails parse(String path, Object? raw) {
    final json = asMap(raw);
    return NovelDetails(
      path: asString(json['path']) ?? path,
      name: asString(json['name'])?.trim() ?? 'Tanpa judul',
      cover: _cover(json['cover']),
      author: _blank(asString(json['author'])),
      artist: _blank(asString(json['artist'])),
      status: _blank(asString(json['status'])),
      summary: _blank(asString(json['summary'])),
      genres: (asString(json['genres']) ?? '')
          .split(RegExp(r'\s*,\s*'))
          .where((g) => g.isNotEmpty)
          .toList(),
      rating: (json['rating'] as num?)?.toDouble(),
      chapters: asList(json['chapters']).map(NovelChapter.tryParse).whereType<NovelChapter>().toList(),
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}

String? _blank(String? s) => s == null || s.trim().isEmpty ? null : s.trim();

/// Sampul "tidak tersedia" bawaan LNReader dianggap tidak ada.
String? _cover(Object? raw) {
  final s = asString(raw);
  if (s == null || s.isEmpty || s.contains('coverNotAvailable')) return null;
  return s;
}

// -------------------------------------------------------------------- filter

/// Tipe filter LNReader (`FilterTypes` di src/types/filters.ts).
enum NovelFilterType {
  text('Text'),
  picker('Picker'),
  checkbox('Checkbox'),
  toggle('Switch'),
  excludable('XCheckbox');

  const NovelFilterType(this.wire);

  final String wire;

  static NovelFilterType? of(String? wire) {
    for (final t in values) {
      if (t.wire == wire) return t;
    }
    return null;
  }
}

class NovelFilterOption {
  const NovelFilterOption(this.label, this.value);

  final String label;
  final String value;
}

/// Definisi satu filter plugin beserta nilai bawaannya.
class NovelFilterDef {
  const NovelFilterDef({
    required this.key,
    required this.label,
    required this.type,
    required this.defaultValue,
    this.options = const [],
  });

  final String key;
  final String label;
  final NovelFilterType type;

  /// String (text/picker), bool (switch), `List<String>` (checkbox),
  /// {include: [], exclude: []} (excludable).
  final Object? defaultValue;
  final List<NovelFilterOption> options;

  static List<NovelFilterDef> parseAll(Object? raw) {
    final out = <NovelFilterDef>[];
    for (final e in asMap(raw).entries) {
      final f = asMap(e.value);
      final type = NovelFilterType.of(asString(f['type']));
      if (type == null) continue;
      out.add(NovelFilterDef(
        key: e.key,
        label: asString(f['label']) ?? e.key,
        type: type,
        defaultValue: f['value'],
        options: [
          for (final o in asList(f['options']))
            NovelFilterOption(asString(asMap(o)['label']) ?? '', '${asMap(o)['value'] ?? ''}'),
        ],
      ));
    }
    return out;
  }
}

/// Nilai filter yang dikirim ke `popularNovels(page, {filters})`:
/// `{key: {type, value}}`. Kosong = pakai default plugin.
typedef NovelFilterValues = Map<String, Object?>;

Map<String, Object?> filterPayload(List<NovelFilterDef> defs, NovelFilterValues values) => {
      for (final d in defs)
        d.key: {'type': d.type.wire, 'value': values.containsKey(d.key) ? values[d.key] : d.defaultValue},
    };
