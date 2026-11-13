import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/state/core_providers.dart';
import 'package:hub_reader/state/tracker_providers.dart';
import 'package:hub_reader/trackers/tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracker palsu yang mencatat update.
class _FakeTracker extends Tracker {
  _FakeTracker(super.prefs, {this.defaultClientId = ''});
  @override
  final String defaultClientId;
  final updates = <(int, int, TrackStatus)>[];
  @override
  String get id => 'anilist';
  @override
  String get name => 'Fake';
  @override
  String get developerUrl => '';
  @override
  String get redirectHint => '';
  @override
  bool get loggedIn => true;
  @override
  Uri authorizeUrl() => Uri();
  @override
  Future<bool> handleRedirect(Uri url) async => false;
  @override
  Future<List<TrackSearchResult>> search(String query, {required bool novel}) async => const [];
  @override
  Future<TrackEntry?> entry(int mediaId) async => null;
  @override
  Future<void> update(int mediaId, {required int progress, required TrackStatus status}) async =>
      updates.add((mediaId, progress, status));
}

void main() {
  test('build-time client ID is used until the user sets one', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    expect(_FakeTracker(prefs).clientId, isNull);
    final t = _FakeTracker(prefs, defaultClientId: '123');
    expect(t.clientId, '123');
    expect(t.usesDefaultClientId, isTrue);
    await t.setClientId(' 456 ');
    expect(t.clientId, '456');
    expect(t.usesDefaultClientId, isFalse);
    await t.setClientId('');
    expect(t.clientId, '123');
  });

  test('chapterRead only raises progress and completes at the total', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final fake = _FakeTracker(prefs);
    final c = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      trackersProvider.overrideWithValue([fake]),
    ]);
    addTearDown(c.dispose);
    final links = c.read(trackLinksProvider.notifier);
    await links.put('s|u', const TrackLink(tracker: 'anilist', mediaId: 7, title: 'T', progress: 3, total: 10));

    await links.chapterRead('s|u', 'Chapter 2');
    expect(fake.updates, isEmpty);
    await links.chapterRead('s|u', 'Chapter 5.5 - Judul');
    expect(fake.updates.single, (7, 5, TrackStatus.reading));
    await links.chapterRead('s|u', 'Bab 10');
    expect(fake.updates.last, (7, 10, TrackStatus.completed));
    expect(c.read(trackLinksProvider)['s|u']!.single.progress, 10);
  });

  test('AniList finds a novel without login', () async {
    SharedPreferences.setMockInitialValues({});
    final t = AniListTracker(await SharedPreferences.getInstance(), dio: Dio());
    try {
      final r = await t.search('Mushoku Tensei', novel: true);
      final fallback = await t.search('Omniscient Reader', novel: true);
      expect(fallback, isNotEmpty);
      expect(r, isNotEmpty);
      expect(r.first.format, 'NOVEL');
    } on TrackerException catch (e) {
      markTestSkipped('AniList offline: $e');
    }
  });
}
