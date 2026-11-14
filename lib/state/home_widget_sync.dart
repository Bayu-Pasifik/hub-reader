import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Isi widget layar utama "Lanjut baca" (lihat ContinueWidgetProvider.kt).
abstract final class HomeWidgetSync {
  static const _androidName = 'ContinueWidgetProvider';

  /// Perbarui widget dengan bacaan terakhir; [link] adalah tautan hubreader://
  /// ke bab itu. Semua null = kosongkan (mis. riwayat dihapus).
  static Future<void> update({String? title, String? subtitle, String? link}) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await HomeWidget.saveWidgetData<String>('continue_title', title);
      await HomeWidget.saveWidgetData<String>('continue_subtitle', subtitle);
      await HomeWidget.saveWidgetData<String>('continue_link', link);
      await HomeWidget.updateWidget(androidName: _androidName);
    } on Object {
      // widget opsional
    }
  }
}
