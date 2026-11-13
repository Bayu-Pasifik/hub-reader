import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/novels/novel_models.dart';
import 'package:hub_reader/novels/novel_source.dart';
import 'package:hub_reader/state/core_providers.dart';
import 'package:hub_reader/state/novel_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSource extends NovelSource {
  _FakeSource()
      : super.custom(
          info: const NovelPluginInfo(id: 'fake', name: 'Fake', site: 'https://x', lang: 'en', version: '1', url: ''),
        );

  int calls = 0;

  @override
  Future<List<NovelItem>> popular(int page, {bool latest = false, NovelFilterValues filters = const {}}) async {
    calls++;
    return page == 1 ? [NovelItem(path: '/n$calls', name: 'Novel $calls')] : const [];
  }
}

void main() {
  test('list reloads after invalidate (e.g. back from the WebView)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final source = _FakeSource();
    final c = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      novelSourceProvider('fake').overrideWith((ref) async => source),
    ]);
    addTearDown(c.dispose);
    const key = (pluginId: 'fake', listing: NovelListing.popular, query: '', filtersJson: '');
    final sub = c.listen(novelListProvider(key), (_, __) {});
    addTearDown(sub.close);

    Future<NovelListState> settled() async {
      for (var i = 0; i < 50 && c.read(novelListProvider(key)).isLoading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      return c.read(novelListProvider(key));
    }

    expect((await settled()).items.single.name, 'Novel 1');

    c.invalidate(novelListProvider);
    final reloaded = await settled();
    expect(reloaded.isLoading, isFalse);
    expect(reloaded.items.single.name, 'Novel 2');
  });
}
