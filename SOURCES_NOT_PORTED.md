# Sumber yang belum di-port / Sources not yet ported

Dibuat 2026-11-17 dari perbandingan `keiyoushi/extensions-source` (folder `src/en` dan `src/id`) dengan katalog Hub Reader (`assets/sources/catalog.json` + sumber Dart tulis tangan).
Generated 2026-11-17 by diffing `keiyoushi/extensions-source` (`src/en` and `src/id`) against the Hub Reader catalog (`assets/sources/catalog.json` + hand-written Dart sources).

| Bahasa / Language | Belum di-port / Not ported |
|---|---|
| Indonesia (id) | 12 (8 sudah di-port: Bacami, MG Komik, West Manga, Komik AV, Hentai Crot, Pix Hentai, MikoRoku, Story About Us) |
| English (en) | 105 (2 lagi di-port 2026-11-18: Sacachispa, NexComic; 17 baru di-port 2026-11-18 / 17 more ported on 2026-11-18: MangaFox, Mangahere, Mangatown, MangaHome, WebtoonClub, Toon Hub, Komix, LustToon, MangaMelon, Tapas, The Duck Webcomics, Dynasty Scans, HentaiFC, HentaiNexus, Manhwa18, Paradise Scans, Pornhwa18) |

> Catatan / Notes
> - ID: Pencocokan berdasarkan nama folder dan nama tampilan; beberapa situs bisa salah terdeteksi. Sumber multi-bahasa (`all`) tidak termasuk.
> - EN: Matching uses folder name and display name, so a few sites may be misdetected. Multi-language (`all`) sources are excluded.
> - ID: Hampir semua sumber di sini kustom (bukan template), jadi tiap situs butuh parser Dart sendiri. Banyak situs Inggris adalah webcomic satu-situs, situs resmi berbayar/login (Kodansha, VIZ, BookWalker, dll.), atau situs hentai.
> - EN: Nearly all of these are custom (non-template) sources, so each needs its own Dart parser. Many English entries are single-site webcomics, paid or login-gated official stores (Kodansha, VIZ, BookWalker, etc.), or hentai sites.

---

## 1. Indonesia (id) — 12 sumber / sources

#### Aman / Safe (6)

| # | Nama / Name | Situs / Site | Catatan / Note |
|---|---|---|---|
| 1 | Komiku.com | https://01.komiku.asia | Dicek ulang 2026-11-18: API JSON dan sampul jalan, tetapi CDN gambar bab (cdnkomiku.xyz) membalas tantangan Cloudflare "Just a moment..." ke aplikasi (Dart maupun HTTP bawaan Android). / Re-checked: API and covers work, but the chapter image CDN serves a Cloudflare challenge to the app. |
| 2 | Softkomik | - | Tidak di-port: sesi API bertanda tangan + dekripsi, anti-scraper. / Not ported: signed API sessions + decryption (anti-scraper). |
| 3 | VoraToon | - | Tidak di-port: gambar bab tidak ada di respons RSC (dimuat lewat JS setelah verifikasi). / Not ported: chapter images are absent from RSC, loaded by JS after a verification step. |

#### Campuran / Mixed (6)

| # | Nama / Name | Situs / Site | Catatan / Note |
|---|---|---|---|
| 1 | CGBUM | https://cgbum.com | Tidak di-port: akses gambar bab dijaga tantangan proof-of-work anti-bot. / Not ported: chapter image access is gated by an anti-bot proof-of-work challenge. |
| 2 | Comicaso | https://v3.comicaso.pro | Tidak di-port: API meminta tantangan verifikasi anti-bot. / Not ported: API demands an anti-bot verification challenge. |
| 3 | CosmicScans | https://04.cosmicscans.to | Tidak di-port: sesi gambar memakai Turnstile. / Not ported: image sessions require Turnstile. |
| 4 | KomikNesia | https://v2.komiknesiaku.com | Situs mati saat dicek ulang (HTTP 521) dan API terenkripsi. / Backend still down (HTTP 521) and API is encrypted. |
| 5 | Manhwa Indo | https://www.manhwaindo.my | Dicek ulang 2026-11-18: daftar, detail, bab jalan, tetapi CDN gambar (upload.gmbr.pro) menolak klien aplikasi (Cloudflare). / Re-checked: listing and chapters work, image CDN refuses the app client (Cloudflare). |
| 6 | Pramramadhan | https://01.pramramadhan.my.id | Situs tidak terjangkau. / Site unreachable. |

#### Dewasa (NSFW) / Adult (NSFW) (3)

| # | Nama / Name | Situs / Site | Catatan / Note |
|---|---|---|---|
| 1 | Doujindesu | - | Tidak di-port: API sengaja diacak (rahasia aplikasi + XOR) untuk menolak scraper pihak ketiga. / Not ported: API is deliberately obfuscated to block third-party scrapers. |
| 2 | KumoPoi | - | Tidak di-port: situs memberi halaman palsu ke klien non-browser. / Not ported: site serves decoy pages to non-browser clients. |
| 3 | Ryukomik | https://ryukomik.my.id | Situs tidak terjangkau. / Site unreachable. |

---

## 2. English (en) — 105 sumber / sources

#### Aman / Safe (23 belum di-port / not yet ported)

| # | Nama / Name | Situs / Site | Catatan / Note |
|---|---|---|---|
| 1 | Alpha Manga | https://www.alpha-manga.com | Gambar diacak lewat interseptor bitmap (descramble) dan situs membalas 202 ke klien non-browser. / Images are scrambled and unscrambled by a bitmap interceptor, and the site answers 202 to non-browser clients. |
| 2 | Bakkin Self-hosted | - | Sumber template tanpa situs tetap (template: bakkin). / Template-only source without a fixed site (template: bakkin). |
| 3 | BatCave | https://batcave.biz | Dilindungi Cloudflare (HTTP 403); tidak bisa diverifikasi tanpa WebView. / Cloudflare-protected (HTTP 403); cannot be verified without a WebView. |
| 4 | Character Design References | https://characterdesignreferences.com | Galeri Squarespace dengan koleksi bernomor, kursor halaman berstatus, dan banyak jenis bagian; belum di-port. / Squarespace galleries with numbered collections, a stateful page cursor, and several section kinds; not ported yet. |
| 5 | Digital Comic Museum | https://digitalcomicmuseum.com | Dilindungi Cloudflare (HTTP 403); tidak bisa diverifikasi tanpa WebView. / Cloudflare-protected (HTTP 403); cannot be verified without a WebView. |
| 6 | Gone with the Blastwave | https://www.blastwave-comic.com | Situs tidak terjangkau / folder upstream tidak ditemukan. / Site unreachable / upstream folder not found. |
| 7 | Hiveworks Comics | https://hiveworkscomics.com | Agregator ratusan webcomic di situs berbeda dengan penanganan khusus per situs; tidak ada satu parser yang cocok. / Aggregator of hundreds of webcomics on different sites with per-site special cases; no single parser fits. |
| 8 | J-Novel | https://j-novel.club | Dilindungi Cloudflare (HTTP 403); tidak bisa diverifikasi tanpa WebView. / Cloudflare-protected (HTTP 403); cannot be verified without a WebView. |
| 9 | K Manga | https://kmanga.kodansha.com | Toko resmi berbayar/login; tidak ada konten gratis tanpa akun. / Paid/login-gated official store; no free content without an account. |
| 10 | Madokami | https://manga.madokami.al | Butuh login (HTTP 401). / Requires login (HTTP 401). |
| 11 | MangaCloud | https://mangacloud.org | Dilindungi Cloudflare (HTTP 403); tidak bisa diverifikasi tanpa WebView. / Cloudflare-protected (HTTP 403); cannot be verified without a WebView. |
| 12 | Mangamo | https://www.mangamo.com | Toko resmi berbayar/login; tidak ada konten gratis tanpa akun. / Paid/login-gated official store; no free content without an account. |
| 13 | Monochrome Custom | - | Sumber template tanpa situs tetap (template: monochrome). / Template-only source without a fixed site (template: monochrome). |
| 14 | Read Comics Online | https://readcomicsonline.ru | Dilindungi Cloudflare (HTTP 403); tidak bisa diverifikasi tanpa WebView. / Cloudflare-protected (HTTP 403); cannot be verified without a WebView. |
| 15 | Renascans | https://renascans.net | Dilindungi Cloudflare (HTTP 403); tidak bisa diverifikasi tanpa WebView. / Cloudflare-protected (HTTP 403); cannot be verified without a WebView. |
| 16 | The Far Side | https://www.thefarside.com | Keterangan kartun digambar ke dalam gambar lewat interseptor bitmap; belum ada padanannya. / Captions are drawn into the image by a bitmap interceptor; no equivalent yet. |
| 17 | The Interpretation of Shadows | https://tioscomic.com | Situs menjalankan pemeriksaan bot ("One moment, please") yang butuh browser. / Site runs a bot check ("One moment, please") that needs a browser. |
| 18 | Vision Haze | https://www.visionhaze.com | Dilindungi Cloudflare (HTTP 403); tidak bisa diverifikasi tanpa WebView. / Cloudflare-protected (HTTP 403); cannot be verified without a WebView. |
| 19 | VIZ | https://www.viz.com | Toko resmi berbayar/login; tidak ada konten gratis tanpa akun. / Paid/login-gated official store; no free content without an account. |
| 20 | Voyce.Me | https://www.voyce.me | Toko resmi berbayar/login; tidak ada konten gratis tanpa akun. / Paid/login-gated official store; no free content without an account. |
| 21 | Webdex Scans | https://webdexscans.com | Dilindungi Cloudflare (HTTP 403); tidak bisa diverifikasi tanpa WebView. / Cloudflare-protected (HTTP 403); cannot be verified without a WebView. |
| 22 | WebNovel | https://www.webnovel.com | Dilindungi Cloudflare (HTTP 403); tidak bisa diverifikasi tanpa WebView. / Cloudflare-protected (HTTP 403); cannot be verified without a WebView. |
| 23 | ZipComic | https://www.zipcomic.com | Dilindungi Cloudflare (HTTP 403); tidak bisa diverifikasi tanpa WebView. / Cloudflare-protected (HTTP 403); cannot be verified without a WebView. |

#### Campuran / Mixed (49)

| # | Nama / Name | Situs / Site | Catatan / Note |
|---|---|---|---|
| 1 | AllManga | https://mkissa.to |  |
| 2 | Bakaloli | https://bakaloli.eu |  |
| 3 | Bbato | - |  |
| 4 | BookWalker | https://bookwalker.com |  |
| 5 | Coffee Manga (Unoriginal) | https://coffeemanga.net | template: imperiomanhwa |
| 6 | ComicK Fanmade | https://comickfan.com | Situs tidak terjangkau saat dicek. / Site unreachable when checked. |
| 7 | Comix | - |  |
| 8 | Coolmic | https://coolmic.me |  |
| 9 | Dashtoon | https://dashtoon.com |  |
| 10 | Dream-Manga | https://dream-manga.com |  |
| 11 | EbookRenta | https://www.ebookrenta.com |  |
| 12 | emaqi | https://emaqi.com |  |
| 13 | InfinityScans | https://infinityscans.org |  |
| 14 | Inkora | https://inkora.spacely.tech |  |
| 15 | INKR | https://comics.inkr.com |  |
| 16 | KaliScans.org (unoriginal) | https://kaliscans.org |  |
| 17 | Kemono Café | https://kemono.cafe |  |
| 18 | Kodansha | https://kodansha.us |  |
| 19 | Lazy Monki Scans | https://lazy-monki-scans.netlify.app |  |
| 20 | Manga MTL | https://mtlmanga.org | template: manhuarm |
| 21 | Manga-Bay | https://manga-bay.biz |  |
| 22 | Manga.uno | https://manga.uno |  |
| 23 | MangaGeko | https://www.mgeko.cc |  |
| 24 | Mangago | https://www.mangago.me | Gambar bab diacak lewat deobfuscator JS (SoJsonV4); belum di-port. / Chapter images use a JS deobfuscator (SoJsonV4); not ported. |
| 25 | MangaLix | https://mangalix.com | Katalog dibaca dari berkas JS terbundel lewat parser literal JS; belum di-port. / Catalog is read from a bundled JS file via a JS-literal parser; not ported. |
| 26 | MangaPlaza | https://mangaplaza.com |  |
| 27 | Mangastash | https://mangastash.org | Dicoba 2026-11-18: daftar, detail, bab jalan, tetapi gambar bab dijawab 403 oleh server asal untuk semua klien. / Tried: lists, details, chapters work, but the origin answers 403 for chapter images to every client. |
| 28 | ManhuaTop | https://manhuatop.org | Dicoba 2026-11-18: API membalas 403 Cloudflare ke klien aplikasi walau curl lolos. / Tried: API answers 403 (Cloudflare) to the app client although curl passes. |
| 29 | ManhwaRead | - | Dilindungi Cloudflare (HTTP 403). / Cloudflare-protected (HTTP 403). |
| 30 | ManhwaZone | https://manhwazone.com |  |
| 31 | MyMangaList | https://www5.mymangalist.org |  |
| 32 | New Manhwa | https://saymanhwa.com |  |
| 34 | OceComic | https://ocecomic.com | Pemeriksaan bot butuh WebView. / Bot check needs a WebView. |
| 35 | Omoi | https://www.omoi.com |  |
| 36 | Oppai Stream | https://read.oppai.stream | Pembaca manhwa sudah tidak ada (situs kini berisi video). / Manhwa reader is gone (site is now video). |
| 37 | ReiManga | https://reimanga.net | Akses gambar dijaga token/guard anti-bot; tidak di-port. / Image access is gated by guard tokens; not ported. |
| 39 | ScansGG | https://scans.gg |  |
| 40 | Schale Scans | https://www.schalescans.com |  |
| 41 | SilentQuill | https://silentquill.net | Dinilai: data lewat payload RSC bertingkat; belum di-port. / Assessed: nested RSC payloads; not ported. |
| 42 | StreameX (unoriginal) | https://streamex.hn |  |
| 43 | Team Shadowi | https://www.team-shadowi.com |  |
| 44 | TodayManga | https://todaymanga.com |  |
| 45 | Toonkotsu | https://toonkotsu.com | Gambar bab dienkripsi dan didekripsi oleh interseptor; belum ada padanannya. / Chapter images are encrypted and decrypted by an interceptor; no equivalent yet. |
| 46 | Toonz/Toonx | https://toonz.to | Daftar jalan, tetapi halaman seri dijaga tantangan Cloudflare (403) untuk klien aplikasi. / Listing works, but series pages are behind a Cloudflare challenge (403) for the app client. |
| 47 | VyvyManga | - |  |
| 48 | Webnex | https://webnex.cc |  |
| 49 | WebtoonLib | https://webtoonlib.to | Gambar bab digabung dengan balon dialog oleh interseptor bitmap; belum ada padanannya. / Bubbles are composited by a bitmap interceptor; no equivalent yet. |
| 50 | XoManga | https://www.xomanga.site |  |
| 51 | Yurivan | https://www.yurivan.com | Dicoba 2026-11-18: API membalas tantangan Cloudflare ke klien aplikasi. / Tried: API answers a Cloudflare challenge to the app client. |

#### Dewasa (NSFW) / Adult (NSFW) (33 tersisa / remaining; HentaiDad, HentaiPill, Hentai.yoga, HentaiHere, HentaiTnT, Transfusions dan sebelumnya 35 lain sudah di-port / already ported)

| # | Nama / Name | Situs / Site | Catatan / Note |
|---|---|---|---|
| 1 | 8Muses | https://comics.8muses.com | Struktur album bertingkat dengan tumpukan halaman berstatus (template eromuse); belum di-port. / Nested albums with a stateful page stack (eromuse template); not ported. |
| 2 | Babes Rater | https://babesrater.com |  |
| 3 | BabeSource | https://babesource.com |  |
| 4 | buttsmithy | https://incase.buttsmithy.com |  |
| 5 | Doujin.io - J18 | https://doujin.io |  |
| 6 | Erofus | https://www.erofus.com | Struktur album bertingkat dengan tumpukan halaman berstatus (template eromuse); belum di-port. / Nested albums with a stateful page stack (eromuse template); not ported. |
| 7 | Fairies vs Tentacles | https://eldrikdgt.com | Situs kosong/pindah domain saat dicek. / Site empty or moved when checked. |
| 8 | Futapo | https://futapo.com |  |
| 9 | Gensura | https://gensura.net |  |
| 10 | GirlsTop | https://en.girlstop.info |  |
| 11 | HentaiKun | https://hentaikun.com |  |
| 12 | HentaiRead | https://hentairead.com | Dilindungi Cloudflare (HTTP 403) ke klien aplikasi. / Cloudflare answers 403 to the app client. |
| 13 | HentaiRead.io | https://hentairead.io | Server Cloudflare menolak klien aplikasi (403) walau curl lolos; dilewati. / Cloudflare answers 403 to the app client although curl passes; skipped. |
| 14 | HentaiSco | https://hentaisco.cc |  |
| 15 | HotComics | https://hotcomics.io |  |
| 16 | Kotokotek | https://kotokotek.wixsite.com |  |
| 17 | LGBToon | https://lgbtoon.com | Daftar dan bab terbaca, tetapi CDN gambar (Cloudflare) menolak klien aplikasi dengan 403; dilewati. / Lists and chapters parse, but the image CDN (Cloudflare) answers 403 to the app client; skipped. |
| 18 | ManhwaH | https://manhwah.com | Daftar dan bab terbaca, tetapi CDN gambar (Cloudflare) menolak klien aplikasi dengan 403; dilewati. / Lists and chapters parse, but the image CDN (Cloudflare) answers 403 to the app client; skipped. |
| 19 | Mehgazone | https://mehgazone.com |  |
| 20 | MyAdultComics | https://myadultcomics.com |  |
| 21 | MyHentaiComics | https://myhentaicomics.com | Dicoba 2026-11-18: klien app ditolak 403 (Cloudflare) walau curl lolos. / Tried: app client gets 403 (Cloudflare) although curl passes. |
| 22 | MyHentaiGallery | https://myhentaigallery.com | Dicoba lalu dihapus: klien app ditolak 403 (Cloudflare) walau curl lolos. / Tried then removed: app client gets 403 (Cloudflare) although curl passes. |
| 23 | Myth Toons | https://mythtoons.org |  |
| 24 | NineHentai | https://9hentai.so | API butuh token CSRF dan sesi; tidak di-port. / API needs a CSRF token and session; not ported. |
| 25 | Nortverse | https://nortverse.com |  |
| 26 | Pornhwa.me | https://pornhwa.me |  |
| 27 | SpyFakku | - |  |
| 28 | Sunshine Butterfly Scans | https://wings.sbs |  |
| 29 | Tailspace | https://tailspace.com | Data memakai aliran Turbo (turbo-stream); belum di-port. / Data uses a turbo-stream payload; not ported. |
| 30 | Temple Scan | https://templetoons.com | Konten dimuat lewat skrip loader yang diobfuskasi (`/api/kaneda/boot`); dilewati. / Content is loaded via an obfuscated loader script; skipped. |
| 31 | The Blank | https://theblank.net | template: pam |
| 32 | ToonHey | https://toonhey.com |  |
| 33 | YaoiHot | https://yaoihot.com |  |
