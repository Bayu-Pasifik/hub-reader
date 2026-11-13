# Hub Reader

Aplikasi Android (Flutter) bergaya Aniyomi/Mihon untuk membaca komik dan novel.

Aplikasi mengambil konten langsung dari situsnya di perangkat (tanpa server), dengan
empat tab: Komik (sumber on-device), Novel (plugin LNReader), Favorit, dan Riwayat.

## Struktur folder

```
lib/
├── main.dart, bootstrap.dart      # buka SharedPreferences, cache, katalog sumber, ProviderScope
├── app.dart                       # MaterialApp.router + tema + kunci aplikasi
├── core/                          # utilitas lintas fitur (cache JSON, parsing, bridge Android)
├── data/                          # penyimpanan lokal: favorit/riwayat, unduhan, cadangan
├── sources/                       # sumber komik on-device (template Madara, MangaThemesia, ...)
├── novels/                        # plugin LNReader (QuickJS), EPUB lokal & ekspor
├── trackers/                      # AniList & MyAnimeList
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
├── catalog.dart                # baca assets/sources/catalog.json → instance template
├── id/komiku.dart              # sumber kustom, scraping HTML
├── id/shinigami.dart           # sumber kustom, API JSON (api.shngm.io)
└── registry.dart               # sumber kustom + katalog
assets/sources/catalog.json     # 453 sumber template, dibuat oleh tool/
tool/generate_source_catalog.mjs  # generator katalog dari keiyoushi/extensions-source
lib/state/source_providers.dart # infinite scroll, detail, halaman bab
lib/ui/screens/sources/         # daftar sumber per bahasa, jelajah, detail, reader
```

### Katalog sumber

Semua extension keiyoushi yang memakai template yang sudah di-port masuk otomatis:
**Madara** (244), **MangaThemesia** (115), **ZeistManga** (33), **Keyoapp** (16), **VineTheme** (6), **MangaCatalog** (18), **Iken** (9), LoneSeal (5),
NatsuId (3), Hwalumi (2), dan ColorlibAnime (2), jadi totalnya 453 sumber dalam 16 bahasa.
Keyoapp (12 Nov 2026): 11 dari 16 situs English jalan penuh; 3 di balik Cloudflare
(Meitoon, Luna Toons, Kaizen Scans) dan 2 sedang down (Mist Scans, Grim Scans). VineTheme: 6 dari 6
jalan penuh (Drake, Elf Toon, Kayn, Kero, Valir, Diva Scans). MangaCatalog: 17 dari 18 situs
jalan dengan semua judulnya (Read Black Clover tidak bisa dihubungi). Iken: 5 dari 9 jalan (Hive,
Ken, Magus, Vortex, dan Azora berbahasa Arab); Nyx & Hijala di balik Cloudflare, Orion & Sana 502. Tab Sumber mengelompokkannya per
bahasa, lengkap dengan chip filter bahasa dan pencarian. Sumber 18+ disembunyikan secara
default; aktifkan lewat menu ⋮ → "Tampilkan sumber 18+".

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
  file lokal bila babnya lengkap terunduh. Antrean hanya ada di memori, jadi bab yang
  belum selesai hilang dari antrean saat aplikasi ditutup dan perlu diunduh ulang.
- Domain situs sering pindah. Ketuk ikon gir di tab Sumber untuk mengganti domain tanpa
  build ulang (ada tombol Tes koneksi). Host lama diingat, jadi URL favorit, riwayat, dan
  unduhan dari domain lama otomatis dialihkan (`HttpSource.rewriteToCurrentHost`).
  Progres baca per bab terikat ke URL bab, jadi bab yang dimuat ulang dari domain baru
  dianggap bab berbeda.

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

**Pindah sumber** (menu ⋮ di detail seri, atau tekan lama sampul favorit): judul dicari di sumber lain
sebahasa (atau plugin yang pernah dibuka), lalu favorit, kategori, tanda sudah dibaca (dicocokkan lewat
nomor bab) dan bab terakhir dibaca dipindah ke sumber pilihan. Favorit lama bisa disimpan atau dihapus.

**Cadangan** (Favorit → ⋮ → Cadangkan & pulihkan): semua SharedPreferences (favorit + kategori,
riwayat, posisi baca, pengaturan) dan daftar pembaruan disimpan ke satu file `.json` lewat pemilih file
Android (`file_picker`). Cookie login & penyimpanan plugin novel hanya ikut bila diaktifkan; unduhan
tidak ikut. Memulihkan mengganti data di HP lalu membangun ulang aplikasi (`AppRestart`).

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

Batasan: `fetchProto` (1 plugin) belum didukung; plugin yang butuh login/WebView storage
(`webStorageUtilized`) dan `pluginSettings` belum punya UI; charset non-UTF-8 selain Latin-1
didekode sebagai UTF-8.

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
4. Build APK: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`.
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
- **Cleartext:** HTTP biasa hanya diizinkan di build debug (`src/debug/AndroidManifest.xml`).
  Build rilis HTTPS saja.
- **GitHub Actions** (`.github/workflows/android.yml`): setiap push atau PR menjalankan
  `analyze`, `test`, dan build APK release, lalu APK diunggah sebagai artifact
  *hub-reader-apk*. Push tag `v*` (mis. `git tag v1.0.0 && git push --tags`) juga
  melampirkan APK ke GitHub Release.
- **Secrets CI** (Settings → Secrets and variables → Actions):
  - `KEYSTORE_BASE64`: isi file `.jks` dalam base64 (`base64 -w0 hub-reader-release.jks`)
  - `KEYSTORE_PASSWORD`: password keystore (store dan key memakai password yang sama)
  - `ANILIST_CLIENT_ID`, `MAL_CLIENT_ID` (opsional): Client ID OAuth bawaan untuk tracker, agar
    pengguna APK rilis bisa langsung login tanpa membuat aplikasi OAuth sendiri
