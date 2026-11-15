# Flutter + plugin sudah membawa aturan consumer sendiri. Tambahan di sini
# hanya untuk yang dipakai lewat refleksi/JNI.

# flutter_js (QuickJS lewat JNI)
-keep class io.abner.flutter_js.** { *; }

# flutter_secure_storage / Tink
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**

# Widget layar utama dan channel di MainActivity
-keep class com.hubreader.hub_reader.** { *; }

# Play Core tidak dipakai (deferred components dimatikan)
-dontwarn com.google.android.play.core.**
