import 'dart:convert';
import '../../core/i18n/strings.dart';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_restart.dart';
import '../../data/local/auto_backup.dart';
import '../../data/local/backup.dart';
import '../../data/local/backup_crypto.dart';
import '../../data/local/webdav_backup.dart';
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
  WebDavConfig _dav = const WebDavConfig();

  @override
  void initState() {
    super.initState();
    WebDavConfig.read(ref.read(sharedPreferencesProvider)).then((c) {
      if (mounted) setState(() => _dav = c);
    });
  }

  Future<void> _saveDav(WebDavConfig config) async {
    setState(() => _dav = config);
    await config.write(ref.read(sharedPreferencesProvider));
  }

  Future<void> _davDialog() async {
    final url = TextEditingController(text: _dav.url);
    final user = TextEditingController(text: _dav.username);
    final pass = TextEditingController(text: _dav.password);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('WebDAV'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: url,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: tr('Alamat folder'),
                hintText: 'https://cloud.example.com/remote.php/dav/files/me/HubReader',
              ),
            ),
            TextField(controller: user, decoration: InputDecoration(labelText: tr('Nama pengguna'))),
            TextField(
              controller: pass,
              obscureText: true,
              decoration: InputDecoration(labelText: tr('Kata sandi')),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Batal'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Simpan'))),
        ],
      ),
    );
    if (ok == true) {
      await _saveDav(_dav.copyWith(url: url.text.trim(), username: user.text.trim(), password: pass.text));
    }
  }

  Future<void> _davTest() async {
    setState(() => _busy = true);
    try {
      await WebDavClient(_dav).test();
      if (mounted) _snack(tr('Terhubung ke WebDAV'));
    } catch (e) {
      if (mounted) _snack(trp('Gagal: {e}', {'e': e}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _davUploadNow() async {
    setState(() => _busy = true);
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final cfg = AutoBackupConfig.read(prefs);
      final data = await AppBackup.create(
        prefs,
        includeSecrets: cfg.secrets,
        plugins: cfg.plugins ? await ref.read(novelRepositoryProvider).exportInstalled() : null,
      );
      final now = DateTime.now();
      String two(int v) => v.toString().padLeft(2, '0');
      final name = 'hub_reader_auto_${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}.json';
      await AutoBackup.uploadToWebDav(prefs, name, utf8.encode(await BackupCrypto.encode(data, password: await AutoBackup.autoPassword(prefs))), keep: cfg.keep, force: true);
      if (mounted) _snack(trp('Cadangan diunggah: {name}', {'name': name}));
    } catch (e) {
      if (mounted) _snack(trp('Gagal: {e}', {'e': e}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _davRestore() async {
    setState(() => _busy = true);
    List<WebDavFile> files;
    try {
      files = await WebDavClient(_dav).list();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack(trp('Gagal: {e}', {'e': e}));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (files.isEmpty) {
      _snack(tr('Belum ada cadangan di server'));
      return;
    }
    final picked = await showModalBottomSheet<WebDavFile>(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          for (final f in files)
            ListTile(
              leading: const Icon(Icons.cloud_download_outlined),
              title: Text(_stamp(f.modified)),
              subtitle: Text('${f.name} · ${_size(f.size)}'),
              onTap: () => Navigator.pop(context, f),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    Object? decoded;
    try {
      decoded = await _unlock(jsonDecode(await WebDavClient(_dav).download(picked.name)));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack(trp('Gagal: {e}', {'e': e}));
      }
      return;
    }
    if (mounted) setState(() => _busy = false);
    await _confirmRestore(decoded);
  }

  String _davStatus() {
    final raw = ref.read(sharedPreferencesProvider).getString(AutoBackup.webDavStatusKey);
    if (raw == null) return tr('Belum pernah');
    final i = raw.indexOf('|');
    final kind = raw.substring(0, i);
    final rest = raw.substring(i + 1);
    if (kind == 'ok') {
      final ms = int.tryParse(rest);
      return ms == null ? tr('Belum pernah') : trp('Terakhir {last}', {'last': _stamp(DateTime.fromMillisecondsSinceEpoch(ms))});
    }
    return trp('Gagal: {e}', {'e': rest});
  }

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
      final password = await _askNewPassword();
      if (password == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
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
        bytes: Uint8List.fromList(utf8.encode(await BackupCrypto.encode(data, password: password))),
        mimeType: 'application/json',
        dialogTitle: tr('Simpan cadangan'),
      );
      if (mounted && uri != null) _snack(trp('Cadangan disimpan: {name}', {'name': name}));
    } catch (e) {
      if (mounted) _snack(trp('Gagal membuat cadangan: {e}', {'e': e}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Dialog sandi untuk cadangan baru. null = dibatalkan, string kosong = tanpa enkripsi.
  Future<String?> _askNewPassword() async {
    final pass = TextEditingController();
    final again = TextEditingController();
    String? error;
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(tr('Enkripsi cadangan?')),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_secrets
                  ? tr('Cadangan ini berisi cookie login & token. Sebaiknya diberi kata sandi. Kosongkan untuk tanpa enkripsi.')
                  : tr('Isi kata sandi untuk mengenkripsi file. Kosongkan untuk tanpa enkripsi.')),
              TextField(controller: pass, obscureText: true, decoration: InputDecoration(labelText: tr('Kata sandi'))),
              TextField(
                controller: again,
                obscureText: true,
                decoration: InputDecoration(labelText: tr('Ulangi kata sandi'), errorText: error),
              ),
              const SizedBox(height: 8),
              Text(tr('Kata sandi yang hilang tidak bisa dipulihkan: cadangan tidak akan terbuka.'),
                  style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Batal'))),
            FilledButton(
              onPressed: () {
                if (pass.text != again.text) {
                  setLocal(() => error = tr('Kata sandi tidak sama'));
                  return;
                }
                Navigator.pop(context, pass.text);
              },
              child: Text(tr('Lanjut')),
            ),
          ],
        ),
      ),
    );
  }

  /// Buka cadangan terenkripsi (minta sandi sampai benar atau dibatalkan);
  /// cadangan polos dikembalikan apa adanya. Batal = lempar [_UnlockCancelled].
  Future<Object?> _unlock(Object? decoded) async {
    if (!BackupCrypto.isEncrypted(decoded)) return decoded;
    var retry = false;
    while (mounted) {
      final pass = TextEditingController();
      final entered = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr('Cadangan terenkripsi')),
          content: TextField(
            controller: pass,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              labelText: tr('Kata sandi'),
              errorText: retry ? tr('Kata sandi salah atau cadangan rusak') : null,
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Batal'))),
            FilledButton(onPressed: () => Navigator.pop(context, pass.text), child: Text(tr('Buka'))),
          ],
        ),
      );
      if (entered == null) break;
      try {
        return await BackupCrypto.decrypt(decoded, entered);
      } on BackupPasswordException {
        retry = true;
      }
    }
    throw const _UnlockCancelled();
  }

  Future<void> _autoPasswordDialog() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final pass = TextEditingController(text: await BackupCrypto.readAutoPassword());
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Enkripsi cadangan otomatis')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(tr('Cadangan otomatis dan unggahan WebDAV dienkripsi dengan kata sandi ini. Kosongkan untuk mematikan.')),
          TextField(controller: pass, obscureText: true, decoration: InputDecoration(labelText: tr('Kata sandi'))),
          const SizedBox(height: 8),
          Text(tr('Kata sandi yang hilang tidak bisa dipulihkan: cadangan tidak akan terbuka.'),
              style: Theme.of(context).textTheme.bodySmall),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Batal'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Simpan'))),
        ],
      ),
    );
    if (ok == true) {
      await AutoBackup.setAutoPassword(prefs, pass.text);
      if (mounted) setState(() {});
    }
  }

  Future<void> _restore() async {
    final files = await FilePicker.pickFiles(dialogTitle: tr('Pilih file cadangan'));
    if (files.isEmpty || !mounted) return;
    Object? decoded;
    try {
      decoded = await _unlock(jsonDecode(utf8.decode(await files.first.xFile.readAsBytes())));
    } on _UnlockCancelled {
      return;
    } catch (_) {
      _snack(tr('File tidak bisa dibaca sebagai cadangan.'));
      return;
    }
    await _confirmRestore(decoded);
  }

  Future<void> _restoreAuto(AutoBackupEntry entry) async {
    Object? decoded;
    try {
      decoded = await _unlock(jsonDecode(await entry.file.readAsString()));
    } on _UnlockCancelled {
      return;
    } catch (_) {
      _snack(tr('Cadangan rusak, tidak bisa dibaca.'));
      return;
    }
    await _confirmRestore(decoded);
  }

  Future<void> _autoNow() async {
    setState(() => _busy = true);
    try {
      final file = await AutoBackup.run(ref.read(sharedPreferencesProvider), ref.read(novelRepositoryProvider));
      if (mounted) _snack(trp('Cadangan dibuat: {name}', {'name': file.uri.pathSegments.last}));
      setState(() => _autoList = AutoBackup.list());
    } catch (e) {
      if (mounted) _snack(trp('Gagal membuat cadangan: {e}', {'e': e}));
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
      _snack(tr('Bukan file cadangan Hub Reader.'));
      return;
    }
    if (!mounted) return;
    final created = summary.createdAt;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Pulihkan cadangan?')),
        content: Text([
          if (created != null)
            trp('Dibuat {date} {time}.', {
              'date': '${created.day}-${created.month}-${created.year}',
              'time': '${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}',
            }),
          trp('{favorites} favorit, {history} riwayat, {settings} data/pengaturan.', {'favorites': summary.favorites, 'history': summary.history, 'settings': summary.settings}),
          if (summary.plugins > 0)
            trp('{n} plugin novel (dipasang bila belum ada di HP ini). Pulihkan hanya file buatan sendiri: kode plugin dijalankan aplikasi.', {'n': summary.plugins}),
          summary.secrets
              ? tr('Termasuk cookie login & pengaturan plugin.')
              : tr('Tanpa cookie login (yang di HP ini tetap dipakai).'),
          tr('\nFavorit, riwayat, progres, dan pengaturan di HP ini akan DIGANTI. Unduhan tidak berubah.'),
        ].join('\n')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Batal'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Pulihkan'))),
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
      _snack(plugins > 0 ? trp('Cadangan dipulihkan, {plugins} plugin novel dipasang', {'plugins': plugins}) : tr('Cadangan dipulihkan'));
      // Bangun ulang aplikasi supaya semua data dibaca ulang.
      AppRestart.restart(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack(trp('Gagal memulihkan: {e}', {'e': e}));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auto = ref.watch(autoBackupProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Cadangan')),
        bottom: _busy ? const PreferredSize(preferredSize: Size.fromHeight(4), child: LinearProgressIndicator()) : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            tr('Cadangan berisi favorit (dengan kategori), riwayat, posisi baca, daftar pembaruan, pengaturan (termasuk daftar repo plugin), dan plugin novel terpasang. File unduhan tidak ikut.'),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(tr('Sertakan cookie login & pengaturan plugin')),
                  subtitle: Text(tr('Berisi sesi login situs; jangan bagikan file ini ke orang lain.')),
                  value: _secrets,
                  onChanged: _busy ? null : (v) => setState(() => _secrets = v),
                ),
                SwitchListTile(
                  title: Text(tr('Sertakan plugin novel terpasang')),
                  subtitle: Text(tr('Kode plugin ikut disimpan, jadi sumber tetap bisa dipasang walau repo-nya hilang.')),
                  value: _plugins,
                  onChanged: _busy ? null : (v) => setState(() => _plugins = v),
                ),
                ListTile(
                  leading: const Icon(Icons.save_alt),
                  title: Text(tr('Buat cadangan')),
                  subtitle: Text(tr('Simpan file .json ke penyimpanan / Drive')),
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
              title: Text(tr('Pulihkan dari file')),
              subtitle: Text(tr('Mengganti data di HP ini dengan isi cadangan')),
              enabled: !_busy,
              onTap: _restore,
            ),
          ),
          const SizedBox(height: 24),
          Text(tr('Cadangan otomatis'), style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            tr('Disimpan di folder aplikasi (Android/data/<paket>/files/backups), bisa diambil lewat USB / pengelola file. Ikut terhapus bila aplikasi dicopot, jadi sesekali salin atau buat cadangan manual ke Drive.'),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: Text(tr('Jadwal')),
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
                  title: Text(tr('Simpan cadangan terbaru')),
                  trailing: DropdownButton<int>(
                    value: auto.keep,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final k in AutoBackupConfig.keepChoices) DropdownMenuItem(value: k, child: Text('$k ${tr('file')}')),
                    ],
                    onChanged: _busy ? null : (v) => v == null ? null : _setAuto(auto.copyWith(keep: v)),
                  ),
                ),
                SwitchListTile(
                  title: Text(tr('Sertakan plugin novel')),
                  value: auto.plugins,
                  onChanged: _busy ? null : (v) => _setAuto(auto.copyWith(plugins: v)),
                ),
                SwitchListTile(
                  title: Text(tr('Sertakan cookie login')),
                  subtitle: Text(ref.read(sharedPreferencesProvider).getBool(AutoBackup.encryptedKey) == true
                      ? tr('Dienkripsi dengan kata sandi cadangan.')
                      : tr('Hanya disertakan bila enkripsi cadangan otomatis aktif.')),
                  value: auto.secrets,
                  onChanged: _busy
                      ? null
                      : (v) async {
                          // Cookie & token tidak boleh tersimpan polos: minta sandi dulu.
                          if (v && ref.read(sharedPreferencesProvider).getBool(AutoBackup.encryptedKey) != true) {
                            await _autoPasswordDialog();
                            if (!mounted ||
                                ref.read(sharedPreferencesProvider).getBool(AutoBackup.encryptedKey) != true) {
                              return;
                            }
                          }
                          await _setAuto(auto.copyWith(secrets: v));
                        },
                ),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: Text(tr('Enkripsi cadangan otomatis')),
                  subtitle: Text(ref.read(sharedPreferencesProvider).getBool(AutoBackup.encryptedKey) == true
                      ? tr('Aktif')
                      : tr('Mati (file JSON polos)')),
                  enabled: !_busy,
                  onTap: _autoPasswordDialog,
                ),
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: Text(tr('Cadangkan sekarang')),
                  subtitle: Builder(builder: (_) {
                    final last = AutoBackup.lastRun(ref.read(sharedPreferencesProvider));
                    return Text(last == null ? tr('Belum pernah') : trp('Terakhir {last}', {'last': _stamp(last)}));
                  }),
                  enabled: !_busy,
                  onTap: _autoNow,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(tr('Cadangan WebDAV'), style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            tr('Unggah cadangan ke server WebDAV (Nextcloud, ownCloud, Synology, Koofr, dll) supaya aman walau aplikasi dicopot atau HP diganti.'),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: Text(tr('Server WebDAV')),
                  subtitle: Text(_dav.configured ? _dav.url : tr('Belum diatur')),
                  enabled: !_busy,
                  onTap: _davDialog,
                ),
                SwitchListTile(
                  title: Text(tr('Unggah cadangan otomatis')),
                  subtitle: Text(tr('Setiap cadangan otomatis ikut diunggah ke server')),
                  value: _dav.enabled,
                  onChanged: _busy || !_dav.configured ? null : (v) => _saveDav(_dav.copyWith(enabled: v)),
                ),
                ListTile(
                  leading: const Icon(Icons.wifi_tethering),
                  title: Text(tr('Tes koneksi')),
                  enabled: !_busy && _dav.configured,
                  onTap: _davTest,
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: Text(tr('Unggah sekarang')),
                  subtitle: Text(_davStatus()),
                  enabled: !_busy && _dav.configured,
                  onTap: _davUploadNow,
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_download_outlined),
                  title: Text(tr('Pulihkan dari WebDAV')),
                  enabled: !_busy && _dav.configured,
                  onTap: _davRestore,
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
                          tooltip: tr('Hapus'),
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

/// Pengguna membatalkan dialog kata sandi saat membuka cadangan terenkripsi.
class _UnlockCancelled implements Exception {
  const _UnlockCancelled();
}
