# Berkontribusi ke Hub Reader

Terima kasih sudah mau membantu. Dokumen ini merangkum cara menjalankan proyek, aturan kode, dan alur menambah sumber.

## Menyiapkan lingkungan

1. Pasang Flutter SDK (stable, Dart `^3.5.0`) dan Android SDK, lalu cek dengan `flutter doctor`.
2. Ambil dependensi: `flutter pub get`.
3. Jalankan di emulator atau HP: `flutter run`.
4. Bila mengubah tabel Drift (`lib/data/local/library_db.dart`), buat ulang kode: `dart run build_runner build --delete-conflicting-outputs`.

Petunjuk build APK dan penandatanganan ada di bagian "Menjalankan di Android" dan "Rilis & CI" pada [README](README.md).

## Sebelum membuka pull request

Jalankan semuanya dan pastikan lulus, karena CI menjalankan hal yang sama:

```bash
flutter analyze --no-fatal-infos
flutter test
```

- Gaya kode mengikuti `flutter_lints` plus `prefer_const_constructors` dan `prefer_final_locals` (lihat `analysis_options.yaml`).
- Jangan menambah import yang tidak terpakai. CI pernah gagal karena itu.
- Satu PR untuk satu perubahan. Tambahkan tes untuk perbaikan bug dan perilaku baru.
- Teks antarmuka baru ditambahkan ke dua bahasa: `lib/core/i18n/strings.dart` (Indonesia) dan `strings_en.dart` (English).
- Pesan commit memakai [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `chore:`, `test:`, `refactor:`.
- Perubahan yang terlihat pengguna dicatat di bagian `[Belum dirilis]` pada [CHANGELOG.md](CHANGELOG.md).

## Menambah atau memperbaiki sumber komik

1. Cek `SOURCES_NOT_PORTED.md` untuk sumber yang sudah diketahui dan alasan belum di-port.
2. Bila situs memakai tema yang sudah ada (Madara, MangaThemesia, dan lainnya di `lib/sources/templates/`), cukup tambahkan entri katalog. Katalog dibuat oleh `tool/generate_source_catalog.mjs` dan disimpan di `assets/sources/catalog.json`.
3. Untuk situs kustom, buat sumber Dart di `lib/sources/en/` atau `lib/sources/id/`, lalu daftarkan di `lib/sources/registry.dart`.
4. Uji di data nyata: daftar, pencarian, detail, daftar bab, dan **gambar halaman** (cek juga Referer dan CDN). Sumber yang gambarnya diblokir (403, Cloudflare, Turnstile) jangan digabung. Catat alasannya di `SOURCES_NOT_PORTED.md`.
5. Tambahkan tes parser dengan HTML atau JSON contoh di `test/`. Jangan membuat tes CI bergantung pada jaringan.
6. Jangan melewati proteksi akses (login berbayar, DRM, penghindaran paywall). Sumber seperti itu tidak akan diterima.

Plugin novel memakai runtime LNReader (QuickJS); bahan pembangunnya ada di `tool/lnreader_runtime/`.

## Melaporkan masalah

- Buka isu di https://github.com/Bayu-Pasifik/hub-reader/issues.
- Sertakan versi aplikasi, versi Android, model HP, langkah mengulang, dan sumber yang bermasalah.
- Dari aplikasi, tombol "Laporkan sumber rusak" membuka isu yang sudah terisi. Log error (Pengaturan → Log error) boleh dilampirkan; data sensitif sudah disamarkan, tapi tetap periksa sebelum mengirim.
- Kerentanan keamanan: jangan dipublikasikan di isu terbuka. Kirim pesan pribadi ke pemilik repo lewat profil GitHub.

## Rilis (untuk pemelihara)

1. Naikkan `version` di `pubspec.yaml` (nomor setelah `+` selalu naik).
2. Tulis catatan di `RELEASE_NOTES.md`. Berkas ini dipakai CI sebagai isi GitHub Release, jadi isinya hanya untuk versi yang sedang dirilis.
3. Pindahkan entri `[Belum dirilis]` di `CHANGELOG.md` ke versi baru dan perbarui tautan di dasar berkas.
4. Commit `chore: rilis vX.Y.Z`, buat tag `vX.Y.Z`, lalu push beserta tag. CI membangun APK per ABI dan melampirkannya ke Release. Build bertag gagal bila keystore belum diatur di GitHub Secrets.

## Lisensi

Dengan mengirim kontribusi, Anda setuju kontribusi itu dilisensikan di bawah [MIT](LICENSE).
