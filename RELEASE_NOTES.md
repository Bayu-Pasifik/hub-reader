## Hub Reader v2.3.0

### Sinkron & impor
- Sinkron progres baca antar perangkat lewat WebDAV: favorit, riwayat, dan posisi baca digabung per item (cap waktu terbaru menang). Menu: Cadangkan & pulihkan, bagian Cadangan WebDAV, Sinkronkan progres baca.
- Impor cadangan Mihon/Tachiyomi (.tachibk): favorit, kategori, status baca, dan riwayat. Sumber dicocokkan lewat nama; seri dari sumber yang tidak ada dilewati dan namanya ditampilkan.

### Pembaruan & verifikasi
- Layar Pembaruan: geser baris ke kanan untuk menandai dibaca, dan menu "Tandai semua dibaca".
- Verifikasi Cloudflare di WebView mengenali judul halaman tantangan dalam beberapa bahasa.

### Privasi & rilis
- Log error disamarkan sebelum dibagikan (email, token di URL, header Cookie/Authorization, nama pengguna di path).
- Build rilis bertag di CI gagal bila keystore tidak diatur, agar APK tidak pernah ditandatangani debug key.

### Catatan
- Penghapusan favorit belum ikut tersinkron antar perangkat (favorit hanya digabung).
- Pasang APK yang sesuai ABI HP (arm64-v8a untuk kebanyakan HP).
- Pasang di atas versi lama hanya bila ditandatangani dengan kunci yang sama.
