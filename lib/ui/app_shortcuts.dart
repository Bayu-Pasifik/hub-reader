import 'package:flutter/foundation.dart';
import 'package:quick_actions/quick_actions.dart';

/// Pintasan ikon aplikasi (tekan lama ikon di launcher Android).
abstract final class AppShortcuts {
  /// Tipe pintasan → lokasi rute. Tab memakai `go`, sisanya `push`.
  static const locations = <String, String>{
    'search_comic': '/source-search',
    'search_novel': '/novel-search',
    'favorites': '/favorites',
    'downloads': '/downloads',
  };

  static const _tabs = {'/favorites'};

  static bool isTab(String location) => _tabs.contains(location);

  static const _items = <ShortcutItem>[
    ShortcutItem(type: 'search_comic', localizedTitle: 'Cari komik'),
    ShortcutItem(type: 'search_novel', localizedTitle: 'Cari novel'),
    ShortcutItem(type: 'favorites', localizedTitle: 'Favorit'),
    ShortcutItem(type: 'downloads', localizedTitle: 'Unduhan'),
  ];

  /// Daftarkan pintasan dan dengarkan pemilihannya. [onLocation] menerima
  /// lokasi rute; [isTab] true bila harus pindah tab (bukan menumpuk layar).
  static Future<void> init(void Function(String location, bool isTab) onLocation) async {
    if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      const quick = QuickActions();
      await quick.initialize((type) {
        final location = locations[type];
        if (location != null) onLocation(location, isTab(location));
      });
      await quick.setShortcutItems(_items);
    } on Object {
      // pintasan opsional
    }
  }
}
