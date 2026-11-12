import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_providers.dart';

enum ReaderMode {
  /// Gulir vertikal tanpa jeda (manhwa/webtoon).
  webtoon('Webtoon (vertikal)'),

  /// Per halaman, geser ke kiri untuk lanjut (komik barat/manhua).
  pagedLtr('Per halaman (kiri → kanan)'),

  /// Per halaman, geser ke kanan untuk lanjut (manga Jepang).
  pagedRtl('Per halaman (kanan → kiri)');

  const ReaderMode(this.label);

  final String label;

  bool get isPaged => this != webtoon;
}

final readerModeProvider = NotifierProvider<ReaderModeNotifier, ReaderMode>(ReaderModeNotifier.new);

class ReaderModeNotifier extends Notifier<ReaderMode> {
  static const _key = 'reader.mode.v1';

  @override
  ReaderMode build() {
    final name = ref.watch(sharedPreferencesProvider).getString(_key);
    return ReaderMode.values.where((m) => m.name == name).firstOrNull ?? ReaderMode.webtoon;
  }

  Future<void> set(ReaderMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(_key, mode.name);
  }
}
