import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../opds/opds_client.dart';
import 'core_providers.dart';

/// Penyimpanan aman (Android Keystore) untuk kata sandi server OPDS.
final opdsSecretStoreProvider = Provider<OpdsSecretStore>((ref) => const OpdsSecretStore());

class OpdsSecretStore {
  const OpdsSecretStore();

  static const _storage = FlutterSecureStorage();
  static String _k(String id) => 'opds.pass.$id';

  Future<String> read(String id) async {
    try {
      return await _storage.read(key: _k(id)) ?? '';
    } on Object {
      return '';
    }
  }

  Future<void> write(String id, String password) async {
    try {
      if (password.isEmpty) {
        await _storage.delete(key: _k(id));
      } else {
        await _storage.write(key: _k(id), value: password);
      }
    } on Object {
      // Keystore tidak tersedia: kata sandi tidak disimpan.
    }
  }
}

/// Daftar server OPDS tersimpan. Daftar (tanpa kata sandi) ada di
/// SharedPreferences; kata sandi ada di penyimpanan aman dan tidak ikut cadangan.
final opdsServersProvider = NotifierProvider<OpdsServersNotifier, List<OpdsServer>>(OpdsServersNotifier.new);

class OpdsServersNotifier extends Notifier<List<OpdsServer>> {
  static const _key = 'opds.servers.v1';

  @override
  List<OpdsServer> build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
    if (raw == null) return const [];
    List<OpdsServer> list;
    try {
      list = [
        for (final e in jsonDecode(raw) as List) OpdsServer.fromJson(Map<String, Object?>.from(e as Map)),
      ];
    } on Object {
      return const [];
    }
    Future.microtask(() => _loadSecrets(list));
    return [for (final s in list) s.withPassword('')];
  }

  /// Pindahkan kata sandi lama (teks biasa di prefs) ke penyimpanan aman,
  /// lalu isi kata sandi tiap server.
  Future<void> _loadSecrets(List<OpdsServer> stored) async {
    final store = ref.read(opdsSecretStoreProvider);
    var migrated = false;
    final loaded = <OpdsServer>[];
    for (final s in stored) {
      if (s.password.isNotEmpty) {
        await store.write(s.id, s.password);
        migrated = true;
        loaded.add(s);
      } else {
        loaded.add(s.withPassword(await store.read(s.id)));
      }
    }
    if (migrated) await _persistList(loaded);
    state = loaded;
  }

  Future<void> upsert(OpdsServer server) async {
    await ref.read(opdsSecretStoreProvider).write(server.id, server.password);
    final i = state.indexWhere((s) => s.id == server.id);
    final next = [...state];
    if (i >= 0) {
      next[i] = server;
    } else {
      next.add(server);
    }
    state = next;
    await _persistList(next);
  }

  Future<void> remove(String id) async {
    await ref.read(opdsSecretStoreProvider).write(id, '');
    final next = state.where((s) => s.id != id).toList();
    state = next;
    await _persistList(next);
  }

  Future<void> _persistList(List<OpdsServer> list) => ref
      .read(sharedPreferencesProvider)
      .setString(_key, jsonEncode([for (final s in list) s.toJson(includePassword: false)]));
}

final opdsClientProvider = Provider<OpdsClient>((ref) => OpdsClient());
