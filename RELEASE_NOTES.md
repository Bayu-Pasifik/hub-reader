## Hub Reader v3.2.0

### Sumber baru
- Katalog bertambah dari 493 menjadi 517 sumber komik lewat lima template baru: **YiiMadara** (7 sumber), **FoolSlide** (11), **Monochrome** dan **Bakkin** (2), serta **Guya** (4).
- Tujuh sumber bahasa Inggris tulisan tangan: **MangaPill**, **TCB Scans**, **MangaKatana**, **Weeb Central**, **Flame Comics**, **Mangafreak**, dan **Asura Scans** (lewat API; bab berbayar disembunyikan, bab dengan gambar teracak belum didukung).
- Beberapa sumber FoolSlide sedang mati di situsnya (timeout atau HTTP 500); itu masalah situs, bukan aplikasi.

### Perbaikan
- Gambar Monochrome kini memakai id seri dan id bab di URL-nya, jadi halaman bab tidak lagi 404.

### Catatan
- Sumber dari template baru hanya muncul setelah memasang APK ini; pembaruan katalog saja tidak cukup.
- Pasang APK yang sesuai ABI HP (arm64-v8a untuk kebanyakan HP).
- Pasang di atas versi lama hanya bila ditandatangani dengan kunci yang sama.

---

## Hub Reader v3.1.0

### Sumber baru
- Katalog bertambah dari 458 menjadi 493 sumber komik.
- Tiga template baru: **MangaHub** (11 sumber, termasuk MangaFox.fun dan MangaHere.onl), **Yiimanga** (12 sumber, termasuk ManhwaGalaxy dan ToonGod), dan **MangaBox** (Mangabat, Mangakakalot, Manganelo).
- 11 sumber lain ikut masuk dari katalog terbaru, dan 2 yang sudah dihapus situsnya dibuang. Domain 6 sumber diperbarui.
- Sebagian sumber baru masih bermasalah: Fastest Manga dan Ranker-Manga belum bisa dibuka, dan beberapa lain minta verifikasi Cloudflare (ketuk Buka di WebView).

### Perbaikan
- Sampul dan halaman komik yang gambarnya ada di domain lain dari situsnya (CDN) tidak lagi ditolak 403. Cookie Cloudflare dan User-Agent WebView tidak dikirim ke domain lain.

### Catatan
- Pasang APK yang sesuai ABI HP (arm64-v8a untuk kebanyakan HP).
- Pasang di atas versi lama hanya bila ditandatangani dengan kunci yang sama.

---

## Hub Reader v3.0.1

### Perbaikan
- Notifikasi "Ditambahkan ke favorit" (tombol Kategori) dan "Dihapus dari favorit" (tombol Urungkan) kini hilang otomatis setelah beberapa detik, tidak lagi menempel di layar.

---

## Hub Reader v3.0.0

### Penyimpanan baru (database)
- Favorit, riwayat, posisi baca, dan penanda hapus kini disimpan di database SQLite, bukan lagi JSON di pengaturan. Lebih tahan data besar dan lebih aman dari kerusakan.
- Data dari versi 2.x dipindahkan otomatis sekali saat pertama dibuka. Data lama tidak dihapus sebagai cadangan.
- Format file cadangan tidak berubah: cadangan lama tetap bisa dipulihkan, dan cadangan baru tetap bisa dibaca versi 2.x.
- Bila database gagal dibuka, aplikasi kembali memakai penyimpanan lama, bukan crash.

### Sinkron antar perangkat
- Menghapus favorit kini ikut tersinkron lewat WebDAV. Memfavoritkan ulang atau menekan Urungkan tetap menang atas penghapusan lama.
- Sinkron otomatis (opsional, mati secara bawaan): favorit dan progres disinkronkan saat aplikasi dibuka atau kembali aktif, dengan jeda minimal 10 menit. Aktifkan di Cadangan, setelah WebDAV diatur.

### Fitur baru
- Lanjutkan membaca: baris di atas tab Favorit berisi bab terakhir dari komik dan novel, satu ketukan untuk kembali membaca.
- Tag favorit: beri label bebas pada tiap favorit, filter per tag, dan cari lewat tag.
- Filter status tracker di Favorit: Sedang dibaca, Selesai, Ditunda, Berhenti, Rencana, Baca ulang.
- Catatan pada sorotan novel: pilih teks lalu pilih Catatan.

### Perbaikan
- Layar Cadangan tidak lagi menampilkan galat palsu di build debug setelah cadangan otomatis berhasil.

### Catatan
- Setelah migrasi, perubahan baru hanya masuk ke database. Bila kembali ke versi 2.x, data yang dibuat setelah migrasi tidak terlihat di sana.
- Pasang APK yang sesuai ABI HP (arm64-v8a untuk kebanyakan HP).
- Pasang di atas versi lama hanya bila ditandatangani dengan kunci yang sama.
