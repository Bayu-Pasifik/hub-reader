# Changelog

Semua perubahan penting pada Hub Reader dicatat di sini. Format mengikuti
[Keep a Changelog](https://keepachangelog.com/id-ID/1.1.0/) dan versi mengikuti
[Semantic Versioning](https://semver.org/lang/id/). Catatan lengkap tiap rilis ada di
[halaman Releases](https://github.com/Bayu-Pasifik/hub-reader/releases).

## [Belum dirilis]

## [3.4.1] - 2026-11-20

### Diperbaiki
- Gambar yang gagal dimuat (halaman reader dan sampul) bisa diketuk untuk dicoba lagi, tanpa keluar dari bab.

### Ditambahkan
- Landing page React bertema neo-brutalism di GitHub Pages.

## [3.4.0] - 2026-11-18

### Ditambahkan
- 15 sumber bahasa Inggris: Sacachispa, NexComic, Schale Scans, Myth Toons, Bbato, Inkora, MyMangaList, KaliScans, StreameX, MyAdultComics, HentaiKun, Pornhwa.me, BabeSource, GirlsTop, Gensura.
- Puluhan sumber lain di sesi yang sama (MangaFox, Mangahere, Mangatown, Tapas, Dynasty Scans, dan lainnya).
- Opsi `noReferer` pada `FnSource` untuk situs yang menolak header Referer.

### Diubah
- Ikon aplikasi baru bergaya neo-brutalist.
- `SOURCES_NOT_PORTED.md` diperbarui dengan alasan tiap sumber yang belum di-port.

## [3.3.0] - 2026-11-17

### Ditambahkan
- Mode layar penuh di pembaca komik dan novel.
- 12 template sumber baru; katalog naik dari 517 menjadi 561 sumber.

## [3.2.0] - 2026-11-17

### Ditambahkan
- Lima template baru (YiiMadara, FoolSlide, Monochrome, Bakkin, Guya); katalog 517 sumber.
- Tujuh sumber Inggris tulisan tangan: MangaPill, TCB Scans, MangaKatana, Weeb Central, Flame Comics, Mangafreak, Asura Scans.

### Diperbaiki
- Gambar Monochrome memakai id seri dan id bab di URL, jadi halaman bab tidak lagi 404.

## [3.1.0] - 2026-11-17

### Ditambahkan
- Template MangaHub, Yiimanga, dan MangaBox; katalog 493 sumber.

### Diperbaiki
- Sampul dan halaman di domain CDN lain tidak lagi ditolak 403; cookie Cloudflare dan User-Agent WebView tidak dikirim ke domain lain.

## [3.0.1] - 2026-11-17

### Diperbaiki
- Notifikasi "Ditambahkan ke favorit" dan "Dihapus dari favorit" hilang otomatis.

## [3.0.0] - 2026-11-17

### Diubah
- Favorit, riwayat, posisi baca, dan penanda hapus disimpan di database SQLite (Drift), bukan JSON di pengaturan. Data 2.x dimigrasi otomatis sekali; data lama tidak dihapus.

### Ditambahkan
- Penghapusan favorit ikut tersinkron lewat WebDAV; sinkron otomatis opsional.
- Baris "Lanjutkan membaca" di tab Favorit.
- Tag favorit dan filter status tracker.
- Catatan pada sorotan novel.

### Diperbaiki
- Layar Cadangan tidak lagi menampilkan galat palsu di build debug.

## [2.4.0] - 2026-11-17

### Ditambahkan
- Enam mode tampilan jelajah dan pencarian (Grid, Grid ringkas, Sampul saja, Daftar, Daftar ringkas, Kartu lebar) dengan jumlah kolom yang bisa diatur.

### Diperbaiki
- Jarak dialog, chip, ikon baris, dan label navigasi bawah.

## [2.3.0] - 2026-11-17

### Ditambahkan
- Sinkron progres baca antar perangkat lewat WebDAV.
- Impor cadangan Mihon/Tachiyomi (`.tachibk`).
- Layar Pembaruan: geser untuk menandai dibaca, "Tandai semua dibaca".
- Log error disamarkan sebelum dibagikan.

### Diubah
- Build rilis bertag gagal bila keystore tidak diatur, agar APK tidak pernah ditandatangani debug key.

## [2.2.0] - 2026-11-17

### Ditambahkan
- Manajer unduhan: jeda/lanjutkan, coba lagi yang gagal, ruang terpakai per seri.
- Pengaturan reader per seri mencakup orientasi, efek pindah halaman, dan filter warna.

## [2.1.0] - 2026-11-17

### Ditambahkan
- Filter Favorit "belum mulai dibaca" dan "terhubung tracker"; urutan "Pembaruan terbaru" dan "Sumber A–Z".

## [2.0.2] - 2026-11-17

### Diubah
- Penyempurnaan tema neo-brutalism: ilustrasi layar kosong berwarna, tombol dengan bayangan keras, label halaman dan indikator kecerahan berupa kotak, pilihan warna novel berupa kotak.

## [2.0.1] - 2026-11-16

### Diubah
- Penyempurnaan tema neo-brutalism: baris sumber berupa kotak bergaris, avatar bulat jadi kotak, ilustrasi layar kosong dibungkus kotak, tab aktif berupa blok kuning.

## [2.0.0] - 2026-11-16

### Diubah
- Desain ulang seluruh aplikasi bergaya neo-brutalism: kertas krem, garis hitam tebal, bayangan keras. Mode gelap, hitam murni, aksen, dan Material You tetap berfungsi.

## [1.6.0] - 2026-11-15

### Ditambahkan
- Template ZManga (CrotPedia, Maid Manga, Mangapoi, Shiro Doujin, OreManga).
- Mirror jsDelivr untuk plugin novel dan daftar repo plugin jarak jauh.

## [1.5.0] - 2026-11-15

### Ditambahkan
- Sinkron tracker dua arah.
- Ubah info seri (judul, penulis, deskripsi, sampul kustom).
- Tekan lama halaman: simpan, bagikan, jadikan sampul.
- Kunci orientasi, gestur kecerahan, urutan antrean unduhan, batas cache gambar.
- Laporkan plugin novel rusak (isu GitHub terisi).
- Gestur kembali prediktif Android 13+.

## [1.4.0] - 2026-11-15

### Ditambahkan
- Onboarding, animasi sampul Hero, cari di dalam bab novel, perbaikan aksesibilitas.
- Proxy HTTP, zoom ketuk dua kali, urutan dan filter per kategori, blokir screenshot.
- Laporkan sumber rusak (isu GitHub terisi).

### Diubah
- APK per ABI (±26 MB, sebelumnya 73 MB) dan kode Dart di-obfuscate.

### Keamanan
- Sumber komik tidak memakai HTTP polos ke host publik; cadangan otomatis tidak menulis cookie login tanpa enkripsi; kamus/terjemah meminta persetujuan.

## [1.3.0] - 2026-11-15

### Ditambahkan
- Cadangan WebDAV dan enkripsi cadangan (AES-256-GCM, PBKDF2).
- Unduh hanya lewat Wi-Fi, lokasi unduhan, unduh otomatis bab baru, filter scanlator, ekspor CBZ.
- Log error lokal dan terjemahan English.

### Keamanan
- R8 untuk APK; WebDAV menolak HTTP polos ke host publik.

## [1.2.0] - 2026-11-14

### Ditambahkan
- Klien server OPDS (Komga, Kavita, Calibre-Web).
- Widget layar utama "Lanjut baca", pintasan ikon aplikasi, rekomendasi "Mirip ini".
- Sorot teks dan kamus/terjemah di reader novel, efek pindah halaman, layar tetap menyala.
- Pilihan bahasa antarmuka Indonesia/English.

## [1.1.0] - 2026-11-14

### Ditambahkan
- DNS over HTTPS (opsional), animasi Lottie, cadangan otomatis berkala, hapus otomatis bab terunduh.
- Pengaturan tipografi novel, zona ketuk, mode dua halaman tablet, auto-scroll webtoon.

### Diubah
- Smart update melewati seri tamat atau belum pernah dibaca.

## [1.0.0] - 2026-11-14

### Ditambahkan
- Rilis pertama: sumber komik on-device, plugin novel LNReader, favorit, riwayat, pencarian global.

[Belum dirilis]: https://github.com/Bayu-Pasifik/hub-reader/compare/v3.4.1...HEAD
[3.4.1]: https://github.com/Bayu-Pasifik/hub-reader/compare/v3.4.0...v3.4.1
[3.4.0]: https://github.com/Bayu-Pasifik/hub-reader/compare/v3.3.0...v3.4.0
[3.3.0]: https://github.com/Bayu-Pasifik/hub-reader/compare/v3.2.0...v3.3.0
[3.2.0]: https://github.com/Bayu-Pasifik/hub-reader/compare/v3.1.0...v3.2.0
[3.1.0]: https://github.com/Bayu-Pasifik/hub-reader/compare/v3.0.1...v3.1.0
[3.0.1]: https://github.com/Bayu-Pasifik/hub-reader/compare/v3.0.0...v3.0.1
[3.0.0]: https://github.com/Bayu-Pasifik/hub-reader/compare/v2.4.0...v3.0.0
[2.4.0]: https://github.com/Bayu-Pasifik/hub-reader/compare/v2.3.0...v2.4.0
[2.3.0]: https://github.com/Bayu-Pasifik/hub-reader/compare/v2.2.0...v2.3.0
[2.2.0]: https://github.com/Bayu-Pasifik/hub-reader/compare/v2.1.0...v2.2.0
[2.1.0]: https://github.com/Bayu-Pasifik/hub-reader/compare/v2.0.2...v2.1.0
[2.0.2]: https://github.com/Bayu-Pasifik/hub-reader/compare/v2.0.1...v2.0.2
[2.0.1]: https://github.com/Bayu-Pasifik/hub-reader/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/Bayu-Pasifik/hub-reader/compare/v1.6.0...v2.0.0
[1.6.0]: https://github.com/Bayu-Pasifik/hub-reader/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/Bayu-Pasifik/hub-reader/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/Bayu-Pasifik/hub-reader/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/Bayu-Pasifik/hub-reader/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/Bayu-Pasifik/hub-reader/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/Bayu-Pasifik/hub-reader/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Bayu-Pasifik/hub-reader/releases/tag/v1.0.0
