// Sumber galeri dewasa (satu entri = satu bab), port Dart dari extension
// keiyoushi/extensions-source (Apache-2.0): src/en/*.

import '../source.dart';
import 'gallery_source.dart';

String _wpSearch(String b, int p, String q) =>
    '$b/${p > 1 ? 'page/$p/' : ''}?s=${Uri.encodeQueryComponent(q)}';

List<MangaSource> adultGalleriesB() => [
      GallerySource(
        id: 'en.kingcomix',
        name: 'KingComiX',
        baseUrl: 'https://kingcomix.com',
        popularUrl: (b, p) => p > 1 ? '$b/page/$p/' : '$b/',
        searchUrl: _wpSearch,
        cardSel: 'div.entry, article.thumb-block',
        cardLinkSel: 'h2.information a, a[title]',
        nextSel: 'a.next.page-numbers, a.nextpostslink, a[rel=next]',
        titleSel: 'h1.singleTitle-h1',
        tagSel: "a[rel='tag']",
        imagesOf: (d, u) => imagesFrom(d, u, '.entry-content .wp-block-gallery img', ['data-src', 'src']),
      ),
      GallerySource(
        id: 'en.xlecx',
        name: 'XlecX',
        baseUrl: 'https://xlecx.one',
        popularUrl: (b, p) => p > 1 ? '$b/page/$p/' : '$b/',
        searchUrl: (b, p, q) =>
            '$b/index.php?do=search&subaction=search&story=${Uri.encodeQueryComponent(q)}&search_start=$p',
        cardSel: 'a.thumb',
        cardTitleSel: 'h3.thumb__title',
        cardThumbSel: 'div.thumb__img img',
        nextSel: '.pagination__pages a:last-child, .pagination a.next, a[rel=next]',
        titleSel: 'h1',
        tagSel: '.tags-list a',
        imagesOf: (d, u) {
          final full = imagesFrom(d, u, '#content-2 img', ['data-src', 'src']);
          final all = full.isNotEmpty ? full : imagesFrom(d, u, '.page__text img', ['data-src', 'src']);
          return {
            for (final e in all)
              if (e.contains('/uploads/')) e.replaceFirst('/thumbs/', '/'),
          }.toList();
        },
      ),
      GallerySource(
        id: 'en.myhentaigallery',
        name: 'MyHentaiGallery',
        baseUrl: 'https://myhentaigallery.com',
        popularUrl: (b, p) => '$b/gpage/$p',
        searchUrl: (b, p, q) => '$b/search?q=${Uri.encodeQueryComponent(q)}&page=$p',
        cardSel: 'li.item',
        cardLinkSel: 'a[href]',
        cardTitleSel: '.comic-info, .tag-name',
        cardThumbSel: '.comic-thumb img',
        nextSel: "a[rel=next], .pagination a.next, a:contains('Next')",
        titleSel: 'h1',
        tagSel: '.comic-tags a, a[href^="/tag"]',
        imagesOf: (d, u) => [
          for (final t in imagesFrom(d, u, '.comic-thumb img', ['src']))
            if (t.contains('/thumbnail/')) t.replaceFirst('/thumbnail/', '/original/'),
        ],
      ),
      GallerySource(
        id: 'en.hentaiforce',
        name: 'HentaiForce',
        baseUrl: 'https://hentaiforce.net',
        popularUrl: (b, p) => p > 1 ? '$b/page/$p' : '$b/',
        searchUrl: (b, p, q) => '$b/search?q=${Uri.encodeQueryComponent(q)}&page=$p',
        cardSel: 'div.gallery-wrapper',
        cardLinkSel: 'a.gallery-thumb',
        cardTitleSel: '.gallery-name a',
        cardThumbSel: 'a.gallery-thumb img',
        nextSel: 'a[rel=next]',
        titleSel: 'h1',
        tagSel: '.tag-container a.tag-btn',
        imagesOf: (d, u) => [
          for (final t in imagesFrom(d, u, 'img[data-src*="/img/"]', ['data-src']))
            if (RegExp(r'-\d+t\.\w+$').hasMatch(t)) t.replaceFirstMapped(RegExp(r'(\d+)t(\.\w+)$'), (m) => '${m[1]}${m[2]}'),
        ],
      ),
      GallerySource(
        id: 'en.onlythebesthentai',
        name: 'Only The Best Hentai',
        baseUrl: 'https://onlythebesthentai.com',
        popularUrl: (b, p) => p > 1 ? '$b/page/$p/' : '$b/',
        searchUrl: _wpSearch,
        cardSel: 'article.article-content',
        cardLinkSel: 'a[rel=bookmark]',
        cardTitleSel: 'a[rel=bookmark][style*="font-weight"]',
        nextSel: 'a.next.page-numbers, a[rel=next]',
        titleSel: 'h1.manga-title, h1',
        tagSel: "a[rel='tag']",
        imagesOf: (d, u) => imagesFrom(d, u, '.entry-content img', ['data-src', 'src'])
            .where((e) => e.contains('/uploads/') && !e.contains('cropped-'))
            .toSet()
            .toList(),
      ),
    ];
