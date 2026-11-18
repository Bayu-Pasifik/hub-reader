// Sumber galeri dewasa (satu entri = satu bab), port Dart dari extension
// keiyoushi/extensions-source (Apache-2.0): src/en/*.

import '../source.dart';
import 'gallery_source.dart';

List<MangaSource> adultGalleriesC() => [
      GallerySource(
        id: 'en.doujins',
        name: 'Doujins',
        baseUrl: 'https://doujins.com',
        popularUrl: (b, p) => p > 1 ? '$b/?page=$p' : '$b/',
        searchUrl: (b, p, q) => '$b/searches?words=${Uri.encodeQueryComponent(q)}${p > 1 ? '&page=$p' : ''}',
        cardSel: 'div.thumbnail-doujin',
        cardLinkSel: 'a[href]',
        cardTitleSel: '.title .text',
        nextSel: 'a[rel=next], .pagination a.next, li.next a',
        titleSel: 'title',
        tagSel: 'a[href*="/tags/"]',
        imagesOf: (d, u) => imagesFrom(d, u, 'img.swiper-lazy', ['data-src', 'src']),
      ),
      // ADD
    ];
