import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/novels/novel_models.dart';
import 'package:hub_reader/state/novel_health_provider.dart';
import 'package:hub_reader/state/source_health_provider.dart';

NovelPluginInfo _p(String id, String site, {String lang = 'en'}) =>
    NovelPluginInfo(id: id, name: id, site: site, lang: lang, version: '1', url: 'u');

SourceHealth _h(HealthStatus s) => SourceHealth(s, DateTime(2026));

void main() {
  test('plugin kembar: sisakan yang jalan', () {
    final out = dedupeNovelPlugins(
      [_p('a', 'https://x.com/'), _p('b', 'https://www.x.com'), _p('c', 'https://y.com')],
      {'a': _h(HealthStatus.broken), 'b': _h(HealthStatus.ok)},
    );
    expect(out.map((p) => p.id), ['b', 'c']);
  });

  test('plugin yang sudah dipakai tetap tampil', () {
    final out = dedupeNovelPlugins(
      [_p('a', 'https://x.com'), _p('b', 'https://x.com')],
      {'b': _h(HealthStatus.ok)},
      keep: (p) => p.id == 'a',
    );
    expect(out.map((p) => p.id), ['a']);
  });

  test('bahasa beda atau situs kosong tidak dianggap kembar', () {
    final out = dedupeNovelPlugins(
      [_p('a', 'https://x.com'), _p('b', 'https://x.com', lang: 'id'), _p('c', ''), _p('d', '')],
      {},
    );
    expect(out.length, 4);
  });
}
