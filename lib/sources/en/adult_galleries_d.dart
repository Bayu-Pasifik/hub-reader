// Sumber galeri dewasa (satu entri = satu bab), port Dart dari extension
// keiyoushi/extensions-source (Apache-2.0): src/en/*.

import '../html_utils.dart';
import '../source.dart';
import 'gallery_source.dart';

List<MangaSource> adultGalleriesD() => [
      GallerySource(
        id: 'en.hentaidad',
        name: 'HentaiDad',
        baseUrl: 'https://hentaidad.com',
        popularUrl: (b, p) => p > 1 ? '$b/images/$p' : '$b/images',
        latestUrl: (b, p) => p > 1 ? '$b/images/$p' : '$b/images',
        searchUrl: (b, p, q) => '$b/search${p > 1 ? '/$p' : ''}?q=${Uri.encodeQueryComponent(q)}',
        cardSel: '.archive-grid a.archive-card-link',
        cardTitleSel: '.archive-card-title',
        nextSel: 'a.pagination-direction[rel=next]',
        titleSel: 'header.post-header h1',
        tagSel: '.post-tags a',
        descSel: '.post-description > div',
        imagesOf: (d, u) => imagesFrom(d, u, '#premium-gallery a.post-gallery-item', ['href']),
      ),
      GallerySource(
        id: 'en.hentaipill',
        name: 'HentaiPill',
        baseUrl: 'https://hentaipill.com',
        popularUrl: (b, p) => p > 1 ? '$b/popular/$p' : '$b/popular',
        latestUrl: (b, p) => p > 1 ? '$b/language/english/$p' : '$b/language/english',
        searchUrl: (b, p, q) => '$b/search?q=${Uri.encodeQueryComponent(q)}&page=$p',
        cardSel: 'div.galleries-list > div.gallery-item',
        cardLinkSel: 'a[href*="/gallery/"]',
        cardTitleSel: 'span',
        cardThumbSel: 'img.lazy',
        nextSel: 'ul.pagination a[rel=next]',
        titleSel: 'div.reading-page-header h1',
        tagSel: '.table-row .table-value a',
        imagesOf: (d, u) => imagesFrom(d, u, 'div.reading-pages-content img.lazy', ['data-src', 'src']),
      ),
      // ADD
    ];
