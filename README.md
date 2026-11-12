# Hub Reader

Aplikasi Android (Flutter) bergaya Aniyomi untuk membaca **novel** dan **komik**
dari API scraper-hub (`D:\Coding\Web\scraper-hub`, Laravel, `/api/v1`).

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
├── templates/mangathemesia.dart  # template tema WP MangaThemesia (dipakai 29 situs id)
├── id/komiku.dart              # sumber kustom (non-template)
└── registry.dart               # daftar sumber bawaan
lib/state/source_providers.dart # infinite scroll, detail, halaman bab
lib/ui/screens/sources/         # daftar sumber, jelajah, detail, reader
```

**Menambah situs bertema MangaThemesia** cukup satu entri di `registry.dart`:

```dart
MangaThemesiaSource(id: 'id.namasitus', name: 'Nama Situs', baseUrl: 'https://domain.tld'),
```

Opsi: `mangaUrlDirectory: '/komik'`, `pageSelector`, `requestsPerSecond`, `contentWarning`.
Situs dengan struktur lain dibuat sebagai subclass `HttpSource` (contoh: `id/komiku.dart`).
Referensi selector tiap situs ada di keiyoushi/extensions-source
(`src/id/<nama>/` dan `lib-multisrc/<tema>/`).

Catatan port dari Kotlin/Jsoup: package `html` **tidak** mendukung `:contains()`
dan `:has()`. Pakai `whereContains()` atau filter manual.

Batasan saat ini:
- Belum ada bypass Cloudflare. Situs yang meminta verifikasi browser akan menampilkan error.
- Favorit dan riwayat belum mencakup seri dari sumber on-device.
- Filter genre/status per sumber belum ada (baru populer, terbaru, dan pencarian judul).
- Domain situs sering pindah, jadi perbarui `baseUrl` di `registry.dart` bila perlu.

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
- `usesCleartextTraffic="true"` hanya untuk pengembangan; pakai HTTPS di produksi.
