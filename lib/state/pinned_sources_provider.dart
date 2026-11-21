import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_providers.dart' show sharedPreferencesProvider;

/// Id sumber yang disematkan pengguna (tampil di bagian "Disematkan" paling atas).
class PinnedSourcesNotifier extends Notifier<Set<String>> {
  PinnedSourcesNotifier(this._key);

  final String _key;

  @override
  Set<String> build() => (ref.watch(sharedPreferencesProvider).getStringList(_key) ?? const []).toSet();

  Future<void> toggle(String id) async {
    final next = {...state};
    if (!next.remove(id)) next.add(id);
    state = next;
    await ref.read(sharedPreferencesProvider).setStringList(_key, next.toList());
  }
}

final pinnedComicSourcesProvider =
    NotifierProvider<PinnedSourcesNotifier, Set<String>>(() => PinnedSourcesNotifier('sources.pinned.v1'));

final pinnedNovelSourcesProvider =
    NotifierProvider<PinnedSourcesNotifier, Set<String>>(() => PinnedSourcesNotifier('novels.pinned.v1'));
