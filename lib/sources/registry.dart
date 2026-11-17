import 'catalog.dart';
import 'en/adult_galleries.dart';
import 'en/adult_webcomics.dart';
import 'en/webcomics_a.dart';
import 'en/webcomics_b.dart';
import 'en/webcomics_c.dart';
import 'en/webcomics_d.dart';
import 'en/webcomics_e.dart';
import 'en/webcomics_f.dart';
import 'en/webcomics_g.dart';
import 'en/webcomics_h.dart';
import 'en/asurascans.dart';
import 'en/flamecomics.dart';
import 'en/mangafreak.dart';
import 'en/mangakatana.dart';
import 'en/mangapill.dart';
import 'en/tcbscans.dart';
import 'en/weebcentral.dart';
import 'id/areakomik.dart';
import 'id/holotoon.dart';
import 'id/komiknextgonline.dart';
import 'id/komikrealm.dart';
import 'id/komiku.dart';
import 'id/wurmz.dart';
import 'id/ikiru.dart';
import 'id/bacakomikpics.dart';
import 'id/keikomik.dart';
import 'id/riztranslation.dart';
import 'id/omicaso.dart';
import 'id/bacami.dart';
import 'id/mgkomik.dart';
import 'id/komikav.dart';
import 'id/westmanga.dart';
import 'id/oceanwp.dart';
import 'id/mangalay.dart';
import 'id/mynimeku.dart';
import 'id/koronaxscan.dart';
import 'id/shinigami.dart';
import 'id/themanga.dart';
import 'local/local_source.dart';
import 'source.dart';

/// Sumber yang ditulis tangan (bukan template). Ditaruh di depan dan menang
/// bila ID-nya sama dengan entri katalog.
List<MangaSource> customSources() => [
      LocalSource(),
      KomikuSource(),
      ShinigamiSource(),
      KomikNextGOnlineSource(),
      KoronaxScanSource(),
      KomikRealmSource(),
      TheMangaSource(),
      HolotoonSource(),
      AreaKomikSource(),
      MyNimekuSource(),
      MangalaySource(),
      WurmzSource(),
      IkiruSource(),
      BacaKomikPicsSource(),
      KeikomikSource(),
      RiztranslationSource(),
      OmicasoSource(),
      BacamiSource(),
      MgKomikSource(),
      KomikAvSource(),
      WestMangaSource(),
      OceanWpSource(id: 'id.hentaicrot', name: 'Hentai Crot', baseUrl: 'https://hentaicrot.com'),
      OceanWpSource(id: 'id.pixhentai', name: 'Pix Hentai', baseUrl: 'https://pixhentai.com'),
      ...adultWebcomics(),
      ...adultGalleries(),
      ...webcomicsA(),
      ...webcomicsB(),
      ...webcomicsC(),
      ...webcomicsD(),
      ...webcomicsE(),
      ...webcomicsF(),
      ...webcomicsG(),
      ...webcomicsH(),
      MangaPillSource(),
      TcbScansSource(),
      MangaKatanaSource(),
      WeebCentralSource(),
      FlameComicsSource(),
      AsuraScansSource(),
      MangafreakSource(),
    ];

/// Semua sumber: sumber kustom + katalog template (Madara, MangaThemesia)
/// yang dihasilkan dari keiyoushi/extensions-source.
///
/// Domain situs sering pindah; ganti lewat ikon gir di tab Sumber, atau
/// perbarui katalog dengan `tool/generate_source_catalog.mjs`.
List<MangaSource> builtInSources({SourceCatalog catalog = SourceCatalog.empty}) {
  final sources = customSources();
  final ids = sources.map((s) => s.id).toSet();
  for (final entry in catalog.entries) {
    if (!ids.add(entry.id)) continue;
    final source = entry.create();
    if (source != null) sources.add(source);
  }
  return sources;
}

class SourceRegistry {
  SourceRegistry(List<MangaSource> sources, {this.experimentalIds = const {}})
      : sources = List.unmodifiable(sources),
        _byId = {for (final s in sources) s.id: s};

  final List<MangaSource> sources;
  final Map<String, MangaSource> _byId;

  /// Sumber katalog yang di Kotlin punya logika khusus; port template bisa
  /// kurang pas (ditandai "eksperimental" di UI).
  final Set<String> experimentalIds;

  MangaSource? byId(String id) => _byId[id];
}
