import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hub_reader/state/core_providers.dart';
import 'package:hub_reader/trackers/tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/state/tracker_providers.dart';

void main() {
  syncTests();
  const chapters = <TrackableChapter>[
    (url: 'c1', number: 1, done: true),
    (url: 'c2', number: 2, done: false),
    (url: 'c3', number: 3.5, done: false),
    (url: 'c4', number: 4, done: false),
    (url: 'x', number: null, done: false),
  ];

  test('menandai bab bernomor <= progres tracker yang belum selesai', () {
    expect(chapterUrlsToMarkRead(chapters, 3), ['c2', 'c3']);
  });

  test('progres 0 atau negatif tidak menandai apa pun', () {
    expect(chapterUrlsToMarkRead(chapters, 0), isEmpty);
    expect(chapterUrlsToMarkRead(chapters, -1), isEmpty);
  });

  test('bab tanpa nomor tidak disentuh', () {
    expect(chapterUrlsToMarkRead(chapters, 99), isNot(contains('x')));
  });

  test('bab 3.5 dihitung lewat floor (3 <= 3)', () {
    expect(chapterUrlsToMarkRead(const [(url: 'a', number: 3.5, done: false)], 3), ['a']);
  });
}

class _FakeTracker extends Tracker {
  _FakeTracker(super.prefs, this.remote);

  TrackEntry? remote;
  final updates = <int>[];

  @override
  String get id => 'fake';
  @override
  String get name => 'Fake';
  @override
  String get developerUrl => '';
  @override
  String get redirectHint => '';
  @override
  String get defaultClientId => '';
  @override
  Future<List<TrackSearchResult>> search(String query, {required bool novel}) async => const [];
  @override
  Future<TrackEntry?> entry(int mediaId) async => remote;
  @override
  Future<void> update(int mediaId, {required int progress, required TrackStatus status}) async {
    updates.add(progress);
    remote = (progress: progress, status: status, total: remote?.total);
  }
}

Future<(ProviderContainer, _FakeTracker)> _setup(TrackEntry remote) async {
  SharedPreferences.setMockInitialValues({
    'tracker.fake.token': 't',
    'tracker.links.v1': jsonEncode({
      's|u': [
        TrackLink(tracker: 'fake', mediaId: 7, title: 'X', progress: 2, total: 10).toJson(),
      ],
    }),
  });
  final prefs = await SharedPreferences.getInstance();
  final fake = _FakeTracker(prefs, remote);
  final c = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    trackersProvider.overrideWithValue([fake]),
  ]);
  addTearDown(c.dispose);
  return (c, fake);
}

void syncTests() {
  test('tracker lebih maju: progres & status lokal mengikuti tracker, tidak ada kiriman', () async {
    final (c, fake) = await _setup((progress: 6, status: TrackStatus.onHold, total: 10));
    final r = await c.read(trackLinksProvider.notifier).sync('s|u', localProgress: 3);
    expect(r.remoteProgress, 6);
    expect(r.pushedTo, 0);
    expect(fake.updates, isEmpty);
    final link = c.read(trackLinksProvider)['s|u']!.single;
    expect(link.progress, 6);
    expect(link.status, TrackStatus.onHold);
  });

  test('lokal lebih maju: dikirim naik ke tracker', () async {
    final (c, fake) = await _setup((progress: 2, status: TrackStatus.reading, total: 10));
    final r = await c.read(trackLinksProvider.notifier).sync('s|u', localProgress: 5);
    expect(r.pushedTo, 5);
    expect(fake.updates, [5]);
    expect(c.read(trackLinksProvider)['s|u']!.single.progress, 5);
  });

  test('lokal mencapai total: status jadi selesai', () async {
    final (c, _) = await _setup((progress: 2, status: TrackStatus.reading, total: 10));
    await c.read(trackLinksProvider.notifier).sync('s|u', localProgress: 10);
    expect(c.read(trackLinksProvider)['s|u']!.single.status, TrackStatus.completed);
  });

  test('entri tidak ada di tracker: tidak ada perubahan dan tidak error', () async {
    final (c, _) = await _setup((progress: 0, status: null, total: null));
    final notifier = c.read(trackLinksProvider.notifier);
    (c.read(trackersProvider).single as _FakeTracker).remote = null;
    final r = await notifier.sync('s|u', localProgress: 5);
    expect(r.remoteProgress, 0);
    expect(r.pushedTo, 0);
    expect(c.read(trackLinksProvider)['s|u']!.single.progress, 2);
  });
}
