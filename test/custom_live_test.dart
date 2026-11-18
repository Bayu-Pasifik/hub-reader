// Uji langsung sumber kustom (tulis tangan) dari PC.
//   CUSTOM_LIVE=1 [CUSTOM_IDS=en.mangapill,en.tcbscans] flutter test test/custom_live_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/sources/registry.dart';

Future<T> _t<T>(Future<T> f) => f.timeout(const Duration(seconds: 40));

void main() {
  final live = Platform.environment['CUSTOM_LIVE'] == '1';
  test('live custom sources', () async {
    final ids = Platform.environment['CUSTOM_IDS']?.split(',');
    final sources = customSources().where((s) => s.id != 'local' && (ids == null || ids.contains(s.id)));
    for (final s in sources) {
      final idx = int.tryParse(Platform.environment["CUSTOM_IDX"] ?? "") ?? 0;
      final buf = StringBuffer('${s.id}: ');
      try {
        final pop = await _t(s.popular(1));
        buf.write('popular=${pop.items.length} ');
        final lat = s.supportsLatest ? await _t(s.latest(1)) : null;
        buf.write('latest=${lat?.items.length} ');
        final q = pop.items[idx].title.split(' ').first;
        final found = await _t(s.search(1, q));
        buf.write('search("$q")=${found.items.length} ');
        final d = await _t(s.details(pop.items[idx].url));
        buf.write('chapters=${d.chapters.length} cover=${d.thumbnailUrl != null} ');
        final pages = await _t(s.pages((Platform.environment["CUSTOM_OLDEST"] == "1" ? d.chapters.last : d.chapters.first)));
        buf.write('pages=${pages.length} first=${pages.first}');
        // Unduh benar-benar satu gambar.
        final headers = s.imageHeaders(referer: (Platform.environment["CUSTOM_OLDEST"] == "1" ? d.chapters.last : d.chapters.first).url);
        final req = await HttpClient().getUrl(Uri.parse(pages.first));
        headers.forEach(req.headers.set);
        final res = await req.close();
        buf.write(' img=${res.statusCode}/${res.headers.contentType?.mimeType}');
        await res.drain<void>();
      } catch (e) {
        buf.write('FAIL $e');
      }
      // ignore: avoid_print
      print(buf);
    }
  }, skip: live ? false : 'set CUSTOM_LIVE=1', timeout: const Timeout(Duration(minutes: 20)));
}
