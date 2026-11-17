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
