import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/novels/novel_models.dart';
import 'package:hub_reader/novels/novel_source.dart';
import 'package:hub_reader/sources/source_exception.dart';
import 'package:hub_reader/ui/widgets/novel_html.dart';

void main() {
  group('manifest', () {
    test('entri plugin + kode bahasa', () {
      final p = NovelPluginInfo.tryParse({
        'id': 'IDWN.id',
        'name': 'IndoWebNovel',
        'site': 'https://indowebnovel.id/',
        'lang': 'Bahasa Indonesia',
        'version': '1.0.3',
        'url': 'https://example.com/a.js',
      })!;
      expect(p.lang, 'id');
      expect(p.host, 'indowebnovel.id');
      expect(langCodeOf('‎العربية'), 'ar');
      expect(langCodeOf('中文, 汉语, 漢語'), 'zh');
      expect(NovelPluginInfo.tryParse({'name': 'x'}), isNull);
    });
  });

  group('detail novel', () {
    test('parse SourceNovel LNReader', () {
      final d = NovelDetails.parse('/n/1', {
        'name': ' Judul ',
        'cover': 'https://github.com/LNReader/lnreader-plugins/blob/main/icons/src/coverNotAvailable.jpg?raw=true',
        'genres': 'Action, Fantasy ,Romance',
        'status': 'Ongoing',
        'author': '',
        'chapters': [
          {'name': 'Bab 1', 'path': '/n/1/1', 'releaseTime': '2024-01-01', 'chapterNumber': 1},
          {'name': 'tanpa path'},
        ],
        'totalPages': 3,
      });
      expect(d.name, 'Judul');
      expect(d.cover, isNull, reason: 'sampul "not available" bawaan dianggap kosong');
      expect(d.genres, ['Action', 'Fantasy', 'Romance']);
      expect(d.author, isNull);
      expect(d.chapters.single.number, 1);
      expect(d.totalPages, 3);
    });
  });

  group('filter', () {
    final defs = NovelFilterDef.parseAll({
      'sort': {
        'label': 'Urut',
        'type': 'Picker',
        'value': 'pop',
        'options': [
          {'label': 'Populer', 'value': 'pop'},
          {'label': 'Baru', 'value': 'new'},
        ],
      },
      'genre': {'label': 'Genre', 'type': 'Checkbox', 'value': <String>[], 'options': []},
      'adult': {'label': '18+', 'type': 'Switch', 'value': false},
      'weird': {'label': '?', 'type': 'Unknown', 'value': 1},
    });

    test('tipe tak dikenal dilewati', () {
      expect(defs.map((d) => d.key), ['sort', 'genre', 'adult']);
      expect(defs.first.options.last.value, 'new');
    });

    test('payload memakai default kecuali yang diubah', () {
      final payload = filterPayload(defs, {'sort': 'new'});
      expect(payload['sort'], {'type': 'Picker', 'value': 'new'});
      expect(payload['adult'], {'type': 'Switch', 'value': false});
      expect(payload['genre'], {'type': 'Checkbox', 'value': <String>[]});
    });
  });

  group('pesan error plugin', () {
    test('dipetakan ke jenis error sumber', () {
      expect(novelError(Exception('Could not reach site (403) try to open in webview.')).kind,
          SourceErrorKind.cloudflare);
      expect(novelError(Exception('Network request failed: SocketException')).kind, SourceErrorKind.noConnection);
      expect(novelError(Exception('Network request timed out')).kind, SourceErrorKind.timeout);
      expect(novelError(Exception("TypeError: cannot read property 'text' of undefined")).kind,
          SourceErrorKind.parse);
    });
  });

  group('HTML bab', () {
    test('paragraf, br, heading, gaya inline, gambar, skrip dibuang', () {
      final blocks = parseNovelHtml('''
        <h3>Bab 1: Awal</h3>
        <p>Halo   <b>dunia</b>,<br> baris dua.</p>
        <script>alert(1)</script>
        <div style="display:none">iklan</div>
        <p>&nbsp;</p>
        <p><img src="/img/a.jpg"></p>
        <hr>
        Teks lepas <i>miring</i>
      ''', baseUrl: Uri.parse('https://situs.com/novel/'));

      expect(blocks, hasLength(5));
      final h = blocks[0] as TextBlock;
      expect(h.heading, 3);
      expect(h.plain, 'Bab 1: Awal');

      final p = blocks[1] as TextBlock;
      expect(p.plain, 'Halo dunia,\nbaris dua.');
      expect(p.spans.firstWhere((s) => s.text == 'dunia').bold, isTrue);

      expect((blocks[2] as ImageBlock).url, 'https://situs.com/img/a.jpg');
      expect(blocks[3], isA<RuleBlock>());
      final last = blocks[4] as TextBlock;
      expect(last.plain, 'Teks lepas miring');
      expect(last.spans.last.italic, isTrue);
    });

    test('teks polos tanpa tag tetap tampil', () {
      final blocks = parseNovelHtml('Satu.\n\nDua.');
      expect((blocks.single as TextBlock).plain, 'Satu. Dua.');
    });
  });

  group('NovelPluginSetting', () {
    final settings = NovelPluginSetting.parseAll({
      'signInUrl': {'value': '', 'label': 'Sign-in link', 'type': 'Text'},
      'preferredMode': {
        'value': 'ai',
        'label': 'Preferred translation',
        'type': 'Select',
        'options': [
          {'label': 'AI', 'value': 'ai'},
          {'label': 'Web', 'value': 'web'},
        ],
      },
      'fallbackToWeb': {'value': true, 'label': 'Fallback', 'type': 'Switch'},
      'langs': {'value': ['en'], 'label': 'Bahasa', 'type': 'CheckboxGroup', 'options': [{'label': 'EN', 'value': 'en'}]},
      'rusak': 'bukan map',
    });

    test('parse tipe, label, opsi, default', () {
      expect(settings.map((s) => s.key), ['signInUrl', 'preferredMode', 'fallbackToWeb', 'langs']);
      expect(settings.map((s) => s.type), [
        NovelSettingType.text,
        NovelSettingType.select,
        NovelSettingType.toggle,
        NovelSettingType.checkboxGroup,
      ]);
      expect(settings[1].options.map((o) => o.value), ['ai', 'web']);
    });

    test('normalize memakai default bila kosong dan menyesuaikan tipe', () {
      expect(settings[0].normalize(null), '');
      expect(settings[1].normalize(null), 'ai');
      expect(settings[1].normalize('web'), 'web');
      expect(settings[2].normalize(null), true);
      expect(settings[2].normalize(false), false);
      expect(settings[3].normalize(null), ['en']);
    });
  });
}
