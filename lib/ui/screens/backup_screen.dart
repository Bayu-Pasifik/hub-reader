import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_restart.dart';
import '../../data/local/auto_backup.dart';
import '../../data/local/backup.dart';
import '../../state/background_updates.dart';
import '../../state/core_providers.dart';
import '../../state/novel_providers.dart';

/// Cadangkan & pulihkan favorit, riwayat, progres baca, dan pengaturan.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _secrets = false;
  bool _plugins = true;
  bool _busy = false;
  late Future<List<AutoBackupEntry>> _autoList = AutoBackup.list();

  static String _stamp(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.day}-${d.month}-${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  static String _size(int bytes) =>
      bytes < 1024 * 1024 ? '${(bytes / 1024).toStringAsFixed(0)} KB' : '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _backup() async {
    setState(() => _busy = true);
    try {
      final data = await AppBackup.create(
        ref.read(sharedPreferencesProvider),
        includeSecrets: _secrets,
        plugins: _plugins ? await ref.read(novelRepositoryProvider).exportInstalled() : null,
      );
      final now = DateTime.now();
      String two(int v) => v.toString().padLeft(2, '0');
      final name = 'hub_reader_${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}.json';
      final uri = await FilePicker.saveFile(
        fileName: name,
        bytes: Uint8List.fromList(utf8.encode(jsonEncode(data))),
        mimeType: 'application/json',
        dialogTitle: 'Simpan cadangan',
      );
      if (mounted && uri != null) _snack('Cadangan disimpan: $name');
    } catch (e) {
      if (mounted) _snack('Gagal membuat cadangan: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final files = await FilePicker.pickFiles(dialogTitle: 'Pilih file cadangan');
    if (files.isEmpty || !mounted) return;
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(await files.first.xFile.readAsBytes()));
    } catch (_) {
      _snack('File tidak bisa dibaca sebagai cadangan.');
      return;
    }
    await _confirmRestore(decoded);
  }

  Future<void> _restoreAuto(AutoBackupEntry entry) async {
    Object? decoded;
    try {
      decoded = jsonDecode(await entry.file.readAsString());
    } catch (_) {
      _snack('Cadangan rusak, tidak bisa dibaca.');
      return;
    }
    await _confirmRestore(decoded);
  }

  Future<void> _autoNow() async {
    setState(() => _busy = true);
    try {
      final file = await AutoBackup.run(ref.read(sharedPreferencesProvider), ref.read(novelRepositoryProvider));
      if (mounted) _snack('Cadangan dibuat: ${file.uri.pathSegments.last}');
      setState(() => _autoList = AutoBackup.list());
    } catch (e) {
      if (mounted) _snack('Gagal membuat cadangan: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setAuto(AutoBackupConfig config) async {
    await ref.read(autoBackupProvider.notifier).set(config);
    if (mounted) setState(() => _autoList = AutoBackup.list());
  }

  Future<void> _confirmRestore(Object? decoded) async {
    final summary = AppBackup.inspect(decoded);
    if (summary == null) {
      _snack('Bukan file cadangan Hub Reader.');
      return;
    }
    if (!mounted) return;
    final created = summary.createdAt;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pulihkan cadangan?'),
        content: Text([
          if (created != null)
            'Dibuat ${created.day}-${created.month}-${created.year} '
                '${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}.',
          '${summary.favorites} favorit, ${summary.history} riwayat, ${summary.settings} data/pengaturan.',
          if (summary.plugins > 0)
            '${summary.plugins} plugin novel (dipasang bila belum ada di HP ini). Pulihkan hanya file buatan sendiri: '
                'kode plugin dijalankan aplikasi.',
          summary.secrets
              ? 'Termasuk cookie login & pengaturan plugin.'
              : 'Tanpa cookie login (yang di HP ini tetap dipakai).',
          '\nFavorit, riwayat, progres, dan pengaturan di HP ini akan DIGANTI. Unduhan tidak berubah.',
        ].join('\n')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Pulihkan')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await AppBackup.restore(ref.read(sharedPreferencesProvider), decoded);
      // Jadwal cadangan/cek bab ikut isi cadangan: pasang ulang job-nya.
      final prefs = ref.read(sharedPreferencesProvider);
      await BackgroundUpdates.scheduleBackup(AutoBackupConfig.read(prefs), replace: true);
      await BackgroundUpdates.schedule(BackgroundUpdateConfig.read(prefs), replace: true);
      final plugins = await ref.read(novelRepositoryProvider).importPlugins(AppBackup.novelPlugins(decoded));
      if (!mounted) return;
      _snack(plugins > 0 ? 'Cadangan dipulihkan, $plugins plugin novel dipasang' : 'Cadangan dipulihkan');
      // Bangun ulang aplikasi supaya semua data dibaca ulang.
      AppRestart.restart(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack('Gagal memulihkan: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auto = ref.watch(autoBackupProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadangan'),
        bottom: _busy ? const PreferredSize(preferredSize: Size.fromHeight(4), child: LinearProgressIndicator()) : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Cadangan berisi favorit (dengan kategori), riwayat, posisi baca, daftar pembaruan, '
            'pengaturan (termasuk daftar repo plugin), dan plugin novel terpasang. File unduhan tidak ikut.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Sertakan cookie login & pengaturan plugin'),
                  subtitle: const Text('Berisi sesi login situs; jangan bagikan file ini ke orang lain.'),
                  value: _secrets,
                  onChanged: _busy ? null : (v) => setState(() => _secrets = v),
                ),
                SwitchListTile(
                  title: const Text('Sertakan plugin novel terpasang'),
                  subtitle: const Text('Kode plugin ikut disimpan, jadi sumber tetap bisa dipasang walau repo-nya hilang.'),
                  value: _plugins,
                  onChanged: _busy ? null : (v) => setState(() => _plugins = v),
                ),
                ListTile(
                  leading: const Icon(Icons.save_alt),
                  title: const Text('Buat cadangan'),
                  subtitle: const Text('Simpan file .json ke penyimpanan / Drive'),
                  enabled: !_busy,
                  onTap: _backup,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Pulihkan dari file'),
              subtitle: const Text('Mengganti data di HP ini dengan isi cadangan'),
              enabled: !_busy,
              onTap: _restore,
            ),
          ),
          const SizedBox(height: 24),
          Text('Cadangan otomatis', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Disimpan di folder aplikasi (Android/data/<paket>/files/backups), bisa diambil lewat USB / pengelola file. '
            'Ikut terhapus bila aplikasi dicopot, jadi sesekali salin atau buat cadangan manual ke Drive.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('Jadwal'),
                  trailing: DropdownButton<int>(
                    value: auto.hours,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final h in AutoBackupConfig.choices)
                        DropdownMenuItem(value: h, child: Text(AutoBackupConfig.label(h))),
                    ],
                    onChanged: _busy ? null : (v) => v == null ? null : _setAuto(auto.copyWith(hours: v)),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.layers_outlined),
                  title: const Text('Simpan cadangan terbaru'),
                  trailing: DropdownButton<int>(
                    value: auto.keep,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final k in AutoBackupConfig.keepChoices) DropdownMenuItem(value: k, child: Text('$k file')),
                    ],
                    onChanged: _busy ? null : (v) => v == null ? null : _setAuto(auto.copyWith(keep: v)),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Sertakan plugin novel'),
                  value: auto.plugins,
                  onChanged: _busy ? null : (v) => _setAuto(auto.copyWith(plugins: v)),
                ),
                SwitchListTile(
                  title: const Text('Sertakan cookie login'),
                  subtitle: const Text('Disimpan tanpa enkripsi di folder aplikasi.'),
                  value: auto.secrets,
                  onChanged: _busy ? null : (v) => _setAuto(auto.copyWith(secrets: v)),
                ),
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Cadangkan sekarang'),
                  subtitle: Builder(builder: (_) {
                    final last = AutoBackup.lastRun(ref.read(sharedPreferencesProvider));
                    return Text(last == null ? 'Belum pernah' : 'Terakhir ${_stamp(last)}');
                  }),
                  enabled: !_busy,
                  onTap: _autoNow,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<AutoBackupEntry>>(
            future: _autoList,
            builder: (context, snap) {
              final items = snap.data ?? const <AutoBackupEntry>[];
              if (items.isEmpty) return const SizedBox.shrink();
              return Card(
                child: Column(
                  children: [
                    for (final e in items)
                      ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text(_stamp(e.modified)),
                        subtitle: Text(_size(e.size)),
                        enabled: !_busy,
                        onTap: () => _restoreAuto(e),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Hapus',
                          onPressed: _busy
                              ? null
                              : () async {
                                  try {
                                    await e.file.delete();
                                  } catch (_) {}
                                  if (mounted) setState(() => _autoList = AutoBackup.list());
                                },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
