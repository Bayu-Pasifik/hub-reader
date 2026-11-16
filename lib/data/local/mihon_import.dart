import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../../sources/source.dart';
import '../models/source_library.dart';
import 'source_library_store.dart';

/// Pembaca protobuf minimal (wire format) untuk cadangan Mihon/Tachiyomi.
class _Proto {
  _Proto(this._b);
  final Uint8List _b;
  int _i = 0;

  bool get done => _i >= _b.length;

  int _varint() {
    var result = 0;
    var shift = 0;
    while (true) {
      if (_i >= _b.length) throw const FormatException('protobuf terpotong');
      final byte = _b[_i++];
      result |= (byte & 0x7f) << shift;
      if (byte & 0x80 == 0) return result;
      shift += 7;
      if (shift > 63) throw const FormatException('varint terlalu panjang');
    }
  }

  /// Baca satu field: `(nomor, nilai)`; nilai int untuk varint, bytes untuk length-delimited.
  (int, Object) next() {
    final tag = _varint();
    final field = tag >> 3;
    switch (tag & 7) {
      case 0:
        return (field, _varint());
      case 1:
        _i += 8;
        return (field, 0);
      case 2:
        final len = _varint();
        if (_i + len > _b.length) throw const FormatException('protobuf terpotong');
        final v = Uint8List.sublistView(_b, _i, _i + len);
        _i += len;
        return (field, v);
      case 5:
        _i += 4;
        return (field, 0);
      default:
        throw const FormatException('tipe wire tidak dikenal');
    }
  }
}

String _str(Object v) => v is Uint8List ? utf8.decode(v, allowMalformed: true) : '';

class MihonChapter {
  MihonChapter({required this.url, this.read = false, this.lastPageRead = 0});
  final String url;
  final bool read;
  final int lastPageRead;
}

class MihonManga {
  MihonManga({
    required this.source,
    required this.url,
    required this.title,
    this.thumbnail,
    this.dateAdded,
    this.favorite = true,
    this.categories = const [],
    this.chapters = const [],
    this.lastRead = const {},
  });
  final int source;
  final String url;
  final String title;
  final String? thumbnail;
  final DateTime? dateAdded;
  final bool favorite;

  /// Urutan (`order`) kategori Mihon.
  final List<int> categories;
  final List<MihonChapter> chapters;

  /// URL bab -> waktu baca terakhir.
  final Map<String, DateTime> lastRead;
}

class MihonBackup {
  MihonBackup({required this.manga, required this.categories, required this.sourceNames});
  final List<MihonManga> manga;

  /// `order` -> nama kategori.
  final Map<int, String> categories;

  /// id sumber Mihon -> nama sumber.
  final Map<int, String> sourceNames;

  /// Baca `.tachibk`/`.proto.gz` (gzip) atau protobuf mentah.
  static MihonBackup parse(List<int> bytes) {
    var data = Uint8List.fromList(bytes);
    if (data.length > 2 && data[0] == 0x1f && data[1] == 0x8b) {
      data = Uint8List.fromList(gzip.decode(data));
    }
    final manga = <MihonManga>[];
    final categories = <int, String>{};
    final sources = <int, String>{};
    final r = _Proto(data);
    while (!r.done) {
      final (field, v) = r.next();
      if (v is! Uint8List) continue;
      switch (field) {
        case 1:
          manga.add(_manga(v));
        case 2:
          final (name, order) = _namePair(v, nameField: 1, numField: 2);
          if (name != null) categories[order] = name;
        case 101:
          final (name, id) = _namePair(v, nameField: 1, numField: 2);
          if (name != null) sources[id] = name;
      }
    }
    if (manga.isEmpty && categories.isEmpty) throw const FormatException('bukan cadangan Mihon');
    return MihonBackup(manga: manga, categories: categories, sourceNames: sources);
  }

  static (String?, int) _namePair(Uint8List bytes, {required int nameField, required int numField}) {
    String? name;
    var number = 0;
    final c = _Proto(bytes);
    while (!c.done) {
      final (f, x) = c.next();
      if (f == nameField) name = _str(x);
      if (f == numField && x is int) number = x;
    }
    return (name, number);
  }

  static MihonManga _manga(Uint8List bytes) {
    var source = 0;
    var url = '';
    var title = '';
    String? thumb;
    int? added;
    var favorite = true;
    final cats = <int>[];
    final chapters = <MihonChapter>[];
    final lastRead = <String, DateTime>{};
    final r = _Proto(bytes);
    while (!r.done) {
      final (f, v) = r.next();
      switch (f) {
        case 1 when v is int:
          source = v;
        case 2:
          url = _str(v);
        case 3:
          title = _str(v);
        case 9:
          thumb = _str(v);
        case 13 when v is int:
          added = v;
        case 17 when v is int:
          cats.add(v);
        case 100 when v is int:
          favorite = v != 0;
        case 16 when v is Uint8List:
          var cUrl = '';
          var read = false;
          var page = 0;
          final c = _Proto(v);
          while (!c.done) {
            final (cf, cv) = c.next();
            if (cf == 1) cUrl = _str(cv);
            if (cf == 4 && cv is int) read = cv != 0;
            if (cf == 6 && cv is int) page = cv;
          }
          if (cUrl.isNotEmpty) chapters.add(MihonChapter(url: cUrl, read: read, lastPageRead: page));
        case 104 when v is Uint8List:
          var hUrl = '';
          var at = 0;
          final c = _Proto(v);
          while (!c.done) {
            final (cf, cv) = c.next();
            if (cf == 1) hUrl = _str(cv);
            if (cf == 2 && cv is int) at = cv;
          }
          if (hUrl.isNotEmpty && at > 0) lastRead[hUrl] = DateTime.fromMillisecondsSinceEpoch(at);
      }
    }
    return MihonManga(
      source: source,
      url: url,
      title: title,
      thumbnail: thumb,
      dateAdded: added == null || added <= 0 ? null : DateTime.fromMillisecondsSinceEpoch(added),
      favorite: favorite,
      categories: cats,
      chapters: chapters,
      lastRead: lastRead,
    );
  }
}

class MihonImportResult {
  const MihonImportResult({required this.imported, required this.skipped, required this.unmatchedSources});
  final int imported;
  final int skipped;
  final Set<String> unmatchedSources;
}

abstract final class MihonImport {
  static const categoriesKey = 'library.categories.v1';

  static String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static String _absolute(String base, String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return url.startsWith('/') ? '$b$url' : '$b/$url';
  }

  /// Gabungkan [backup] ke library lokal. Sumber dicocokkan lewat nama; seri dari
  /// sumber yang tidak ada di aplikasi dilewati. Data yang sudah ada tidak ditimpa.
  static Future<MihonImportResult> apply(
    SharedPreferences prefs,
    MihonBackup backup,
    List<MangaSource> sources,
  ) async {
    final byName = {for (final s in sources) _norm(s.name): s};
    final store = SourceLibraryStore(prefs);
    final favorites = {for (final f in store.readFavorites()) f.item.key: f};
    final history = {for (final h in store.readHistory()) h.item.key: h};
    final progress = store.readProgress();
    final knownCategories = [...?prefs.getStringList(categoriesKey)];
    var imported = 0;
    var skipped = 0;
    final unmatched = <String>{};

    for (final m in backup.manga) {
      if (!m.favorite && m.chapters.every((c) => !c.read)) continue;
      final srcName = backup.sourceNames[m.source];
      final source = srcName == null ? null : byName[_norm(srcName)];
      if (source == null) {
        skipped++;
        unmatched.add(srcName ?? '#${m.source}');
        continue;
      }
      final item = SourceLibraryItem(
        sourceId: source.id,
        url: _absolute(source.baseUrl, m.url),
        title: m.title,
        thumbnailUrl: m.thumbnail,
      );
      if (m.favorite && !favorites.containsKey(item.key)) {
        final cats = [
          for (final o in m.categories)
            if (backup.categories[o] case final n?) n,
        ];
        for (final c in cats) {
          if (!knownCategories.contains(c)) knownCategories.add(c);
        }
        favorites[item.key] = SourceFavorite(item: item, addedAt: m.dateAdded ?? DateTime.now(), categories: cats);
      }
      final chapterProgress = progress.putIfAbsent(item.key, () => {});
      for (final c in m.chapters) {
        if (!c.read && c.lastPageRead == 0) continue;
        chapterProgress.putIfAbsent(
          _absolute(source.baseUrl, c.url),
          () => SourceChapterProgress(
            page: c.lastPageRead,
            total: 0,
            done: c.read,
            updatedAt: m.lastRead[c.url] ?? DateTime.fromMillisecondsSinceEpoch(0),
          ),
        );
      }
      if (chapterProgress.isEmpty) progress.remove(item.key);
      if (m.lastRead.isNotEmpty) {
        final last = m.lastRead.entries.reduce((a, b) => a.value.isAfter(b.value) ? a : b);
        final chUrl = _absolute(source.baseUrl, last.key);
        final old = history[item.key];
        if (old == null || last.value.isAfter(old.readAt)) {
          history[item.key] = SourceHistoryEntry(
            item: item,
            chapterUrl: chUrl,
            chapterName: chUrl.split('/').where((s) => s.isNotEmpty).last,
            readAt: last.value,
          );
        }
      }
      imported++;
    }

    await store.writeFavorites(favorites.values.toList()..sort((a, b) => b.addedAt.compareTo(a.addedAt)));
    await store.writeHistory((history.values.toList()..sort((a, b) => b.readAt.compareTo(a.readAt))).take(300).toList());
    await store.writeProgress(progress);
    await prefs.setStringList(categoriesKey, knownCategories);
    return MihonImportResult(imported: imported, skipped: skipped, unmatchedSources: unmatched);
  }
}
