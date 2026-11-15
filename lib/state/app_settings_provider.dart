import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/strings.dart';
import '../core/net/doh.dart';
import 'core_providers.dart';
import '../ui/app_shortcuts.dart';
import 'home_widget_sync.dart';

/// Warna utama aplikasi.
enum AppAccent {
  indigo('Indigo', Colors.indigo),
  teal('Hijau toska', Colors.teal),
  green('Hijau', Colors.green),
  orange('Oranye', Colors.deepOrange),
  pink('Merah muda', Colors.pink),
  purple('Ungu', Colors.deepPurple),
  blueGrey('Abu biru', Colors.blueGrey);

  const AppAccent(this._label, this.color);

  final String _label;

  String get label => tr(_label);
  final Color color;
}

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.pureBlack = false,
    this.accent = AppAccent.indigo,
    this.dynamicColor = false,
    this.appLock = false,
    this.lockAfter = const Duration(minutes: 1),
    this.incognito = false,
    this.secureScreen = false,
    this.lookupConsent = false,
    this.autoDeleteRead = false,
    this.autoDownloadNew = false,
    this.downloadWifiOnly = false,
    this.downloadParallel = 2,
    this.language = AppLanguage.id,
  });

  final ThemeMode themeMode;

  /// Latar hitam pekat pada tema gelap (hemat baterai di layar OLED).
  final bool pureBlack;
  final AppAccent accent;

  /// Warna dari wallpaper (Material You, Android 12+); mengalahkan [accent].
  final bool dynamicColor;

  /// Minta sidik jari / PIN perangkat saat aplikasi dibuka.
  final bool appLock;

  /// Kunci lagi setelah aplikasi di latar selama ini.
  final Duration lockAfter;

  /// Mode samaran: riwayat & posisi baca tidak dicatat.
  final bool incognito;

  /// Blokir screenshot, rekam layar, dan pratinjau di daftar aplikasi terbaru.
  final bool secureScreen;

  /// Pengguna setuju teks terpilih dikirim ke layanan kamus/terjemah online
  /// (MyMemory, dictionaryapi.dev). Diminta saat Kamus dipakai pertama kali.
  final bool lookupConsent;

  /// Hapus unduhan bab yang sudah selesai dibaca agar penyimpanan tidak penuh.
  final bool autoDeleteRead;

  /// Unduh otomatis bab baru yang ditemukan saat cek pembaruan.
  final bool autoDownloadNew;

  /// Antrean unduhan hanya berjalan lewat jaringan tanpa kuota (Wi-Fi).
  final bool downloadWifiOnly;

  /// Gambar yang diunduh bersamaan dalam satu bab (1-4).
  final int downloadParallel;

  /// Bahasa antarmuka.
  final AppLanguage language;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? pureBlack,
    AppAccent? accent,
    bool? dynamicColor,
    bool? appLock,
    Duration? lockAfter,
    bool? incognito,
    bool? secureScreen,
    bool? lookupConsent,
    bool? autoDeleteRead,
    bool? autoDownloadNew,
    bool? downloadWifiOnly,
    int? downloadParallel,
    AppLanguage? language,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        pureBlack: pureBlack ?? this.pureBlack,
        accent: accent ?? this.accent,
        dynamicColor: dynamicColor ?? this.dynamicColor,
        appLock: appLock ?? this.appLock,
        lockAfter: lockAfter ?? this.lockAfter,
        incognito: incognito ?? this.incognito,
        secureScreen: secureScreen ?? this.secureScreen,
        lookupConsent: lookupConsent ?? this.lookupConsent,
        autoDeleteRead: autoDeleteRead ?? this.autoDeleteRead,
        autoDownloadNew: autoDownloadNew ?? this.autoDownloadNew,
        downloadWifiOnly: downloadWifiOnly ?? this.downloadWifiOnly,
        downloadParallel: downloadParallel ?? this.downloadParallel,
        language: language ?? this.language,
      );
}

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(AppSettingsNotifier.new);

class AppSettingsNotifier extends Notifier<AppSettings> {
  static const _theme = 'app.theme.v1';
  static const _black = 'app.pure_black.v1';
  static const _accent = 'app.accent.v1';
  static const _dynamic = 'app.dynamic_color.v1';
  static const _lock = 'app.lock.v1';
  static const _lockAfter = 'app.lock_after_seconds.v1';
  static const _incognito = 'app.incognito.v1';
  static const _secureScreen = 'app.secure_screen.v1';
  static const _lookupConsent = 'app.lookup_consent.v1';
  static const _autoDeleteRead = 'app.auto_delete_read.v1';
  static const _autoDownloadNew = 'app.auto_download_new.v1';
  static const _downloadWifiOnly = 'app.download_wifi_only.v1';
  static const _downloadParallel = 'app.download_parallel.v1';
  static const _language = 'app.language.v1';

  @override
  AppSettings build() {
    final p = ref.watch(sharedPreferencesProvider);
    currentLanguage = AppLanguage.byName(p.getString(_language)) ?? AppLanguage.id;
    return AppSettings(
      themeMode: ThemeMode.values.where((m) => m.name == p.getString(_theme)).firstOrNull ?? ThemeMode.system,
      pureBlack: p.getBool(_black) ?? false,
      accent: AppAccent.values.where((a) => a.name == p.getString(_accent)).firstOrNull ?? AppAccent.indigo,
      dynamicColor: p.getBool(_dynamic) ?? false,
      appLock: p.getBool(_lock) ?? false,
      lockAfter: Duration(seconds: p.getInt(_lockAfter) ?? 60),
      incognito: p.getBool(_incognito) ?? false,
      secureScreen: p.getBool(_secureScreen) ?? false,
      lookupConsent: p.getBool(_lookupConsent) ?? false,
      autoDeleteRead: p.getBool(_autoDeleteRead) ?? false,
      autoDownloadNew: p.getBool(_autoDownloadNew) ?? false,
      downloadWifiOnly: p.getBool(_downloadWifiOnly) ?? false,
      downloadParallel: (p.getInt(_downloadParallel) ?? 2).clamp(1, 4),
      language: currentLanguage,
    );
  }

  Future<void> update(AppSettings Function(AppSettings) change) async {
    final before = state.language;
    state = change(state);
    currentLanguage = state.language;
    if (state.language != before) {
      rebuildAllWidgets();
      HomeWidgetSync.refreshLabels();
      AppShortcuts.refresh();
    }
    final p = ref.read(sharedPreferencesProvider);
    await p.setString(_theme, state.themeMode.name);
    await p.setBool(_black, state.pureBlack);
    await p.setString(_accent, state.accent.name);
    await p.setBool(_dynamic, state.dynamicColor);
    await p.setBool(_lock, state.appLock);
    await p.setInt(_lockAfter, state.lockAfter.inSeconds);
    await p.setBool(_incognito, state.incognito);
    await p.setBool(_secureScreen, state.secureScreen);
    await p.setBool(_lookupConsent, state.lookupConsent);
    await p.setBool(_autoDeleteRead, state.autoDeleteRead);
    await p.setBool(_autoDownloadNew, state.autoDownloadNew);
    await p.setBool(_downloadWifiOnly, state.downloadWifiOnly);
    await p.setInt(_downloadParallel, state.downloadParallel);
    await p.setString(_language, state.language.name);
  }
}

/// DNS-over-HTTPS untuk melewati blokir DNS dari provider internet.
final dohProviderProvider = NotifierProvider<DohNotifier, DohProvider>(DohNotifier.new);

class DohNotifier extends Notifier<DohProvider> {
  @override
  DohProvider build() => DohProvider.read(ref.watch(sharedPreferencesProvider));

  Future<void> set(DohProvider v) async {
    state = v;
    applyDoh(v);
    await ref.read(sharedPreferencesProvider).setString(DohProvider.prefsKey, v.name);
  }
}
