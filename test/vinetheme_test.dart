import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/sources/models.dart';
import 'package:hub_reader/sources/templates/vinetheme.dart';

// Payload disederhanakan dari respons asli drakecomic.net (API JSON dan
// Next.js RSC dengan header `rsc: 1`). Tes ini memeriksa parser saja.

final _source = VineThemeSource(id: 'en.x', name: 'X', baseUrl: 'https://x.net', lang: 'en');

String _rsc(Object detail) => [
      '1:"\$Sreact.fragment"',
      '6:I[41165,["3238","\$4"],"\$5"]',
      '27:${jsonEncode([
            '\$',
            'div',
            null,
            {'children': detail},
          ])}',
      ':HL["/_next/static/css/a.css","style"]',
    ].join('\n');

void main() {
  test('API list maps urlSlug to series URLs and resolves relative covers', () {
    final page = _source.parseList({
      'data': [
        {'id': 'drake-s-1', 'slug': 'old', 'urlSlug': 'disastrous-necromancer', 'title': 'Disastrous Necromancer',
          'coverImage': '/uploads/series/dn/cover.webp'},
        {'id': 'broken', 'title': ''},
      ],
      'meta': {'hasMore': true},
    });
    expect(page.items.single.url, 'https://x.net/series/comic/disastrous-necromancer');
    expect(page.items.single.thumbnailUrl, 'https://x.net/uploads/series/dn/cover.webp');
    expect(page.hasNextPage, isTrue);
  });

  test('RSC rows are searched recursively for the detail object', () {
    final payload = _rsc({
      'series': {'title': 'A'},
      'chapters': [],
      'totalPages': 4,
    });
    final found = findInNextRsc(payload, (m) => m.containsKey('series') && m.containsKey('chapters'));
    expect(found?['totalPages'], 4);
    expect(findInNextRsc(payload, (m) => m.containsKey('nothing')), isNull);
  });

  test('details hide locked chapters, sort by number and build chapter URLs', () {
    final d = _source.parseDetails(
      {
        'title': 'Disastrous Necromancer',
        'urlSlug': 'disastrous-necromancer',
        'status': 'ONGOING',
        'type': 'MANHUA',
        'origin': 'CHINESE',
        'coverImage': '/uploads/cover.webp',
        'description': '<p>In a world of magic.</p><p>Second<br>line</p>',
        'aliases': ['Catastrophic Necromancer', 'Disastrous Necromancer'],
        'genres': [
          {'name': 'Action', 'slug': 'action'},
        ],
        'team': {'name': 'Drake'},
      },
      [
        {'number': 2.5, 'title': 'Side', 'publishedAt': r'$D2026-11-09T15:06:23.894Z'},
        {'number': 3, 'title': '3', 'isLocked': true},
        {'number': 321, 'title': '321', 'publishedAt': '2026-11-01T00:00:00Z'},
        {'number': 321, 'title': 'duplicate'},
      ],
      Uri.parse('https://x.net/series/comic/disastrous-necromancer'),
    );
    expect(d.status, SourceMangaStatus.ongoing);
    expect(d.genres, ['Manhua', 'Chinese', 'Action']);
    expect(d.author, 'Drake');
    expect(d.description, 'In a world of magic.\n\nSecond\nline\n\nAlternative titles:\n- Catastrophic Necromancer');
    expect(d.chapters.map((c) => c.name), ['Chapter 321', 'Side']);
    expect(d.chapters.last.url, 'https://x.net/series/comic/disastrous-necromancer/chapter/2.5');
    expect(d.chapters.last.uploadedAt?.toUtc(), DateTime.utc(2026, 11, 9, 15, 6, 23, 894));
  });

  test('pages come from chapter.pages in the RSC payload', () {
    final pages = _source.parsePages(_rsc({
      'chapter': {
        'pages': [
          {'imageUrl': '/uploads/series/dn/0321/p1.webp'},
          {'imageUrl': 'https://media.x.net/p2.webp'},
          {'imageUrl': null},
        ],
      },
    }));
    expect(pages, ['https://x.net/uploads/series/dn/0321/p1.webp', 'https://media.x.net/p2.webp']);
  });
}
