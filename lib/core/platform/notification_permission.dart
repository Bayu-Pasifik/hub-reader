import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Izin notifikasi (Android 13+) untuk pemberitahuan bab baru.
abstract final class NotificationPermission {
  static AndroidFlutterLocalNotificationsPlugin? _android() {
    if (!Platform.isAndroid) return null;
    return FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  }

  /// true = sudah diizinkan, false = ditolak/dimatikan, null = tidak bisa diketahui.
  static Future<bool?> isGranted() async {
    try {
      return await _android()?.areNotificationsEnabled();
    } catch (_) {
      return null;
    }
  }

  /// Tampilkan dialog izin sistem. Hasilnya sama dengan [isGranted] setelahnya.
  static Future<bool?> request() async {
    try {
      return await _android()?.requestNotificationsPermission();
    } catch (_) {
      return null;
    }
  }
}
