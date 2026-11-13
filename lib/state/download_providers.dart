import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/download_store.dart';
import '../data/models/download.dart';
import '../sources/models.dart';
import '../sources/source_exception.dart';
import 'novel_providers.dart';
import 'source_providers.dart';

/// Di-override di main() setelah folder unduhan dibuka.
final downloadStoreProvider = Provider<DownloadStore>(
  (ref) => throw UnimplementedError('Override downloadStoreProvider di main()'),
);

// ------------------------------------------------------------------ indeks

/// Bab yang sudah lengkap diunduh, per [chapterKey].
final downloadIndexProvider =
    NotifierProvider<DownloadIndexNotifier, Map<String, DownloadedChapter>>(DownloadIndexNotifier.new);

class DownloadIndexNotifier extends Notifier<Map<String, DownloadedChapter>> {
  DownloadStore get _store => ref.read(downloadStoreProvider);

  @override
  Map<String, DownloadedChapter> build() => ref.watch(downloadStoreProvider).readIndex();

  Future<void> add(DownloadedChapter chapter) async {
    state = {...state, chapter.key: chapter};
    await _store.writeIndex(state);
  }

  Future<void> remove(String key) async {
    final entry = state[key];
    if (entry == null) return;
    state = {...state}..remove(key);
    await _store.writeIndex(state);
    await _store.deleteDir(entry.relativeDir);
  }
}

/// Path file lokal halaman bab, atau null bila belum/tidak lengkap terunduh.
final localPagesProvider = Provider.family<List<String>?, String>((ref, key) {
  final entry = ref.watch(downloadIndexProvider.select((index) => index[key]));
  return entry == null ? null : ref.read(downloadStoreProvider).localPages(entry);
});

// ---------------------------------------------------------------- antrean

/// Antrean unduhan (hanya di memori; antrean hilang bila aplikasi ditutup,
/// tapi bab yang sudah selesai tetap tersimpan).
final downloadQueueProvider =
    NotifierProvider<DownloadQueueNotifier, List<DownloadTask>>(DownloadQueueNotifier.new);

class DownloadQueueNotifier extends Notifier<List<DownloadTask>> {
  /// Gambar yang diunduh bersamaan dalam satu bab.
  static const _parallel = 2;

  bool _running = false;
  final _cancelled = <String>{};
  final _http = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 60),
    responseType: ResponseType.bytes,
  ));

  @override
  List<DownloadTask> build() => const [];

  /// Masukkan bab ke antrean (yang sudah terunduh/sudah antre dilewati).
  void enqueue({
    required String sourceId,
    required String mangaUrl,
    required SourceMangaDetails manga,
    required Iterable<SourceChapter> chapters,
  }) {
    final index = ref.read(downloadIndexProvider);
    final queued = state.map((t) => t.key).toSet();
    final fresh = [
      for (final c in chapters)
        if (!index.containsKey(chapterKey(sourceId, c.url)) && !queued.contains(chapterKey(sourceId, c.url)))
          DownloadTask(
            sourceId: sourceId,
            mangaUrl: mangaUrl,
            mangaTitle: manga.title,
            thumbnailUrl: manga.thumbnailUrl,
            chapter: c,
          ),
    ];
    if (fresh.isEmpty) return;
    state = [...state, ...fresh];
    _run();
  }

  /// Batalkan (antre atau sedang berjalan). File setengah jadi dihapus.
  void cancel(String key) {
    _cancelled.add(key);
    state = state.where((t) => t.key != key).toList();
  }

  void retry(String key) {
    state = [
      for (final t in state) t.key == key ? t.copyWith(status: DownloadStatus.queued, done: 0) : t,
    ];
    _run();
  }

  void _update(DownloadTask task) {
    state = [for (final t in state) t.key == task.key ? task : t];
  }

  Future<void> _run() async {
    if (_running) return;
    _running = true;
    try {
      while (true) {
        final task = state.where((t) => t.status == DownloadStatus.queued).firstOrNull;
        if (task == null) break;
        await _download(task);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _download(DownloadTask task) async {
    _cancelled.remove(task.key);
    var current = task.copyWith(status: DownloadStatus.downloading, done: 0);
    _update(current);
    final relativeDir = DownloadStore.relativeDirFor(task.sourceId, task.mangaUrl, task.chapter.url);
    final store = ref.read(downloadStoreProvider);
    try {
      if (isNovelSourceId(task.sourceId)) {
        await _downloadNovel(task, relativeDir);
        state = state.where((t) => t.key != task.key).toList();
        return;
      }
      final source = ref.read(sourceProvider(task.sourceId));
      if (source == null) throw SourceException(SourceErrorKind.unknown, detail: 'Sumber ${task.sourceId} tidak ada.');
      final urls = await source.pages(task.chapter);
      current = current.copyWith(total: urls.length);
      _update(current);

      final dir = store.dirOf(relativeDir);
      await dir.create(recursive: true);
      final headers = source.imageHeaders(referer: task.chapter.url);
      final files = List<String>.generate(urls.length, (i) => '${(i + 1).toString().padLeft(3, '0')}${_ext(urls[i])}');

      var next = 0;
      var done = 0;
      Future<void> worker() async {
        while (next < urls.length) {
          if (_cancelled.contains(task.key)) throw const _Cancelled();
          final i = next++;
          final file = File('${dir.path}${Platform.pathSeparator}${files[i]}');
          if (!(await file.exists() && await file.length() > 0)) {
            final res = await _http.get<List<int>>(urls[i], options: Options(headers: headers));
            await file.writeAsBytes(res.data ?? const [], flush: true);
          }
          done++;
          current = current.copyWith(done: done);
          if (!_cancelled.contains(task.key)) _update(current);
        }
      }

      await Future.wait([for (var w = 0; w < _parallel; w++) worker()]);
      if (_cancelled.contains(task.key)) throw const _Cancelled();

      await ref.read(downloadIndexProvider.notifier).add(DownloadedChapter(
            sourceId: task.sourceId,
            mangaUrl: task.mangaUrl,
            mangaTitle: task.mangaTitle,
            thumbnailUrl: task.thumbnailUrl,
            chapterUrl: task.chapter.url,
            chapterName: task.chapter.name,
            relativeDir: relativeDir,
            files: files,
            downloadedAt: DateTime.now(),
          ));
      state = state.where((t) => t.key != task.key).toList();
    } on _Cancelled {
      await store.deleteDir(relativeDir);
    } catch (error) {
      final e = toSourceException(error);
      _update(current.copyWith(status: DownloadStatus.failed, error: e.title));
    }
  }

  /// Bab novel: satu file HTML hasil `parseChapter` plugin.
  Future<void> _downloadNovel(DownloadTask task, String relativeDir) async {
    final store = ref.read(downloadStoreProvider);
    _update(task.copyWith(status: DownloadStatus.downloading, done: 0, total: 1));
    final source = await ref.read(novelSourceProvider(pluginIdOf(task.sourceId)).future);
    final html = await source.chapter(task.chapter.url);
    if (html.trim().isEmpty) throw const SourceException(SourceErrorKind.parse, detail: 'Isi bab kosong.');
    if (_cancelled.contains(task.key)) throw const _Cancelled();
    final dir = store.dirOf(relativeDir);
    await dir.create(recursive: true);
    await File('${dir.path}${Platform.pathSeparator}${DownloadStore.novelChapterFile}').writeAsString(html, flush: true);
    await ref.read(downloadIndexProvider.notifier).add(DownloadedChapter(
          sourceId: task.sourceId,
          mangaUrl: task.mangaUrl,
          mangaTitle: task.mangaTitle,
          thumbnailUrl: task.thumbnailUrl,
          chapterUrl: task.chapter.url,
          chapterName: task.chapter.name,
          relativeDir: relativeDir,
          files: const [DownloadStore.novelChapterFile],
          downloadedAt: DateTime.now(),
        ));
  }

  static String _ext(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    for (final ext in const ['.webp', '.png', '.jpeg', '.jpg', '.gif', '.avif']) {
      if (path.endsWith(ext)) return ext;
    }
    return '.jpg';
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}

/// Tugas antrean untuk satu bab (untuk tombol unduh di daftar bab).
final downloadTaskProvider = Provider.family<DownloadTask?, String>(
  (ref, key) => ref.watch(downloadQueueProvider.select((q) => q.where((t) => t.key == key).firstOrNull)),
);
