import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/ui/deep_links.dart';
import 'package:hub_reader/ui/router.dart';

void main() {
  test('app links round-trip to router locations', () {
    final manga = sourceMangaLocation('id.komiku', 'https://komiku.org/manga/a b/?x=1&y=2');
    final link = DeepLinks.linkFor(manga);
    expect(link, startsWith('hubreader://open/source/id.komiku/manga?url='));
    expect(DeepLinks.locationFor(Uri.parse(link)), manga);

    final novel = novelDetailLocation('wtrlab', '/novel/123');
    expect(DeepLinks.locationFor(Uri.parse(DeepLinks.linkFor(novel))), novel);

    final reader = novelReaderLocation('wtrlab', '/novel/123', '/novel/123/ch-2');
    expect(DeepLinks.locationFor(Uri.parse(DeepLinks.linkFor(reader))), isNotNull);
  });

  test('only series and reader routes are allowed', () {
    String? loc(String s) => DeepLinks.locationFor(Uri.parse(s));
    expect(loc('hubreader://open/webview?url=https://evil.example'), isNull);
    expect(loc('hubreader://open/backup'), isNull);
    expect(loc('hubreader://open/app-settings'), isNull);
    expect(loc('hubreader://open/source/x/manga'), isNull); // url wajib
    expect(loc('hubreader://other/source/x/manga?url=a'), isNull);
    expect(loc('https://open/source/x/manga?url=a'), isNull);
    expect(loc('hubreader://open/source/x/y/manga?url=a'), isNull);
    // Parameter tambahan dibuang.
    expect(loc('hubreader://open/source/x/manga?url=a&evil=1'), '/source/x/manga?url=a');
  });
}
