import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/state/reader_settings_provider.dart';

void main() {
  test('spread mapping: cover alone then pairs', () {
    expect(spreadCount(0), 0);
    expect(spreadCount(1), 1);
    expect(spreadCount(2), 2);
    expect(spreadCount(3), 2);
    expect(spreadCount(10), 6);
    expect(pagesOfSpread(0, 10), [0]);
    expect(pagesOfSpread(1, 10), [1, 2]);
    expect(pagesOfSpread(5, 10), [9]);
    expect(pagesOfSpread(2, 3), isEmpty);
  });

  test('every page belongs to the spread that contains it', () {
    for (final total in [1, 2, 3, 4, 9, 10]) {
      for (var p = 0; p < total; p++) {
        expect(pagesOfSpread(spreadOfPage(p), total), contains(p), reason: 'total=$total p=$p');
      }
    }
  });

  test('display spread defaults on and round-trips', () {
    expect(const ReaderDisplay().spread, isTrue);
    expect(ReaderDisplay.fromJson(const ReaderDisplay(spread: false).toJson().cast<String, Object?>()).spread, isFalse);
    expect(ReaderDisplay.fromJson(const {}).spread, isTrue);
  });
}
