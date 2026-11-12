import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/data/models/source_library.dart';
import 'package:hub_reader/sources/models.dart';
import 'package:hub_reader/state/core_providers.dart';
import 'package:hub_reader/state/source_library_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _item = SourceLibraryItem(
  sourceId: 'id.komiku',
  url: 'https://komiku.org/manga/one-piece/',
  title: 'One Piece',
);

Future<ProviderContainer> _container() async {
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('favorite toggle persists across containers and drives isFavorite', () async {
    final c = await _container();
    const key = (sourceId: 'id.komiku', url: 'https://komiku.org/manga/one-piece/');
    expect(c.read(isSourceFavoriteProvider(key)), isFalse);

    await c.read(sourceFavoritesProvider.notifier).toggle(_item);
    expect(c.read(isSourceFavoriteProvider(key)), isTrue);

    // Container baru membaca ulang dari SharedPreferences.
    final c2 = await _container();
    expect(c2.read(sourceFavoritesProvider).single.item.title, 'One Piece');

    await c.read(sourceFavoritesProvider.notifier).toggle(_item);
    expect(c.read(sourceFavoritesProvider), isEmpty);
  });

  test('history keeps one entry per series, newest first', () async {
    final c = await _container();
    final notifier = c.read(sourceHistoryProvider.notifier);
    const other = SourceLibraryItem(sourceId: 'id.ngomik', url: 'https://x/manga/a/', title: 'A');

    await notifier.record(_item, const SourceChapter(url: 'https://komiku.org/ch-1/', name: 'Chapter 1'));
    await notifier.record(other, const SourceChapter(url: 'https://x/a-1/', name: 'Chapter 1'));
    await notifier.record(_item, const SourceChapter(url: 'https://komiku.org/ch-2/', name: 'Chapter 2'));

    final history = c.read(sourceHistoryProvider);
    expect(history.map((e) => e.item.title), ['One Piece', 'A']);
    expect(history.first.chapterName, 'Chapter 2');

    const key = (sourceId: 'id.komiku', url: 'https://komiku.org/manga/one-piece/');
    expect(c.read(sourceLastReadProvider(key))?.chapterUrl, 'https://komiku.org/ch-2/');
  });
}
