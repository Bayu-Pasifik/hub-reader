import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform/network_bridge.dart';
import 'core_providers.dart';
import '../data/local/download_store.dart';
import '../data/models/download.dart';
import '../sources/models.dart';
import '../sources/source_exception.dart';
import 'app_settings_provider.dart';
import 'novel_providers.dart';
import 'source_library_providers.dart' show sourceProgressProvider;
import 'source_providers.dart';
import '../core/i18n/strings.dart';

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

  /// Hapus unduhan bab yang sudah ditandai selesai dibaca (bila pengaturan
  /// aktif). Mengembalikan jumlah bab yang dihapus.
  Future<int> purgeRead() async {
    if (!ref.read(appSettingsProvider).autoDeleteRead) return 0;
    final progress = ref.read(sourceProgressProvider);
    final doomed = {
      for (final e in state.entries)
        if (progress[e.value.mangaKey]?[e.value.chapterUrl]?.done ?? false) e.key: e.value,
    };
    if (doomed.isEmpty) return 0;
    state = {...state}..removeWhere((k, _) => doomed.containsKey(k));
    await _store.writeIndex(state);
    for (final e in doomed.values) {
      try {
        await _store.deleteDir(e.relativeDir);
      } catch (_) {
        // Gagal menghapus satu folder tidak boleh menghentikan sisanya.
      }
    }
    return doomed.length;
  }
}

/// Path file lokal halaman bab, atau null bila belum/tidak lengkap terunduh.
final localPagesProvider = Provider.family<List<String>?, String>((ref, key) {
  final entry = ref.watch(downloadIndexProvider.select((index) => index[key]));
  return entry == null ? null : ref.read(downloadStoreProvider).localPages(entry);
});

// ---------------------------------------------------------------- antrean

/// Antrean unduhan. Disimpan di SharedPreferences setiap kali isi/statusnya
/// berubah, lalu dilanjutkan otomatis saat aplikasi dibuka lagi.
final downloadQueueProvider =
    NotifierProvider<DownloadQueueNotifier, List<DownloadTask>>(DownloadQueueNotifier.new);

/// Antrean dijeda pengguna: bab yang sedang diunduh diselesaikan, lalu tidak ada yang baru dimulai.
/// Tersimpan, jadi tetap dijeda setelah aplikasi dibuka lagi.
final downloadPausedProvider = NotifierProvider<DownloadPausedNotifier, bool>(DownloadPausedNotifier.new);

class DownloadPausedNotifier extends Notifier<bool> {
  static const _key = 'download.paused.v1';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;

  /// Jeda atau lanjutkan. Melanjutkan langsung menjalankan antrean lagi.
  Future<void> set(bool paused) async {
    state = paused;
    await ref.read(sharedPreferencesProvider).setBool(_key, paused);
    if (!paused) ref.read(downloadQueueProvider.notifier).resume();
  }
}

/// True selama antrean menunggu Wi-Fi karena "Unduh hanya lewat Wi-Fi" aktif.
final downloadWaitingForWifiProvider = StateProvider<bool>((ref) => false);

class DownloadQueueNotifier extends Notifier<List<DownloadTask>> {
  /// Jeda antar pengecekan jaringan saat menunggu Wi-Fi.
  static const wifiPoll = Duration(seconds: 20);

  bool _running = false;
  Timer? _wifiTimer;
  final _cancelled = <String>{};
  final _http = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 60),
    responseType: ResponseType.bytes,
  ));

  /// Tanda isi antrean terakhir yang disimpan (kunci + status), supaya
  /// pembaruan progres per halaman tidak menulis ke disk.
  String? _savedSignature;

  @override
  List<DownloadTask> build() {
    final store = ref.watch(downloadStoreProvider);
    final restored = store.readQueue();
    listenSelf((_, next) => _persist(next));
    ref.onDispose(() => _wifiTimer?.cancel());
    _savedSignature = _signature(restored);
    if (restored.any((t) => t.status == DownloadStatus.queued) && !ref.read(downloadPausedProvider)) {
      Future.microtask(_run);
    }
    return restored;
  }

  static String _signature(List<DownloadTask> queue) =>
      [for (final t in queue) '${t.key}#${t.status == DownloadStatus.failed ? 'f' : 'q'}'].join('\n');

  void _persist(List<DownloadTask> queue) {
    final sig = _signature(queue);
    if (sig == _savedSignature) return;
    _savedSignature = sig;
    ref.read(downloadStoreProvider).writeQueue(queue);
  }

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

  /// Pindahkan tugas dari [oldIndex] ke [newIndex] (konvensi ReorderableListView). Tugas yang
  /// sedang berjalan tetap berjalan; urutan menentukan bab antre mana yang diunduh berikutnya.
  void reorder(int oldIndex, int newIndex) {
    final next = reorderList(state, oldIndex, newIndex);
    if (next != null) state = next;
  }

  /// Batalkan semua tugas (antre, berjalan, dan gagal).
  void cancelAll() {
    for (final t in state) {
      _cancelled.add(t.key);
    }
    state = const [];
  }

  /// Buang tugas yang gagal dari antrean.
  void clearFailed() {
    state = state.where((t) => t.status != DownloadStatus.failed).toList();
  }

  /// Coba lagi semua tugas yang gagal.
  void retryAllFailed() {
    if (!state.any((t) => t.status == DownloadStatus.failed)) return;
    state = [
      for (final t in state) t.status == DownloadStatus.failed ? t.copyWith(status: DownloadStatus.queued, done: 0) : t,
    ];
    _run();
  }

  /// Dipanggil saat jeda dicabut.
  void resume() => _run();

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
        if (ref.read(downloadPausedProvider)) break;
        final task = state.where((t) => t.status == DownloadStatus.queued).firstOrNull;
        if (task == null) break;
        if (ref.read(appSettingsProvider).downloadWifiOnly && !await NetworkBridge.isUnmetered()) {
          // Tetap antre; coba lagi sebentar lagi (Wi-Fi bisa tersambung kapan saja).
          ref.read(downloadWaitingForWifiProvider.notifier).state = true;
          _wifiTimer?.cancel();
          _wifiTimer = Timer(wifiPoll, _run);
          return;
        }
        ref.read(downloadWaitingForWifiProvider.notifier).state = false;
        await _download(task);
      }
      ref.read(downloadWaitingForWifiProvider.notifier).state = false;
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
      if (source == null) throw SourceException(SourceErrorKind.unknown, detail: trp('Sumber {id} tidak ada.', {'id': task.sourceId}));
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

      final parallel = ref.read(appSettingsProvider).downloadParallel.clamp(1, 4);
      await Future.wait([for (var w = 0; w < parallel; w++) worker()]);
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
    if (html.trim().isEmpty) throw SourceException(SourceErrorKind.parse, detail: tr('Isi bab kosong.'));
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

/// Ukuran file unduhan: total dan per seri (`mangaKey`), dihitung dari file di disk.
typedef DownloadSizes = ({int total, Map<String, int> bySeries});

final downloadSizesProvider = FutureProvider<DownloadSizes>((ref) async {
  final index = ref.watch(downloadIndexProvider);
  final store = ref.watch(downloadStoreProvider);
  final bySeries = <String, int>{};
  var total = 0;
  for (final c in index.values) {
    final dir = store.dirOf(c.relativeDir).path;
    var size = 0;
    for (final f in c.files) {
      try {
        size += await File('$dir${Platform.pathSeparator}$f').length();
      } on Object {
        // File hilang: abaikan, ukuran dihitung dari yang ada.
      }
    }
    bySeries[c.mangaKey] = (bySeries[c.mangaKey] ?? 0) + size;
    total += size;
  }
  return (total: total, bySeries: bySeries);
});

/// "1,4 MB", "820 KB", dst.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

/// Tugas antrean untuk satu bab (untuk tombol unduh di daftar bab).
final downloadTaskProvider = Provider.family<DownloadTask?, String>(
  (ref, key) => ref.watch(downloadQueueProvider.select((q) => q.where((t) => t.key == key).firstOrNull)),
);

/// Salinan [list] dengan item [oldIndex] dipindah ke [newIndex] (konvensi
/// ReorderableListView: [newIndex] dihitung sebelum item dicabut). Null bila
/// indeks di luar rentang atau urutan tidak berubah.
List<T>? reorderList<T>(List<T> list, int oldIndex, int newIndex) {
  if (oldIndex < 0 || oldIndex >= list.length || newIndex < 0 || newIndex > list.length) return null;
  final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
  if (target == oldIndex) return null;
  final next = [...list];
  next.insert(target, next.removeAt(oldIndex));
  return next;
}
