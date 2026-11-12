/// Konfigurasi koneksi ke scraper-hub.
///
/// Nilai default diambil dari `--dart-define` saat build/run:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1 \
///               --dart-define=API_KEY=xxxx
/// Nilai ini bisa ditimpa dari layar Pengaturan (disimpan di SharedPreferences).
class AppConfig {
  const AppConfig({required this.baseUrl, required this.apiKey});

  /// Fitur scraper-hub (Beranda, Jelajah, Pengaturan server) sedang
  /// disembunyikan; aplikasi fokus ke sumber on-device. Aktifkan lagi dengan
  /// `--dart-define=ENABLE_SCRAPER_HUB=true`.
  static const bool enableScraperHub = bool.fromEnvironment('ENABLE_SCRAPER_HUB');

  /// 10.0.2.2 = alamat "localhost" komputer host bila dilihat dari emulator Android.
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  /// Salah satu nilai `API_KEYS` di .env scraper-hub (buat dengan `php artisan api:key`).
  static const String defaultApiKey = String.fromEnvironment('API_KEY');

  factory AppConfig.fromDefines() =>
      const AppConfig(baseUrl: defaultBaseUrl, apiKey: defaultApiKey);

  final String baseUrl;
  final String apiKey;

  bool get hasApiKey => apiKey.trim().isNotEmpty;

  /// Dio menggabungkan baseUrl + path, jadi baseUrl harus diakhiri "/".
  String get normalizedBaseUrl {
    final trimmed = baseUrl.trim();
    return trimmed.endsWith('/') ? trimmed : '$trimmed/';
  }

  /// scheme://host:port dari server API. Dipakai untuk memperbaiki URL gambar
  /// yang dibuat Laravel dengan APP_URL=localhost (tidak terjangkau dari HP).
  Uri? get origin {
    final uri = Uri.tryParse(baseUrl.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
    );
  }

  AppConfig copyWith({String? baseUrl, String? apiKey}) => AppConfig(
        baseUrl: baseUrl ?? this.baseUrl,
        apiKey: apiKey ?? this.apiKey,
      );

  @override
  bool operator ==(Object other) =>
      other is AppConfig && other.baseUrl == baseUrl && other.apiKey == apiKey;

  @override
  int get hashCode => Object.hash(baseUrl, apiKey);
}
