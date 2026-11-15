## Hub Reader v1.4.0

### Fitur baru
- **Onboarding** untuk instalasi baru: pilih bahasa, ringkasan cara kerja, pengaturan awal (unduh hanya Wi-Fi, sumber 18+, izin notifikasi bab baru). Pengguna lama yang memperbarui tidak melihatnya.
- **Animasi sampul (Hero)** dari jelajah, pencarian global, dan "Mirip ini" ke header detail seri.
- **Cari di dalam bab** pada pembaca novel: sorot semua hasil, penghitung, tombol sebelumnya/berikutnya.
- **Aksesibilitas**: label pembaca layar di reader komik, aksi halaman berikutnya/sebelumnya, tooltip tombol ikon, hormati "Hapus animasi", skala font sistem sampai 2x tanpa overflow.
- **Proxy HTTP** untuk semua koneksi aplikasi (Pengaturan → Jaringan).
- **Reader komik**: zoom ketuk dua kali, kecerahan layar, pra-muat halaman.
- **Library**: urutan dan filter per kategori, balik urutan, unduh bab berikutnya otomatis saat membaca.
- **Laporkan sumber rusak**: membuka isu GitHub terisi, dikirim sendiri oleh pengguna.
- **Blokir screenshot** (Pengaturan → Privasi & keamanan).

### Build dan keamanan
- APK kini per ABI (±26 MB, sebelumnya 73 MB); pembaruan dalam aplikasi memilih APK sesuai perangkat.
- Kode Dart di-obfuscate pada build rilis.
- Sumber komik tidak pernah memakai HTTP polos ke host publik.
- Cadangan otomatis tidak menulis cookie login tanpa enkripsi.
- Kamus/terjemah meminta persetujuan sebelum mengirim teks ke layanan web.

### Catatan
- **Pasang APK yang sesuai ABI HP** (arm64-v8a untuk kebanyakan HP). APK universal hanya untuk tautan unduh versi lama; tidak bisa menimpa APK per ABI.
- Pasang di atas versi lama hanya bila ditandatangani dengan kunci yang sama.
