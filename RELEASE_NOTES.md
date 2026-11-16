## Hub Reader v2.4.0

### Tampilan jelajah & pencarian
- Halaman jelajah komik dan novel bisa ditampilkan dalam enam mode: Grid, Grid ringkas, Sampul saja, Daftar, Daftar ringkas, dan Kartu lebar. Jumlah kolom bisa diatur (1-6 atau otomatis) untuk mode grid.
- Tombol tampilan ada di AppBar jelajah dan pencarian global; pilihannya juga ada di Pengaturan > Tampilan. Komik dan novel disimpan terpisah, tampilan Favorit tidak berubah.
- Hasil pencarian global mengikuti pilihan itu: mode grid jadi baris yang bisa digeser, mode satu kolom jadi daftar ke bawah.

### Perapian UI
- Dialog (server OPDS, WebDAV, enkripsi cadangan) kini punya jarak antar kolom isian.
- Chip di sheet Favorit dan editor info seri tidak lagi menempel saat turun baris.
- Ikon di baris bab, unduhan, repo, dan kategori punya jarak.
- Label bottom nav tidak lagi menempel ke tepi layar, dan aksi AppBar punya margin kanan.

### Catatan
- Penghapusan favorit belum ikut tersinkron antar perangkat (favorit hanya digabung).
- Pasang APK yang sesuai ABI HP (arm64-v8a untuk kebanyakan HP).
- Pasang di atas versi lama hanya bila ditandatangani dengan kunci yang sama.
