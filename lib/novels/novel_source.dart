import 'dart:convert';

import '../core/utils/json.dart';
import '../sources/source_exception.dart';
import 'lnreader/engine_isolate.dart';
import 'lnreader/http_bridge.dart';
import 'lnreader/js_engine.dart';
import 'novel_models.dart';

/// Satu plugin LNReader yang sudah dimuat ke [LnEngine].
class NovelSource {
  NovelSource({required this.info, required this.engine, required Map<String, Object?> meta})
      : name = asString(meta['name']) ?? info.name,
        site = asString(meta['site']) ?? info.site,
        version = asString(meta['version']) ?? info.version,
        filters = NovelFilterDef.parseAll(meta['filters']),
        settings = NovelPluginSetting.parseAll(meta['pluginSettings']),
        hasParsePage = meta['hasParsePage'] == true,
        hasResolveUrl = meta['hasResolveUrl'] == true,
        imageHeaders = {
          for (final e in asMap(asMap(meta['imageRequestInit'])['headers']).entries) e.key: '${e.value}',
        };

  final NovelPluginInfo info;
  final LnEngine engine;
  final String name;
  final String site;
  final String version;
  final List<NovelFilterDef> filters;

  /// `pluginSettings` (mis. login & mode terjemahan WTR-LAB).
  final List<NovelPluginSetting> settings;
  final bool hasParsePage;
  final bool hasResolveUrl;

  /// Header untuk memuat sampul (`imageRequestInit.headers`).
  final Map<String, String> imageHeaders;

  String get id => info.id;
  String get lang => info.lang;

  /// Key `@libs/storage` milik plugin ini (lihat `storageKey` di runtime.js).
  String _storageKey(String key) => '${id}_DB_$key';

  /// Nilai pengaturan saat ini (default plugin bila belum diubah).
  Object? settingValue(NovelPluginSetting setting) {
    final stored = engine.readStorage(_storageKey(setting.key));
    Object? value;
    if (stored != null) {
      try {
        final item = asMap(jsonDecode(stored));
        final expires = asInt(item['expires']);
        if (expires == null || DateTime.now().millisecondsSinceEpoch <= expires) value = item['value'];
      } catch (_) {
        // nilai rusak: pakai default
      }
    }
    return setting.normalize(value);
  }

  /// Simpan pengaturan dengan format `storage.set(key, value)` milik plugin.
  void setSetting(NovelPluginSetting setting, Object? value) {
    engine.writeStorage(
      _storageKey(setting.key),
      jsonEncode({'created': DateTime.now().toUtc().toIso8601String(), 'value': setting.normalize(value)}),
    );
  }

  Future<Object?> _call(String method, List<Object?> args) async {
    try {
      return await engine.invoke(id, method, args);
    } catch (e) {
      throw novelError(e, site: site);
    }
  }

  /// Daftar populer (`showLatestNovels: false`) atau terbaru, dengan filter.
  Future<List<NovelItem>> popular(int page, {bool latest = false, NovelFilterValues filters = const {}}) async {
    final raw = await _call('popularNovels', [
      page,
      {
        'showLatestNovels': latest,
        'filters': this.filters.isEmpty ? null : filterPayload(this.filters, filters),
      },
    ]);
    return _items(raw);
  }

  Future<List<NovelItem>> search(String query, int page) async => _items(await _call('searchNovels', [query, page]));

  /// Detail + bab halaman pertama.
  Future<NovelDetails> details(String path) async => NovelDetails.parse(path, await _call('parseNovel', [path]));

  /// Bab di halaman [page] (hanya plugin berhalaman).
  Future<List<NovelChapter>> chapterPage(String path, int page) async {
    final raw = asMap(await _call('parsePage', [path, '$page']));
    return asList(raw['chapters']).map(NovelChapter.tryParse).whereType<NovelChapter>().toList();
  }

  /// Isi bab berupa HTML.
  Future<String> chapter(String path) async => asString(await _call('parseChapter', [path])) ?? '';

  /// URL web novel/bab, untuk dibuka di browser/WebView.
  Future<String> webUrl(String path, {required bool isNovel}) async {
    if (hasResolveUrl) {
      try {
        final url = asString(await engine.invoke(id, 'resolveUrl', [path, isNovel]));
        if (url != null) return url;
      } catch (_) {
        // jatuh ke cara bawaan
      }
    }
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final base = site.endsWith('/') ? site : '$site/';
    return Uri.parse(base).resolve(path.startsWith('/') ? path.substring(1) : path).toString();
  }

  static List<NovelItem> _items(Object? raw) {
    final seen = <String>{};
    return asList(raw).map(NovelItem.tryParse).whereType<NovelItem>().where((n) => seen.add(n.path)).toList();
  }
}

/// Pesan error plugin (teks bebas, umumnya English) → [SourceException]
/// supaya bisa memakai tampilan error sumber komik yang sudah ada.
SourceException novelError(Object error, {String? site}) {
  if (error is SourceException) return error;
  final message = error is LnPluginException || error is LnNetworkException ? '$error' : error.toString();
  final lower = message.toLowerCase();
  final siteUri = site == null ? null : Uri.tryParse(site);
  if (lower.contains('webview') ||
      lower.contains('cloudflare') ||
      lower.contains('bot check') ||
      lower.contains('captcha') ||
      RegExp(r'\b(403|503)\b').hasMatch(lower)) {
    return SourceException(SourceErrorKind.cloudflare, url: siteUri, detail: message);
  }
  if (lower.contains('timed out') || lower.contains('waktu habis')) {
    return SourceException(SourceErrorKind.timeout, detail: message);
  }
  if (lower.contains('network request failed') || lower.contains('socketexception') || lower.contains('handshake')) {
    return SourceException(SourceErrorKind.noConnection, detail: message);
  }
  if (RegExp(r'\b404\b').hasMatch(lower)) return SourceException(SourceErrorKind.notFound, detail: message);
  if (RegExp(r'\b(500|502|504|52[0-6])\b').hasMatch(lower)) {
    return SourceException(SourceErrorKind.server, detail: message);
  }
  if (lower.contains('typeerror') || lower.contains('cannot read') || lower.contains('undefined')) {
    return SourceException(SourceErrorKind.parse, detail: 'Plugin gagal membaca halaman situs: $message');
  }
  return SourceException(SourceErrorKind.unknown, detail: message);
}
