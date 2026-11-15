import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../core/i18n/strings.dart';

/// Isi widget layar utama "Lanjut baca" (lihat ContinueWidgetProvider.kt).
abstract final class HomeWidgetSync {
  static const _androidName = 'ContinueWidgetProvider';

  /// Perbarui widget dengan bacaan terakhir; [link] adalah tautan hubreader://
  /// ke bab itu. Semua null = kosongkan (mis. riwayat dihapus).
  static Future<void> update({String? title, String? subtitle, String? link}) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _saveLabels();
      await HomeWidget.saveWidgetData<String>('continue_title', title);
      await HomeWidget.saveWidgetData<String>('continue_subtitle', subtitle);
      await HomeWidget.saveWidgetData<String>('continue_link', link);
      await HomeWidget.updateWidget(androidName: _androidName);
    } on Object {
      // widget opsional
    }
  }

  /// Teks tetap widget mengikuti bahasa aplikasi (bukan bahasa sistem).
  static Future<void> _saveLabels() async {
    await HomeWidget.saveWidgetData<String>('widget_label', tr('LANJUT BACA'));
    await HomeWidget.saveWidgetData<String>('widget_empty_title', tr('Belum ada bacaan'));
    await HomeWidget.saveWidgetData<String>('widget_empty_subtitle', tr('Buka Hub Reader untuk mulai'));
  }

  /// Perbarui hanya teks tetap (mis. setelah bahasa berganti).
  static Future<void> refreshLabels() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _saveLabels();
      await HomeWidget.updateWidget(androidName: _androidName);
    } on Object {
      // widget opsional
    }
  }
}
