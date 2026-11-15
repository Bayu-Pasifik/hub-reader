import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/core/i18n/strings.dart';
import 'package:hub_reader/core/i18n/strings_en.dart';
import 'package:hub_reader/core/net/doh.dart';
import 'package:hub_reader/sources/models.dart';
import 'package:hub_reader/state/app_settings_provider.dart';
import 'package:hub_reader/state/novel_providers.dart';
import 'package:hub_reader/state/reader_settings_provider.dart';
import 'package:hub_reader/state/source_health_provider.dart';
import 'package:hub_reader/state/source_library_providers.dart';
import 'package:hub_reader/trackers/tracker.dart';

void main() {
  tearDown(() => currentLanguage = AppLanguage.id);

  test('trp menyisipkan nilai pada bahasa Indonesia dan Inggris', () {
    currentLanguage = AppLanguage.id;
    expect(trp('{n} bab masuk antrean unduhan', {'n': 3}), '3 bab masuk antrean unduhan');
    currentLanguage = AppLanguage.en;
    expect(trp('{n} bab masuk antrean unduhan', {'n': 3}), '3 chapters added to the download queue');
  });

  test('setiap kunci tr()/trp() di lib punya terjemahan Inggris', () {
    final re = RegExp(r"\btrp?\('((?:[^'\\]|\\.)*)'");
    final missing = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.endsWith('strings_en.dart')) continue;
      for (final m in re.allMatches(f.readAsStringSync())) {
        final key = m.group(1)!.replaceAll(r'\n', '\n').replaceAll(r"\'", "'").replaceAll(r'\$', r'$');
        if (!stringsEn.containsKey(key)) missing.add('${f.path}: $key');
      }
    }
    expect(missing, isEmpty);
  });

  test('penampung {x} di terjemahan sama dengan di kunci', () {
    final ph = RegExp(r'\{(\w+)\}');
    for (final e in stringsEn.entries) {
      final a = ph.allMatches(e.key).map((m) => m.group(1)).toSet();
      final b = ph.allMatches(e.value).map((m) => m.group(1)).toSet();
      expect(b, a, reason: e.key);
    }
  });

  test('label enum diterjemahkan ke Inggris', () {
    final labels = <String>[
      for (final e in AppAccent.values) e.label,
      for (final e in ReaderMode.values) e.label,
      for (final e in PageTransitionStyle.values) e.label,
      for (final e in TapZoneLayout.values) e.label,
      for (final e in LibrarySort.values) e.label,
      for (final e in LibraryKind.values) e.label,
      for (final e in LibraryDisplay.values) e.label,
      for (final e in TrackStatus.values) e.label,
      for (final e in DohProvider.values) e.label,
      for (final e in NovelFont.values) e.label,
      for (final e in HealthStatus.values) e.label,
      for (final e in ContentWarning.values) e.label,
      for (final e in SourceMangaStatus.values) e.label,
    ];
    currentLanguage = AppLanguage.id;
    final ids = labels.toSet();
    expect(ids.where((l) => !stringsEn.containsKey(l)), isEmpty);
  });
}
