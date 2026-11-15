import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/core/platform/reader_bridge.dart';
import 'package:hub_reader/state/novel_providers.dart';
import 'package:hub_reader/state/reader_settings_provider.dart';

void main() {
  test('byName: nama tak dikenal atau kosong jadi otomatis', () {
    expect(ReaderOrientation.byName('landscape'), ReaderOrientation.landscape);
    expect(ReaderOrientation.byName('portrait'), ReaderOrientation.portrait);
    expect(ReaderOrientation.byName(null), ReaderOrientation.auto);
    expect(ReaderOrientation.byName('xyz'), ReaderOrientation.auto);
  });

  test('ReaderDisplay: orientasi tersimpan dan terbaca, default otomatis', () {
    expect(const ReaderDisplay().orientation, ReaderOrientation.auto);
    final d = const ReaderDisplay().copyWith(orientation: ReaderOrientation.landscape);
    expect(ReaderDisplay.fromJson(d.toJson()).orientation, ReaderOrientation.landscape);
    expect(ReaderDisplay.fromJson(const {}).orientation, ReaderOrientation.auto);
    expect(d == const ReaderDisplay(), isFalse);
  });

  test('NovelReaderSettings: orientasi tersimpan dan terbaca, data lama tetap otomatis', () {
    final s = const NovelReaderSettings().copyWith(orientation: ReaderOrientation.portrait);
    expect(NovelReaderSettings.fromJson(s.toJson()).orientation, ReaderOrientation.portrait);
    expect(NovelReaderSettings.fromJson(const {'font_size': 20}).orientation, ReaderOrientation.auto);
  });
}
