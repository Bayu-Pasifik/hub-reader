// Sumber dewasa seri-bab (HTML statis), port Dart dari extension
// keiyoushi/extensions-source (Apache-2.0): src/en/*.

import '../source.dart';
import 'chapter_source.dart';
import 'gallery_source.dart';

List<MangaSource> adultChapters() => [
      ChapterSource(
        id: 'en.manhwa18dash',
        name: 'Manhwa18Dash',
        baseUrl: 'https://manhwa18dash.com',
        popularUrl: (b, p) => '$b/manhwa?sort=popular',
        searchUrl: (b, p, q) => null,
        localSearch: true,
        cardSel: 'a.manga-card',
        cardTitleSel: '.manga-title',
        titleSel: '#mangaTitle',
        coverSel: 'meta[property="og:image"]',
        chapterSel: 'a[href*="/chapter-"]',
        reverseChapters: true,
        imagesOf: (d, u) => imagesFrom(d, u, 'img[data-src*="/mangas/"], img[src*="/mangas/"]', ['data-src', 'src']),
      ),
      ChapterSource(
        id: 'en.hentara',
        name: 'Hentara',
        baseUrl: 'https://hentara.com',
        popularUrl: (b, p) => '$b/',
        searchUrl: (b, p, q) => p > 1 ? null : '$b/search?q=${Uri.encodeQueryComponent(q)}',
        cardSel: 'a.ssr-card',
        cardTitleSel: '.ssr-card-title',
        titleSel: 'h1',
        coverSel: 'meta[property="og:image"]',
        tagSel: '.ssr-genre',
        statusSel: '.ssr-status',
        chapterSel: 'a.ssr-chapter',
        cleanTitle: (t) => t.replaceFirst(RegExp(r'^Read\s+'), '').replaceFirst(RegExp(r'\s+Manhwa Online Free.*$'), ''),
        imagesOf: (d, u) => imagesFrom(d, u, 'img[src*="/chapter-"], img[data-src*="/chapter-"]', ['data-src', 'src']),
      ),
      ChapterSource(
        id: 'en.manhwa210',
        name: 'Manhwa210',
        baseUrl: 'https://manhwa210.com',
        popularUrl: (b, p) => p > 1 ? '$b/?page=$p' : '$b/',
        searchUrl: (b, p, q) => '$b/search?q=${Uri.encodeQueryComponent(q)}',
        cardSel: 'div.manga-vertical',
        cardLinkSel: 'a.text-ellipsis',
        cardTitleSel: 'a.text-ellipsis',
        cardThumbSel: '.cover',
        titleSel: 'meta[property="og:title"]',
        coverSel: 'meta[property="og:image"]',
        chapterSel: 'a[href*="/chapter-"]',
        cleanTitle: (t) => t.replaceFirst(RegExp(r'\s*[-|–].*$'), ''),
        imagesOf: (d, u) => imagesFrom(d, u, 'img.lazy', ['data-src', 'src']),
      ),
      ChapterSource(
        id: 'en.asuratoonsinfo',
        name: 'Asuratoons (unoriginal)',
        baseUrl: 'https://www.asuratoons.info',
        popularUrl: (b, p) => '$b/',
        searchUrl: (b, p, q) => null,
        localSearch: true,
        cardSel: 'a.block.h-full.flex',
        cardTitleSel: 'img',
        titleSel: 'h1',
        coverSel: 'meta[property="og:image"]',
        chapterSel: 'a[data-testid="chapter-card"]',
        chapterNameSel: null,
        imagesOf: (d, u) => imagesFrom(d, u, 'img[data-testid="chapter-image"]', ['src']),
      ),
      ChapterSource(
        id: 'en.desirescans',
        name: 'DesireScans',
        baseUrl: 'https://desirescans.com',
        popularUrl: (b, p) => '$b/series?page=$p',
        searchUrl: (b, p, q) => '$b/series?q=${Uri.encodeQueryComponent(q)}&page=$p',
        cardSel: 'a[href^="/series/comic/"][href*="ref=browse"]',
        cardTitleSel: 'img',
        nextSel: 'a[href*="page="][rel=next], a[aria-label*="ext"][href*="page="]',
        titleSel: 'h1',
        coverSel: 'meta[property="og:image"]',
        chapterSel: 'a[href*="/chapter/"]',
        imagesOf: (d, u) {
          final html = d.outerHtml.replaceAll(r'\"', '"').replaceAll(r'\/', '/');
          return {
            for (final m in RegExp(r'https://media\.desirescans\.com/series/[^"\s\\]+/p-[^"\s\\]+\.webp').allMatches(html))
              m[0]!,
          }.toList();
        },
      ),
      ChapterSource(
        id: 'en.pornhwadbreader',
        name: 'PornhwaDB Reader',
        baseUrl: 'https://pornhwareader.com',
        popularUrl: (b, p) => '$b/browse?page=$p',
        searchUrl: (b, p, q) => '$b/browse?q=${Uri.encodeQueryComponent(q)}&page=$p',
        cardSel: 'li[data-pornhwa-id]',
        cardLinkSel: 'h3 a',
        cardTitleSel: 'h3 a',
        nextSel: 'a[href*="page="][rel=next], a[aria-label*="ext"]',
        titleSel: 'h1#series-title, h1',
        coverSel: 'meta[property="og:image"]',
        chapterSel: r'a[href*="/chapter-"]',
        imagesOf: (d, u) {
          final html = d.outerHtml.replaceAll(r'\"', '"').replaceAll(r'\/', '/');
          final pages = <int, String>{};
          for (final m in RegExp(r'https://media\.pornhwareader\.com/pages/[0-9a-f-]+/(\d+)-[0-9a-f]{40,}\.webp')
              .allMatches(html)) {
            pages[int.parse(m[1]!)] ??= m[0]!;
          }
          return [for (final k in pages.keys.toList()..sort()) pages[k]!];
        },
      ),
      ChapterSource(
        id: 'en.hentai18',
        name: 'Hentai18',
        baseUrl: 'https://hentai18.net',
        popularUrl: (b, p) => '$b/?page=$p',
        searchUrl: (b, p, q) => '$b/search?q=${Uri.encodeQueryComponent(q)}&page=$p',
        cardSel: r'a[href^="/read-hentai/"]:not([href*="-chapter-"])',
        thumbFromUrl: (u) => 'https://media.hentai18.net/images/thumbs/${Uri.parse(u).pathSegments.last}.jpg',
        titleSel: 'h1',
        coverSel: 'meta[property="og:image"]',
        chapterSel: r'a[href*="-chapter-"][href*="-ch"]',
        imagesOf: numberedChapterImages,
      ),
      ChapterSource(
        id: 'en.manhwalike',
        name: 'Manhwalike',
        baseUrl: 'https://manhwalike.com',
        popularUrl: (b, p) => p > 1 ? '$b/?page=$p' : '$b/',
        searchUrl: (b, p, q) => '$b/?s=${Uri.encodeQueryComponent(q)}${p > 1 ? '&page=$p' : ''}',
        cardSel: 'div.item',
        cardLinkSel: 'h3.title a',
        cardTitleSel: 'h3.title a',
        titleSel: 'h1',
        coverSel: 'meta[property="og:image"]',
        tagSel: 'a.property-item[href^="/manga-genre-"]',
        chapterSel: r'a[href*="-chapter-"][href*="-ch"]',
        imagesOf: numberedChapterImages,
      ),
      ChapterSource(
        id: 'en.hentaifull',
        name: 'HentaiFull',
        baseUrl: 'https://hentaifull.net',
        popularUrl: (b, p) => p > 1 ? '$b/?page=$p' : '$b/',
        searchUrl: (b, p, q) => '$b/search?q=${Uri.encodeQueryComponent(q)}${p > 1 ? '&page=$p' : ''}',
        cardSel: 'div.item',
        cardLinkSel: '.hentai-cover a, a[href^="/hentai/"]',
        cardTitleSel: 'img',
        cardThumbSel: 'img',
        titleSel: 'h1',
        coverSel: 'meta[property="og:image"]',
        tagSel: 'a.tag, a.tag-link',
        chapterSel: 'li.citem',
        imagesOf: numberedChapterImages,
      ),
    ];
