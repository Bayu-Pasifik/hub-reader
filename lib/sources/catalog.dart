import 'dart:convert';

import '../core/utils/json.dart';
import 'models.dart';
import 'source.dart';
import 'templates/iken.dart';
import 'templates/keyoapp.dart';
import 'templates/loneseal.dart';
import 'templates/madara.dart';
import 'templates/mangacatalog.dart';
import 'templates/mangathemesia.dart';
import 'templates/natsuid.dart';
import 'templates/small_templates.dart';
import 'templates/vinetheme.dart';
import 'templates/zeistmanga.dart';

/// Satu entri di `assets/sources/catalog.json` (dihasilkan oleh
/// `tool/generate_source_catalog.mjs` dari keiyoushi/extensions-source).
class CatalogEntry {
  const CatalogEntry({
    required this.id,
    required this.name,
    required this.lang,
    required this.baseUrl,
    required this.theme,
    required this.contentWarning,
    this.options = const {},
    this.raw = const {},
    this.repo,
    this.orphaned = false,
  });

  final String id;
  final String name;
  final String lang;
  final String baseUrl;
  final String theme;
  final ContentWarning contentWarning;
  final JsonMap options;

  /// JSON asli entri (untuk disimpan ulang & membandingkan katalog).
  final JsonMap raw;

  /// URL repo asal; null = katalog bawaan aplikasi.
  final String? repo;

  /// Sudah hilang dari semua repo (dan katalog bawaan), tapi entrinya masih
  /// tersimpan di perangkat sehingga sumbernya tetap bisa dipakai.
  final bool orphaned;

  /// Kotlin meng-override logika inti; port template bisa kurang pas.
  bool get customized => options['customized'] == true;

  CatalogEntry withOrigin({String? repo, bool orphaned = false}) => CatalogEntry(
        id: id,
        name: name,
        lang: lang,
        baseUrl: baseUrl,
        theme: theme,
        contentWarning: contentWarning,
        options: options,
        raw: raw,
        repo: repo,
        orphaned: orphaned,
      );

  static CatalogEntry? tryParse(JsonMap json) {
    final id = asString(json['id']);
    final baseUrl = asString(json['baseUrl']);
    final theme = asString(json['theme']);
    if (id == null || baseUrl == null || theme == null) return null;
    return CatalogEntry(
      id: id,
      name: asString(json['name']) ?? id,
      lang: asString(json['lang']) ?? 'all',
      baseUrl: baseUrl,
      theme: theme,
      contentWarning: switch (asString(json['contentWarning'])) {
        'nsfw' => ContentWarning.nsfw,
        'mixed' => ContentWarning.mixed,
        _ => ContentWarning.safe,
      },
      options: asMap(json['options']),
      raw: json,
    );
  }

  /// Buat instance sumber dari template yang sesuai; null bila template
  /// belum di-port.
  MangaSource? create() => switch (theme) {
        'mangathemesia' => MangaThemesiaSource(
            id: id,
            name: name,
            lang: lang,
            baseUrl: baseUrl,
            contentWarning: contentWarning,
            mangaUrlDirectory: asString(options['mangaUrlDirectory']) ?? '/manga',
            pageSelector:
                asString(options['pageSelector'])?.replaceAll(':not(noscript img)', '') ?? 'div#readerarea img',
          ),
        'madara' => MadaraSource(
            id: id,
            name: name,
            lang: lang,
            baseUrl: baseUrl,
            contentWarning: contentWarning,
            mangaSubString: asString(options['mangaSubString']) ?? 'manga',
            chapterMode: madaraChapterModeFrom(asString(options['chapterMode'])),
            noAjax: options['noAjax'] == true,
            filterNonMangaItems: options['filterNonMangaItems'] != false,
            vals: asMap(options['vals']),
          ),
        'zeistmanga' => ZeistMangaSource(
            id: id,
            name: name,
            lang: lang,
            baseUrl: baseUrl,
            contentWarning: contentWarning,
            vals: asMap(options['vals']),
          ),
        'loneseal' => LoneSealSource(
            id: id,
            name: name,
            lang: lang,
            baseUrl: baseUrl,
            contentWarning: contentWarning,
            urlLayout: asString(asMap(options['vals'])['urlLayout']) ?? 'SLUG',
            includeChapterTitle: asMap(options['vals'])['includeChapterTitle'] == true,
            apiOnBase: asMap(options['vals'])['apiOnBase'] == true,
          ),
        'natsuid' => NatsuIdSource(
            id: id,
            name: name,
            lang: lang,
            baseUrl: baseUrl,
            contentWarning: contentWarning,
            chapterPageOne: asMap(options['vals'])['chapterPageOne'] == true,
          ),
        'colorlibanime' =>
          ColorlibAnimeSource(id: id, name: name, lang: lang, baseUrl: baseUrl, contentWarning: contentWarning),
        'hwalumi' => HwalumiSource(id: id, name: name, lang: lang, baseUrl: baseUrl, contentWarning: contentWarning),
        'keyoapp' => KeyoappSource(
            id: id,
            name: name,
            lang: lang,
            baseUrl: baseUrl,
            contentWarning: contentWarning,
            variant: keyoappVariantFrom(asString(options['variant'])),
            popularFromSearch: options['popularFromSearch'] == true,
          ),
        'vinetheme' =>
          VineThemeSource(id: id, name: name, lang: lang, baseUrl: baseUrl, contentWarning: contentWarning),
        'mangacatalog' => MangaCatalogSource(
            id: id,
            name: name,
            lang: lang,
            baseUrl: baseUrl,
            contentWarning: contentWarning,
            layout: mangaCatalogLayoutFrom(asString(options['layout'])),
            titles: [
              for (final t in asList(options['titles']))
                if (asList(t) case [final String title, final String path]) (title, path),
            ],
          ),
        'iken' => IkenSource(
            id: id,
            name: name,
            lang: lang,
            baseUrl: baseUrl,
            contentWarning: contentWarning,
            perPage: asInt(options['perPage']) ?? 18,
            sortPagesByFilename: asMap(options['vals'])['sortPagesByFilename'] == true,
          ),
        _ => null,
      };
}

class SourceCatalog {
  const SourceCatalog(this.entries, {this.hostHistory = const {}});

  static const empty = SourceCatalog([]);

  final List<CatalogEntry> entries;

  /// id sumber → host yang pernah dipakai (katalog bawaan / versi repo
  /// lama). URL tersimpan berhost lama dialihkan ke domain saat ini.
  final Map<String, Set<String>> hostHistory;

  Iterable<CatalogEntry> get orphans => entries.where((e) => e.orphaned);

  /// Format `catalog.json` (`{"sources": [...]}`) atau daftar entri langsung.
  factory SourceCatalog.fromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    final list = decoded is List ? decoded : asMap(decoded)['sources'];
    return SourceCatalog([
      for (final e in asList(list))
        if (CatalogEntry.tryParse(asMap(e)) case final entry?) entry,
    ]);
  }

  /// Sidik isi katalog; sama = registry tidak perlu dibangun ulang.
  String get signature {
    var h = 0x811c9dc5;
    for (final e in entries) {
      for (final b in utf8.encode('${e.orphaned}|${e.repo}|${jsonEncode(e.raw)}\n')) {
        h = ((h ^ b) * 0x01000193) & 0xffffffff;
      }
    }
    return '${entries.length}:${h.toRadixString(16)}';
  }
}
