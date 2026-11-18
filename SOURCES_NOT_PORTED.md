# Sumber yang belum di-port / Sources not yet ported

Dibuat 2026-11-17 dari perbandingan `keiyoushi/extensions-source` (folder `src/en` dan `src/id`) dengan katalog Hub Reader (`assets/sources/catalog.json` + sumber Dart tulis tangan).
Generated 2026-11-17 by diffing `keiyoushi/extensions-source` (`src/en` and `src/id`) against the Hub Reader catalog (`assets/sources/catalog.json` + hand-written Dart sources).

| Bahasa / Language | Belum di-port / Not ported |
|---|---|
| Indonesia (id) | 14 (6 sudah di-port: Bacami, MG Komik, West Manga, Komik AV, Hentai Crot, Pix Hentai) |
| English (en) | 124 (sisanya dari 153; 29 baru di-port 2026-11-18 / 29 more ported on 2026-11-18) |

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
| 1 | Komiku.com | https://01.komiku.asia | Dicoba lalu dihapus: gambar diblokir tantangan Cloudflare. / Tried then removed: images blocked by Cloudflare challenge. |
| 2 | Softkomik | - | Tidak di-port: sesi API bertanda tangan + dekripsi CryptoJS. / Not ported: signed API sessions + CryptoJS decryption. |
| 3 | VoraToon | - | Dicoba lalu dihapus: gambar bab gagal diekstrak dari RSC. / Tried then removed: chapter images could not be extracted from RSC. |

#### Campuran / Mixed (8)

| # | Nama / Name | Situs / Site | Catatan / Note |
|---|---|---|---|
| 1 | CGBUM | https://cgbum.com | Tidak di-port: gambar bab dilindungi tantangan proof-of-work. / Not ported: chapter images gated by a proof-of-work challenge. |
| 2 | Comicaso | https://v3.comicaso.pro | Tidak di-port: API meminta tantangan verifikasi. / Not ported: API demands a verification challenge. |
| 3 | CosmicScans | https://04.cosmicscans.to | Tidak di-port: sesi gambar memakai Turnstile. / Not ported: image sessions require Turnstile. |
| 4 | KomikNesia | https://v2.komiknesiaku.com | Situs mati saat dicek (HTTP 521). / Site down when checked (HTTP 521). |
| 5 | Manhwa Indo | https://www.manhwaindo.my | Dicoba lalu dihapus: CDN gambar memblokir klien. / Tried then removed: image CDN blocks the client. |
| 6 | MikoRoku | https://mikoroku.com | Situs error saat dicek (HTTP 500). / Site erroring when checked (HTTP 500). |
| 7 | Pramramadhan | https://01.pramramadhan.my.id | Situs tidak terjangkau. / Site unreachable. |

#### Dewasa (NSFW) / Adult (NSFW) (6)

| # | Nama / Name | Situs / Site | Catatan / Note |
|---|---|---|---|
| 1 | Doujindesu | - | Tidak di-port: API memakai rahasia aplikasi + dekripsi XOR. / Not ported: API uses an app secret + XOR decryption. |
| 2 | KumoPoi | - | Dicoba lalu dihapus: halaman palsu (honeypot) untuk klien non-browser. / Tried then removed: honeypot pages for non-browser clients. |
| 3 | Ryukomik | https://ryukomik.my.id | Situs tidak terjangkau. / Site unreachable. |
| 4 | Story About Us | https://storyabout-us.com | Tidak di-port: bab berupa PDF yang dirender di perangkat. / Not ported: chapters are PDFs rendered on-device. |

---

## 2. English (en) — 124 sumber / sources

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

#### Campuran / Mixed (63)

| # | Nama / Name | Situs / Site | Catatan / Note |
|---|---|---|---|
| 1 | AllManga | https://mkissa.to |  |
| 2 | Bakaloli | https://bakaloli.eu |  |
| 3 | Bbato | - |  |
| 4 | BookWalker | https://bookwalker.com |  |
| 5 | Coffee Manga (Unoriginal) | https://coffeemanga.net | template: imperiomanhwa |
| 6 | ComicK Fanmade | https://comickfan.com |  |
| 7 | Comix | - |  |
| 8 | Coolmic | https://coolmic.me |  |
| 9 | Dashtoon | https://dashtoon.com |  |
| 10 | Dream-Manga | https://dream-manga.com |  |
| 11 | Dynasty Scans | https://dynasty-scans.com |  |
| 12 | EbookRenta | https://www.ebookrenta.com |  |
| 13 | emaqi | https://emaqi.com |  |
| 14 | InfinityScans | https://infinityscans.org |  |
| 15 | Inkora | https://inkora.spacely.tech |  |
| 16 | INKR | https://comics.inkr.com |  |
| 17 | KaliScans.org (unoriginal) | https://kaliscans.org |  |
| 18 | Kemono Café | https://kemono.cafe |  |
| 19 | Kodansha | https://kodansha.us |  |
| 20 | Komix | https://komix.to |  |
| 21 | Lazy Monki Scans | https://lazy-monki-scans.netlify.app |  |
| 22 | LustToon | https://lustoon.com |  |
| 23 | Manga MTL | https://mtlmanga.org | template: manhuarm |
| 24 | Manga-Bay | https://manga-bay.biz |  |
| 25 | Manga.uno | https://manga.uno |  |
| 26 | MangaFox | https://fanfox.net |  |
| 27 | MangaGeko | https://www.mgeko.cc |  |
| 28 | Mangago | https://www.mangago.me |  |
| 29 | Mangahere | https://www.mangahere.cc |  |
| 30 | MangaHome | https://www.mangahome.com |  |
| 31 | MangaLix | https://mangalix.com |  |
| 32 | MangaMelon | https://mangamelon.com |  |
| 33 | MangaPlaza | https://mangaplaza.com |  |
| 34 | Mangastash | https://mangastash.org |  |
| 35 | Mangatown | https://www.mangatown.com |  |
| 36 | ManhuaTop | https://manhuatop.org |  |
| 37 | ManhwaRead | - |  |
| 38 | ManhwaZone | https://manhwazone.com |  |
| 39 | MyMangaList | https://www5.mymangalist.org |  |
| 40 | New Manhwa | https://saymanhwa.com |  |
| 41 | NexComic | https://nexcomic.com |  |
| 42 | OceComic | https://ocecomic.com |  |
| 43 | Omoi | https://www.omoi.com |  |
| 44 | Oppai Stream | https://read.oppai.stream |  |
| 45 | ReiManga | https://reimanga.net |  |
| 46 | SACACHISPA | https://sacachispa.site |  |
| 47 | ScansGG | https://scans.gg |  |
| 48 | Schale Scans | https://www.schalescans.com |  |
| 49 | SilentQuill | https://silentquill.net |  |
| 50 | StreameX (unoriginal) | https://streamex.hn |  |
| 51 | Tapas | https://tapas.io |  |
| 52 | Team Shadowi | https://www.team-shadowi.com |  |
| 53 | The Duck Webcomics | https://www.theduckwebcomics.com |  |
| 54 | TodayManga | https://todaymanga.com |  |
| 55 | Toon Hub | https://toon-hub.com |  |
| 56 | Toonkotsu | https://toonkotsu.com |  |
| 57 | Toonz/Toonx | https://toonz.to |  |
| 58 | VyvyManga | - |  |
| 59 | Webnex | https://webnex.cc |  |
| 60 | WebtoonClub | https://webtoonclub.com |  |
| 61 | WebtoonLib | https://webtoonlib.to |  |
| 62 | XoManga | https://www.xomanga.site |  |
| 63 | Yurivan | https://www.yurivan.com |  |

#### Dewasa (NSFW) / Adult (NSFW) (38 tersisa / remaining; HentaiDad, HentaiPill, Hentai.yoga, HentaiHere, HentaiTnT, Transfusions dan sebelumnya 35 lain sudah di-port / already ported)

| # | Nama / Name | Situs / Site | Catatan / Note |
|---|---|---|---|
| 1 | 8Muses | https://comics.8muses.com | template: eromuse |
| 2 | Babes Rater | https://babesrater.com |  |
| 3 | BabeSource | https://babesource.com |  |
| 4 | buttsmithy | https://incase.buttsmithy.com |  |
| 5 | Doujin.io - J18 | https://doujin.io |  |
| 6 | Erofus | https://www.erofus.com | template: eromuse |
| 7 | Fairies vs Tentacles | https://eldrikdgt.com | Situs kosong/pindah domain saat dicek. / Site empty or moved when checked. |
| 8 | Futapo | https://futapo.com |  |
| 9 | Gensura | https://gensura.net |  |
| 10 | GirlsTop | https://en.girlstop.info |  |
| 11 | HentaiFC | https://hentaifc.com |  |
| 12 | HentaiKun | https://hentaikun.com |  |
| 13 | HentaiNexus | https://hentainexus.com |  |
| 14 | HentaiRead | https://hentairead.com |  |
| 15 | HentaiRead.io | https://hentairead.io | Server Cloudflare menolak klien aplikasi (403) walau curl lolos; dilewati. / Cloudflare answers 403 to the app client although curl passes; skipped. |
| 16 | HentaiSco | https://hentaisco.cc |  |
| 17 | HotComics | https://hotcomics.io |  |
| 18 | Kotokotek | https://kotokotek.wixsite.com |  |
| 19 | LGBToon | https://lgbtoon.com | Daftar dan bab terbaca, tetapi CDN gambar (Cloudflare) menolak klien aplikasi dengan 403; dilewati. / Lists and chapters parse, but the image CDN (Cloudflare) answers 403 to the app client; skipped. |
| 20 | Manhwa18 | https://manhwa18.com |  |
| 21 | ManhwaH | https://manhwah.com | Daftar dan bab terbaca, tetapi CDN gambar (Cloudflare) menolak klien aplikasi dengan 403; dilewati. / Lists and chapters parse, but the image CDN (Cloudflare) answers 403 to the app client; skipped. |
| 22 | Mehgazone | https://mehgazone.com |  |
| 23 | MyAdultComics | https://myadultcomics.com |  |
| 24 | MyHentaiComics | https://myhentaicomics.com |  |
| 25 | MyHentaiGallery | https://myhentaigallery.com | Dicoba lalu dihapus: klien app ditolak 403 (Cloudflare) walau curl lolos. / Tried then removed: app client gets 403 (Cloudflare) although curl passes. |
| 26 | Myth Toons | https://mythtoons.org |  |
| 27 | NineHentai | https://9hentai.so | API butuh token CSRF dan sesi; tidak di-port. / API needs a CSRF token and session; not ported. |
| 28 | Nortverse | https://nortverse.com |  |
| 29 | Paradise Scans | https://paradisescans.com |  |
| 30 | Pornhwa.me | https://pornhwa.me |  |
| 31 | Pornhwa18 | https://pornhwa18.com |  |
| 32 | SpyFakku | - |  |
| 33 | Sunshine Butterfly Scans | https://wings.sbs |  |
| 34 | Tailspace | https://tailspace.com |  |
| 35 | Temple Scan | https://templetoons.com | Konten dimuat lewat skrip loader yang diobfuskasi (`/api/kaneda/boot`); dilewati. / Content is loaded via an obfuscated loader script; skipped. |
| 36 | The Blank | https://theblank.net | template: pam |
| 37 | ToonHey | https://toonhey.com |  |
| 38 | YaoiHot | https://yaoihot.com |  |
