import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/state/core_providers.dart';
import 'package:hub_reader/state/novel_highlights.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _make([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  const key = 'p|/bab-1';

  test('matchingHighlight: sama atau terkandung; kosong bila belum disorot', () {
    expect(matchingHighlight(['halo dunia'], 'halo dunia'), 'halo dunia');
    expect(matchingHighlight(['dunia'], '  halo dunia yang indah '), 'dunia');
    expect(matchingHighlight(['lain'], 'halo'), isNull);
    expect(matchingHighlight(['x'], '   '), isNull);
  });

  test('catatan tersimpan, diubah, dan dihapus bila dikosongkan', () async {
    final c = await _make();
    final n = c.read(novelHighlightNotesProvider.notifier);
    await n.set(key, 'kalimat', '  penting  ');
    expect(n.noteFor(key, 'kalimat'), 'penting');
    await n.set(key, 'kalimat', 'diubah');
    expect(n.noteFor(key, 'kalimat'), 'diubah');
    await n.set(key, 'kalimat', '   ');
    expect(c.read(novelHighlightNotesProvider), isEmpty);
  });

  test('catatan bertahan setelah buka ulang dan ikut hilang saat sorotan dihapus', () async {
    final c = await _make();
    await c.read(novelHighlightNotesProvider.notifier).set(key, 'kalimat', 'catatan');
    await c.read(novelHighlightNotesProvider.notifier).set(key, 'lain', 'dua');

    final prefs = c.read(sharedPreferencesProvider);
    final c2 = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(c2.dispose);
    expect(c2.read(novelHighlightNotesProvider)[key], {'kalimat': 'catatan', 'lain': 'dua'});

    await c2.read(novelHighlightNotesProvider.notifier).removeFor(key, 'ini kalimat panjang');
    expect(c2.read(novelHighlightNotesProvider)[key], {'lain': 'dua'});
  });

  test('data rusak tidak membuat crash', () async {
    final c = await _make({'novel.highlight_notes.v1': '{bukan json'});
    expect(c.read(novelHighlightNotesProvider), isEmpty);
  });
}
