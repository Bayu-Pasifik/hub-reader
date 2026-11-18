// Port Dart dari extension Story About Us milik keiyoushi/extensions-source
// (Apache-2.0): src/id/storyaboutus.
//
// Bab berupa berkas PDF. PDF diunduh lalu tiap halaman dirender jadi JPEG
// oleh PdfRenderer Android (channel `hub_reader/pdf`); halaman dikembalikan
// sebagai path berkas lokal.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/i18n/strings.dart';
import '../../core/utils/json.dart';
import '../html_utils.dart';
import '../models.dart';
import '../source.dart';
import '../source_exception.dart';

class StoryAboutUsSource extends HttpSource {
  StoryAboutUsSource({super.dio});

  static const _channel = MethodChannel('hub_reader/pdf');

  @override
  String get id => 'id.storyaboutus';
  @override
  String get name => 'Story About Us';
  @override
  String get lang => 'id';
  @override
  String get defaultBaseUrl => 'https://storyabout-us.com';
  @override
  ContentWarning get contentWarning => ContentWarning.nsfw;
  @override
  bool get supportsLatest => false;
  @override
  Map<String, String> get extraHeaders => const {'Accept': 'application/json, text/plain, */*'};

  static const _cdn = 'https://cdn.storyabout-us.com';

  List<JsonMap>? _all;

  Future<List<JsonMap>> _list() async =>
      _all ??= [for (final m in asList(await fetchJson(Uri.parse('$baseUrl/api/manga')))) asMap(m)];

  SourceManga _card(JsonMap m) => SourceManga(
        url: '$baseUrl/chapter.html?title=${m['id']}',
        title: clean(asString(m['title'])),
        thumbnailUrl: asString(m['cover']),
      );

  @override
  Future<MangaPage> popular(int page) async {
    if (page > 1) return const MangaPage([], hasNextPage: false);
    return MangaPage([for (final m in await _list()) _card(m)], hasNextPage: false);
  }

  @override
  Future<MangaPage> latest(int page) => popular(page);

  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) async {
    if (page > 1) return const MangaPage([], hasNextPage: false);
    final q = query.trim().toLowerCase();
    return MangaPage([
      for (final m in await _list())
        if (q.isEmpty || (asString(m['title']) ?? '').toLowerCase().contains(q)) _card(m),
    ], hasNextPage: false);
  }

  @override
  Future<SourceMangaDetails> details(String mangaUrl) async {
    final slug = Uri.parse(mangaUrl).queryParameters['title'];
    if (slug == null) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Judul seri tidak ditemukan.'));
    }
    final m = asMap(await fetchJson(Uri.parse('$baseUrl/api/manga/$slug')));
    final title = clean(asString(m['title']));
    if (title.isEmpty) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Judul seri tidak ditemukan.'));
    }
    final chapters = <SourceChapter>[];
    for (final c in asList(m['chapters'])) {
      final cm = asMap(c);
      final key = asString(cm['key']);
      if (key == null) continue;
      final n = asDouble(cm['number']);
      final label = asString(cm['label']);
      final ts = asInt(cm['uploaded_at']);
      chapters.add(SourceChapter(
        url: key,
        name: label ?? 'Chapter ${n == null ? asString(cm['chapter']) : (n % 1 == 0 ? n.toInt() : n)}',
        number: n,
        uploadedAt: ts == null || ts == 0 ? null : DateTime.fromMillisecondsSinceEpoch(ts),
      ));
    }
    chapters.sort((a, b) => (b.number ?? 0).compareTo(a.number ?? 0));
    return SourceMangaDetails(
      url: mangaUrl,
      title: title,
      thumbnailUrl: asString(m['cover']),
      description: clean(asString(m['summary'])),
      genres: const [],
      status: switch (asString(m['status'])) {
        'ongoing' => SourceMangaStatus.ongoing,
        'end' => SourceMangaStatus.completed,
        'end-season' || 'hiatus' => SourceMangaStatus.hiatus,
        _ => SourceMangaStatus.unknown,
      },
      chapters: chapters,
    );
  }

  @override
  Future<List<String>> pages(SourceChapter chapter) async {
    if (!Platform.isAndroid) {
      throw SourceException(SourceErrorKind.parse, detail: tr('Bab PDF hanya didukung di Android.'));
    }
    final tmp = await getTemporaryDirectory();
    final root = Directory('${tmp.path}/storyaboutus_pdf')..createSync(recursive: true);
    // Bersihkan hasil lama (> 1 jam).
    final expired = DateTime.now().subtract(const Duration(hours: 1));
    for (final e in root.listSync()) {
      if (e.statSync().modified.isBefore(expired)) e.deleteSync(recursive: true);
    }
    final safe = chapter.url.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final out = Directory('${root.path}/$safe');
    final cached = out.existsSync()
        ? (out.listSync().whereType<File>().where((f) => f.path.endsWith('.jpg')).map((f) => f.path).toList()..sort())
        : <String>[];
    if (cached.isNotEmpty) return cached;
    out.createSync(recursive: true);
    final pdf = '${root.path}/$safe.pdf';
    try {
      await dio.download(
        '$_cdn/${chapter.url}',
        pdf,
        options: Options(receiveTimeout: const Duration(minutes: 3), headers: {'Accept': '*/*'}),
      );
      final result = await _channel.invokeListMethod<String>('render', {'path': pdf, 'outDir': out.path});
      final files = result ?? const <String>[];
      if (files.isEmpty) {
        throw SourceException(SourceErrorKind.parse, detail: tr('Gambar bab tidak ditemukan.'));
      }
      return files;
    } on PlatformException catch (e) {
      throw SourceException(SourceErrorKind.parse, detail: e.message ?? 'PDF');
    } on DioException catch (e) {
      throw toSourceException(e);
    } finally {
      final f = File(pdf);
      if (f.existsSync()) f.deleteSync();
    }
  }
}
