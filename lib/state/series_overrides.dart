import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../core/utils/json.dart';
import '../novels/novel_models.dart';
import '../sources/models.dart';
import 'core_providers.dart';
import 'source_library_providers.dart';

/// Info seri yang diubah pengguna. Field null = ikut data dari situs.
class SeriesOverride {
  const SeriesOverride({this.title, this.author, this.description, this.coverPath});

  final String? title;
  final String? author;
  final String? description;

  /// File sampul kustom di penyimpanan aplikasi.
  final String? coverPath;

  bool get isEmpty => title == null && author == null && description == null && coverPath == null;

  SeriesOverride copyWith({
    String? Function()? title,
    String? Function()? author,
    String? Function()? description,
    String? Function()? coverPath,
  }) =>
      SeriesOverride(
        title: title != null ? title() : this.title,
        author: author != null ? author() : this.author,
        description: description != null ? description() : this.description,
        coverPath: coverPath != null ? coverPath() : this.coverPath,
      );

  static String? _clean(Object? v) {
    final s = asString(v)?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static SeriesOverride fromJson(Object? raw) {
    final j = asMap(raw);
    return SeriesOverride(
      title: _clean(j['title']),
      author: _clean(j['author']),
      description: _clean(j['description']),
      coverPath: _clean(j['cover']),
    );
  }

  JsonMap toJson() => {
        if (title != null) 'title': title,
        if (author != null) 'author': author,
        if (description != null) 'description': description,
        if (coverPath != null) 'cover': coverPath,
      };

  /// Sampul kustom dipakai hanya bila filenya masih ada (cadangan tidak membawa file).
  String? get usableCover => coverPath != null && File(coverPath!).existsSync() ? coverPath : null;
}

String _key(SourceItemKey k) => '${k.sourceId}|${k.url}';

/// Info seri kustom (judul, penulis, deskripsi, sampul) per seri. Kunci sama dengan pustaka
/// sumber (`<sourceId>|<url seri>`), jadi berlaku untuk komik dan novel.
final seriesOverridesProvider =
    NotifierProvider<SeriesOverridesNotifier, Map<String, SeriesOverride>>(SeriesOverridesNotifier.new);

class SeriesOverridesNotifier extends Notifier<Map<String, SeriesOverride>> {
  static const prefsKey = 'library.overrides.v1';

  @override
  Map<String, SeriesOverride> build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(prefsKey);
    if (raw == null) return const {};
    try {
      return {
        for (final e in asMap(jsonDecode(raw)).entries)
          if (!SeriesOverride.fromJson(e.value).isEmpty) e.key: SeriesOverride.fromJson(e.value),
      };
    } on Object {
      return const {};
    }
  }

  /// Override kosong menghapus entri (dan file sampul lama bila diganti/dihapus).
  Future<void> set(SourceItemKey series, SeriesOverride value) async {
    final k = _key(series);
    final old = state[k];
    final next = {...state};
    value.isEmpty ? next.remove(k) : next[k] = value;
    state = next;
    await ref.read(sharedPreferencesProvider).setString(
          prefsKey,
          jsonEncode({for (final e in next.entries) e.key: e.value.toJson()}),
        );
    if (old?.coverPath != null && old!.coverPath != value.coverPath) {
      try {
        await File(old.coverPath!).delete();
      } on Object {
        // sudah hilang
      }
    }
  }

  /// Salin gambar pilihan ke penyimpanan aplikasi; mengembalikan path salinan.
  /// Nama unik per panggilan supaya gambar baru tidak tertahan cache gambar lama.
  Future<String> storeCover(SourceItemKey series, List<int> bytes, String fileName) async {
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/custom_covers');
    await dir.create(recursive: true);
    final dot = fileName.lastIndexOf('.');
    final ext = dot > 0 && fileName.length - dot <= 5 ? fileName.substring(dot).toLowerCase() : '.jpg';
    final target = File('${dir.path}/${_key(series).hashCode.toUnsigned(32).toRadixString(16)}_'
        '${DateTime.now().millisecondsSinceEpoch}$ext');
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  }
}

final seriesOverrideProvider = Provider.autoDispose.family<SeriesOverride?, SourceItemKey>(
  (ref, k) => ref.watch(seriesOverridesProvider.select((m) => m[_key(k)])),
);

SourceMangaDetails applyMangaOverride(SourceMangaDetails d, SeriesOverride? o) {
  if (o == null) return d;
  return SourceMangaDetails(
    url: d.url,
    title: o.title ?? d.title,
    thumbnailUrl: o.usableCover ?? d.thumbnailUrl,
    author: o.author ?? d.author,
    artist: d.artist,
    description: o.description ?? d.description,
    genres: d.genres,
    status: d.status,
    chapters: d.chapters,
  );
}

NovelDetails applyNovelOverride(NovelDetails d, SeriesOverride? o) {
  if (o == null) return d;
  return NovelDetails(
    path: d.path,
    name: o.title ?? d.name,
    cover: o.usableCover ?? d.cover,
    author: o.author ?? d.author,
    artist: d.artist,
    status: d.status,
    summary: o.description ?? d.summary,
    genres: d.genres,
    rating: d.rating,
    chapters: d.chapters,
    totalPages: d.totalPages,
  );
}
