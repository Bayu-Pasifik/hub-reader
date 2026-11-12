# Hub Reader

Aplikasi Android (Flutter) bergaya Aniyomi/Mihon untuk membaca komik.

**Mode saat ini:** fokus ke *sumber on-device*. Aplikasi mengambil konten langsung
dari situs komik, dengan tiga tab: Sumber, Favorit, dan Riwayat. Integrasi API scraper-hub
(`D:\Coding\Web\scraper-hub`, Laravel, `/api/v1`) masih ada di kode tetapi
disembunyikan. Aktifkan lagi dengan:

```bash
flutter run --dart-define=ENABLE_SCRAPER_HUB=true --dart-define=API_KEY=<key>
```

## Struktur folder

```
lib/
├── main.dart                      # init SharedPreferences + cache, ProviderScope
├── app.dart                       # MaterialApp.router + tema
├── core/                          # utilitas lintas fitur
│   ├── config/app_config.dart     # base URL + API key (dart-define / Pengaturan)
│   ├── network/dio_factory.dart   # Dio: timeout, header Accept & X-Api-Key
│   ├── network/api_exception.dart # klasifikasi error + pesan Bahasa Indonesia
│   ├── storage/json_cache.dart    # cache respons API untuk mode offline
│   └── utils/                     # parsing JSON toleran, formatter, URL gambar
├── data/                          # LAPISAN DATA
│   ├── api/scraper_hub_api.dart   # endpoint scraper-hub (JSON mentah)
│   ├── models/                    # Series, Chapter, Paginated, HomeSections, ...
│   ├── repositories/catalog_repository.dart  # network-first + cache fallback
│   └── local/library_store.dart   # favorit & riwayat (SharedPreferences)
├── state/                         # LOGIKA STATE (Riverpod)
│   ├── core_providers.dart        # settings, Dio, API, repository
│   ├── catalog_providers.dart     # home, detail, bab, filter, isi bab
│   ├── browse_provider.dart       # pencarian + infinite scroll
│   └── library_providers.dart     # favorit & riwayat
└── ui/                            # UI
    ├── router.dart                # go_router
    ├── shell/main_shell.dart      # bottom navigation 5 tab
    ├── screens/                   # home, browse, detail, reader, favorit, riwayat, pengaturan
    └── widgets/                   # kartu seri, sampul, error/empty/offline view
test/models_test.dart              # tes parsing JSON sesuai format scraper-hub
test/sources_test.dart             # tes parser HTML sumber on-device
```

## Endpoint yang dipakai

| Fitur | Endpoint | Catatan |
|---|---|---|
| Beranda | `GET /home` | section `novels_recently_updated`, `novels_most_chapters`, `novels_completed`, `comics_recently_updated` |
| Filter | `GET /genres` | genre & status per jenis |
| Daftar/cari | `GET /novels`, `GET /comics` | `search`, `genre`, `status`, `sort=latest\|title\|chapters`, `page`, `per_page≤100` |
| Detail | `GET /{type}/{id}` | `description` + 5 `latest_chapters` hanya di sini |
| Bab | `GET /{type}/{id}/chapters` | paginasi, `per_page≤500`, urut naik |

Semua request mengirim header `X-Api-Key`. Endpoint `auth:sanctum`
(library/history/progress di server) belum dipakai karena favorit & riwayat disimpan lokal.

## Sumber on-device (extension)

Tab **Sumber** membaca komik langsung dari situsnya, tanpa lewat scraper-hub.
Scraping dilakukan di HP (IP pengguna), mirip extension Mihon.

```
lib/sources/
├── source.dart                 # kontrak MangaSource + HttpSource (Dio, header browser, rate limit)
├── models.dart                 # SourceManga, SourceMangaDetails, SourceChapter, MangaPage
├── source_exception.dart       # error situs (Cloudflare, timeout, format berubah)
├── html_utils.dart             # pengganti util Jsoup: absUrl, imgAttr, ownText, parse tanggal/nomor bab
├── templates/mangathemesia.dart  # template tema WP MangaThemesia
├── templates/madara.dart       # template tema WP Madara (AJAX & non-AJAX, 5 mode bab)
├── catalog.dart                # baca assets/sources/catalog.json → instance template
├── id/komiku.dart              # sumber kustom, scraping HTML
├── id/shinigami.dart           # sumber kustom, API JSON (api.shngm.io)
└── registry.dart               # sumber kustom + katalog
assets/sources/catalog.json     # 359 sumber template, dibuat oleh tool/
tool/generate_source_catalog.mjs  # generator katalog dari keiyoushi/extensions-source
lib/state/source_providers.dart # infinite scroll, detail, halaman bab
lib/ui/screens/sources/         # daftar sumber per bahasa, jelajah, detail, reader
```

### Katalog sumber

Semua extension keiyoushi yang memakai template **Madara** (244) atau **MangaThemesia** (115)
masuk otomatis, jadi totalnya 359 sumber dalam 16 bahasa. Tab Sumber mengelompokkannya per
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

Hasil uji langsung ke 359 situs dari PC (12 Nov 2026): **140 jalan penuh** (daftar → detail →
gambar halaman). Sisanya gagal karena tidak bisa terhubung (84: domain mati/pindah atau
diblokir ISP), Cloudflare (64, umumnya bisa diatasi di HP lewat "Buka di WebView"),
situs yang wajib login/password, struktur HTML khusus, atau gambar terenkripsi
(*chapter protector*, belum didukung).

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

## Menjalankan di Android

1. Pasang Flutter SDK (stable) + Android Studio/SDK, lalu cek dengan `flutter doctor`.
2. Buat folder platform Android (file `lib/`, `pubspec.yaml`, dan
   `AndroidManifest.xml` yang sudah ada tidak akan ditimpa):
   ```bash
   cd D:\Coding\mobile\hub_reader
   flutter create --platforms=android --org com.hubreader .
   flutter pub get
   ```
3. Jalankan scraper-hub:
   ```bash
   cd D:\Coding\Web\scraper-hub
   php artisan api:key          # tambahkan hasilnya ke API_KEYS di .env
   php artisan serve --host=0.0.0.0 --port=8000
   ```
   `--host=0.0.0.0` diperlukan bila memakai HP fisik.
4. Jalankan aplikasi:
   ```bash
   # Emulator (10.0.2.2 = localhost komputer)
   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1 --dart-define=API_KEY=<key>

   # HP fisik di Wi-Fi yang sama
   flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000/api/v1 --dart-define=API_KEY=<key>
   ```
   Alamat & key juga bisa diubah dari layar **Pengaturan** (ikon gir di Beranda).
5. Build APK: `flutter build apk --release --dart-define=...` → `build/app/outputs/flutter-apk/app-release.apk`.
6. Tes: `flutter test`.

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
  Build rilis HTTPS saja. Kalau scraper-hub diaktifkan lagi di rilis, pakai HTTPS.
- **GitHub Actions** (`.github/workflows/android.yml`): setiap push atau PR menjalankan
  `analyze`, `test`, dan build APK release, lalu APK diunggah sebagai artifact
  *hub-reader-apk*. Push tag `v*` (mis. `git tag v1.0.0 && git push --tags`) juga
  melampirkan APK ke GitHub Release.
- **Secrets CI** (Settings → Secrets and variables → Actions):
  - `KEYSTORE_BASE64`: isi file `.jks` dalam base64 (`base64 -w0 hub-reader-release.jks`)
  - `KEYSTORE_PASSWORD`: password keystore (store dan key memakai password yang sama)

## TODO / batasan yang diketahui

- **Isi bab belum ada di API.** scraper-hub hanya menyimpan metadata bab (nomor,
  judul, URL sumber, terkunci). Reader saat ini membuka `chapter.url` di WebView.
  Usulan kontrak endpoint ada di `lib/data/models/chapter_content.dart`; setelah
  endpoint dibuat, cukup ubah `CatalogRepository.chapterContent()`. Reader teks
  novel dan reader gambar komik sudah ada.
- **Sampul lokal:** `cover.thumbnail` dibuat dengan `APP_URL`. Bila `APP_URL=localhost`,
  aplikasi menulis ulang host-nya ke host API (`resolveMediaUrl`). Lebih rapi bila
  `APP_URL` di-set ke alamat yang bisa dijangkau HP, lalu `php artisan storage:link`.
- **Sinkronisasi akun** (opsional): login Sanctum + `PUT /library/{type}/{id}` dan
  `POST /{type}/{id}/progress` belum diintegrasikan (lihat TODO di `scraper_hub_api.dart`).
