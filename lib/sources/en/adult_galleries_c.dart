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
      GallerySource(
        id: 'en.yiffcomics',
        name: 'Yiff Comics (unoriginal)',
        baseUrl: 'https://yiff-comics.com',
        popularUrl: (b, p) => p > 1 ? '$b/?page=$p' : '$b/',
        searchUrl: (b, p, q) => '$b/search?q=${Uri.encodeQueryComponent(q)}${p > 1 ? '&page=$p' : ''}',
        cardSel: r'a[href^="/yiff/"]',
        cardTitleSel: 'img',
        cardThumbSel: 'img',
        nextSel: 'a[rel=next]',
        titleSel: 'h1',
        tagSel: 'a[href^="/genre/"]',
        imagesOf: (d, u) {
          final html = d.outerHtml.replaceAll(r'\"', '"').replaceAll(r'\/', '/');
          // Hanya halaman pertama yang ada di HTML; sisanya berurutan p001..pNNN.
          final count = int.tryParse(RegExp(r'"numberOfPages":(\d+)').firstMatch(html)?[1] ?? '') ?? 0;
          final base = RegExp(r'(https://cdn\.yiff-comics\.com/posts/[^"\s\\]+?/)(?:cover|p\d+)').firstMatch(html)?[1];
          if (base == null || count == 0) return const [];
          return [for (var i = 1; i <= count; i++) '${base}p${i.toString().padLeft(3, '0')}.webp'];
        },
      ),
      // ADD
    ];
