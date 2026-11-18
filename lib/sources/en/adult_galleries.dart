// Sumber galeri dewasa (satu entri = satu bab), port Dart dari extension
// keiyoushi/extensions-source (Apache-2.0): src/en/*.

import '../source.dart';
import 'gallery_source.dart';

String _pg(String base, String path, int page) => page > 1 ? '$base/${path}page/$page/' : '$base/$path';

List<MangaSource> adultGalleries() => [
      GallerySource(
        id: 'en.xyzcomics',
        name: 'XYZ Comics',
        baseUrl: 'https://xyzcomics.com',
        popularUrl: (b, p) => _pg(b, 'allsexkomix/', p),
        searchUrl: (b, p, q) => '$b/${p > 1 ? 'page/$p/' : ''}?s=${Uri.encodeQueryComponent(q)}',
        cardSel: 'article.post',
        cardLinkSel: 'figure.post-image a',
        cardTitleSel: 'h2.post-title a',
        cardThumbSel: 'figure.post-image img.wp-post-image',
        nextSel: 'a.nextp, .pagenav a.next, a.page-numbers.next, a[rel=next]',
        titleSel: 'h1.post-title',
        tagSel: 'a.post-tag-button',
        imagesOf: (d, u) => imagesFrom(d, u, '.pswp-gallery .pswp-gallery__item a[href]', ['href']),
      ),
      GallerySource(
        id: 'en.ilikecomix',
        name: 'ILikeComix',
        baseUrl: 'https://ilikecomix.com',
        popularUrl: (b, p) => _pg(b, 'king-porn-comics/', p),
        searchUrl: (b, p, q) => '$b/${p > 1 ? 'page/$p/' : ''}?s=${Uri.encodeQueryComponent(q)}',
        cardSel: 'article',
        cardLinkSel: 'h2.post-title a',
        cardThumbSel: 'figure.post-image img',
        nextSel: 'a.nextp',
        titleSel: 'h1.post-title',
        tagSel: "a[rel='tag']",
        imagesOf: (d, u) {
          final fig = imagesFrom(d, u, 'figure[data-pswp-src]', ['data-pswp-src']);
          final img = imagesFrom(
              d, u, '.entry-content img', ['data-pswp-src', 'data-src', 'data-lazy-src', 'src']);
          return [...fig, ...img]
              .where((e) => e.contains('/comic/') && !RegExp(r'-\d+x\d+\.').hasMatch(e))
              .toSet()
              .toList();
        },
      ),
      GallerySource(
        id: 'en.cutiecomics',
        name: 'Cutie Comics',
        baseUrl: 'https://cutiecomics.com',
        popularUrl: (b, p) => '$b/page/$p',
        searchUrl: (b, p, q) => q.length < 4
            ? null
            : '$b/index.php?do=search&subaction=search&story=${Uri.encodeQueryComponent(q)}&search_start=$p',
        cardSel: '#dle-content > div.w25',
        cardLinkSel: 'strong.field-content > a',
        cardTitleSel: 'strong.field-content > a',
        cardThumbSel: 'a > img',
        nextSel: '.navigation > a > i.fa-angle-right',
        titleSel: 'h1#page-title',
        tagSel: 'h3.field-label ~ span',
        imagesOf: (d, u) => imagesFrom(d, u, 'div.galery > img', ['src']),
      ),
      GallerySource(
        id: 'en.porncomix',
        name: 'PornComix',
        baseUrl: 'https://bestporncomix.com',
        popularUrl: (b, p) => _pg(b, 'allmultking/', p),
        searchUrl: (b, p, q) => '$b/${p > 1 ? 'page/$p/' : ''}?s=${Uri.encodeQueryComponent(q)}',
        cardSel: '#loops-wrapper article',
        cardLinkSel: 'h2.post-title a',
        cardTitleSel: 'h2.post-title a',
        nextSel: 'a.nextp',
        titleSel: 'h1.post-title, h1.entry-title',
        tagSel: 'a[rel=tag], .post-tags a, .tags-links a',
        imagesOf: (d, u) {
          final pswp = imagesFrom(d, u, '.pswp-gallery__item', ['data-pswp-src']);
          if (pswp.isNotEmpty) return pswp;
          return imagesFrom(d, u, 'div.entry-content img', ['data-pagespeed-lazy-src', 'data-src', 'src']);
        },
      ),
      GallerySource(
        id: 'en.eggporncomics',
        name: 'Eggporncomics',
        baseUrl: 'https://eggporncomics.com',
        popularUrl: (b, p) => '$b/category/1/anime-comics?page=$p',
        latestUrl: (b, p) => '$b/latest-comics?page=$p',
        searchUrl: (b, p, q) => '$b/search/${q.replaceAll(RegExp(r"[\s']"), '-')}?page=$p',
        cardSel: 'div.preview',
        cardLinkSel: 'a',
        cardTitleSel: 'div.name',
        nextSel: 'ul.ne-pe li.next:not(.disabled)',
        titleSel: 'h1',
        tagSel: 'div.links ul a',
        imagesOf: (d, u) => [
          for (final i in imagesFrom(d, u, 'div.grid div.image img', ['src'])) i.replaceFirst('thumb300_', ''),
        ],
      ),
    ];
