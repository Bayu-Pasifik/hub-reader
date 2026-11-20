<div align="center">

<img src="assets/branding/icon-512.png" alt="Logo Hub Reader" width="120" />

# Hub Reader

**Pembaca komik dan novel untuk Android. Tanpa server, tanpa akun, tanpa iklan.**

[![Android CI](https://github.com/Bayu-Pasifik/hub-reader/actions/workflows/android.yml/badge.svg)](https://github.com/Bayu-Pasifik/hub-reader/actions/workflows/android.yml)
[![Rilis](https://img.shields.io/github/v/release/Bayu-Pasifik/hub-reader)](https://github.com/Bayu-Pasifik/hub-reader/releases/latest)
[![Lisensi: MIT](https://img.shields.io/badge/lisensi-MIT-yellow.svg)](LICENSE)

[Unduh APK](https://github.com/Bayu-Pasifik/hub-reader/releases/latest) · [Situs](https://bayu-pasifik.github.io/hub-reader/) · [Changelog](CHANGELOG.md) · [Privasi](PRIVACY.md)

</div>

Hub Reader bergaya Aniyomi dan Mihon. Aplikasi membaca konten **langsung dari situsnya di HP Anda**, tanpa perantara. Favorit, riwayat, dan unduhan tersimpan di perangkat.

## Fitur

**Membaca**
- **Komik**: 561 sumber dari template ala extension Mihon, ditambah puluhan sumber tulisan tangan (Inggris dan Indonesia). Mode per halaman dan webtoon, zoom, efek pindah halaman, dua halaman di tablet, auto-scroll, gestur kecerahan, dan mode layar penuh.
- **Novel**: plugin [LNReader](https://github.com/lnreader/lnreader-plugins) (371 plugin, 17 bahasa) lewat QuickJS. Pengaturan tipografi, cari di dalam bab, sorot dan catatan, kamus/terjemah, TTS, dan ekspor EPUB.
- **Lokal**: baca komik (CBZ, folder) dan novel (EPUB) dari penyimpanan perangkat, serta server OPDS (Komga, Kavita, Calibre-Web).

**Perpustakaan**
- Favorit dengan kategori, tag, filter, dan enam mode tampilan. "Lanjutkan membaca", cek pembaruan (juga di latar belakang), dan pindah sumber.
- Unduhan dengan antrean, jeda, hanya Wi-Fi, unduh otomatis bab baru, dan ekspor CBZ.
- Tracker: AniList, MyAnimeList, Kitsu, MangaUpdates, dengan sinkron dua arah.
- Cadangan manual dan otomatis, enkripsi AES-256-GCM, WebDAV, sinkron progres antar perangkat, dan impor cadangan Mihon/Tachiyomi.

**Privasi dan kenyamanan**
- Kunci aplikasi (biometrik), blokir screenshot, mode samaran, DNS over HTTPS, dan proxy HTTP.
- Tema neo-brutalism dengan mode gelap, hitam murni, dan Material You. Antarmuka Indonesia dan English.
- Widget layar utama, pintasan ikon, dan gestur kembali prediktif Android 13+.

Sumber 18+ **disembunyikan secara bawaan**. Aktifkan lewat Pengaturan › Sumber › "Tampilkan sumber NSFW (18+)".

## Memasang

1. Buka halaman [Releases](https://github.com/Bayu-Pasifik/hub-reader/releases/latest).
2. Unduh APK sesuai HP Anda. Kebanyakan HP memakai `arm64-v8a`.

   | Berkas | Untuk |
   |---|---|
   | `hub-reader-<versi>-arm64-v8a.apk` | Hampir semua HP modern |
   | `hub-reader-<versi>-armeabi-v7a.apk` | HP 32-bit lama |
   | `hub-reader-<versi>-x86_64.apk` | Emulator dan Chromebook |

3. Izinkan pemasangan dari sumber ini, lalu pasang.4. Pembaruan berikutnya ditawarkan di dalam aplikasi.

Pasang selalu APK yang sesuai ABI HP. APK universal (`hub-reader-<versi>.apk`) hanya ada agar tautan lama tidak rusak dan tidak bisa menimpa APK per ABI.

## Cara kerja

- Aplikasi memuat halaman situs sumber di HP dan mengekstrak daftar judul, bab, dan gambar. Tidak ada server milik pengembang di antaranya.
- Katalog sumber diperbarui dari repo ini tiap 12 jam tanpa perlu memperbarui APK. Anda juga bisa menambah repo katalog sendiri.
- Situs yang meminta verifikasi Cloudflare dibuka lewat WebView, lalu cookie-nya dipakai ulang.
- Sumber yang belum bisa diport dan alasannya ada di [SOURCES_NOT_PORTED.md](SOURCES_NOT_PORTED.md).

## Membangun dari kode

```bash
flutter pub get
flutter run            # emulator atau HP
flutter test
flutter build apk --release --split-per-abi
```

Perlu Flutter stable (Dart `^3.5.0`) dan Android SDK. Arsitektur, struktur folder, penandatanganan, CI, dan catatan tiap fitur ada di [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

## Berkontribusi

Laporan bug, perbaikan, dan sumber baru disambut. Baca [CONTRIBUTING.md](CONTRIBUTING.md) lebih dulu.

## Dokumen lain

| Dokumen | Isi |
|---|---|
| [CHANGELOG.md](CHANGELOG.md) | Riwayat perubahan per versi |
| [PRIVACY.md](PRIVACY.md) | Data yang disimpan dan koneksi yang dibuat aplikasi |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | Dokumentasi teknis rinci |
| [SOURCES_NOT_PORTED.md](SOURCES_NOT_PORTED.md) | Sumber yang belum atau tidak bisa di-port |

## Penafian dan lisensi

Hub Reader hanyalah pembaca. Aplikasi **tidak menyimpan atau menghosting** komik dan novel. Semua konten berasal dari situs pihak ketiga, dan hak ciptanya milik situs atau pemegang haknya. Pengembang tidak berafiliasi dengan situs-situs itu.

Kode dilisensikan [MIT](LICENSE). Template dan selector sumber diport dari [keiyoushi/extensions-source](https://github.com/keiyoushi/extensions-source) (Apache License 2.0), dengan atribusi di kepala tiap berkas hasil port. Plugin novel berasal dari [lnreader/lnreader-plugins](https://github.com/lnreader/lnreader-plugins). Glyph ikon memakai ikon Material `auto_stories` (Apache-2.0).
