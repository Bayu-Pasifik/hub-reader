import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/i18n/strings.dart';
import '../core/utils/json.dart';
import '../data/models/source_library.dart';
import '../sources/models.dart';
import 'app_settings_provider.dart';
import 'core_providers.dart';
import 'download_providers.dart';
import 'library_chapters.dart';
import 'source_library_providers.dart';

/// Satu bab baru yang ditemukan saat mengecek favorit.
class LibraryUpdate {
  const LibraryUpdate({
    required this.item,
    required this.chapterUrl,
    required this.chapterName,
    required this.foundAt,
  });

  final SourceLibraryItem item;
  final String chapterUrl;
  final String chapterName;
  final DateTime foundAt;

  static LibraryUpdate? tryParse(Object? raw) {
    final json = asMap(raw);
    final item = SourceLibraryItem.tryParse(asMap(json['item']));
    final url = asString(json['chapter_url']);
    if (item == null || url == null) return null;
    return LibraryUpdate(
      item: item,
      chapterUrl: url,
      chapterName: asString(json['chapter_name']) ?? tr('Bab'),
      foundAt: asDate(json['found_at']) ?? DateTime.now(),
    );
  }

  JsonMap toJson() => {
        'item': item.toJson(),
        'chapter_url': chapterUrl,
        'chapter_name': chapterName,
        'found_at': foundAt.toIso8601String(),
      };
}

class LibraryUpdatesState {
  const LibraryUpdatesState({
    this.updates = const [],
    this.lastCheck,
    this.lastSeen,
    this.checking = false,
    this.done = 0,
    this.total = 0,
    this.failed = const [],
    this.loaded = false,
  });

  /// Terbaru di atas.
  final List<LibraryUpdate> updates;
  final DateTime? lastCheck;

  /// Terakhir layar Pembaruan dibuka (untuk lencana "baru").
  final DateTime? lastSeen;
  final bool checking;
  final int done;
  final int total;

  /// Judul seri yang gagal dicek pada pengecekan terakhir.
  final List<String> failed;
  final bool loaded;

  int get unseen => updates.where((u) => lastSeen == null || u.foundAt.isAfter(lastSeen!)).length;

  LibraryUpdatesState copyWith({
    List<LibraryUpdate>? updates,
    DateTime? lastCheck,
    DateTime? lastSeen,
    bool? checking,
    int? done,
    int? total,
    List<String>? failed,
    bool? loaded,
  }) =>
      LibraryUpdatesState(
        updates: updates ?? this.updates,
        lastCheck: lastCheck ?? this.lastCheck,
        lastSeen: lastSeen ?? this.lastSeen,
        checking: checking ?? this.checking,
        done: done ?? this.done,
        total: total ?? this.total,
        failed: failed ?? this.failed,
        loaded: loaded ?? this.loaded,
      );
}

/// Cek otomatis saat aplikasi dibuka (bila pengecekan terakhir sudah lama).
final libraryAutoCheckProvider = NotifierProvider<LibraryAutoCheckNotifier, bool>(LibraryAutoCheckNotifier.new);

class LibraryAutoCheckNotifier extends Notifier<bool> {
  static const _key = 'library.updates.auto.v1';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? true;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setBool(_key, value);
  }
}

/// Aturan seri mana yang ikut dicek saat memperbarui perpustakaan.
class LibraryUpdateRules {
  const LibraryUpdateRules({
    this.skipCompleted = true,
    this.skipUnstarted = true,
    this.skipUnread = false,
    this.excludedCategories = const [],
  });

  /// Lewati seri yang terdeteksi tamat.
  final bool skipCompleted;

  /// Lewati seri yang belum pernah dibuka/dibaca.
  final bool skipUnstarted;

  /// Lewati seri yang masih punya bab baru belum dibaca.
  final bool skipUnread;

  /// Seri yang semua kategorinya ada di daftar ini tidak dicek.
  final List<String> excludedCategories;

  LibraryUpdateRules copyWith({
    bool? skipCompleted,
    bool? skipUnstarted,
    bool? skipUnread,
    List<String>? excludedCategories,
  }) =>
      LibraryUpdateRules(
        skipCompleted: skipCompleted ?? this.skipCompleted,
        skipUnstarted: skipUnstarted ?? this.skipUnstarted,
        skipUnread: skipUnread ?? this.skipUnread,
        excludedCategories: excludedCategories ?? this.excludedCategories,
      );

  static const _key = 'library.updates.rules.v1';

  static LibraryUpdateRules read(SharedPreferences prefs) {
    try {
      final json = asMap(jsonDecode(prefs.getString(_key) ?? '{}'));
      return LibraryUpdateRules(
        skipCompleted: json['skip_completed'] as bool? ?? true,
        skipUnstarted: json['skip_unstarted'] as bool? ?? true,
        skipUnread: json['skip_unread'] as bool? ?? false,
        excludedCategories: asStringList(json['excluded_categories']),
      );
    } catch (_) {
      return const LibraryUpdateRules();
    }
  }

  Future<void> write(SharedPreferences prefs) => prefs.setString(
        _key,
        jsonEncode({
          'skip_completed': skipCompleted,
          'skip_unstarted': skipUnstarted,
          'skip_unread': skipUnread,
          'excluded_categories': excludedCategories,
        }),
      );
}

final libraryUpdateRulesProvider =
    NotifierProvider<LibraryUpdateRulesNotifier, LibraryUpdateRules>(LibraryUpdateRulesNotifier.new);

class LibraryUpdateRulesNotifier extends Notifier<LibraryUpdateRules> {
  @override
  LibraryUpdateRules build() => LibraryUpdateRules.read(ref.watch(sharedPreferencesProvider));

  Future<void> set(LibraryUpdateRules rules) async {
    state = rules;
    await rules.write(ref.read(sharedPreferencesProvider));
  }
}

final libraryUpdatesProvider =
    NotifierProvider<LibraryUpdatesNotifier, LibraryUpdatesState>(LibraryUpdatesNotifier.new);

/// Cek bab baru dari semua favorit (komik & novel).
///
/// Disimpan di `<support>/library_updates.json`: daftar URL bab yang sudah
/// diketahui per seri, plus riwayat bab baru. Seri yang baru difavoritkan
/// hanya dicatat babnya pada pengecekan pertama (tidak dianggap baru).
class LibraryUpdatesNotifier extends Notifier<LibraryUpdatesState> {
  static const _parallel = 3;
  static const _timeout = Duration(seconds: 60);
  static const _maxUpdates = 500;

  /// Batas bab baru per seri per pengecekan (situs yang mengganti semua
  /// URL bab tidak membanjiri daftar).
  static const _maxNewPerSeries = 50;

  /// Interval cek otomatis saat aplikasi dibuka.
  static const autoInterval = Duration(hours: 6);

  Map<String, Set<String>> _known = {};

  /// Kunci seri yang terakhir terdeteksi tamat; tidak dicek lagi.
  Set<String> _completed = {};
  File? _file;
  bool _cancel = false;

  @override
  LibraryUpdatesState build() {
    Future.microtask(_load);
    return const LibraryUpdatesState();
  }

  Future<File> _storeFile() async =>
      _file ??= File('${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}library_updates.json');

  Future<void> _load() async {
    try {
      final file = await _storeFile();
      if (await file.exists()) {
        final json = asMap(jsonDecode(await file.readAsString()));
        _known = {
          for (final e in asMap(json['known']).entries) e.key: asStringList(e.value).toSet(),
        };
        _completed = asStringList(json['completed']).toSet();
        state = state.copyWith(
          updates: asList(json['updates']).map(LibraryUpdate.tryParse).whereType<LibraryUpdate>().toList(),
          lastCheck: asDate(json['last_check']),
          lastSeen: asDate(json['last_seen']),
        );
      }
    } catch (_) {
      // file rusak: mulai dari kosong
    }
    state = state.copyWith(loaded: true);
  }

  Future<void> _save() async {
    try {
      final file = await _storeFile();
      await file.writeAsString(jsonEncode({
        'known': {for (final e in _known.entries) e.key: e.value.toList()},
        'completed': _completed.toList(),
        'updates': [for (final u in state.updates) u.toJson()],
        'last_check': state.lastCheck?.toIso8601String(),
        'last_seen': state.lastSeen?.toIso8601String(),
      }));
    } catch (_) {
      // best-effort
    }
  }

  /// Baca ulang file: isolate latar (WorkManager) mungkin menulis bab baru
  /// selagi aplikasi tertidur.
  Future<void> reload() async {
    if (state.checking) return;
    await _load();
  }

  Future<void> markSeen() async {
    state = state.copyWith(lastSeen: DateTime.now());
    await _save();
  }

  Future<void> clear() async {
    state = state.copyWith(updates: const []);
    await _save();
  }

  void stop() => _cancel = true;

  /// Cek otomatis bila diaktifkan dan pengecekan terakhir sudah lewat
  /// [autoInterval].
  Future<void> maybeAutoCheck() async {
    if (!state.loaded) await _load();
    if (!ref.read(libraryAutoCheckProvider)) return;
    final last = state.lastCheck;
    if (last != null && DateTime.now().difference(last) < autoInterval) return;
    await checkAll(notify: true);
  }

  /// Apakah seri ikut dicek, menurut [rules]. Bawaan: lewati seri tamat dan
  /// seri yang belum pernah dibaca. Seri tamat tidak dicek lagi, dan seri yang
  /// belum dibaca otomatis ikut lagi setelah dibuka.
  static bool shouldCheck({
    required bool completed,
    required bool started,
    bool hasUnread = false,
    List<String> categories = const [],
    LibraryUpdateRules rules = const LibraryUpdateRules(),
  }) {
    if (rules.skipCompleted && completed) return false;
    if (rules.skipUnstarted && !started) return false;
    if (rules.skipUnread && hasUnread) return false;
    if (categories.isNotEmpty && categories.every(rules.excludedCategories.contains)) return false;
    return true;
  }

  /// Bandingkan bab terbaru dengan yang sudah diketahui.
  static List<({String url, String name, double? number})> newChapters(
    Set<String>? known,
    List<({String url, String name, double? number})> fetched,
  ) {
    if (known == null || fetched.isEmpty) return const [];
    final fresh = fetched.where((c) => !known.contains(c.url)).toList();
    // Semua bab "baru" = situs mengganti format URL; jangan dianggap baru.
    if (fresh.length == fetched.length && known.isNotEmpty) return const [];
    return fresh.length > _maxNewPerSeries ? fresh.sublist(0, _maxNewPerSeries) : fresh;
  }

  Future<int> checkAll({bool notify = false}) async {
    if (state.checking) return 0;
    if (!state.loaded) await _load();
    final favorites = ref.read(sourceFavoritesProvider).map((f) => f.item).toList();
    final progress = ref.read(sourceProgressProvider);
    final started = {for (final h in ref.read(sourceHistoryProvider)) h.item.key};
    final rules = ref.read(libraryUpdateRulesProvider);
    final categoriesOf = {for (final f in ref.read(sourceFavoritesProvider)) f.item.key: f.categories};
    // Seri yang masih punya bab baru belum dibaca.
    final withUnread = {
      for (final u in state.updates)
        if (!(progress[u.item.key]?[u.chapterUrl]?.done ?? false)) u.item.key,
    };
    final toCheck = [
      for (final f in favorites)
        if (shouldCheck(
          completed: _completed.contains(f.key),
          started: started.contains(f.key) || (progress[f.key]?.isNotEmpty ?? false),
          hasUnread: withUnread.contains(f.key),
          categories: categoriesOf[f.key] ?? const [],
          rules: rules,
        ))
          f,
    ];
    debugPrint('Library update check: ${toCheck.length}/${favorites.length} series (rest completed/unread)');
    _cancel = false;
    state = state.copyWith(checking: true, done: 0, total: toCheck.length, failed: const []);
    final queue = [...toCheck];
    final found = <LibraryUpdate>[];
    final failed = <String>[];
    var done = 0;

    Future<void> worker() async {
      while (queue.isNotEmpty && !_cancel) {
        final item = queue.removeAt(0);
        try {
          final series = await fetchLibrarySeries(ref.read, item).timeout(_timeout);
          final fetched = series.chapters;
          final now = DateTime.now();
          if (series.completed) {
            _completed.add(item.key);
          } else {
            _completed.remove(item.key);
          }
          for (final c in newChapters(_known[item.key], fetched)) {
            found.add(LibraryUpdate(item: item, chapterUrl: c.url, chapterName: c.name, foundAt: now));
          }
          _known[item.key] = {...?_known[item.key], ...fetched.map((c) => c.url)};
        } catch (_) {
          failed.add(item.title);
        }
        done++;
        state = state.copyWith(done: done);
      }
    }

    await Future.wait(List.generate(_parallel, (_) => worker()));
    // Bersihkan seri yang sudah tidak difavoritkan.
    final keys = favorites.map((f) => f.key).toSet();
    _known.removeWhere((k, _) => !keys.contains(k));
    _completed.removeWhere((k) => !keys.contains(k));
    state = state.copyWith(
      updates: [...found, ...state.updates].take(_maxUpdates).toList(),
      lastCheck: DateTime.now(),
      checking: false,
      failed: failed,
    );
    await _save();
    if (found.isNotEmpty) autoDownload(found);
    if (notify && found.isNotEmpty) await _notify(found);
    return found.length;
  }

  /// Batas bab yang diantre otomatis per pengecekan.
  static const maxAutoDownload = 20;

  /// Antrekan unduhan bab baru bila "Unduh otomatis" aktif. Bab terlama dulu.
  void autoDownload(List<LibraryUpdate> found) {
    try {
      if (!ref.read(appSettingsProvider).autoDownloadNew) return;
      final queue = ref.read(downloadQueueProvider.notifier);
      var budget = maxAutoDownload;
      final byItem = <String, List<LibraryUpdate>>{};
      for (final u in found) {
        (byItem[u.item.key] ??= []).add(u);
      }
      for (final list in byItem.values) {
        if (budget <= 0) break;
        final chapters = list.reversed.take(budget).toList();
        budget -= chapters.length;
        final item = list.first.item;
        queue.enqueue(
          sourceId: item.sourceId,
          mangaUrl: item.url,
          manga: SourceMangaDetails(url: item.url, title: item.title, thumbnailUrl: item.thumbnailUrl),
          chapters: [for (final c in chapters) SourceChapter(url: c.chapterUrl, name: c.chapterName)],
        );
      }
    } catch (e) {
      debugPrint('autoDownload: $e');
    }
  }

  // ------------------------------------------------------------ notifikasi

  static final _notifications = FlutterLocalNotificationsPlugin();
  static bool _notificationsReady = false;

  Future<void> _notify(List<LibraryUpdate> found) async {
    try {
      if (!_notificationsReady) {
        await _notifications.initialize(
          settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
        );
        try {
          // Di isolate latar tidak ada Activity untuk dialog izin; izin yang
          // sudah diberikan sebelumnya tetap berlaku.
          await _notifications
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission();
        } catch (_) {}
        _notificationsReady = true;
      }
      final titles = {for (final u in found) u.item.title}.toList();
      await _notifications.show(
        id: 1001,
        title: trp('{n} bab baru', {'n': found.length}),
        body: titles.length <= 3 ? titles.join(', ') : trp('{list} +{n} lagi', {'list': titles.take(3).join(', '), 'n': titles.length - 3}),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'library_updates',
            tr('Bab baru'),
            channelDescription: tr('Bab baru dari novel & komik favorit'),
            importance: Importance.defaultImportance,
          ),
        ),
      );
    } catch (_) {
      // notifikasi opsional
    }
  }
}
