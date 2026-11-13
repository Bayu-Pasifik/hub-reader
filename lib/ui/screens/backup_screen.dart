import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_restart.dart';
import '../../data/local/backup.dart';
import '../../state/core_providers.dart';

/// Cadangkan & pulihkan favorit, riwayat, progres baca, dan pengaturan.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _secrets = false;
  bool _busy = false;

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _backup() async {
    setState(() => _busy = true);
    try {
      final data = await AppBackup.create(ref.read(sharedPreferencesProvider), includeSecrets: _secrets);
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
      if (!mounted) return;
      _snack('Cadangan dipulihkan');
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadangan'),
        bottom: _busy ? const PreferredSize(preferredSize: Size.fromHeight(4), child: LinearProgressIndicator()) : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Cadangan berisi favorit (dengan kategori), riwayat, posisi baca, daftar pembaruan, dan '
            'pengaturan. File unduhan tidak ikut.',
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
        ],
      ),
    );
  }
}
