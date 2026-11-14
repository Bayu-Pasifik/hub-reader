## Hub Reader v1.2.0

### Fitur baru
- **Server OPDS** (Komga, Kavita, Calibre-Web): jelajahi katalog dengan login Basic, cari, dan unduh EPUB/CBZ langsung ke perpustakaan Lokal. Pengaturan → Server OPDS.
- **Widget layar utama "Lanjut baca"**: menampilkan seri dan bab terakhir; ketuk untuk membukanya.
- **Pintasan ikon aplikasi**: tekan lama ikon untuk Cari komik, Cari novel, Favorit, atau Unduhan.
- **Rekomendasi "Mirip ini"** di detail komik (karya penulis sama dan seri dengan kata judul serupa).
- **Sorot teks dan kamus/terjemah** di reader novel: pilih teks, lalu Sorot atau Kamus (terjemah ke Indonesia/Inggris, definisi untuk kata Inggris).
- **Efek pindah halaman** di reader komik: pudar, zoom, balik halaman.
- **Layar tetap menyala** di reader komik (bisa dimatikan di pengaturan baca).
- **Pilihan bahasa antarmuka** Indonesia/English (baru mencakup layar utama dan pengaturan).

### Catatan
- Lalu lintas HTTP (tanpa TLS) kini diizinkan agar server OPDS di jaringan lokal bisa dipakai.
- Kamus/terjemah mengirim teks terpilih ke layanan web (MyMemory, dictionaryapi.dev).
- Kata sandi server OPDS disimpan di penyimpanan aplikasi tanpa enkripsi tambahan.
