import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/config/app_config.dart';
import '../../state/app_settings_provider.dart';
import '../../state/core_providers.dart';
import '../../state/download_providers.dart';
import '../widgets/app_lock.dart';

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

  Future<void> _clearImages() async {
    await DefaultCacheManager().emptyCache();
    PaintingBinding.instance.imageCache.clear();
    _snack('Cache gambar dihapus');
    await _measure();
  }

  Future<void> _clearApi() async {
    await ref.read(jsonCacheProvider).clear();
    _snack('Cache data dihapus');
    await _measure();
  }

  Future<void> _clearPlugins() async {
    final dir = await _pluginsDir();
    if (await dir.exists()) await dir.delete(recursive: true);
    _snack('Kode plugin novel dihapus; diunduh lagi saat dibuka');
    await _measure();
  }

  Future<void> _toggleLock(bool on) async {
    // Pastikan perangkat punya kunci layar & pemiliknya yang menyalakan.
    final ok = await AppLockGate.authenticate(on ? 'Nyalakan kunci aplikasi' : 'Matikan kunci aplikasi');
    if (!mounted) return;
    if (!ok) {
      _snack(on ? 'Tidak bisa memverifikasi. Pastikan HP punya PIN/pola/sidik jari.' : 'Verifikasi gagal');
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
          child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        );
    String sizeOf(int? v) => v == null ? 'menghitung…' : _size(v);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        children: [
          header('Tampilan'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('Sistem'), icon: Icon(Icons.brightness_auto)),
                ButtonSegment(value: ThemeMode.light, label: Text('Terang'), icon: Icon(Icons.light_mode)),
                ButtonSegment(value: ThemeMode.dark, label: Text('Gelap'), icon: Icon(Icons.dark_mode)),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (v) => n.update((x) => x.copyWith(themeMode: v.first)),
            ),
          ),
          SwitchListTile(
            title: const Text('Hitam pekat di tema gelap'),
            subtitle: const Text('Hemat baterai di layar OLED'),
            value: s.pureBlack,
            onChanged: (v) => n.update((x) => x.copyWith(pureBlack: v)),
          ),
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
            title: const Text('Kunci aplikasi'),
            subtitle: const Text('Sidik jari / PIN perangkat saat membuka aplikasi'),
            value: s.appLock,
            onChanged: _toggleLock,
          ),
          if (s.appLock)
            ListTile(
              leading: const SizedBox(width: 24),
              title: const Text('Kunci lagi setelah di latar'),
              trailing: DropdownButton<int>(
                value: s.lockAfter.inSeconds,
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Langsung')),
                  DropdownMenuItem(value: 60, child: Text('1 menit')),
                  DropdownMenuItem(value: 300, child: Text('5 menit')),
                  DropdownMenuItem(value: 1800, child: Text('30 menit')),
                ],
                onChanged: (v) => n.update((x) => x.copyWith(lockAfter: Duration(seconds: v ?? 60))),
              ),
            ),
          header('Penyimpanan'),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const Text('Cache gambar'),
            subtitle: Text('${sizeOf(sizes?.images)} · sampul & halaman komik yang pernah dibuka'),
            trailing: TextButton(onPressed: _clearImages, child: const Text('Hapus')),
          ),
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: const Text('Cache data'),
            subtitle: Text('${sizeOf(sizes?.api)} · detail & daftar bab novel untuk offline'),
            trailing: TextButton(onPressed: _clearApi, child: const Text('Hapus')),
          ),
          ListTile(
            leading: const Icon(Icons.extension_outlined),
            title: const Text('Kode plugin novel'),
            subtitle: Text('${sizeOf(sizes?.plugins)} · diunduh lagi saat plugin dibuka'),
            trailing: TextButton(onPressed: _clearPlugins, child: const Text('Hapus')),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Unduhan'),
            subtitle: Text(sizeOf(sizes?.downloads)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await context.push('/downloads');
              _measure();
            },
          ),
          header('Data'),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Cadangkan & pulihkan'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/backup'),
          ),
          if (AppConfig.enableScraperHub)
            ListTile(
              leading: const Icon(Icons.dns_outlined),
              title: const Text('Server scraper-hub'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings'),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
