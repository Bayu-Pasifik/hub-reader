import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/net/doh.dart';
import '../../data/local/download_store.dart';
import '../../state/app_settings_provider.dart';
import '../../state/app_update_provider.dart';
import '../../state/core_providers.dart';
import '../../state/download_providers.dart';
import '../../state/novel_providers.dart';
import '../../state/source_providers.dart';
import '../../state/source_settings_provider.dart';
import '../../state/tracker_providers.dart';
import 'tracker_screens.dart';
import '../widgets/app_update_ui.dart';
import '../widgets/app_lock.dart';
import '../../core/i18n/strings.dart';

/// Ukuran folder (byte), 0 bila tidak ada.
Future<int> _dirSize(Directory dir) async {
  var total = 0;
  try {
    if (!await dir.exists()) return 0;
    await for (final e in dir.list(recursive: true, followLinks: false)) {
      if (e is File) total += await e.length();
    }
  } catch (_) {
    // folder berubah saat dihitung
  }
  return total;
}

String _size(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

typedef _CacheSizes = ({int images, int api, int plugins, int downloads});

/// Pengaturan aplikasi: tampilan, privasi & keamanan, penyimpanan.
class AppSettingsScreen extends ConsumerStatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  ConsumerState<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends ConsumerState<AppSettingsScreen> {
  _CacheSizes? _sizes;

  @override
  void initState() {
    super.initState();
    _measure();
  }

  Future<Directory> _imagesDir() async =>
      Directory('${(await getTemporaryDirectory()).path}${Platform.pathSeparator}${DefaultCacheManager.key}');
  Future<Directory> _apiDir() async =>
      Directory('${(await getApplicationCacheDirectory()).path}${Platform.pathSeparator}api_cache');
  Future<Directory> _pluginsDir() async => Directory(
        '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}lnreader${Platform.pathSeparator}plugins',
      );

  Future<void> _measure() async {
    final sizes = (
      images: await _dirSize(await _imagesDir()),
      api: await _dirSize(await _apiDir()),
      plugins: await _dirSize(await _pluginsDir()),
      downloads: await _dirSize(ref.read(downloadStoreProvider).root),
    );
    if (mounted) setState(() => _sizes = sizes);
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  static String _locationLabel(DownloadLocationKind kind) => switch (kind) {
        DownloadLocationKind.internal => tr('Penyimpanan internal (privat)'),
        DownloadLocationKind.shared => tr('Memori bersama (Android/data, bisa diakses lewat USB)'),
        DownloadLocationKind.sdCard => tr('Kartu SD'),
      };

  /// Pilih folder unduhan lalu pindahkan semua unduhan ke sana.
  Future<void> _pickDownloadLocation() async {
    final store = ref.read(downloadStoreProvider);
    if (ref.read(downloadQueueProvider).isNotEmpty) {
      _snack(tr('Tunggu antrean unduhan selesai sebelum memindahkan.'));
      return;
    }
    final options = await DownloadStore.locations();
    if (!mounted) return;
    final current = store.root.absolute.path;
    final picked = await showDialog<DownloadLocation>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(tr('Lokasi unduhan')),
        children: [
          for (final o in options)
            ListTile(
              leading: Icon(o.directory.absolute.path == current ? Icons.radio_button_checked : Icons.radio_button_off),
              title: Text(_locationLabel(o.kind)),
              subtitle: Text(o.directory.path, style: const TextStyle(fontSize: 11)),
              onTap: () => Navigator.pop(context, o),
            ),
        ],
      ),
    );
    if (picked == null || picked.directory.absolute.path == current || !mounted) return;
    final progress = ValueNotifier<(int, int)>((0, 0));
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(tr('Memindahkan unduhan…')),
          content: ValueListenableBuilder<(int, int)>(
            valueListenable: progress,
            builder: (_, p, __) => Column(mainAxisSize: MainAxisSize.min, children: [
              LinearProgressIndicator(value: p.$2 == 0 ? null : p.$1 / p.$2),
              const SizedBox(height: 8),
              Text(p.$2 == 0 ? '' : '${p.$1} / ${p.$2}'),
            ]),
          ),
        ),
      ),
    );
    String? error;
    try {
      await store.moveTo(picked.directory, onProgress: (d, t) => progress.value = (d, t));
    } catch (e) {
      error = '$e';
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    _snack(error == null ? tr('Unduhan dipindahkan') : trp('Gagal memindahkan: {e}', {'e': error}));
    await _measure();
  }

  Future<void> _clearImages() async {
    await DefaultCacheManager().emptyCache();
    PaintingBinding.instance.imageCache.clear();
    _snack(tr('Cache gambar dihapus'));
    await _measure();
  }

  Future<void> _clearApi() async {
    await ref.read(jsonCacheProvider).clear();
    _snack(tr('Cache data dihapus'));
    await _measure();
  }

  Future<void> _clearPlugins() async {
    final orphans = ref.read(novelManifestProvider).valueOrNull?.orphans.length ?? 0;
    if (orphans > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr('Hapus kode plugin?')),
          content: Text(
            trp('{n} plugin sudah hilang dari repo dan tidak bisa diunduh lagi. ', {'n': orphans}) +
                tr('Buat cadangan (dengan plugin) dulu bila masih ingin memakainya.'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Batal'))),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Hapus'))),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    final dir = await _pluginsDir();
    if (await dir.exists()) await dir.delete(recursive: true);
    ref.invalidate(novelManifestProvider);
    _snack(tr('Kode plugin novel dihapus; diunduh lagi saat dibuka'));
    await _measure();
  }

  Future<void> _toggleLock(bool on) async {
    // Pastikan perangkat punya kunci layar & pemiliknya yang menyalakan.
    final ok = await AppLockGate.authenticate(on ? tr('Nyalakan kunci aplikasi') : tr('Matikan kunci aplikasi'));
    if (!mounted) return;
    if (!ok) {
      _snack(on ? tr('Tidak bisa memverifikasi. Pastikan HP punya PIN/pola/sidik jari.') : tr('Verifikasi gagal'));
      return;
    }
    await ref.read(appSettingsProvider.notifier).update((s) => s.copyWith(appLock: on));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appSettingsProvider);
    final n = ref.read(appSettingsProvider.notifier);
    final theme = Theme.of(context);
    final sizes = _sizes;
    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Text(tr(text), style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        );
    String sizeOf(int? v) => v == null ? 'menghitung…' : _size(v);

    return Scaffold(
      appBar: AppBar(title: Text(tr('Pengaturan'))),
      body: ListView(
        children: [
          header(tr('Tampilan')),
          ListTile(
            title: Text(tr('Bahasa')),
            subtitle: Text(tr('Bahasa antarmuka aplikasi')),
            trailing: DropdownButton<AppLanguage>(
              value: s.language,
              onChanged: (v) {
                if (v != null) n.update((x) => x.copyWith(language: v));
              },
              items: [for (final l in AppLanguage.values) DropdownMenuItem(value: l, child: Text(l.label))],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(value: ThemeMode.system, label: Text(tr('Sistem')), icon: Icon(Icons.brightness_auto)),
                ButtonSegment(value: ThemeMode.light, label: Text(tr('Terang')), icon: Icon(Icons.light_mode)),
                ButtonSegment(value: ThemeMode.dark, label: Text(tr('Gelap')), icon: Icon(Icons.dark_mode)),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (v) => n.update((x) => x.copyWith(themeMode: v.first)),
            ),
          ),
          SwitchListTile(
            title: Text(tr('Hitam pekat di tema gelap')),
            subtitle: Text(tr('Hemat baterai di layar OLED')),
            value: s.pureBlack,
            onChanged: (v) => n.update((x) => x.copyWith(pureBlack: v)),
          ),
          SwitchListTile(
            title: Text(tr('Warna dari wallpaper')),
            subtitle: Text(tr('Material You, perlu Android 12 ke atas')),
            value: s.dynamicColor,
            onChanged: (v) => n.update((x) => x.copyWith(dynamicColor: v)),
          ),
          if (!s.dynamicColor)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final a in AppAccent.values)
                  Tooltip(
                    message: a.label,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => n.update((x) => x.copyWith(accent: a)),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: a.color,
                        child: s.accent == a ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          header('Privasi & keamanan'),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: Text(tr('Kunci aplikasi')),
            subtitle: Text(tr('Sidik jari / PIN perangkat saat membuka aplikasi')),
            value: s.appLock,
            onChanged: _toggleLock,
          ),
          if (s.appLock)
            ListTile(
              leading: const SizedBox(width: 24),
              title: Text(tr('Kunci lagi setelah di latar')),
              trailing: DropdownButton<int>(
                value: s.lockAfter.inSeconds,
                items: [
                  DropdownMenuItem(value: 0, child: Text(tr('Langsung'))),
                  DropdownMenuItem(value: 60, child: Text(tr('1 menit'))),
                  DropdownMenuItem(value: 300, child: Text(tr('5 menit'))),
                  DropdownMenuItem(value: 1800, child: Text(tr('30 menit'))),
                ],
                onChanged: (v) => n.update((x) => x.copyWith(lockAfter: Duration(seconds: v ?? 60))),
              ),
            ),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_off_outlined),
            title: Text(tr('Mode samaran')),
            subtitle: Text(tr('Riwayat & posisi baca tidak dicatat')),
            value: s.incognito,
            onChanged: (v) => n.update((x) => x.copyWith(incognito: v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.auto_delete_outlined),
            title: Text(tr('Hapus unduhan yang sudah dibaca')),
            subtitle: Text(tr('Bab yang selesai dibaca dihapus otomatis agar penyimpanan tidak penuh')),
            value: s.autoDeleteRead,
            onChanged: (v) async {
              await n.update((x) => x.copyWith(autoDeleteRead: v));
              if (v) await ref.read(downloadIndexProvider.notifier).purgeRead();
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.download_for_offline_outlined),
            title: Text(tr('Unduh otomatis bab baru')),
            subtitle: Text(tr('Bab baru dari favorit diunduh otomatis saat cek pembaruan (maks. 20 per cek)')),
            value: s.autoDownloadNew,
            onChanged: (v) => n.update((x) => x.copyWith(autoDownloadNew: v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.wifi),
            title: Text(tr('Unduh hanya lewat Wi-Fi')),
            subtitle: Text(tr('Antrean menunggu sampai tersambung Wi-Fi (bukan data seluler)')),
            value: s.downloadWifiOnly,
            onChanged: (v) => n.update((x) => x.copyWith(downloadWifiOnly: v)),
          ),
          ListTile(
            leading: const Icon(Icons.speed_outlined),
            title: Text(tr('Gambar diunduh bersamaan')),
            subtitle: Text(tr('Lebih banyak = lebih cepat, tapi situs bisa memblokir')),
            trailing: DropdownButton<int>(
              value: s.downloadParallel,
              underline: const SizedBox.shrink(),
              items: [for (var i = 1; i <= 4; i++) DropdownMenuItem(value: i, child: Text('$i'))],
              onChanged: (v) => n.update((x) => x.copyWith(downloadParallel: v ?? 2)),
            ),
          ),
          header(tr('Jaringan')),
          ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: Text(tr('DNS over HTTPS (DoH)')),
            subtitle: Text(tr('Opsional. Nyalakan bila situs diblokir provider internet (tanpa VPN)')),
            trailing: DropdownButton<DohProvider>(
              value: ref.watch(dohProviderProvider),
              items: [for (final d in DohProvider.values) DropdownMenuItem(value: d, child: Text(d.label))],
              onChanged: (v) => ref.read(dohProviderProvider.notifier).set(v ?? DohProvider.none),
            ),
          ),
          header(tr('Sumber')),
          SwitchListTile(
            secondary: const Icon(Icons.eighteen_up_rating_outlined),
            title: Text(tr('Tampilkan sumber NSFW (18+)')),
            subtitle: Text(tr('Sumber komik khusus dewasa ikut tampil di daftar')),
            value: ref.watch(showNsfwSourcesProvider),
            onChanged: (v) => ref.read(showNsfwSourcesProvider.notifier).set(v),
          ),
          Builder(builder: (context) {
            final orphans = ref.watch(sourceCatalogStateProvider.select((s) => s.catalog.orphans.length));
            return ListTile(
              leading: const Icon(Icons.collections_bookmark_outlined),
              title: Text(tr('Repo sumber komik')),
              subtitle: Text(
                trp('{n} repo + katalog bawaan', {'n': ref.watch(sourceCatalogReposProvider).length}) +
                (orphans > 0 ? ' · ' + trp('{n} sumber tanpa repo', {'n': orphans}) : ''),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/source-repos'),
            );
          }),
          ListTile(
            leading: const Icon(Icons.hub_outlined),
            title: Text(tr('Repo plugin novel')),
            subtitle: Text(
              trp('{n} repo', {'n': ref.watch(novelReposProvider).length}) +
              ((ref.watch(novelManifestProvider).valueOrNull?.orphans.length ?? 0) > 0 ? ' · ' + trp('{n} plugin tanpa repo', {'n': ref.watch(novelManifestProvider).valueOrNull!.orphans.length}) : ''),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/novel-repos'),
          ),
          header('Tracker'),
          for (final t in ref.watch(trackersProvider)) TrackerSettingsTile(tracker: t),
          header('Penyimpanan'),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: Text(tr('Cache gambar')),
            subtitle: Text('${sizeOf(sizes?.images)} · ${tr('sampul & halaman komik yang pernah dibuka')}'),
            trailing: TextButton(onPressed: _clearImages, child: Text(tr('Hapus'))),
          ),
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: Text(tr('Cache data')),
            subtitle: Text('${sizeOf(sizes?.api)} · ${tr('detail & daftar bab novel untuk offline')}'),
            trailing: TextButton(onPressed: _clearApi, child: Text(tr('Hapus'))),
          ),
          ListTile(
            leading: const Icon(Icons.extension_outlined),
            title: Text(tr('Kode plugin novel')),
            subtitle: Text('${sizeOf(sizes?.plugins)} · ${tr('diunduh lagi saat plugin dibuka')}'),
            trailing: TextButton(onPressed: _clearPlugins, child: Text(tr('Hapus'))),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(tr('Unduhan')),
            subtitle: Text(sizeOf(sizes?.downloads)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await context.push('/downloads');
              _measure();
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(tr('Lokasi unduhan')),
            subtitle: Text(ref.watch(downloadStoreProvider).root.path, style: const TextStyle(fontSize: 12)),
            onTap: _pickDownloadLocation,
          ),
          header('Data'),
          ListTile(
            leading: const Icon(Icons.insights_outlined),
            title: Text(tr('Statistik baca')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/stats'),
          ),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: Text(tr('Server OPDS')),
            subtitle: Text(tr('Komga, Kavita, Calibre-Web: unduh buku & komik')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/opds'),
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: Text(tr('Cadangkan & pulihkan')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/backup'),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: Text(tr('Log error')),
            subtitle: Text(tr('Catatan error lokal untuk laporan bug (tidak dikirim otomatis)')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/crash-log'),
          ),
          header('Tentang'),
          ListTile(
            leading: const Icon(Icons.system_update_outlined),
            title: Text(tr('Periksa pembaruan')),
            subtitle: Text(switch (ref.watch(appVersionProvider)) {
              AsyncData(:final value) when value != null => trp('Versi {value} · dari GitHub Releases', {'value': value}),
              _ => tr('Dari GitHub Releases'),
            }),
            onTap: () => checkForUpdatesNow(context, ref),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.update),
            title: Text(tr('Cek pembaruan otomatis')),
            subtitle: Text(tr('Saat aplikasi dibuka, paling sering sekali sehari')),
            value: ref.watch(checkUpdatesProvider),
            onChanged: (v) => ref.read(checkUpdatesProvider.notifier).set(v),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
