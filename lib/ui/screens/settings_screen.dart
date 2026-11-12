import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/dio_factory.dart';
import '../../data/api/scraper_hub_api.dart';
import '../../state/core_providers.dart';

/// Atur alamat server & API key tanpa build ulang (berguna di HP fisik
/// yang IP komputernya berubah-ubah).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final AppConfig _initial = ref.read(settingsProvider);
  late final _baseUrl = TextEditingController(text: _initial.baseUrl);
  late final _apiKey = TextEditingController(text: _initial.apiKey);
  bool _obscureKey = true;
  bool _testing = false;
  String? _testResult;
  bool _testOk = false;

  @override
  void dispose() {
    _baseUrl.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  AppConfig get _draft => AppConfig(baseUrl: _baseUrl.text.trim(), apiKey: _apiKey.text.trim());

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final config = _draft;
    final dio = createDio(config);
    try {
      // /genres ringan dan tetap butuh API key → menguji alamat + key sekaligus.
      await ScraperHubApi(dio, hasApiKey: config.hasApiKey).genres();
      _testOk = true;
      _testResult = 'Terhubung. Server dan API key valid.';
    } catch (error) {
      final e = toApiException(error);
      _testOk = false;
      _testResult = '${e.title}. ${e.message}';
    } finally {
      dio.close();
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final uri = Uri.tryParse(_baseUrl.text.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      _showSnack('Alamat server tidak valid. Contoh: http://192.168.1.10:8000/api/v1');
      return;
    }
    await ref.read(settingsProvider.notifier).save(_draft);
    _showSnack('Pengaturan disimpan.');
  }

  Future<void> _reset() async {
    await ref.read(settingsProvider.notifier).resetToDefaults();
    final config = ref.read(settingsProvider);
    setState(() {
      _baseUrl.text = config.baseUrl;
      _apiKey.text = config.apiKey;
      _testResult = null;
    });
    _showSnack('Dikembalikan ke nilai --dart-define.');
  }

  Future<void> _clearCache() async {
    await ref.read(jsonCacheProvider).clear();
    _showSnack('Cache offline dihapus.');
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _baseUrl,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Alamat API',
              helperText: 'Emulator: http://10.0.2.2:8000/api/v1 · HP: http://<IP-komputer>:8000/api/v1',
              helperMaxLines: 2,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _apiKey,
            obscureText: _obscureKey,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'API key (X-Api-Key)',
              helperText: 'Salah satu nilai API_KEYS di .env scraper-hub',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscureKey ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _testing ? null : _testConnection,
                  icon: _testing
                      ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.network_check),
                  label: const Text('Tes koneksi'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Simpan'),
                ),
              ),
            ],
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 12),
            Text(
              _testResult!,
              style: TextStyle(color: _testOk ? scheme.primary : scheme.error),
            ),
          ],
          const Divider(height: 40),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.restore),
            title: const Text('Kembalikan ke default'),
            subtitle: const Text('Pakai nilai API_BASE_URL / API_KEY dari --dart-define'),
            onTap: _reset,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Hapus cache offline'),
            subtitle: const Text('Favorit & riwayat tidak ikut terhapus'),
            onTap: _clearCache,
          ),
        ],
      ),
    );
  }
}
