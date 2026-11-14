import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../opds/opds_client.dart';
import 'core_providers.dart';

/// Daftar server OPDS tersimpan. Kata sandi disimpan di penyimpanan
/// aplikasi (tidak dienkripsi tambahan).
final opdsServersProvider = NotifierProvider<OpdsServersNotifier, List<OpdsServer>>(OpdsServersNotifier.new);

class OpdsServersNotifier extends Notifier<List<OpdsServer>> {
  static const _key = 'opds.servers.v1';

  @override
  List<OpdsServer> build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
    if (raw == null) return const [];
    try {
      return [
        for (final e in jsonDecode(raw) as List) OpdsServer.fromJson(Map<String, Object?>.from(e as Map)),
      ];
    } on Object {
      return const [];
    }
  }

  Future<void> upsert(OpdsServer server) async {
    final i = state.indexWhere((s) => s.id == server.id);
    final next = [...state];
    if (i >= 0) {
      next[i] = server;
    } else {
      next.add(server);
    }
    await _save(next);
  }

  Future<void> remove(String id) => _save(state.where((s) => s.id != id).toList());

  Future<void> _save(List<OpdsServer> next) async {
    state = next;
    await ref.read(sharedPreferencesProvider).setString(_key, jsonEncode([for (final s in next) s.toJson()]));
  }
}

final opdsClientProvider = Provider<OpdsClient>((ref) => OpdsClient());
