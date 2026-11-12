import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/json.dart';
import 'core_providers.dart';

/// Domain pengganti satu sumber.
class BaseUrlSetting {
  const BaseUrlSetting({required this.url, this.previousHosts = const []});

  /// Kosong = pakai domain bawaan (host lama tetap diingat).
  final String url;

  bool get hasOverride => url.isNotEmpty;

  /// Host yang pernah dipakai, untuk mengalihkan URL tersimpan yang lama.
  final List<String> previousHosts;

  JsonMap toJson() => {'url': url, 'previous_hosts': previousHosts};

  static BaseUrlSetting? tryParse(Object? raw) {
    final m = asMap(raw);
    final hosts = asStringList(m['previous_hosts']);
    final url = asString(m['url']) ?? '';
    if (url.isEmpty && hosts.isEmpty) return null;
    return BaseUrlSetting(url: url, previousHosts: hosts);
  }
}

/// Override domain per sumber (id sumber → setting). Mengubahnya membuat
/// ulang registry, jadi semua layar sumber memakai domain baru.
final sourceBaseUrlProvider =
    NotifierProvider<SourceBaseUrlNotifier, Map<String, BaseUrlSetting>>(SourceBaseUrlNotifier.new);

class SourceBaseUrlNotifier extends Notifier<Map<String, BaseUrlSetting>> {
  static const _key = 'sources.base_url.v1';

  @override
  Map<String, BaseUrlSetting> build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
    if (raw == null) return {};
    try {
      return {
        for (final e in asMap(jsonDecode(raw)).entries)
          if (BaseUrlSetting.tryParse(e.value) case final s?) e.key: s,
      };
    } catch (_) {
      return {};
    }
  }

  /// [currentUrl] = domain yang sedang dipakai (bawaan atau override lama);
  /// host-nya disimpan agar URL lama tetap bisa dialihkan.
  Future<void> set(String sourceId, String url, {required String currentUrl}) async {
    final normalized = url.trim().replaceFirst(RegExp(r'/+$'), '');
    final hosts = {
      ...?state[sourceId]?.previousHosts,
      if (Uri.tryParse(currentUrl)?.host case final h? when h.isNotEmpty) h,
    }..remove(Uri.tryParse(normalized)?.host);
    state = {...state, sourceId: BaseUrlSetting(url: normalized, previousHosts: hosts.toList())};
    await _save();
  }

  /// Kembali ke domain bawaan; host override lama tetap diingat supaya URL
  /// tersimpan darinya masih dialihkan.
  Future<void> reset(String sourceId, {required String currentUrl, required String defaultUrl}) async {
    final old = state[sourceId];
    if (old == null || !old.hasOverride) return;
    final hosts = {...old.previousHosts, if (Uri.tryParse(currentUrl)?.host case final h? when h.isNotEmpty) h}
      ..remove(Uri.tryParse(defaultUrl)?.host);
    state = {...state, sourceId: BaseUrlSetting(url: '', previousHosts: hosts.toList())};
    await _save();
  }

  Future<void> _save() => ref
      .read(sharedPreferencesProvider)
      .setString(_key, jsonEncode({for (final e in state.entries) e.key: e.value.toJson()}));
}

// ------------------------------------------------------- tampilan daftar

/// Tampilkan sumber 18+ (NSFW) di daftar. Default: tidak.
final showNsfwSourcesProvider = NotifierProvider<ShowNsfwNotifier, bool>(ShowNsfwNotifier.new);

class ShowNsfwNotifier extends Notifier<bool> {
  static const _key = 'sources.show_nsfw.v1';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setBool(_key, value);
  }
}

/// Bahasa yang dipilih di tab Sumber (null = semua).
final sourceLanguageProvider = NotifierProvider<SourceLanguageNotifier, String?>(SourceLanguageNotifier.new);

class SourceLanguageNotifier extends Notifier<String?> {
  static const _key = 'sources.language.v1';

  @override
  String? build() => ref.watch(sharedPreferencesProvider).getString(_key);

  Future<void> set(String? lang) async {
    state = lang;
    final prefs = ref.read(sharedPreferencesProvider);
    lang == null ? await prefs.remove(_key) : await prefs.setString(_key, lang);
  }
}
