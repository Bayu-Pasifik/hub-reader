import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/sources/models.dart';
import 'package:hub_reader/sources/source.dart';
import 'package:hub_reader/sources/source_exception.dart';
import 'package:hub_reader/state/core_providers.dart';
import 'package:hub_reader/state/source_health_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sumber palsu: popular() mengembalikan hasil atau melempar error tertentu.
class _FakeSource extends MangaSource {
  _FakeSource(this.id, {this.error, this.empty = false});

  @override
  final String id;
  final Object? error;
  final bool empty;

  @override
  String get name => id;
  @override
  String get lang => 'id';
  @override
  String get baseUrl => 'https://$id.test';
  @override
  ContentWarning get contentWarning => ContentWarning.safe;

  @override
  Future<MangaPage> popular(int page) async {
    if (error != null) throw error!;
    return MangaPage(empty ? const [] : const [SourceManga(url: 'https://x/1', title: 'A')], hasNextPage: false);
  }

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
  test('errors map to health statuses', () {
    HealthStatus of(SourceErrorKind k, [int? code]) => SourceHealth.fromError(SourceException(k, statusCode: code)).status;
    expect(of(SourceErrorKind.cloudflare, 403), HealthStatus.cloudflare);
    expect(of(SourceErrorKind.noConnection), HealthStatus.dead);
    expect(of(SourceErrorKind.server, 522), HealthStatus.dead);
    expect(of(SourceErrorKind.parse), HealthStatus.broken);
    expect(of(SourceErrorKind.rateLimited, 429), HealthStatus.ok);
  });

  test('checkAll records every source, ranks them, and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);

    await c.read(sourceHealthProvider.notifier).checkAll([
      _FakeSource('ok'),
      _FakeSource('cf', error: const SourceException(SourceErrorKind.cloudflare, statusCode: 403)),
      _FakeSource('dead', error: const SourceException(SourceErrorKind.noConnection)),
      _FakeSource('empty', empty: true),
    ]);

    final h = c.read(sourceHealthProvider);
    expect(h.map((k, v) => MapEntry(k, v.status)), {
      'ok': HealthStatus.ok,
      'cf': HealthStatus.cloudflare,
      'dead': HealthStatus.dead,
      'empty': HealthStatus.broken,
    });
    expect(h['cf']!.detail, 'HTTP 403');
    expect(c.read(healthRunProvider).running, isFalse);
    expect(c.read(healthRunProvider).done, 4);
    expect(healthRank(h['ok']) < healthRank(null) && healthRank(null) < healthRank(h['dead']), isTrue);

    // Container baru membaca hasil tersimpan.
    final c2 = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(c2.dispose);
    expect(c2.read(sourceHealthProvider)['dead']?.status, HealthStatus.dead);
  });
}
