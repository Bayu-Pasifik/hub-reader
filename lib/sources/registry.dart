import 'id/komiku.dart';
import 'id/shinigami.dart';
import 'source.dart';
import 'templates/mangathemesia.dart';

/// Daftar extension bawaan. Tambah sumber baru di sini.
///
/// Domain situs sering pindah; bila sumber gagal terhubung, cek `baseUrl`
/// terbaru di keiyoushi/extensions-source (`src/id/<nama>/build.gradle.kts`).
List<MangaSource> builtInSources() => [
      KomikuSource(),
      ShinigamiSource(),
      MangaThemesiaSource(
        id: 'id.apkomik',
        name: 'APKOMIK',
        baseUrl: 'https://01.apkomik.com',
      ),
      MangaThemesiaSource(
        id: 'id.komikstation',
        name: 'Komik Station',
        baseUrl: 'https://komikstation.org',
        requestsPerSecond: 4,
      ),
      // Dikeluarkan (12 Nov 2026): m1.manhwalist.my.id ("under construction"),
      // kuromanga.id (lolos Cloudflare lewat WebView, tapi server asal 522/down).
      MangaThemesiaSource(
        id: 'id.izanamiscans',
        name: 'Izanami Scans',
        baseUrl: 'https://izanamiscans.my.id',
        requestsPerSecond: 3,
      ),
      MangaThemesiaSource(
        id: 'id.ngomik',
        name: 'Ngomik',
        baseUrl: 'https://02.ngomik.cc',
      ),
      MangaThemesiaSource(
        id: 'id.noromax',
        name: 'Noromax',
        baseUrl: 'https://noromax02.my.id',
      ),
      MangaThemesiaSource(
        id: 'id.isekaikomik',
        name: 'IsekaiKomik',
        baseUrl: 'https://ch1.isekaikomik.site',
      ),
    ];

class SourceRegistry {
  SourceRegistry(List<MangaSource> sources)
      : sources = List.unmodifiable(sources),
        _byId = {for (final s in sources) s.id: s};

  final List<MangaSource> sources;
  final Map<String, MangaSource> _byId;

  MangaSource? byId(String id) => _byId[id];
}
