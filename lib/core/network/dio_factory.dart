import 'package:dio/dio.dart';

import '../config/app_config.dart';

/// Membuat instance Dio dengan timeout dan header yang dibutuhkan scraper-hub.
Dio createDio(AppConfig config) {
  return Dio(
    BaseOptions(
      baseUrl: config.normalizedBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
      headers: {
        // Tanpa ini Laravel bisa membalas redirect/HTML alih-alih JSON.
        'Accept': 'application/json',
        if (config.hasApiKey) 'X-Api-Key': config.apiKey.trim(),
      },
    ),
  );
}
