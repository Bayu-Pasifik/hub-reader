import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/data/models/source_library.dart';
import 'package:hub_reader/sources/models.dart';
import 'package:hub_reader/state/app_settings_provider.dart';
import 'package:hub_reader/state/core_providers.dart';
import 'package:hub_reader/state/source_library_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('incognito skips history and reading progress but keeps manual marks', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);
    const item = SourceLibraryItem(sourceId: 's', url: 'u', title: 'T');
    final key = (sourceId: 's', url: 'u');

    await c.read(appSettingsProvider.notifier).update((s) => s.copyWith(incognito: true));
    await c.read(sourceHistoryProvider.notifier).record(item, const SourceChapter(url: 'c1', name: 'Bab 1'));
    await c.read(sourceProgressProvider.notifier).update(key, 'c1', page: 5, total: 10);
    expect(c.read(sourceHistoryProvider), isEmpty);
    expect(c.read(sourceProgressProvider), isEmpty);

    await c.read(sourceProgressProvider.notifier).setDone(key, 'c1', done: true);
    expect(c.read(sourceProgressProvider)['s|u']?['c1']?.done, isTrue);

    await c.read(appSettingsProvider.notifier).update((s) => s.copyWith(incognito: false));
    await c.read(sourceHistoryProvider.notifier).record(item, const SourceChapter(url: 'c2', name: 'Bab 2'));
    expect(c.read(sourceHistoryProvider).single.chapterUrl, 'c2');
  });
}
