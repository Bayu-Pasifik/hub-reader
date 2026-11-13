import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/core/utils/image_borders.dart';
import 'package:hub_reader/state/core_providers.dart';
import 'package:hub_reader/state/reader_settings_provider.dart';
import 'package:hub_reader/ui/widgets/cropped_page_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gambar RGBA [w]x[h] berlatar [bg] dengan kotak isi [content] (gelap/terang).
Uint8List _page(int w, int h, {required int bg, required int ink, required (int, int, int, int) box}) {
  final px = Uint8List(w * h * 4);
  final (l, t, r, b) = box;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final v = x >= l && x < r && y >= t && y < b ? ink : bg;
      final i = (y * w + x) * 4;
      px[i] = px[i + 1] = px[i + 2] = v;
      px[i + 3] = 255;
    }
  }
  return px;
}

void main() {
  group('findContentBounds', () {
    test('crops a white margin on all sides (with 1% padding)', () {
      final px = _page(200, 300, bg: 255, ink: 0, box: (40, 30, 160, 270));
      final b = findContentBounds(px, 200, 300)!;
      expect(b.left, 38 / 200);
      expect(b.top, 27 / 300);
      expect(b.right, 162 / 200);
      expect(b.bottom, 273 / 300);
    });

    test('black borders are detected too', () {
      final px = _page(200, 200, bg: 0, ink: 220, box: (50, 50, 150, 150));
      expect(findContentBounds(px, 200, 200), isNotNull);
    });

    test('webtoon mode only trims left and right', () {
      final px = _page(200, 300, bg: 255, ink: 0, box: (40, 30, 160, 270));
      final b = findContentBounds(px, 200, 300, vertical: false)!;
      expect(b.top, 0);
      expect(b.bottom, 1);
      expect(b.left, 38 / 200);
    });

    test('art that reaches the corners is left alone', () {
      final px = _page(100, 100, bg: 120, ink: 0, box: (10, 10, 90, 90));
      expect(findContentBounds(px, 100, 100), isNull);
    });

    test('a blank page or a tiny speck is not cropped', () {
      expect(findContentBounds(_page(100, 100, bg: 255, ink: 255, box: (0, 0, 0, 0)), 100, 100), isNull);
      expect(findContentBounds(_page(100, 100, bg: 255, ink: 0, box: (45, 45, 55, 55)), 100, 100), isNull);
    });

    test('margins under 2% are not worth cropping', () {
      final px = _page(200, 200, bg: 255, ink: 0, box: (1, 1, 199, 199));
      expect(findContentBounds(px, 200, 200), isNull);
    });
  });

  group('color matrix', () {
    test('no filter means no matrix', () {
      expect(readerColorMatrix(const ReaderDisplay(dim: 0.3)), isNull);
    });

    test('invert maps white to black and keeps alpha', () {
      final m = readerColorMatrix(const ReaderDisplay(invert: true))!;
      double apply(int row, List<double> rgba) =>
          m[row * 5] * rgba[0] +
          m[row * 5 + 1] * rgba[1] +
          m[row * 5 + 2] * rgba[2] +
          m[row * 5 + 3] * rgba[3] +
          m[row * 5 + 4];
      expect(apply(0, [255, 255, 255, 255]), 0);
      expect(apply(0, [0, 0, 0, 255]), 255);
      expect(apply(3, [0, 0, 0, 200]), 200);
    });
  });

  group('settings', () {
    late ProviderContainer c;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    });
    tearDown(() => c.dispose());

    test('series override wins over global mode and crop, then can be cleared', () async {
      final key = seriesReaderKey('id.komiku', 'https://x/manga/a/');
      await c.read(readerModeProvider.notifier).set(ReaderMode.webtoon);
      await c.read(readerDisplayProvider.notifier).set(const ReaderDisplay(grayscale: true));
      expect(c.read(effectiveReaderProvider(key)).perSeries, isFalse);

      await c
          .read(seriesReaderOverridesProvider.notifier)
          .set(key, const SeriesReaderOverride(mode: ReaderMode.pagedRtl, cropBorders: true));
      final e = c.read(effectiveReaderProvider(key));
      expect(e.mode, ReaderMode.pagedRtl);
      expect(e.display.cropBorders, isTrue);
      expect(e.display.grayscale, isTrue, reason: 'color filters stay global');
      expect(c.read(effectiveReaderProvider(seriesReaderKey('id.komiku', 'other'))).mode, ReaderMode.webtoon);

      await c.read(seriesReaderOverridesProvider.notifier).set(key, null);
      expect(c.read(effectiveReaderProvider(key)).mode, ReaderMode.webtoon);
    });

    test('settings survive a restart', () async {
      final key = seriesReaderKey('s', 'u');
      await c.read(readerDisplayProvider.notifier).set(const ReaderDisplay(invert: true, dim: 0.4));
      await c
          .read(seriesReaderOverridesProvider.notifier)
          .set(key, const SeriesReaderOverride(mode: ReaderMode.pagedLtr));
      final prefs = await SharedPreferences.getInstance();
      final fresh = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
      addTearDown(fresh.dispose);
      expect(fresh.read(readerDisplayProvider), const ReaderDisplay(invert: true, dim: 0.4));
      expect(fresh.read(effectiveReaderProvider(key)).mode, ReaderMode.pagedLtr);
    });
  });
}
