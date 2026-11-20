# Kebijakan Privasi / Privacy Policy

Berlaku untuk aplikasi Android **Hub Reader**. Terakhir diperbarui: 2026-11-20.

## Ringkasan

- Hub Reader **tidak punya server**, **tidak memakai analitik**, dan **tidak mengirim data pemakaian atau laporan crash** ke pengembang.
- Favorit, riwayat, progres baca, unduhan, dan pengaturan disimpan **hanya di perangkat Anda**.
- Aplikasi tidak meminta akun. Login hanya diperlukan bila Anda sendiri menghubungkan tracker, server WebDAV, atau server OPDS.

## Data yang disimpan di perangkat

| Data | Tempat | Catatan |
|---|---|---|
| Favorit, kategori, tag, riwayat, posisi baca | Database SQLite aplikasi | Ikut cadangan bila Anda membuatnya |
| Unduhan bab dan cache gambar | Penyimpanan aplikasi atau lokasi unduhan yang Anda pilih | Batas cache gambar bisa diatur |
| Pengaturan, cookie verifikasi situs | Penyimpanan aplikasi | Cookie login tidak ditulis ke cadangan otomatis tanpa enkripsi |
| Token tracker | Penyimpanan aplikasi | Dapat dihapus dengan keluar dari tracker |
| Kata sandi server OPDS | Android Keystore (`flutter_secure_storage`) | Tidak ikut cadangan |
| Log error | Berkas lokal | Tidak pernah dikirim otomatis; data sensitif disamarkan sebelum dibagikan |

Menghapus data aplikasi atau mencopot pemasangan menghapus semua data di atas.

## Koneksi jaringan

Aplikasi hanya terhubung ke layanan di bawah ini, sesuai fitur yang Anda pakai. Permintaan keluar dari perangkat Anda langsung ke layanan itu, tanpa perantara milik pengembang.

- **Situs sumber komik dan novel** yang Anda buka. Situs tersebut dapat melihat alamat IP dan header peramban Anda, seperti pada pemakaian peramban biasa. Kebijakan privasi mereka berlaku.
- **GitHub dan jsDelivr**: memeriksa pembaruan aplikasi, katalog sumber, daftar repo plugin novel, dan manifest plugin.
- **Tracker (opsional)**: AniList, MyAnimeList, Kitsu, MangaUpdates. Data yang dikirim berupa token login, judul seri, status, dan progres baca yang Anda tautkan.
- **WebDAV (opsional)**: berkas cadangan dan data sinkron progres dikirim ke server yang Anda tentukan. Anda dapat mengenkripsi cadangan (AES-256-GCM); kata sandi yang hilang tidak bisa dipulihkan.
- **Server OPDS (opsional)**: Komga, Kavita, Calibre-Web, atau sejenisnya, sesuai alamat yang Anda masukkan.
- **Kamus dan terjemah (opsional)**: teks yang Anda pilih di pembaca novel dikirim ke MyMemory dan dictionaryapi.dev. Aplikasi meminta persetujuan Anda sebelum mengirim.
- **DNS over HTTPS (opsional, mati secara bawaan)**: bila diaktifkan, kueri DNS dikirim ke penyedia yang Anda pilih (Cloudflare, Google, AdGuard, dan lainnya).
- **Proxy HTTP (opsional)**: bila diatur, semua koneksi aplikasi lewat proxy yang Anda tentukan.

## Laporan masalah

Tombol "Laporkan sumber rusak" dan "Laporkan plugin rusak" hanya **membuka halaman isu GitHub yang sudah terisi**. Tidak ada yang terkirim sebelum Anda memeriksa dan mengirimnya sendiri.

## Izin Android

- `INTERNET`, `ACCESS_NETWORK_STATE`: mengambil konten dan mengatur unduhan hanya lewat Wi-Fi.
- `POST_NOTIFICATIONS`: pemberitahuan bab baru dan progres unduhan (opsional).
- `USE_BIOMETRIC`: kunci aplikasi (opsional).
- Akses berkas lewat pemilih berkas sistem saat Anda mengimpor atau mengekspor cadangan, EPUB, atau CBZ.

## Anak-anak

Aplikasi memuat sumber yang dapat berisi konten dewasa. Sumber 18+ disembunyikan sampai Anda mengaktifkannya di pengaturan. Aplikasi tidak ditujukan bagi anak di bawah usia yang diizinkan untuk konten tersebut.

## Penafian konten

Hub Reader hanyalah pembaca. Aplikasi **tidak menyimpan, menghosting, atau mendistribusikan** komik maupun novel. Semua konten berasal dari situs pihak ketiga yang Anda akses sendiri. Pengembang tidak berafiliasi dengan situs-situs itu dan tidak bertanggung jawab atas isinya. Pastikan pemakaian Anda sesuai hukum dan ketentuan situs terkait.

## Perubahan

Perubahan kebijakan dicatat di berkas ini dan di [CHANGELOG.md](CHANGELOG.md) bila berkaitan dengan fitur.

## Kontak

Buka isu di https://github.com/Bayu-Pasifik/hub-reader/issues.
