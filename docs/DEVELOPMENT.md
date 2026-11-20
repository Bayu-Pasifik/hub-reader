# Hub Reader: dokumentasi teknis

Catatan rinci arsitektur, sumber, tracker, cadangan, rilis, dan fitur per layar. Ringkasan untuk pengguna ada di [README](../README.md); cara berkontribusi ada di [CONTRIBUTING](../CONTRIBUTING.md).

Aplikasi Android (Flutter) bergaya Aniyomi/Mihon untuk membaca komik dan novel. Konten diambil langsung dari situsnya di perangkat (tanpa server), dengan empat tab: Komik (sumber on-device), Novel (plugin LNReader), Favorit, dan Riwayat.

## Struktur folder

```
lib/
├── main.dart, bootstrap.dart      # buka SharedPreferences, cache, katalog sumber, ProviderScope
├── app.dart                       # MaterialApp.router + tema + kunci aplikasi
├── core/                          # utilitas lintas fitur (cache JSON, parsing, bridge Android)
├── data/                          # penyimpanan lokal: favorit/riwayat, unduhan, cadangan
├── sources/                       # sumber komik on-device (template Madara, MangaThemesia, ...)
├── novels/                        # plugin LNReader (QuickJS), EPUB lokal & ekspor
├── trackers/                      # AniList, MyAnimeList, Kitsu, MangaUpdates
├── state/                         # provider Riverpod
└── ui/                            # router, shell tab, layar, widget
test/                              # tes parser sumber, plugin, cadangan, dll.
```

## Sumber on-device (extension)

Tab **Komik** membaca komik langsung dari situsnya.
Scraping dilakukan di HP (IP pengguna), mirip extension Mihon.

```
lib/sources/
├── source.dart                 # kontrak MangaSource + HttpSource (Dio, header browser, rate limit)
├── models.dart                 # SourceManga, SourceMangaDetails, SourceChapter, MangaPage
├── source_exception.dart       # error situs (Cloudflare, timeout, format berubah)
├── html_utils.dart             # pengganti util Jsoup: absUrl, imgAttr, ownText, parse tanggal/nomor bab
├── templates/mangathemesia.dart  # template tema WP MangaThemesia
├── templates/madara.dart       # template tema WP Madara (AJAX & non-AJAX, 5 mode bab)
├── templates/keyoapp.dart      # template Keyoapp (situs scanlation English: classic, Livewire, V2)
├── templates/vinetheme.dart    # template VineTheme (API JSON + payload Next.js RSC)
├── templates/mangacatalog.dart # template MangaCatalog (situs fan satu franchise, daftar judul tetap)
├── templates/iken.dart         # template Iken (API JSON di api.<domain>)
├── templates/mangahub.dart     # template MangaHub (GraphQL + kunci API, gambar bisa terenkripsi AES-GCM)
├── templates/yiimanga.dart     # template Yiimanga (situs HTML: daftar /page/N/, genre, bab di satu halaman)
├── templates/mangabox.dart     # template MangaBox (Mangabat, Mangakakalot, Manganelo; bab dari API)
├── templates/yiimadara.dart    # template YiiMadara (situs Yii2 bermarkup Madara; 7 sumber)
├── templates/foolslide.dart    # template FoolSlide (pembaca scanlation lama; POST adult=true)
├── templates/guya.dart         # template Guya (API JSON: Guya.moe, Danke, Hachirumi)
├── templates/json_readers.dart # Monochrome CMS dan BakkinReaderX (JSON)
├── templates/mangak.dart       # template MangaK (Next.js + API JSON: Comizy, MangaK, ToonTop)
├── templates/heancms.dart      # template HeanCms (API JSON: Omega Scans, Lua Scans)
├── templates/ezmanhwa.dart     # template EZManhwa (API JSON: EZmanga, Qi Scans)
├── templates/initmanga.dart    # template InitManga (UIkit; gambar bisa terenkripsi AES-CBC; mode Image Protector belum)
├── templates/mangataro.dart    # template MangaTaro (API WP + token bab MD5: MangaTaro, Rolia Scan)
├── templates/mangadventure.dart # template MangAdventure (API JSON v2: Arc-Relight, Assorted Scans)
├── templates/manga18.dart      # template Manga18 (HTML; gambar ber-base64 di skrip)
├── templates/hiper.dart        # template Hiper (API tRPC + header kunci per situs: Hiperdex, Hipercool, Hipertoon)
├── templates/mangareader.dart  # template MangaReader (gaya "ani": MangaNow, Jmanga, Raw Otaku; filter hanya urutan)
├── templates/wpcomics.dart     # template WPComics (gaya NetTruyen: XOXO Comics, Raw18, 5 situs Vietnam)
├── templates/goda.dart         # template GoDa (Astro: Goda, 18Manhua)
├── templates/liliana.dart      # template Liliana (ManhuaPlus, Raw1001, MangaKoma, DocTruyen5s)
├── catalog.dart                # entri katalog → instance template
├── catalog_repository.dart     # katalog dari repo remote + cache + sumber yatim
├── id/komiku.dart              # sumber kustom, scraping HTML
├── id/shinigami.dart           # sumber kustom, API JSON (api.shngm.io)
├── en/                         # sumber kustom Inggris: MangaPill, TCB Scans, MangaKatana, Weeb Central,
│                               #   Flame Comics (JSON Next.js), Mangafreak, Asura Scans (API JSON)
└── registry.dart               # sumber kustom + katalog
assets/sources/catalog.json     # 561 sumber template, dibuat oleh tool/
tool/generate_source_catalog.mjs  # generator katalog dari keiyoushi/extensions-source
lib/state/source_providers.dart # infinite scroll, detail, halaman bab
lib/ui/screens/sources/         # daftar sumber per bahasa, jelajah, detail, reader
```

### Katalog sumber

Semua extension keiyoushi yang memakai template yang sudah di-port masuk otomatis:
**Madara** (247), **MangaThemesia** (115), **ZeistManga** (38), **Keyoapp** (16), **VineTheme** (6), **MangaCatalog** (18), **Iken** (9), **Yiimanga** (12), **MangaHub** (11), **FoolSlide** (11), **YiiMadara** (7), **Guya** (4), **MangaBox** (3), Monochrome (1), Bakkin (1), LoneSeal (5),
NatsuId (3), Hwalumi (2), ColorlibAnime (2), dan ZManga (6; CrotPedia wajib login member), jadi totalnya 517 sumber dalam 16 bahasa.
Keyoapp (12 Nov 2026): 11 dari 16 situs English jalan penuh; 3 di balik Cloudflare
(Meitoon, Luna Toons, Kaizen Scans) dan 2 sedang down (Mist Scans, Grim Scans). VineTheme: 6 dari 6
jalan penuh (Drake, Elf Toon, Kayn, Kero, Valir, Diva Scans). MangaCatalog: 17 dari 18 situs
jalan dengan semua judulnya (Read Black Clover tidak bisa dihubungi). Iken: 5 dari 9 jalan (Hive,
Ken, Magus, Vortex, dan Azora berbahasa Arab); Nyx & Hijala di balik Cloudflare, Orion & Sana 502. Tab Sumber mengelompokkannya per
bahasa, lengkap dengan chip filter bahasa dan pencarian. Sumber 18+ disembunyikan secara
default; aktifkan lewat Pengaturan › Sumber › "Tampilkan sumber NSFW (18+)".

Setelah `catalog.json` diperbarui dan di-push ke `main`, aplikasi yang sudah terpasang ikut
mendapatkannya tanpa update APK: katalog juga diambil dari repo
(`raw.githubusercontent.com/Bayu-Pasifik/hub-reader/main/assets/sources/catalog.json`) tiap 12 jam.
Atur lewat Pengaturan › Sumber › Repo sumber komik: tambah mirror/fork (format `catalog.json`
yang sama), ubah prioritas, atau hapus. Katalog bawaan APK selalu jadi cadangan paling bawah.
Salinan tiap repo disimpan di HP; sumber yang hilang dari semua repo tetap tersimpan sebagai
sumber "yatim" dan tetap jalan, dan host lama tiap sumber diingat supaya favorit/riwayat lama
dialihkan ke domain baru. Repo hanya berisi data: template baru tetap butuh update aplikasi.

Perbarui katalog dari checkout extensions-source terbaru:

```bash
git clone --depth 1 https://github.com/keiyoushi/extensions-source /tmp/ks
node tool/generate_source_catalog.mjs /tmp/ks assets/sources/catalog.json
```

Generator membaca `build.gradle.kts` (nama, bahasa, `baseUrl`, label konten) dan override
sederhana di Kotlin (`mangaSubString`, `chapterMode`, `MadaraNoAjax`, `mangaUrlDirectory`,
`pageSelector`). Situs yang meng-override logika inti (list, detail, halaman) ditandai
**eksperimental** di UI, karena port template mungkin kurang pas untuk situs itu.

Hasil uji langsung Madara + MangaThemesia dari PC (12 Nov 2026): **159 dari 359 jalan penuh**
(daftar → detail → gambar halaman): Madara 111/244, MangaThemesia 48/115. Sisanya gagal karena
tidak bisa terhubung (89: domain mati/pindah, atau koneksi TLS diputus, pola blokir ISP;
coba DNS/VPN), Cloudflare (64, umumnya bisa diatasi di HP lewat "Buka di WebView"), situs yang
wajib login/member, atau struktur HTML/JS khusus.

Port Madara memakai override selector Kotlin per situs (`options.vals`, mis.
`mangaDetailsSelectorTitle`, `archiveUrlSelector`, `pageListParseSelector`) bila selectornya
bisa dipakai parser Dart (tanpa `:contains`/`:has`), mendekripsi *chapter protector*
(AES CryptoJS, lewat `pointycastle`), dan punya cadangan judul `og:title` serta gambar di
`<canvas data-page-url>`.

**Laporkan sumber rusak** (`lib/sources/source_report.dart`): layar error sumber komik (jelajah, detail seri, reader) menampilkan tombol **Laporkan sumber ini** bila errornya dari sumber (halaman tidak ditemukan, struktur berubah/parse, error server, tak dikenal). Gangguan koneksi, timeout, Cloudflare, dan batas permintaan tidak memunculkannya karena umumnya masalah jaringan pengguna. Tombol membuka isu GitHub yang sudah terisi (nama, id, domain, jenis error, detail ≤300 karakter, versi aplikasi) di browser untuk ditinjau dan dikirim sendiri; aplikasi tidak mengirim apa pun, dan riwayat, favorit, cookie, serta proxy tidak ikut. Plugin novel juga punya tombol ini (jelajah, detail, dan pembaca): isu memuat nama plugin, `lnr:<id> v<versi>`, dan domain situs; plugin lokal (EPUB) tidak dilaporkan.

**Cek kesehatan sumber:** menu ⋮ → "Cek N sumber" mencoba halaman populer tiap sumber
dari HP itu sendiri (jaringan, DNS/VPN, dan cookie Cloudflare milik pengguna), 6 sumber
paralel. Statusnya: Jalan, Perlu verifikasi (Cloudflare), Rusak (respons tidak bisa diparse),
atau Mati (tidak terhubung, timeout, 404, 5xx). Hasilnya disimpan (`sources.health.v1`) dan
diperbarui otomatis setiap kali sumber dibuka. Daftar diurutkan dari yang jalan, sumber mati
diredupkan dan bisa disembunyikan, dan tekan lama sebuah sumber untuk mengecek ulang.

Situs dengan struktur lain dibuat sebagai subclass `HttpSource` (contoh: `id/komiku.dart`,
`id/shinigami.dart`) lalu didaftarkan di `customSources()` pada `registry.dart`.

Catatan port dari Kotlin/Jsoup: package `html` **tidak** mendukung `:contains()`
dan `:has()`. Pakai `whereContains()` atau filter manual.

Batasan saat ini:
- Cloudflare: bila situs meminta verifikasi, error-nya menampilkan tombol **Buka di WebView**.
  Setelah lolos, cookie `cf_clearance` disalin dari `CookieManager` Android (lewat
  MethodChannel `hub_reader/cookies` di `MainActivity.kt`) ke `SourceCookieStore`, lalu
  dipakai Dio dan pemuat gambar. Dio memakai User-Agent asli WebView karena cookie
  itu terikat ke UA. Cookie berlaku sampai kedaluwarsa, lalu verifikasi diulang.
- Filter per sumber ada lewat tombol filter di layar jelajah. Sumber mendefinisikannya
  lewat `filters()` (`SelectFilterDef` atau `MultiSelectFilterDef`, lihat `sources/filters.dart`).
  MangaThemesia mendukung urutan, status, tipe, dan genre (genre diambil dari `ul.genrez`
  di situs). Komiku mendukung urutan, tipe, status, genre 1, dan genre 2.
- Unduhan offline: gambar bab disimpan di `<documents>/downloads/<sumber>/<hash seri>/<hash bab>/`,
  dan indeksnya ada di SharedPreferences (`downloads.index.v1`). Reader otomatis memakai
  file lokal bila babnya lengkap terunduh. Antrean disimpan (`downloads.queue.v1`) dan
  dilanjutkan otomatis saat aplikasi dibuka lagi; bab yang terputus diulang tanpa mengunduh ulang halaman yang sudah ada.
- Reader komik (tambahan): **Zoom ketuk dua kali** (`ZoomablePage`; memperbesar ke titik yang diketuk, ketuk lagi untuk kembali; di mode per halaman, ketuk pinggir jadi tertunda ±300 ms karena menunggu ketukan kedua, bisa dimatikan), **Kecerahan layar** (jendela Android, 0 = ikut sistem, kembali otomatis saat reader ditutup), dan **Pra-muat halaman** 0-6 di depan (mode per halaman, halaman dari jaringan). Semuanya di `reader.display.v1`.
- Reader komik: ikon pengaturan di reader berisi mode baca, **Potong tepi kosong**, dan filter warna
  (hitam putih, balik warna, redupkan). Mode dan potong tepi bisa disimpan khusus per seri
  (`reader.series.v1`); filter warna berlaku umum (`reader.display.v1`). Deteksi tepi memakai salinan
  gambar selebar 256 px di isolate. Di mode webtoon hanya kiri-kanan yang dipotong.
- Pembaruan aplikasi: Pengaturan → **Periksa pembaruan**, plus cek otomatis saat aplikasi dibuka
  (maks. sekali sehari, bisa dimatikan). Versi terbaru dibaca dari redirect
  `github.com/<repo>/releases/latest` (tanpa REST API, jadi tidak kena batas 60 request/jam), lalu
  APK `hub-reader-<versi>.apk` hasil CI dibuka di browser. Rilis dibuat dengan push tag `v<versi>`
  yang sama dengan `version:` di `pubspec.yaml`.
- Domain situs sering pindah. Ketuk ikon gir di tab Sumber untuk mengganti domain tanpa
  build ulang (ada tombol Tes koneksi). Host lama diingat, jadi URL favorit, riwayat, dan
  unduhan dari domain lama otomatis dialihkan (`HttpSource.rewriteToCurrentHost`).
  Progres baca per bab terikat ke URL bab, jadi bab yang dimuat ulang dari domain baru
  dianggap bab berbeda.

**Animasi:** `assets/lottie/*.json` dibuat sendiri (`tool/gen_lottie.mjs`). Empat ilustrasi `*.lottie` diunduh dari
[LottieFiles](https://lottiefiles.com/) (animasi gratis, Lottie Simple License): `empty_box` (daftar kosong), `no_internet`
(tidak ada koneksi), `search_file` (hasil pencarian kosong), `no_history` (riwayat kosong). Dibaca lewat decoder dotLottie
di `state_views.dart`; warnanya tidak mengikuti aksen tema.

**Lisensi:** template dan selector di-port dari
[keiyoushi/extensions-source](https://github.com/keiyoushi/extensions-source)
(Apache License 2.0). Atribusi ada di kepala setiap file hasil port. Hak cipta konten
tetap milik situs atau pemegang haknya.

## Sumber novel (plugin LNReader)

Tab **Novel** memakai plugin dari [lnreader/lnreader-plugins](https://github.com/lnreader/lnreader-plugins)
apa adanya: JS hasil compile di branch `plugins/v3.0.0` (manifest `.dist/plugins.min.json`,
371 plugin dalam 17 bahasa) dijalankan langsung di HP dengan QuickJS
([flutter_js](https://pub.dev/packages/flutter_js)), sama seperti aplikasi LNReader menjalankannya
di Hermes. Plugin baru atau perbaikan dari upstream langsung terpakai tanpa rilis aplikasi.

```
lib/novels/
├── lnreader/js_engine.dart      # QuickJS + host `__host(op, payload)`: fetch, timer, storage, decode
├── lnreader/engine_isolate.dart # engine di isolate latar; fetch & storage dikerjakan isolate UI
├── lnreader/http_bridge.dart    # fetch() plugin → Dio (UA & cookie bersama sumber komik)
├── plugin_repository.dart       # manifest + kode plugin, disimpan di <support>/lnreader/
├── novel_source.dart            # popularNovels/searchNovels/parseNovel/parsePage/parseChapter
└── novel_models.dart            # NovelItem, NovelDetails, NovelChapter, filter LNReader
lib/state/novel_providers.dart   # engine, manifest, daftar, detail, isi bab, pengaturan baca
lib/ui/screens/novels/           # daftar plugin, jelajah + filter, detail, pembaca teks
assets/lnreader/runtime.js       # dibuat oleh tool/lnreader_runtime (jangan diedit)
```

`assets/lnreader/runtime.js` menyediakan `require()` yang sama dengan LNReader
(`cheerio` 1.0.0-rc.12, `htmlparser2`, `dayjs`, `@libs/fetch`, `@libs/storage`,
`@libs/filterInputs`, `@libs/novelStatus`, `@libs/defaultCover`, `@libs/aes`, ...) plus API web
yang tidak ada di QuickJS: `fetch`/`Response`/`Headers`/`FormData`, `URL`/`URLSearchParams`
(core-js), `setTimeout`, `AbortController`, `TextEncoder`/`TextDecoder`, `atob`/`btoa`, `Buffer`,
serta shim `BigInt`/`DataView#setBigUint64` (QuickJS flutter_js tanpa BigInt; dipakai AES-GCM `@libs/aes`).
Request dari plugin dijalankan Dio di Dart, jadi cookie `cf_clearance` hasil "Buka di WebView"
ikut terkirim. `@libs/storage` disimpan di SharedPreferences (`lnr.kv.*`).

Pembaca novel mengubah HTML bab menjadi teks dengan gaya sendiri (tema terang/sepia/gelap/hitam,
ukuran huruf, jarak baris, margin, serif, rata kiri-kanan), menyimpan posisi baca per bab
(persen), lalu pindah bab sebelumnya/berikutnya, termasuk lintas halaman untuk plugin
berhalaman (`parsePage`). Favorit & riwayat novel berbagi tab dengan komik (id `lnr:<plugin>`).

**Tracker AniList & MyAnimeList** (`lib/trackers/`): buat aplikasi OAuth sendiri (AniList: redirect
`https://anilist.co/api/v2/oauth/pin`; MAL: tipe "other", redirect bebas), isi Client ID di Pengaturan →
Tracker (atau bawa Client ID bawaan saat build: `--dart-define=ANILIST_CLIENT_ID=…` /
`--dart-define=MAL_CLIENT_ID=…`; isian pengguna tetap menang) lalu login di WebView (AniList implicit grant, MAL PKCE plain + refresh token). Di detail seri,
menu **Tracking** menautkan seri ke entri tracker (cari judul; novel dicari sebagai NOVEL/light novel),
mengubah progres & status, atau melepas tautan. Progres naik otomatis saat bab selesai dibaca (halaman
terakhir komik / akhir bab novel / tombol bab berikutnya), tidak pernah turun, dan jadi "Selesai" saat
mencapai jumlah bab. Token tracker termasuk data rahasia di cadangan.

**Kitsu & MangaUpdates** tidak perlu Client ID: login dengan email/username dan password di
Pengaturan → Tracker. Password tidak disimpan, hanya token sesi (Kitsu: password grant dengan client
publik aplikasi Kitsu + refresh token; MangaUpdates: session token API v1). MangaUpdates tidak punya
jumlah bab, jadi status "Selesai" diatur manual; daftar buatan pengguna di MangaUpdates tampil tanpa status.

**Tablet & layar lebar**: mulai 600dp navigasi pindah ke rail di kiri; mulai 840dp detail seri komik/novel
jadi dua panel (info di kiri, daftar bab di kanan). Teks reader novel dibatasi 720dp per baris. Grid
jelajah memuat halaman berikutnya sendiri sampai layar penuh.

**Bookmark & catatan**: tekan lama bab komik (atau pilih beberapa bab novel) untuk bookmark; ikon
bookmark di reader menandai bab yang sedang dibaca. Menu ⋮ di detail seri punya **Catatan** (teks bebas,
tampil di bawah sinopsis) dan filter **Hanya bab ber-bookmark**. Disimpan di `library.bookmarks.v1` /
`library.notes.v1`, ikut cadangan, dan ikut dipindah saat **Pindah sumber** (bookmark dicocokkan lewat
nomor bab).

**Cleartext HTTP**: permintaan sumber komik, gambar hasil parse (`absUrl`), dan ganti domain tidak pernah lewat `http://` ke host publik. Dio sumber menaikkannya ke `https://` (`lib/core/net/cleartext.dart`), dan dialog ganti domain menolak `http://` publik. Pengecualian: localhost, IP privat, `.local`, dan nama host tanpa titik.

**Blokir screenshot** (Pengaturan → Privasi & keamanan, `app.secure_screen.v1`, mati secara default): memasang `FLAG_SECURE` lewat channel `hub_reader/reader`, jadi screenshot dan rekam layar menghasilkan layar hitam, dan pratinjau di daftar aplikasi terbaru dikosongkan.

**Mode samaran** (ikon mata di Riwayat, atau Pengaturan): riwayat dan posisi baca otomatis tidak
dicatat; tanda dibaca manual tetap bisa. Bilah kecil di atas navigasi menandai mode ini aktif.

**Sumber Lokal** (grup paling atas di tab Komik, `lib/sources/local/`): komik dari penyimpanan perangkat.
Menu ⋮ Sumber → **Impor komik (CBZ/ZIP)** memilih satu atau beberapa arsip, menebak judul seri dari nama
file, lalu menyalinnya ke `Android/data/com.hubreader.hub_reader/files/local/<Judul>/` (folder itu juga
bisa diisi langsung lewat USB/pengelola file). Satu arsip atau satu subfolder gambar = satu bab; arsip di
akar folder = seri satu bab; `cover.*` dan `description.txt` opsional. Arsip diekstrak ke cache saat
dibaca (nama file diganti nomor urut, jadi entri `../` tidak bisa keluar folder). Menu detail seri punya
**Hapus dari perangkat**; unduh & cek kesehatan tidak berlaku untuk sumber ini.

**Novel EPUB lokal** (`lib/novels/local_epub.dart`): ubin **Lokal (EPUB)** paling atas di tab Novel (tombol
impor di kanan) atau impor .epub dari menu Sumber. File disalin ke `files/local_novels/`, diekstrak ke cache
(entri `../` dilewati), lalu dibaca dari OPF: judul, penulis, sinopsis, subjek, sampul (`cover-image` /
`<meta name="cover">`). Bab = urutan spine dengan judul dari daftar isi EPUB3 (nav) atau EPUB2 (NCX), atau
heading pertama; halaman kosong dilewati. Gambar di bab diarahkan ke file hasil ekstrak (`file://`) dan
dirender di reader. `NovelSource.custom` memungkinkan sumber novel tanpa mesin plugin JS.

**Ekspor ke EPUB** (menu ⋮ detail novel, `lib/novels/epub_writer.dart`): semua bab (termasuk plugin
berhalaman) atau hanya yang sudah diunduh dijadikan EPUB 3 (plus NCX untuk pembaca EPUB 2) dengan sampul,
penulis, sinopsis, dan genre, lalu disimpan lewat dialog sistem. Isi bab diambil dari unduhan bila ada,
kalau tidak dari situs; HTML dibersihkan menjadi XHTML valid (script/iframe/gambar jarak jauh dibuang). Bab
yang gagal dimuat dilewati dan dilaporkan.

**Bagikan & deep link** (`lib/ui/deep_links.dart`): menu ⋮ detail komik/novel → **Bagikan** mengirim judul,
URL situs, dan tautan aplikasi `hubreader://open/<rute>` lewat share sheet. Tautan itu membuka seri/novel di
aplikasi (saat dibuka dari nol maupun saat aplikasi sudah jalan). Deep linking otomatis Flutter dimatikan;
`MainActivity` meneruskan tautan lewat channel `hub_reader/links` dan hanya rute detail & reader yang
diterima (parameter lain dibuang), jadi tautan dari luar tidak bisa membuka WebView ke situs sembarang atau
layar cadangan/pengaturan.

**Statistik** (ikon grafik di Riwayat, atau Pengaturan → Data): lama membaca hari ini / 7 hari / total,
rentetan hari membaca, grafik 14 hari, bab selesai (komik & novel), favorit, dan 5 seri paling banyak
dibaca. Lama membaca dihitung dari aktivitas di reader (gulir, ganti halaman, auto-scroll, TTS) dengan
jeda maksimal 3 menit per aktivitas; disimpan per hari di `stats.reading.v1` (ikut cadangan, tidak
dicatat saat mode samaran).

**Pengaturan** (menu ⋮ di tab Komik/Novel/Favorit): tema sistem/terang/gelap, hitam pekat (OLED),
warna aksen; kunci aplikasi dengan sidik jari/PIN perangkat (`local_auth`, `MainActivity` kini
`FlutterFragmentActivity`, tema `LaunchTheme`/`NormalTheme` turunan `Theme.AppCompat` agar dialog
biometrik tidak crash di Android 8 ke bawah), kunci lagi setelah di latar 0/1/5/30 menit; ukuran & hapus cache gambar,
cache data, kode plugin novel, dan tautan ke Unduhan & Cadangan.

**Bahasa antarmuka** (Pengaturan → Tampilan): Indonesia atau English. Teks sumber ditulis dalam bahasa
Indonesia dan dibungkus `tr()` (`lib/core/i18n/strings.dart`); terjemahan Inggris ada di tabel
`strings_en.dart` (kunci = teks Indonesia, yang belum diterjemahkan tampil apa adanya). Teks dengan nilai
sisipan memakai `trp('{n} bab', {'n': 3})` (penampung `{nama}`). Status sumber, peringatan konten, status seri,
dan nama bahasa ikut diterjemahkan; `test/i18n_test.dart` memastikan setiap kunci punya terjemahan.
Pesan error sumber, label filter bawaan, widget layar utama, dan pintasan ikon ikut berganti bahasa. Yang tetap apa adanya hanya konten dari situs (judul, genre, filter dan pesan error dari plugin novel).

**Proxy HTTP** (Pengaturan → Jaringan, `lib/core/net/proxy.dart`, `net.proxy.v1`): satu alamat `host:port` untuk semua koneksi aplikasi (sumber komik, gambar, plugin novel, tracker) lewat `HttpClient.findProxy` (CONNECT untuk HTTPS). Host jaringan lokal (localhost, IP privat, `.local`) tetap langsung, jadi OPDS/WebDAV di LAN tidak terpengaruh. Tidak mendukung SOCKS maupun login proxy, dan WebView (verifikasi Cloudflare) tidak lewat proxy. Berlaku juga di cek latar belakang. Uji manual: proxy CONNECT sederhana di PC (`10.0.2.2:<port>` dari emulator) mencatat tujuan tiap koneksi.

**Animasi sampul (Hero)** (`lib/ui/widgets/cover_hero.dart`): dari layar jelajah komik/novel, pencarian global, dan "Mirip ini", sampul terbang ke header layar detail. Daftar mengirim `SeriesPreview` (judul + sampul) lewat `extra` GoRouter, jadi header langsung tampil selagi detail dimuat. Item ganda di satu daftar hanya memberi Hero pada kemunculan pertama (dua Hero bertag sama menggagalkan transisi). Daftar di dalam tab (Favorit, Riwayat) tidak beranimasi: detail dibuka di Navigator root dan Hero hanya terbang di satu Navigator.

**Onboarding** (`lib/ui/screens/onboarding_screen.dart`, `lib/state/onboarding_provider.dart`): instalasi baru melihat tiga halaman sambutan di atas aplikasi: bahasa antarmuka, cara kerja, dan pengaturan awal (unduh hanya Wi-Fi, sumber NSFW, izin notifikasi bab baru lewat dialog sistem). Bisa dilewati kapan saja. Keputusan tampil dibuat sekali saat aplikasi dibuka (`OnboardingState.resolve`): pengguna lama yang baru memperbarui (sudah ada pengaturan/favorit tersimpan) tidak melihatnya, dan instalasi baru yang ditutup di tengah onboarding melihatnya lagi (`onboarding.pending.v1`, tidak ikut cadangan). Layar ini berada di luar Navigator, jadi tombol kembali ditangani lewat `WidgetsBindingObserver.didPopRoute` + `SystemNavigator.setFrameworkHandlesBack`: mundur satu halaman, dan di halaman pertama keluar aplikasi seperti biasa.

**Aksesibilitas**: semua tombol ikon punya tooltip (jadi label pembaca layar). Reader komik memberi tiap gambar label "Halaman 3 dari 8", penghitung halaman sebagai live region (diumumkan tiap ganti halaman), dan aksi kustom "Halaman berikutnya/sebelumnya" untuk mode per halaman (menu aksi pembaca layar, tanpa perlu menggeser). "Hapus animasi" di pengaturan sistem mematikan efek perpindahan halaman, animasi ketuk dua kali, dan animasi Lottie. Skala font sistem sampai 2x diuji di emulator: tinggi sel grid (Favorit, jelajah komik & novel) dan baris chip bahasa ikut skala font (`TextScaledGridDelegate`, `chipRowHeight` di `lib/ui/widgets/layout.dart`), grafik Statistik ikut skala, bilah atas pembaca novel memindahkan tombolnya ke baris sendiri di skala >1.3x, dan label tab bawah dibatasi 1.1x supaya lima tab muat. Hasil uji: `adb shell settings put system font_scale 2.0` lalu cari `RenderFlex overflowed` di Pengaturan → Log error.

**Tema & jaringan**: **Warna dari wallpaper** (Material You, Android 12+) di Pengaturan → Tampilan.
**DNS over HTTPS** (`lib/core/net/doh.dart`) bersifat opsional dan mati secara default; nyalakan di
Pengaturan → Jaringan bila situs diblokir ISP, lalu pilih penyedia (mis. AliDNS) tanpa perlu VPN.

**Server OPDS** (Pengaturan → Server OPDS, `lib/opds/`): jelajahi katalog OPDS 1.x milik sendiri (Komga,
Kavita, Calibre-Web), cari, lalu unduh EPUB ke Novel Lokal atau CBZ ke Sumber Lokal. Mendukung Basic auth;
kata sandi disimpan di Android Keystore dan tidak ikut cadangan. HTTP polos hanya diterima untuk jaringan
lokal. Penulis dan metadata hasil unduhan mengikuti isi file, bukan entri OPDS.

**Widget "Lanjut baca"** (`ContinueWidgetProvider.kt`, `lib/state/home_widget_sync.dart`): widget layar
utama menampilkan seri terakhir dibaca dari riwayat dan membukanya langsung. **App shortcuts**
(`lib/ui/app_shortcuts.dart`) membuka tab langsung dari ikon aplikasi. Detail seri punya **Mirip ini**
(karya penulis sama dan seri sejudul), dan menambah favorit yang judulnya sudah ada memunculkan peringatan.

**Cari di dalam bab** (ikon kaca pembesar di bilah atas pembaca novel, `searchBlocks` di `lib/ui/widgets/novel_html.dart`): ketik kata untuk menyorot semua kemunculannya di bab yang sedang dibuka (tanpa membedakan huruf besar/kecil; kuning untuk semua hasil, jingga untuk yang aktif). Penghitung "2/20", tombol sebelumnya/berikutnya (berputar di ujung), dan Enter untuk lanjut. Pencarian dibatasi 500 hasil, berjalan di perangkat tanpa jaringan, dan ditutup saat pindah bab. Hanya untuk pembaca novel; komik berupa gambar.

**Pembaca novel (tambahan)**: pilih teks untuk **Sorot** (highlight) atau **Kamus**/terjemah (Indonesia ↔
Inggris; teks dikirim ke layanan web MyMemory dan dictionaryapi.dev hanya setelah kamu setuju di dialog pertama, bisa dicabut di Pengaturan → Kamus & terjemah online) dan **timer tidur**
untuk TTS (15/30/45/60 menit atau akhir bab).

**Pindah sumber** (menu ⋮ di detail seri, atau tekan lama sampul favorit): judul dicari di sumber lain
sebahasa (atau plugin yang pernah dibuka), lalu favorit, kategori, tanda sudah dibaca (dicocokkan lewat
nomor bab) dan bab terakhir dibaca dipindah ke sumber pilihan. Favorit lama bisa disimpan atau dihapus.

**Cadangan** (Favorit → ⋮ → Cadangkan & pulihkan): semua SharedPreferences (favorit + kategori,
riwayat, posisi baca, pengaturan) dan daftar pembaruan disimpan ke satu file `.json` lewat pemilih file
Android (`file_picker`). Cookie login & penyimpanan plugin novel hanya ikut bila diaktifkan; unduhan
tidak ikut. Memulihkan mengganti data di HP lalu membangun ulang aplikasi (`AppRestart`).

**Tampilan favorit** (ikon filter di Favorit): mode Grid, Grid ringkas (judul di atas sampul), Sampul saja, dan Daftar,
plus slider jumlah kolom (otomatis atau 1–6). Disimpan di `library.layout.v1`. Ikon dadu **Baca acak** membuka seri
acak dari tab yang sedang tampil (mengikuti filter & pencarian).

**Aturan pembaruan** (menu ⋮ di Pembaruan): lewati seri tamat, seri yang belum dibaca, seri yang masih punya bab baru
belum dibaca, dan kategori tertentu (seri dilewati bila semua kategorinya dikecualikan). Berlaku juga untuk cek di latar
belakang. Bawaan: lewati tamat dan belum dibaca. Disimpan di `library.updates.rules.v1`.

**Filter scanlator** (menu ⋮ detail seri, muncul bila ada ≥2 grup): `SourceChapter.scanlator` diisi sumber yang punya data grup (kini VineTheme, dari nama tim); selain itu grup dibaca dari awalan `[Grup]` pada nama bab/folder (berguna di Sumber Lokal). Grup tampil di subtitle bab; pilihan disembunyikan disimpan per seri dan ikut membatasi unduh massal. Mayoritas sumber situs satu-grup tidak punya data ini, jadi filter tidak muncul di sana.

**Cadangan WebDAV** (layar Cadangan): unggah cadangan otomatis/manual ke server WebDAV (Nextcloud, ownCloud, Synology, Koofr), tes koneksi, dan pulihkan dari daftar berkas di server. Kata sandi disimpan di Keystore, bukan di cadangan.

**Enkripsi cadangan** (`lib/data/local/backup_crypto.dart`): cookie login & token di cadangan otomatis hanya disertakan bila enkripsi otomatis aktif (menyalakan "Sertakan cookie login" meminta sandi dulu; bila enkripsi dimatikan, cadangan berikutnya dibuat tanpa rahasia). cadangan manual menawarkan kata sandi opsional; cadangan otomatis dan unggahan WebDAV dienkripsi bila "Enkripsi cadangan otomatis" aktif (sandi di Keystore, tidak ikut cadangan). Format: amplop JSON `hub_reader-backup-enc` berisi salt, nonce, dan ciphertext AES-256-GCM; kunci dari PBKDF2-HMAC-SHA256 (210.000 iterasi, tercatat di amplop). Mengimpor cadangan terenkripsi meminta sandi; sandi salah atau berkas diubah ditolak oleh tag GCM. Jika enkripsi otomatis aktif tetapi sandi tidak terbaca dari Keystore, cadangan gagal, bukan ditulis polos.

**Unduh bab berikutnya saat membaca** (Pengaturan, 0/1/2/3/5/10 bab, `lib/state/download_ahead.dart`): saat reader komik membuka bab seri favorit, bab di depannya (yang terdekat dulu) masuk antrean unduhan, sekali per bab yang dibuka. Bab yang sudah terunduh atau antre tidak memakai jatah, grup scanlator yang disembunyikan dilewati, dan aturan "hanya Wi-Fi" tetap berlaku. Tidak berlaku untuk Sumber Lokal maupun novel. Mati secara default.

**Unduhan**: Pengaturan → "Unduh hanya lewat Wi-Fi" menahan antrean sampai jaringan tanpa kuota (`NetworkBridge`, channel `hub_reader/network`; bila status tidak terbaca, dianggap bukan Wi-Fi), lalu lanjut sendiri (cek tiap 20 detik). "Lokasi unduhan" memindahkan semua unduhan ke penyimpanan internal, memori bersama, atau kartu SD (`DownloadStore.moveTo`; file asal baru dihapus setelah semua tersalin; pilihan di `downloads.root.v1`, kembali ke folder bawaan bila volume hilang). Jumlah gambar paralel 1-4.

**Log error**: `CrashLog` (`lib/core/crash/crash_log.dart`) mencatat `FlutterError` dan error async yang tidak tertangkap ke `crash.log` (maks. 128 KB). Pengaturan → Log error untuk melihat, membagikan, atau menghapus. Tidak ada pengiriman jaringan.

**Build rilis**: R8 aktif (`isMinifyEnabled`, `isShrinkResources`, aturan di `android/app/proguard-rules.pro`). Cleartext HTTP tetap diizinkan di manifest karena `network_security_config` tidak mendukung CIDR (OPDS/WebDAV di LAN); OPDS dan WebDAV menolak HTTP ke host publik di sisi Dart.

**Ekspor CBZ** (layar Unduhan): ikon arsip per bab menyimpan CBZ lewat dialog sistem; ikon di tingkat seri mengekspor
semua bab ke folder pilihan. Halaman diberi nomor ulang (`001.ext`) plus `ComicInfo.xml`, jadi terbaca di Komga, Kavita, dan Mihon.

**Urutan & filter per kategori**: di sheet filter Favorit, saklar "Khusus kategori" menyimpan urutan, balik urutan, jenis, dan filter (belum dibaca, sudah mulai dibaca, sudah diunduh) khusus tab kategori yang sedang dibuka (`library.view.categories.v1`); kategori tanpa pengaturan sendiri dan tab Semua memakai tampilan umum. Pengaturan ikut berganti nama/terhapus bersama kategorinya. Mode tampilan (grid/daftar, kolom) tetap satu untuk semua.

**Favorit** bisa dikelompokkan ke kategori (tab; menu ⋮ → Kelola kategori untuk tambah, ganti nama,
urutkan, hapus). Tekan lama sampul untuk memilih kategori atau menghapus dari favorit. Ikon filter:
jenis (komik/novel), hanya yang ada bab baru belum dibaca, dan urutan (ditambahkan, judul, terakhir
dibaca, jumlah bab baru). Sampul menampilkan jumlah bab baru yang belum dibaca; ada juga pencarian judul.

**Pembaruan** (ikon di tab Favorit): semua favorit komik & novel dicek bab barunya (3 seri
bersamaan), otomatis saat aplikasi dibuka bila pengecekan terakhir lebih dari 6 jam (bisa dimatikan),
atau tarik untuk cek manual. Bab yang sudah dikenal per seri disimpan di `<support>/library_updates.json`;
pengecekan pertama hanya mencatat. Bab baru tampil per hari, lencana di tab Favorit menghitung yang
belum dilihat, dan notifikasi (`flutter_local_notifications`) muncul setelah cek otomatis menemukan
bab baru. **Cek di latar belakang** (menu ⋮ Pembaruan): `workmanager` menjadwalkan cek tiap 6/12/24/48
jam (bawaan 12 jam) walau aplikasi ditutup, hanya saat ada jaringan (opsional Wi-Fi saja) dan baterai
tidak lemah. Isolate latar memakai dependensi yang sama lewat `lib/bootstrap.dart` dan User-Agent
WebView yang disimpan saat aplikasi terakhir dibuka (cookie `cf_clearance` terikat ke UA).

Tiap plugin novel diberi status (Jalan / Perlu verifikasi / Rusak / Mati). Data awal berasal dari cek
di PC (`node check.mjs && node health.mjs` menulis `assets/lnreader/health.json`), lalu diperbarui
dari HP: saat daftar populer dibuka, lewat menu **Cek semua plugin**, atau tekan lama satu plugin.
Menu **Sembunyikan yang rusak** menyembunyikan plugin rusak/mati dari tab Novel dan cari global.

Pengaturan pembaca (ikon Tt): tema, ukuran huruf, jarak baris, margin, jenis huruf (Sans/Serif/Rapat/Mono),
rata kiri-kanan, tombol volume untuk menggulir, layar tetap menyala, dan kecepatan gulir otomatis
(ikon panah ganda; berhenti sejenak saat layar disentuh, lanjut ke bab berikutnya di akhir bab).
Tombol volume dan layar menyala lewat channel `hub_reader/reader` di `MainActivity.kt`.

Tekan lama bab di detail novel untuk mode pilih: tandai sudah/belum dibaca, tandai semua bab sampai
bab itu, pilih semua, atau unduh yang dipilih. Di pembaca, pindah ke bab berikutnya menandai bab ini
selesai, dan menarik layar melewati akhir bab langsung membuka bab berikutnya (bisa dimatikan).

Ikon globe di tab Novel membuka **cari global**: satu kata kunci dicari di semua plugin yang pernah
dibuka, atau semua plugin satu bahasa (4 plugin bersamaan, batas 40 detik per plugin). Hasil
ditampilkan per sumber; sumber dengan hasil naik ke atas.

Tombol headphone di pembaca membacakan bab (TTS, `flutter_tts`) mulai dari paragraf yang terlihat:
paragraf aktif disorot dan diikuti layar, ada jeda/lompat paragraf, kecepatan & nada, dan lanjut
otomatis ke bab berikutnya. Bahasa suara mengikuti bahasa plugin.

Bab novel bisa diunduh (per bab, 5/10 berikutnya, atau semua yang belum dibaca) lewat antrean
unduhan yang sama dengan komik; isinya disimpan sebagai `chapter.html`. Detail & daftar bab novel
di-cache, jadi bab terunduh tetap bisa dibuka beserta navigasi babnya saat offline.

Plugin yang punya `pluginSettings` (mis. **WTR-LAB**: link login email, mode terjemahan AI/Web+/Web)
mendapat menu **Pengaturan plugin** di layar jelajah. Nilainya disimpan lewat `@libs/storage` dengan
key yang sama seperti aplikasi LNReader, lalu plugin dimuat ulang. Uji live:
`LNR_LIVE=1 flutter test test/lnreader_settings_live_test.dart`.

Bangun ulang runtime / uji semua plugin dari PC (Node 20+):

```bash
cd tool/lnreader_runtime && npm install
node build.mjs                      # → assets/lnreader/runtime.js
node check.mjs --lang "Bahasa Indonesia"   # popular → novel → bab, per plugin
```

Tes engine (`test/lnreader_engine_test.dart`) butuh library QuickJS milik flutter_js. Di Windows,
tambahkan `%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\flutter_js-0.8.7\windows\shared` ke `PATH`;
tanpa itu tes dilewati. Uji live plugin asli lewat engine Dart:
`LNR_LIVE=1 LNR_IDS=IDWN.id,novelfire flutter test test/lnreader_live_test.dart`.

Hasil uji langsung dari PC (13 Nov 2026, `node check.mjs`): **190 dari 371 plugin jalan penuh**
(daftar populer → detail → isi bab). Sisanya gagal di sisi situs: Cloudflare/403/captcha
(umumnya bisa diatasi di HP lewat "Buka di WebView"), domain mati atau sertifikat TLS rusak,
dan daftar kosong (situs berubah atau memblokir; hasilnya sama bila plugin dijalankan di Node biasa).

Kompatibilitas runtime:
- `fetchProto` dari `@libs/fetch` tidak dipakai plugin mana pun (Wuxia World membuat frame protobuf
  sendiri lewat `fetchApi`), jadi tetap ditolak.
- Plugin `webStorageUtilized` (RanobeLib, Linovelib, Novel Fire, Novel Phoenix): **Buka situs di WebView**
  tidak menutup sendiri. Login bila perlu, lalu ketuk Selesai atau kembali. Isi `localStorage`/`sessionStorage`
  disalin ke `<id>_LocalStorage`/`_SessionStorage`, sama seperti LNReader. Dari keempatnya, hanya
  RanobeLib yang benar-benar membacanya (token login).
- Charset: GBK/GB2312/GB18030, Shift_JIS, EUC-JP, windows-125x, dan ISO-8859 didekode lewat paket
  `charset`. EUC-KR tetap UTF-8 karena decoder paket itu salah (tidak ada plugin yang memakainya).
- QuickJS tidak punya `Intl`; runtime menyediakan `Intl.DateTimeFormat`/`NumberFormat` minimal
  (dipakai RanobeLib untuk zona waktu).

## Menjalankan di Android

1. Pasang Flutter SDK (stable) + Android Studio/SDK, lalu cek dengan `flutter doctor`.
2. Buat folder platform Android (file `lib/`, `pubspec.yaml`, dan
   `AndroidManifest.xml` yang sudah ada tidak akan ditimpa):
   ```bash
   cd D:\Coding\mobile\hub_reader
   flutter create --platforms=android --org com.hubreader .
   flutter pub get
   ```
3. Jalankan: `flutter run` (emulator atau HP).
4. Build APK: `flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols` → `build/app/outputs/flutter-apk/app-<abi>-release.apk` (arm64-v8a ±26 MB, armeabi-v7a ±24 MB, x86_64 ±28 MB; tanpa `--split-per-abi` satu APK universal ±73 MB).
5. Tes: `flutter test`.

## Rilis & CI

- **Ikon:** ikon adaptif vektor ada di `android/app/src/main/res/drawable/ic_launcher_*.xml`
  dan `mipmap-anydpi-v26/`, plus PNG untuk Android lama di `mipmap-*`. Versi 512px
  ada di `assets/branding/icon-512.png`. Glyph-nya ikon Material `auto_stories` (Apache-2.0).
- **Signing:** `android/app/build.gradle.kts` membaca `android/key.properties`
  (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`). File ini dan `*.jks`
  di-gitignore. Tanpa `key.properties`, APK release ditandatangani debug key.
  **Simpan cadangan keystore dan password-nya.** Tanpa keduanya, update aplikasi tidak
  bisa dipasang di atas versi lama.
- **Cleartext:** HTTP biasa diizinkan di manifest agar server OPDS di jaringan lokal bisa dipakai; `OpdsClient` menolak HTTP ke host publik (hanya localhost, IP privat, `.local`). Kata sandi server OPDS disimpan di Android Keystore (`flutter_secure_storage`), tidak ikut cadangan.
- **GitHub Actions** (`.github/workflows/android.yml`): setiap push atau PR menjalankan
  `analyze`, `test`, dan build APK release, lalu APK diunggah sebagai artifact
  *hub-reader-apk*. Push tag `v*` (mis. `git tag v1.0.0 && git push --tags`) juga
  melampirkan APK ke GitHub Release.
  CI membangun satu APK per ABI (`hub-reader-<versi>-<abi>.apk`); pembaruan dalam aplikasi memilih APK sesuai ABI perangkat (channel `hub_reader/links`, `abi`). Rilis memuat juga `hub-reader-<versi>.apk` universal, hanya agar tautan unduh di aplikasi versi ≤1.3.0 tidak 404. **Jangan mencampur:** `versionCode` APK per ABI memakai offset (arm64 +2000, armeabi-v7a +1000, x86_64 +4000), jadi APK universal tidak bisa dipasang menimpa APK per ABI yang lebih baru. Pasang selalu APK yang sesuai ABI HP. Simbol debug build obfuscate diunggah sebagai artifact
  *hub-reader-symbols-<sha commit>* (90 hari); pakai `flutter symbolize -i stack.txt -d <folder simbol>`
  untuk membaca stack trace dari APK rilis.
- **Secrets CI** (Settings → Secrets and variables → Actions):
  - `KEYSTORE_BASE64`: isi file `.jks` dalam base64 (`base64 -w0 hub-reader-release.jks`)
  - `KEYSTORE_PASSWORD`: password keystore (store dan key memakai password yang sama)
  - `ANILIST_CLIENT_ID`, `MAL_CLIENT_ID` (opsional): Client ID OAuth bawaan untuk tracker, agar
    pengguna APK rilis bisa langsung login tanpa membuat aplikasi OAuth sendiri

**Kembali prediktif (Android 13+)**: `android:enableOnBackInvokedCallback="true"` di manifest dan `PredictiveBackPageTransitionsBuilder` di tema (`lib/app.dart`). Menggeser dari tepi layar menampilkan pratinjau layar sebelumnya dan animasi penutupan. Di Android lama tombol kembali berjalan seperti biasa. Uji emulator API 37: geser dari tepi di jelajah sumber, dan kembali di onboarding.

**Sinkron tracker dua arah**: di sheet Tracking (menu ⋮ detail seri), tombol **Sinkronkan dari tracker** menarik progres, status, dan jumlah bab dari tiap tracker yang tertaut. Bab lokal bernomor ≤ progres tracker ditandai sudah dibaca (`chapterUrlsToMarkRead`), dan bila progres lokal lebih tinggi, tracker dinaikkan (jadi "Selesai" bila mencapai jumlah bab). Menautkan seri yang sudah ada progresnya di tracker juga langsung menandai bab lokal. Satu tracker gagal tidak menghentikan yang lain. Belum ada: impor seluruh daftar tracker ke library.

**Ubah info seri** (menu ⋮ detail komik/novel → Ubah info, `lib/state/series_overrides.dart`, `library.overrides.v1`): judul, penulis, deskripsi, dan sampul kustom dari galeri/file (maks. 8 MB, disalin ke `files/custom_covers/`). Hanya kolom yang berbeda dari situs yang disimpan, sisanya tetap mengikuti situs; **Setel ulang** menghapus semua perubahan. Berlaku di detail, Favorit, dan Riwayat. Pengaturan ikut cadangan, tetapi file sampul tidak; bila file hilang, sampul kembali ke situs. Belum ikut dipindah saat **Pindah sumber**.

**Tekan lama halaman komik** (`lib/ui/widgets/page_actions.dart`): menu **Simpan ke galeri** (Pictures/Hub Reader lewat MediaStore, tanpa izin penyimpanan di Android 10+; Android 9 ke bawah memakai dialog simpan sistem), **Bagikan halaman**, dan **Jadikan sampul seri** (memakai sampul kustom dari Ubah info). Gambar diambil dari file unduhan atau cache gambar, jadi halaman yang sudah tampil tidak diunduh ulang. Nama berkas `<nama bab>_p<nomor>.<ekstensi>`; ekstensi dikenali dari isi gambar.

**Kunci orientasi** (pengaturan reader komik dan novel → Orientasi layar, `ReaderOrientation` di `lib/core/platform/reader_bridge.dart`): Otomatis (ikut sistem), Potret, atau Lanskap. Dipasang lewat `SystemChrome.setPreferredOrientations` saat reader dibuka dan dikembalikan ke otomatis saat reader ditutup. Komik: `reader.display.v1` (`orient`); novel: `novels.reader.v1` (`orientation`).

**Urutkan antrean unduhan** (layar Unduhan): tarik gagang ≡ di tiap baris antrean untuk memindahkannya; bab antre diunduh sesuai urutan dari atas, jadi menaikkan sebuah bab membuatnya diunduh lebih dulu (bab yang sedang berjalan tetap selesai dulu). Urutan disimpan bersama antrean dan bertahan setelah aplikasi ditutup. Pembaca layar mendapat aksi pindah ke atas/bawah dari `ReorderableListView`.

**Gestur kecerahan** (pengaturan reader komik → Gestur kecerahan, mati secara default, `lib/ui/widgets/brightness_strip.dart`): geser vertikal di strip 44 dp tepi kiri layar mengubah kecerahan jendela (0.05-1, indikator persen saat menggeser) dan menyimpannya ke pengaturan Kecerahan layar. Strip hanya mengambil geseran vertikal, jadi ketuk pinggir untuk pindah halaman tetap jalan; di mode webtoon, menggulir dari tepi kiri 44 dp ikut menjadi gestur kecerahan selama opsi ini aktif.

**Batas cache gambar** (Pengaturan → Penyimpanan, `app.image_cache_mb.v1`, bawaan 500 MB, pilihan 100/250/500/1000/2000 MB atau tanpa batas, `lib/core/net/image_cache.dart`): cache sampul dan halaman komik (`AppImageCache`, menggantikan DefaultCacheManager dengan folder dan database yang sama, batas jumlah file 100.000) dipangkas berdasarkan ukuran. Entri yang paling lama tidak dipakai dibuang saat aplikasi dibuka (setelah 8 detik), setiap aplikasi masuk ke latar, dan langsung saat batas diubah. Catatan teknis: `trimTo` membaca daftar entri lewat `CacheObjectProvider` kedua dan sengaja tidak menutupnya, karena sqflite membagi satu koneksi per berkas dan menutupnya membuat `removeFile` gagal diam-diam.
