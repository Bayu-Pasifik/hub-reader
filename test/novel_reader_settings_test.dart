import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/state/novel_providers.dart';

void main() {
  test('defaults and round trip of typography settings', () {
    const d = NovelReaderSettings();
    expect(d.paragraphSpacing, 0.9);
    expect(d.bold, false);
    expect(d.align, NovelAlign.start);
    expect(d.customFontPath, isNull);

    final s = d.copyWith(
      paragraphSpacing: 1.5,
      bold: true,
      align: NovelAlign.center,
      customFontPath: '/x/a.ttf',
      customBg: 0xFF000000,
      customFg: 0xFFFFFFFF,
    );
    final back = NovelReaderSettings.fromJson(s.toJson());
    expect(back.paragraphSpacing, 1.5);
    expect(back.bold, true);
    expect(back.align, NovelAlign.center);
    expect(back.customFontPath, '/x/a.ttf');
    expect(back.customBg, 0xFF000000);
    expect(back.customFg, 0xFFFFFFFF);

    final cleared = s.copyWith(customFontPath: null, customBg: null);
    expect(cleared.customFontPath, isNull);
    expect(cleared.customBg, isNull);
    expect(cleared.customFg, 0xFFFFFFFF);
  });

  test('legacy justify flag migrates to align', () {
    expect(NovelReaderSettings.fromJson({'justify': true}).align, NovelAlign.justify);
    expect(NovelReaderSettings.fromJson({}).align, NovelAlign.start);
  });
}
