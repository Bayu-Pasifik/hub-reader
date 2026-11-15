## Hub Reader v1.3.0

### Fitur baru
- **Cadangan WebDAV**: unggah cadangan otomatis atau manual ke Nextcloud, ownCloud, Synology, dan sejenisnya; tes koneksi; pulihkan dari daftar berkas di server.
- **Enkripsi cadangan** (AES-256-GCM, kunci dari kata sandi lewat PBKDF2): opsional untuk cadangan manual, otomatis, dan unggahan WebDAV. Kata sandi yang hilang tidak bisa dipulihkan.
- **Unduh hanya lewat Wi-Fi**, jumlah gambar yang diunduh bersamaan (1-4), dan **pilihan lokasi unduhan** (penyimpanan internal, memori bersama, kartu SD) dengan pemindahan otomatis.
- **Unduh otomatis bab baru** saat cek pembaruan (maks. 20 per cek).
- **Filter scanlator** di detail seri (grup tampil di tiap bab; berlaku juga untuk unduh massal).
- **Tampilan favorit** (grid, grid ringkas, sampul saja, daftar), **Baca acak**, **aturan pembaruan**, dan **ekspor CBZ** dengan `ComicInfo.xml`.
- **Log error lokal** (Pengaturan → Log error): catatan error untuk laporan bug, bisa dibagikan atau dihapus. Tidak pernah dikirim otomatis.
- Terjemahan **English** menyeluruh, plus ilustrasi Lottie untuk keadaan kosong.

### Keamanan dan perbaikan
- APK kini memakai R8 (perkecil dan kaburkan kode).
- WebDAV menolak HTTP polos ke host publik (login Basic tidak terkirim tanpa enkripsi); HTTP hanya diterima untuk jaringan lokal.
- Madara membaca daftar bab dari tautan seri bila markup bab diganti situs; daftar sumber novel menyembunyikan plugin kembar.

### Catatan
- Pasang di atas versi lama hanya bila ditandatangani dengan kunci yang sama; jika gagal, cadangkan data lalu pasang ulang.
- Kamus/terjemah di reader novel mengirim teks terpilih ke layanan web (MyMemory, dictionaryapi.dev).
