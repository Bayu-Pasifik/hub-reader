# Sumber yang belum di-port / Sources not yet ported

Dibuat 2026-11-17 dari perbandingan `keiyoushi/extensions-source` (folder `src/en` dan `src/id`) dengan katalog Hub Reader (`assets/sources/catalog.json` + sumber Dart tulis tangan).
Generated 2026-11-17 by diffing `keiyoushi/extensions-source` (`src/en` and `src/id`) against the Hub Reader catalog (`assets/sources/catalog.json` + hand-written Dart sources).

| Bahasa / Language | Belum di-port / Not ported |
|---|---|
| Indonesia (id) | 14 (6 sudah di-port: Bacami, MG Komik, West Manga, Komik AV, Hentai Crot, Pix Hentai) |
| English (en) | 154 (64 sudah di-port dari kelompok Aman / 64 ported from the Safe group) |

> Catatan / Notes
> - ID: Pencocokan berdasarkan nama folder dan nama tampilan; beberapa situs bisa salah terdeteksi. Sumber multi-bahasa (`all`) tidak termasuk.
> - EN: Matching uses folder name and display name, so a few sites may be misdetected. Multi-language (`all`) sources are excluded.
> - ID: Hampir semua sumber di sini kustom (bukan template), jadi tiap situs butuh parser Dart sendiri. Banyak situs Inggris adalah webcomic satu-situs, situs resmi berbayar/login (Kodansha, VIZ, BookWalker, dll.), atau situs hentai.
> - EN: Nearly all of these are custom (non-template) sources, so each needs its own Dart parser. Many English entries are single-site webcomics, paid or login-gated official stores (Kodansha, VIZ, BookWalker, etc.), or hentai sites.

---

## 1. Indonesia (id) — 14 sumber / sources

#### Aman / Safe (6)

| # | Nama / Name | Situs / Site | Catatan / Note |
|---|---|---|---|
| 2 | Komiku.com | https://01.komiku.asia | Dicoba lalu dihapus: gambar diblokir tantangan Cloudflare. / Tried then removed: images blocked by Cloudflare challenge. |
| 4 | Softkomik | - | Tidak di-port: sesi API bertanda tangan + dekripsi CryptoJS. / Not ported: signed API sessions + CryptoJS decryption. |
| 5 | VoraToon | - | Dicoba lalu dihapus: gambar bab gagal diekstrak dari RSC. / Tried then removed: chapter images could not be extracted from RSC. |

#### Campuran / Mixed (8)

| # | Nama / Name | Situs / Site | Catatan / Note |
|---|---|---|---|
| 1 | CGBUM | https://cgbum.com | Tidak di-port: gambar bab dilindungi tantangan proof-of-work. / Not ported: chapter images gated by a proof-of-work challenge. |
| 2 | Comicaso | https://v3.comicaso.pro | Tidak di-port: API meminta tantangan verifikasi. / Not ported: API demands a verification challenge. |
| 3 | CosmicScans | https://04.cosmicscans.to | Tidak di-port: sesi gambar memakai Turnstile. / Not ported: image sessions require Turnstile. |
| 5 | KomikNesia | https://v2.komiknesiaku.com | Situs mati saat dicek (HTTP 521). / Site down when checked (HTTP 521). |
| 6 | Manhwa Indo | https://www.manhwaindo.my | Dicoba lalu dihapus: CDN gambar memblokir klien. / Tried then removed: image CDN blocks the client. |
| 7 | MikoRoku | https://mikoroku.com | Situs error saat dicek (HTTP 500). / Site erroring when checked (HTTP 500). |
| 8 | Pramramadhan | https://01.pramramadhan.my.id | Situs tidak terjangkau. / Site unreachable. |

#### Dewasa (NSFW) / Adult (NSFW) (6)

| # | Nama / Name | Situs / Site | Catatan / Note |
|---|---|---|---|
| 1 | Doujindesu | - | Tidak di-port: API memakai rahasia aplikasi + dekripsi XOR. / Not ported: API uses an app secret + XOR decryption. |
| 3 | KumoPoi | - | Dicoba lalu dihapus: halaman palsu (honeypot) untuk klien non-browser. / Tried then removed: honeypot pages for non-browser clients. |
| 5 | Ryukomik | https://ryukomik.my.id | Situs tidak terjangkau. / Site unreachable. |
| 6 | Story About Us | https://storyabout-us.com | Tidak di-port: bab berupa PDF yang dirender di perangkat. / Not ported: chapters are PDFs rendered on-device. |

---

## 2. English (en) — 154 sumber / sources

#### Aman / Safe (36 belum di-port / not yet ported; 64 sudah di-port / ported)

| # | Nama / Name | Situs / Site | Catatan / Note |
|---|---|---|---|
| 1 | Alpha Manga | https://www.alpha-manga.com | Gambar diacak lewat interseptor bitmap (descramble) dan situs membalas 202 ke klien non-browser. / Images are scrambled and unscrambled by a bitmap interceptor, and the site answers 202 to non-browser clients. |
| 2 | Bakkin Self-hosted | - | Sumber template tanpa situs tetap (template: bakkin). / Template-only source without a fixed site (template: bakkin). |
| 3 | BatCave | https://batcave.biz | Dilindungi Cloudflare (HTTP 403); tidak bisa diverifikasi tanpa WebView. / Cloudflare-protected (HTTP 403); cannot be verified without a WebView. |
| 4 | Character Design References | https://characterdesignreferences.com | Galeri Squarespace dengan koleksi bernomor, kursor halaman berstatus, dan banyak jenis bagian; belum di-port. / Squarespace galleries with numbered collections, a stateful page cursor, and several section kinds; not ported yet. |
| 5 | ComicHubFree | https://comichubfree.com | Dilindungi Cloudflare (HTTP 403); tidak bisa diverifikasi tanpa WebView. / Cloudflare-protected (HTTP 403); cannot be verified without a WebView. |
| 6 | Comivex | https://comivex.com | Situs tidak terjangkau / folder upstream tidak ditemukan. / Site unreachable / upstream folder not found. |
| 7 | Digital Comic Museum | https://digitalcomicmuseum.com | Dilindungi Cloudflare (HTTP 403); tidak bisa diverifikasi tanpa WebView. / Cloudflare-protected (HTTP 403); cannot be verified without a WebView. |
| 8 | Gone with the Blastwave | https://www.blastwave-comic.com | Situs tidak terjangkau / folder upstream tidak ditemukan. / Site unreachable / upstream folder not found. |
| 9 | Hiveworks Comics | https://hiveworkscomics.com | Agregator ratusan webcomic di situs berbeda dengan penanganan khusus per situs; tidak ada satu parser yang cocok. / Aggregator of hundreds of webcomics on different sites with per-site special cases; no single parser fits. |
| 10 | J-Novel | https://j-novel.club | Dilindungi Cloudflare (HTTP 403); tidak bisa diverifikasi tanpa WebView. / Cloudflare-protected (HTTP 403); cannot be verified without a WebView. |
| 11 | K Manga | https://kmanga.kodansha.com | Toko resmi berbayar/login; tidak ada konten gratis tanpa akun. / Paid/login-gated official store; no free content without an account. |
| 12 | Leslie&Victims | https://leslie-victims.pages.dev | Daftar halaman bab ditemukan lewat HEAD per gambar; belum di-port. / Chapter pages are discovered by per-image HEAD probing; not ported yet. |
| 13 | Luminare Translations | https://luminaretranslations.com | Dilindungi Cloudflare (HTTP 403); tidak bisa diverifikasi tanpa WebView. / Cloudflare-protected (HTTP 403); cannot be verified without a WebView. |
| 14 | Madokami | https://manga.madokami.al | Butuh login (HTTP 401). / Requires login (HTTP 401). |
| 15 | Manga Demon | https://demonicscans.org | Dilindungi Cloudflare (HTTP 403); tidak bisa diverifikasi tanpa WebView. / Cloudflare-protected (HTTP 403); cannot be verified without a WebView. |
| 16 | MangaBolt | https://mangabolt.com | API rute `manga-list` sudah dihapus situs (404). / API route `manga-list` was removed by the site (404). |
| 17 | MangaCloud | https://mangacloud.org | Dilindungi Cloudflare (HTTP 403); tidak bisa diverifikasi tanpa WebView. / Cloudflare-protected (HTTP 403); cannot be verified without a WebView. |
| 18 | Mangamo | https://www.mangamo.com | Toko resmi berbayar/login; tidak ada konten gratis tanpa akun. / Paid/login-gated official store; no free content without an account. |
| 19 | Megatokyo | https://megatokyo.com | Situs memakai sertifikat SSL rusak dan membalas 403 ke klien non-browser. / Site uses a broken SSL certificate and answers 403 to non-browser clients. |
| 20 | Monochrome Custom | - | Sumber template tanpa situs tetap (template: monochrome). / Template-only source without a fixed site (template: monochrome). |
| 21 | Nux Scans | https://nuxscans-comics.blogspot.com | Struktur situs berubah sehingga parser upstream tidak lagi cocok (penanda daftar bab tidak ditemukan). / The site structure changed so the upstream parser no longer matches (chapter-list markers not found). |
| 22 | One Punch Man Online | https://w21.1punchman.com | Halaman bab hanya berisi iklan untuk klien non-browser (tanpa gambar). / Chapter pages only serve ads to non-browser clients (no images). |
| 23 | OriYami | https://oriyami.com | Dilindungi Cloudflare (HTTP 403); tidak bisa diverifikasi tanpa WebView. / Cloudflare-protected (HTTP 403); cannot be verified without a WebView. |
| 24 | Philia Scans | https://philiascans.org | Dilindungi Cloudflare (HTTP 403); tidak bisa diverifikasi tanpa WebView. / Cloudflare-protected (HTTP 403); cannot be verified without a WebView. |
| 25 | Read Comics Online | https://readcomicsonline.ru | Dilindungi Cloudflare (HTTP 403); tidak bisa diverifikasi tanpa WebView. / Cloudflare-protected (HTTP 403); cannot be verified without a WebView. |
| 26 | Renascans | https://renascans.net | Dilindungi Cloudflare (HTTP 403); tidak bisa diverifikasi tanpa WebView. / Cloudflare-protected (HTTP 403); cannot be verified without a WebView. |
| 27 | The Far Side | https://www.thefarside.com | Keterangan kartun digambar ke dalam gambar lewat interseptor bitmap; belum ada padanannya. / Captions are drawn into the image by a bitmap interceptor; no equivalent yet. |
| 28 | The Interpretation of Shadows | https://tioscomic.com | Situs menjalankan pemeriksaan bot ("One moment, please") yang butuh browser. / Site runs a bot check ("One moment, please") that needs a browser. |
| 29 | The Wandering Inn | https://webcomic.wanderinginn.com | Dilindungi Cloudflare (HTTP 403); tidak bisa diverifikasi tanpa WebView. / Cloudflare-protected (HTTP 403); cannot be verified without a WebView. |
| 30 | Vision Haze | https://www.visionhaze.com | Dilindungi Cloudflare (HTTP 403); tidak bisa diverifikasi tanpa WebView. / Cloudflare-protected (HTTP 403); cannot be verified without a WebView. |
| 31 | VIZ | https://www.viz.com | Toko resmi berbayar/login; tidak ada konten gratis tanpa akun. / Paid/login-gated official store; no free content without an account. |
| 32 | Voyce.Me | https://www.voyce.me | Toko resmi berbayar/login; tidak ada konten gratis tanpa akun. / Paid/login-gated official store; no free content without an account. |
| 33 | War For Rayuba | https://xrabohrok.github.io/WarMap/#/ | Bab diambil lewat API Cubari/GitHub; belum di-port. / Chapters come via the Cubari/GitHub API; not ported yet. |
| 34 | Webdex Scans | https://webdexscans.com | Dilindungi Cloudflare (HTTP 403); tidak bisa diverifikasi tanpa WebView. / Cloudflare-protected (HTTP 403); cannot be verified without a WebView. |
| 35 | WebNovel | https://www.webnovel.com | Dilindungi Cloudflare (HTTP 403); tidak bisa diverifikasi tanpa WebView. / Cloudflare-protected (HTTP 403); cannot be verified without a WebView. |
| 36 | ZipComic | https://www.zipcomic.com | Dilindungi Cloudflare (HTTP 403); tidak bisa diverifikasi tanpa WebView. / Cloudflare-protected (HTTP 403); cannot be verified without a WebView. |

#### Campuran / Mixed (73)

| # | Nama / Name | Situs / Site | Catatan / Note |
|---|---|---|---|
| 1 | AllManga | https://mkissa.to |  |
| 2 | Atsumaru | https://atsu.moe |  |
| 3 | Bakaloli | https://bakaloli.eu |  |
| 4 | Bbato | - |  |
| 5 | BookWalker | https://bookwalker.com |  |
| 6 | Chikari | https://chikari.moe |  |
| 7 | Coffee Manga (Unoriginal) | https://coffeemanga.net | template: imperiomanhwa |
| 8 | ComicK Fanmade | https://comickfan.com |  |
| 9 | ComicLand | https://comicland.org |  |
| 10 | Comix | - |  |
| 11 | Coolmic | https://coolmic.me |  |
| 12 | Dashtoon | https://dashtoon.com |  |
| 13 | Dream-Manga | https://dream-manga.com |  |
| 14 | Dynasty Scans | https://dynasty-scans.com |  |
| 15 | EbookRenta | https://www.ebookrenta.com |  |
| 16 | emaqi | https://emaqi.com |  |
| 17 | Extra Fabulous Comics | https://www.extrafabulouscomics.com |  |
| 18 | Hyakuro Translations | https://hyakuro.net |  |
| 19 | InfinityScans | https://infinityscans.org |  |
| 20 | Inkora | https://inkora.spacely.tech |  |
| 21 | INKR | https://comics.inkr.com |  |
| 22 | KaliScans.org (unoriginal) | https://kaliscans.org |  |
| 23 | Kappa Beast | https://kappabeast.com |  |
| 24 | Kemono Café | https://kemono.cafe |  |
| 25 | Kodansha | https://kodansha.us |  |
| 26 | Komix | https://komix.to |  |
| 27 | KuraManga | https://kuramanga.com |  |
| 28 | Lazy Monki Scans | https://lazy-monki-scans.netlify.app |  |
| 29 | LustToon | https://lustoon.com |  |
| 30 | Manga MTL | https://mtlmanga.org | template: manhuarm |
| 31 | Manga-Bay | https://manga-bay.biz |  |
| 32 | Manga.uno | https://manga.uno |  |
| 33 | MangaDE | https://mangade.io |  |
| 34 | MangaFox | https://fanfox.net |  |
| 35 | MangaGeko | https://www.mgeko.cc |  |
| 36 | Mangago | https://www.mangago.me |  |
| 37 | Mangahere | https://www.mangahere.cc |  |
| 38 | MangaHome | https://www.mangahome.com |  |
| 39 | MangaLix | https://mangalix.com |  |
| 40 | MangaMelon | https://mangamelon.com |  |
| 41 | MangaPlaza | https://mangaplaza.com |  |
| 42 | Mangastash | https://mangastash.org |  |
| 43 | Mangatown | https://www.mangatown.com |  |
| 44 | ManhuaTop | https://manhuatop.org |  |
| 45 | ManhwaRead | - |  |
| 46 | ManhwaZ | https://manhwaz.cc |  |
| 47 | ManhwaZone | https://manhwazone.com |  |
| 48 | MyMangaList | https://www5.mymangalist.org |  |
| 49 | New Manhwa | https://saymanhwa.com |  |
| 50 | NexComic | https://nexcomic.com |  |
| 51 | OceComic | https://ocecomic.com |  |
| 52 | Omoi | https://www.omoi.com |  |
| 53 | Oppai Stream | https://read.oppai.stream |  |
| 54 | ReiManga | https://reimanga.net |  |
| 55 | SACACHISPA | https://sacachispa.site |  |
| 56 | ScansGG | https://scans.gg |  |
| 57 | Schale Scans | https://www.schalescans.com |  |
| 58 | SilentQuill | https://silentquill.net |  |
| 59 | StreameX (unoriginal) | https://streamex.hn |  |
| 60 | Tapas | https://tapas.io |  |
| 61 | Team Shadowi | https://www.team-shadowi.com |  |
| 62 | The Duck Webcomics | https://www.theduckwebcomics.com |  |
| 63 | Tinyview | https://tinyview.com |  |
| 64 | TodayManga | https://todaymanga.com |  |
| 65 | Toon Hub | https://toon-hub.com |  |
| 66 | Toonkotsu | https://toonkotsu.com |  |
| 67 | Toonz/Toonx | https://toonz.to |  |
| 68 | VyvyManga | - |  |
| 69 | Webnex | https://webnex.cc |  |
| 70 | WebtoonClub | https://webtoonclub.com |  |
| 71 | WebtoonLib | https://webtoonlib.to |  |
| 72 | XoManga | https://www.xomanga.site |  |
| 73 | Yurivan | https://www.yurivan.com |  |

#### Dewasa (NSFW) / Adult (NSFW) (46 tersisa dari 79; 33 sudah di-port: ManhwaX, Manhwalike, HentaiFull, DesireScans, PornhwaDB Reader, Hentai18, Yiff Comics, Doujins, Milftoon, Webtoon Hentai, 8Muses.xxx, Revival Scans, Asuratoons (unoriginal), EAHentai, HentaiKisu, Manhwa18Dash, Hentara, Manhwa210, Multporn, Oh Joy Sex Toy, Rule34Comic, KingComiX, XlecX, HentaiForce, Only The Best Hentai, Vixen Logic, Oglaf, I Roved Out, Mahouirexnohentaikarte, XYZ Comics, ILikeComix, Cutie Comics, PornComix, Eggporncomics. XYZ Comics dan PornComix di balik Cloudflare, belum terverifikasi)

| # | Nama / Name | Situs / Site | Catatan / Note |
|---|---|---|---|
| 1 | 8Muses | https://comics.8muses.com | template: eromuse |
| 4 | Babes Rater | https://babesrater.com |  |
| 5 | BabeSource | https://babesource.com |  |
| 6 | buttsmithy | https://incase.buttsmithy.com |  |
| 9 | Doujin.io - J18 | https://doujin.io |  |
| 13 | Erofus | https://www.erofus.com | template: eromuse |
| 14 | Fairies vs Tentacles | https://eldrikdgt.com |  |
| 15 | Futapo | https://futapo.com |  |
| 16 | Gensura | https://gensura.net |  |
| 17 | GirlsTop | https://en.girlstop.info |  |
| 18 | HD Porn Comics | https://hdporncomics.com |  |
| 19 | Hentai.yoga | https://hentai.yoga |  |
| 21 | HentaiDad | https://hentaidad.com |  |
| 22 | HentaiFC | https://hentaifc.com |  |
| 25 | HentaiHere | https://hentaihere.com |  |
| 27 | HentaiKun | https://hentaikun.com |  |
| 28 | HentaiNexus | https://hentainexus.com |  |
| 29 | HentaiPill | https://hentaipill.com |  |
| 30 | HentaiRead | https://hentairead.com |  |
| 31 | HentaiRead.io | https://hentairead.io | Server Cloudflare menolak klien aplikasi (403) walau curl lolos; dilewati. / Cloudflare answers 403 to the app client although curl passes; skipped. |
| 32 | HentaiSco | https://hentaisco.cc |  |
| 33 | HentaiTnT | https://hentaitnt.net |  |
| 35 | HotComics | https://hotcomics.io |  |
| 39 | Kotokotek | https://kotokotek.wixsite.com |  |
| 40 | LGBToon | https://lgbtoon.com | Daftar dan bab terbaca, tetapi CDN gambar (Cloudflare) menolak klien aplikasi dengan 403; dilewati. / Lists and chapters parse, but the image CDN (Cloudflare) answers 403 to the app client; skipped. |
| 42 | Manhwa18 | https://manhwa18.com |  |
| 45 | ManhwaH | https://manhwah.com | Daftar dan bab terbaca, tetapi CDN gambar (Cloudflare) menolak klien aplikasi dengan 403; dilewati. / Lists and chapters parse, but the image CDN (Cloudflare) answers 403 to the app client; skipped. |
| 48 | Mehgazone | https://mehgazone.com |  |
| 51 | MyAdultComics | https://myadultcomics.com |  |
| 52 | MyHentaiComics | https://myhentaicomics.com |  |
| 53 | MyHentaiGallery | https://myhentaigallery.com | Dicoba lalu dihapus: klien app ditolak 403 (Cloudflare) walau curl lolos. / Tried then removed: app client gets 403 (Cloudflare) although curl passes. |
| 54 | Myth Toons | https://mythtoons.org |  |
| 55 | NineHentai | https://9hentai.so |  |
| 56 | Nortverse | https://nortverse.com |  |
| 60 | Paradise Scans | https://paradisescans.com |  |
| 62 | Pornhwa.me | https://pornhwa.me |  |
| 63 | Pornhwa18 | https://pornhwa18.com |  |
| 67 | SpyFakku | - |  |
| 68 | Sunshine Butterfly Scans | https://wings.sbs |  |
| 69 | Tailspace | https://tailspace.com |  |
| 70 | Temple Scan | https://templetoons.com | Konten dimuat lewat skrip loader yang diobfuskasi (`/api/kaneda/boot`); dilewati. / Content is loaded via an obfuscated loader script; skipped. |
| 71 | The Blank | https://theblank.net | template: pam |
| 72 | ToonHey | https://toonhey.com |  |
| 73 | Transfusions | https://transfusionscomic.com |  |
| 78 | YaoiHot | https://yaoihot.com |  |
