import 'id/komiku.dart';
import 'source.dart';
import 'templates/mangathemesia.dart';

/// Daftar extension bawaan. Tambah sumber baru di sini.
///
/// Domain situs sering pindah; bila sumber gagal terhubung, cek `baseUrl`
/// terbaru di keiyoushi/extensions-source (`src/id/<nama>/build.gradle.kts`).
List<MangaSource> builtInSources() => [
      KomikuSource(),
      MangaThemesiaSource(
        id: 'id.komikstation',
        name: 'Komik Station',
        baseUrl: 'https://komikstation.org',
        requestsPerSecond: 4,
      ),
      // Diuji 12 Nov 2026 & dikeluarkan: kuromanga.id (Cloudflare 403),
      // m1.manhwalist.my.id (situs "under construction").
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
