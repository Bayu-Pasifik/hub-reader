import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/update/app_update.dart';
import '../../state/app_update_provider.dart';
import '../../state/core_providers.dart';

/// Dialog "versi baru tersedia". [onLater] dipanggil bila pengguna menunda.
Future<void> showUpdateDialog(
  BuildContext context,
  AppRelease release, {
  String? current,
  VoidCallback? onLater,
}) =>
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        Future<void> open(Uri url) async {
          Navigator.pop(dialogContext);
          final ok = await AppUpdate.open(url);
          if (!ok && context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Tidak ada browser untuk membuka tautan')));
          }
        }

        return AlertDialog(
          icon: const Icon(Icons.system_update_outlined),
          title: Text('Versi ${release.version} tersedia'),
          content: Text(
            [
              if (current != null) 'Terpasang: $current.',
              'APK diunduh lewat browser, lalu pasang di atas versi lama (data tetap ada).',
            ].join('\n'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                onLater?.call();
              },
              child: const Text('Nanti'),
            ),
            TextButton(onPressed: () => open(release.page), child: const Text('Catatan rilis')),
            FilledButton(onPressed: () => open(release.apk), child: const Text('Unduh APK')),
          ],
        );
      },
    );

/// Cek manual dari Pengaturan; hasilnya selalu ditampilkan.
Future<void> checkForUpdatesNow(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  void say(String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  say('Memeriksa pembaruan…');
  final current = await ref.read(appVersionProvider.future);
  final AppRelease? release;
  try {
    release = await AppUpdate.latest();
  } on Object {
    say('Gagal memeriksa pembaruan. Periksa koneksi internet.');
    return;
  }
  await ref.read(sharedPreferencesProvider).setInt(UpdatePolicy.lastCheckKey, DateTime.now().millisecondsSinceEpoch);
  if (!context.mounted) return;
  messenger.hideCurrentSnackBar();
  if (release == null) {
    say('Belum ada rilis di GitHub.');
  } else if (current != null && AppUpdate.compare(release.version, current) <= 0) {
    say('Sudah versi terbaru ($current).');
  } else {
    await showUpdateDialog(context, release, current: current);
  }
}

/// Cek otomatis saat aplikasi dibuka (maks. sekali sehari).
Future<void> autoCheckForUpdates(BuildContext? Function() contextOf, WidgetRef ref) async {
  if (!ref.read(checkUpdatesProvider)) return;
  final prefs = ref.read(sharedPreferencesProvider);
  final current = await ref.read(appVersionProvider.future);
  final release = await UpdatePolicy.autoCheck(prefs, current: current, fetch: AppUpdate.latest);
  if (release == null) return;
  final context = contextOf();
  if (context == null || !context.mounted) return;
  await showUpdateDialog(
    context,
    release,
    current: current,
    onLater: () => UpdatePolicy.skip(prefs, release),
  );
}
