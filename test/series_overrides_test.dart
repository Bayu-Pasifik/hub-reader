import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/novels/novel_models.dart';
import 'package:hub_reader/sources/models.dart';
import 'package:hub_reader/state/series_overrides.dart';

void main() {
  const manga = SourceMangaDetails(
    url: 'u',
    title: 'Site Title',
    thumbnailUrl: 'https://x/cover.jpg',
    author: 'Site Author',
    description: 'Site desc',
  );

  test('tanpa override data situs tidak berubah', () {
    expect(applyMangaOverride(manga, null), same(manga));
  });

  test('override mengganti hanya kolom yang diisi', () {
    final d = applyMangaOverride(manga, const SeriesOverride(title: 'Mine'));
    expect(d.title, 'Mine');
    expect(d.author, 'Site Author');
    expect(d.description, 'Site desc');
    expect(d.thumbnailUrl, 'https://x/cover.jpg');
  });

  test('sampul kustom dipakai bila file ada, kembali ke situs bila hilang', () {
    final f = File('${Directory.systemTemp.path}/ov_cover_test.jpg')..writeAsBytesSync([1, 2, 3]);
    addTearDown(() => f.existsSync() ? f.deleteSync() : null);
    expect(applyMangaOverride(manga, SeriesOverride(coverPath: f.path)).thumbnailUrl, f.path);
    f.deleteSync();
    expect(applyMangaOverride(manga, SeriesOverride(coverPath: f.path)).thumbnailUrl, 'https://x/cover.jpg');
  });

  test('novel: override judul, penulis, ringkasan', () {
    const n = NovelDetails(path: 'p', name: 'N', author: 'A', summary: 'S');
    final d = applyNovelOverride(n, const SeriesOverride(title: 'T', author: 'B', description: 'D'));
    expect((d.name, d.author, d.summary), ('T', 'B', 'D'));
  });

  test('JSON bolak-balik; teks kosong dianggap tidak ada', () {
    final o = SeriesOverride.fromJson({'title': '  Hai ', 'author': '  ', 'cover': '/a.jpg'});
    expect(o.title, 'Hai');
    expect(o.author, isNull);
    expect(SeriesOverride.fromJson(o.toJson()).coverPath, '/a.jpg');
    expect(SeriesOverride.fromJson({}).isEmpty, isTrue);
  });
}
