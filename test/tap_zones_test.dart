import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/state/reader_settings_provider.dart';

void main() {
  const w = 300.0;

  test('thirds: kiri mundur, kanan maju, tengah diam (LTR)', () {
    const z = TapZones();
    expect(z.resolve(20, w, rtl: false), false);
    expect(z.resolve(280, w, rtl: false), true);
    expect(z.resolve(150, w, rtl: false), isNull);
  });

  test('RTL membalik arah', () {
    const z = TapZones();
    expect(z.resolve(20, w, rtl: true), true);
    expect(z.resolve(280, w, rtl: true), false);
  });

  test('swap menukar kiri/kanan', () {
    const z = TapZones(swap: true);
    expect(z.resolve(20, w, rtl: false), true);
    expect(z.resolve(280, w, rtl: false), false);
  });

  test('halves: tidak ada zona mati', () {
    const z = TapZones(layout: TapZoneLayout.halves);
    expect(z.resolve(149, w, rtl: false), false);
    expect(z.resolve(151, w, rtl: false), true);
  });

  test('edges: hanya 25% pinggir', () {
    const z = TapZones(layout: TapZoneLayout.edges);
    expect(z.resolve(60, w, rtl: false), false);
    expect(z.resolve(100, w, rtl: false), isNull);
    expect(z.resolve(260, w, rtl: false), true);
  });

  test('off: tidak ada aksi', () {
    const z = TapZones(layout: TapZoneLayout.off);
    expect(z.resolve(20, w, rtl: false), isNull);
    expect(z.resolve(280, w, rtl: false), isNull);
  });

  test('json round trip + data rusak jatuh ke default', () {
    final z = TapZones.fromJson(const TapZones(layout: TapZoneLayout.edges, swap: true).toJson());
    expect(z.layout, TapZoneLayout.edges);
    expect(z.swap, true);
    expect(TapZones.fromJson(const {'layout': 'x'}).layout, TapZoneLayout.thirds);
  });
}
