import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/data/local/backup.dart';
import 'package:hub_reader/data/models/source_library.dart';
import 'package:hub_reader/sources/models.dart';
import 'package:hub_reader/sources/source.dart';
import 'package:hub_reader/state/bookmarks_provider.dart';
import 'package:hub_reader/state/core_providers.dart';
import 'package:hub_reader/state/migration.dart';
import 'package:hub_reader/state/source_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sumber palsu: bab 1..n dengan URL `<prefix>/c<n>`.
class _Fake extends MangaSource {
  _Fake(this.id, this.prefix, this.count);

  @override
  final String id;
  final String prefix;
  final int count;

  @override
  String get name => id;
  @override
  String get lang => 'id';
  @override
  String get baseUrl => prefix;
  @override
  ContentWarning get contentWarning => ContentWarning.safe;
  @override
  Future<MangaPage> popular(int page) async => const MangaPage([], hasNextPage: false);
  @override
  Future<MangaPage> latest(int page) async => const MangaPage([], hasNextPage: false);
  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) async =>
      const MangaPage([], hasNextPage: false);
  @override
  Future<SourceMangaDetails> details(String mangaUrl) async => SourceMangaDetails(
        url: mangaUrl,
        title: 'T',
        chapters: [
          for (var n = count; n >= 1; n--) SourceChapter(url: '$prefix/c$n', name: 'Bab $n', number: n.toDouble()),
        ],
      );
  @override
  Future<List<String>> pages(SourceChapter chapter) async => const [];
  @override
  Map<String, String> imageHeaders({String? referer}) => const {};
}

void main() {
  late SharedPreferences prefs;
  late ProviderContainer c;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    c = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      sourceProvider('a').overrideWithValue(_Fake('a', 'https://a', 5)),
      sourceProvider('b').overrideWithValue(_Fake('b', 'https://b', 6)),
    ]);
  });
  tearDown(() => c.dispose());

  const series = (sourceId: 'a', url: 'https://a/s');

  test('bookmarks toggle, survive a restart and are part of backups', () async {
    final n = c.read(chapterBookmarksProvider.notifier);
    expect(await n.toggle(series, 'https://a/c2'), isTrue);
    await n.setMany(series, ['https://a/c3', 'https://a/c4'], bookmarked: true);
    expect(await n.toggle(series, 'https://a/c3'), isFalse);
    expect(c.read(seriesBookmarksProvider(series)), {'https://a/c2', 'https://a/c4'});

    await c.read(seriesNotesProvider.notifier).set(series, '  lanjut di arc 2  ');
    expect(c.read(seriesNoteProvider(series)), 'lanjut di arc 2');

    final fresh = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(fresh.dispose);
    expect(fresh.read(seriesBookmarksProvider(series)), {'https://a/c2', 'https://a/c4'});
    expect(fresh.read(seriesNoteProvider(series)), 'lanjut di arc 2');

    final backup = (await AppBackup.create(prefs, includeSecrets: false)).toString();
    expect(backup, contains(ChapterBookmarksNotifier.key));
    expect(backup, contains(SeriesNotesNotifier.key));
  });

  test('empty note and last bookmark removal clean up', () async {
    await c.read(seriesNotesProvider.notifier).set(series, 'x');
    await c.read(seriesNotesProvider.notifier).set(series, '   ');
    expect(c.read(seriesNoteProvider(series)), isNull);
    await c.read(chapterBookmarksProvider.notifier).toggle(series, 'u');
    await c.read(chapterBookmarksProvider.notifier).toggle(series, 'u');
    expect(c.read(chapterBookmarksProvider), isEmpty);
  });

  test('migration carries bookmarks by chapter number and the note', () async {
    await c.read(chapterBookmarksProvider.notifier).setMany(series, ['https://a/c2', 'https://a/c5'], bookmarked: true);
    await c.read(seriesNotesProvider.notifier).set(series, 'catatan lama');
    await migrateSeries(
      c.read,
      from: const SourceLibraryItem(sourceId: 'a', url: 'https://a/s', title: 'T'),
      to: const SourceLibraryItem(sourceId: 'b', url: 'https://b/s', title: 'T'),
      keepOld: true,
    );
    const target = (sourceId: 'b', url: 'https://b/s');
    expect(c.read(seriesBookmarksProvider(target)), {'https://b/c2', 'https://b/c5'});
    expect(c.read(seriesNoteProvider(target)), 'catatan lama');
  });
}
