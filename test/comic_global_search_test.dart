import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/sources/local/local_source.dart';
import 'package:hub_reader/sources/models.dart';
import 'package:hub_reader/sources/source.dart';
import 'package:hub_reader/state/comic_global_search.dart';
import 'package:hub_reader/state/source_health_provider.dart';

class _FakeSource extends MangaSource {
  _FakeSource(this.id, {this.lang = 'id', this.nsfw = false});

  @override
  final String id;
  @override
  final String lang;
  final bool nsfw;

  @override
  String get name => id;
  @override
  String get baseUrl => 'https://$id.test';
  @override
  ContentWarning get contentWarning => nsfw ? ContentWarning.nsfw : ContentWarning.safe;

  @override
  Future<MangaPage> popular(int page) async => const MangaPage([], hasNextPage: false);
  @override
  Future<MangaPage> latest(int page) => popular(page);
  @override
  Future<MangaPage> search(int page, String query, {FilterValues filters = FilterValues.empty}) => popular(page);
  @override
  Future<SourceMangaDetails> details(String mangaUrl) => throw UnimplementedError();
  @override
  Future<List<String>> pages(SourceChapter chapter) => throw UnimplementedError();
  @override
  Map<String, String> imageHeaders({String? referer}) => const {};
}

void main() {
  final now = DateTime(2026);
  final local = LocalSource();
  final sources = <MangaSource>[
    local,
    _FakeSource('zeta'),
    _FakeSource('alpha'),
    _FakeSource('dead'),
    _FakeSource('broken'),
    _FakeSource('cf'),
    _FakeSource('adult', nsfw: true),
    _FakeSource('english', lang: 'en'),
  ];
  final health = {
    'dead': SourceHealth(HealthStatus.dead, now),
    'broken': SourceHealth(HealthStatus.broken, now),
    'cf': SourceHealth(HealthStatus.cloudflare, now),
    'zeta': SourceHealth(HealthStatus.ok, now),
  };

  List<String> ids(ComicSearchScope scope, {Set<String> used = const {}, bool nsfw = false}) =>
      comicSearchTargets(sources, scope: scope, usedIds: used, health: health, showNsfw: nsfw).map((s) => s.id).toList();

  test('language scope skips dead, broken, nsfw and local; healthy first', () {
    expect(ids(const LanguageScope('id')), ['zeta', 'alpha', 'cf']);
    expect(ids(const LanguageScope('id'), nsfw: true), ['zeta', 'adult', 'alpha', 'cf']);
    expect(ids(const LanguageScope('en')), ['english']);
  });

  test('used scope only searches favorite/history sources, local included', () {
    expect(ids(const UsedSourcesScope(), used: {local.id, 'alpha', 'dead', 'english'}), unorderedEquals([local.id, 'alpha', 'english']));
    expect(ids(const UsedSourcesScope()), isEmpty);
  });

  test('language counts exclude unusable and local sources', () {
    expect(comicSearchLanguages(sources, health: health, showNsfw: false), {'id': 3, 'en': 1});
  });
}
