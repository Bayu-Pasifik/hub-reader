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
      GallerySource(
        id: 'en.ohjoysextoy',
        name: 'Oh Joy Sex Toy',
        baseUrl: 'https://www.ohjoysextoy.com',
        popularUrl: (b, p) => '$b/category/comic/${p > 1 ? 'page/$p/' : ''}',
        searchUrl: _wpSearch,
        cardSel: 'div.comicthumbwrap, .post-text',
        cardLinkSel: 'h2.post-title a, a[title]',
        nextSel: 'a[href*="category/comic/page/"]',
        titleSel: 'h2.post-title',
        tagSel: '.post-tags a',
        imagesOf: (d, u) => imagesFrom(d, u, '#comic .comicpane img', ['src']),
      ),
      GallerySource(
        id: 'en.rule34comic',
        name: 'Rule34Comic',
        baseUrl: 'https://rule34comic.party',
        popularUrl: (b, p) => p > 1 ? '$b/comic/$p/' : '$b/',
        searchUrl: (b, p, q) => p > 1 ? null : '$b/search/${Uri.encodeComponent(q)}/',
        cardSel: 'div.item.thumb',
        cardLinkSel: 'a.th',
        cardTitleSel: '.thumb_title',
        cardThumbSel: 'img',
        nextSel: 'div.item.pager.next a',
        titleSel: 'h1.album-hero__title',
        tagSel: '.album-hero__meta a',
        imagesOf: (d, u) => imagesFrom(d, u, '.album-holder .images img[data-original]', ['data-original']),
      ),
      GallerySource(
        id: 'en.multporn',
        name: 'Multporn',
        baseUrl: 'https://multporn.net',
        popularUrl: (b, p) =>
            '$b/new?type=3&language=1&sort_by=created&sort_order=DESC&page=${p - 1}',
        searchUrl: (b, p, q) => '$b/search?search_api_views_fulltext=${Uri.encodeQueryComponent(q)}&page=${p - 1}',
        cardSel: 'div.masonry-item',
        cardLinkSel: '.views-field-title a',
        cardTitleSel: '.views-field-title a',
        cardThumbSel: '.views-field-field-preview img',
        nextSel: 'li.pager-next a, a[title="Go to next page"]',
        titleSel: 'h1#page-title',
        tagSel: '.field-label-inline .links.inline a',
        // Galeri Juicebox: gambar ada di blok <noscript> (teks mentah), jadi diambil lewat regex.
        imagesOf: (d, u) => [
          for (final m in RegExp(r'src="([^"?]*/styles/juicebox_medium/public/[^"?]+)').allMatches(d.outerHtml))
            m[1]!.replaceFirst('/styles/juicebox_medium/public', ''),
        ],
      ),
    ];
