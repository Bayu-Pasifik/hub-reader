import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_js/flutter_js.dart';

import 'http_bridge.dart';

/// Penyimpanan key-value sinkron untuk `@libs/storage` plugin LNReader.
abstract class PluginKeyValueStore {
  String? get(String key);
  void set(String key, String value);
  void delete(String key);
  Iterable<String> keys();
}

class MemoryKeyValueStore implements PluginKeyValueStore {
  MemoryKeyValueStore([Map<String, String>? initial]) : _map = {...?initial};

  final Map<String, String> _map;

  @override
  String? get(String key) => _map[key];

  @override
  void set(String key, String value) => _map[key] = value;

  @override
  void delete(String key) => _map.remove(key);

  @override
  Iterable<String> keys() => _map.keys;
}

/// Error dari kode plugin JS (atau runtime-nya).
class LnPluginException implements Exception {
  const LnPluginException(this.message);

  final String message;

  @override
  String toString() => message;
}

typedef LnFetch = Future<LnHttpResponse> Function(LnHttpRequest request);

/// Mesin QuickJS yang menjalankan plugin LNReader (sinkron, satu isolate).
///
/// `assets/lnreader/runtime.js` (lihat tool/lnreader_runtime) menyediakan
/// `require` (cheerio, htmlparser2, dayjs, `@libs/*`) dan API web yang tidak
/// ada di QuickJS. Semua I/O lewat satu fungsi Dart `__host(op, payload)`:
/// fetch lewat [fetch], timer lewat [Timer], storage lewat [store].
///
/// Satu engine dipakai bersama semua plugin (kunci = id plugin). Aplikasi
/// memakainya lewat `LnEngine` (engine_isolate.dart) agar parsing HTML tidak
/// berjalan di isolate UI.
class LnJsEngine {
  LnJsEngine({
    required String runtimeCode,
    required this.fetch,
    this.abort,
    PluginKeyValueStore? store,
    this.callTimeout = const Duration(seconds: 90),
    this.log,
  }) : store = store ?? MemoryKeyValueStore() {
    // Rejection "tak tertangani" sesaat (Promise.reject di plugin yang baru
    // ditangani runtime satu tick kemudian) bukan error; jangan di-print.
    _rt = QuickJsRuntime2(stackSize: 1024 * 1024, hostPromiseRejectionHandler: (_) {});
    final setGlobal = _evalFn('(function(k, v) { globalThis[k] = v; })');
    setGlobal.invoke(['__host', _host]);
    _check(_rt.evaluate(runtimeCode, name: 'runtime.js'), 'runtime.js');
    _load = _evalFn('(function(k, c) { return __lnr.load(k, c); })');
    _invoke = _evalFn('(function(a, b, c, d) { __lnr.invoke(a, b, c, d); })');
    _resolveFetch = _evalFn('(function(a, b) { __lnr.resolveFetch(a, b); })');
    _rejectFetch = _evalFn('(function(a, b) { __lnr.rejectFetch(a, b); })');
    _fireTimer = _evalFn('(function(a) { __lnr.fireTimer(a); })');
  }

  late final QuickJsRuntime2 _rt;
  late final JSInvokable _load;
  late final JSInvokable _invoke;
  late final JSInvokable _resolveFetch;
  late final JSInvokable _rejectFetch;
  late final JSInvokable _fireTimer;

  final LnFetch fetch;
  final void Function(int requestId)? abort;
  final PluginKeyValueStore store;
  final Duration callTimeout;
  final void Function(String message)? log;

  final _calls = <int, Completer<Object?>>{};
  final _bodies = <int, LnHttpResponse>{};
  final _timers = <int, Timer>{};
  int _callSeq = 0;
  bool _disposed = false;

  JSInvokable _evalFn(String code) {
    final result = _rt.evaluate(code);
    _check(result, code);
    return result.rawResult as JSInvokable;
  }

  void _check(JsEvalResult result, String what) {
    if (result.isError) throw LnPluginException('JS error ($what): ${result.stringResult}');
  }

  /// Jalankan job Promise yang tertunda setelah setiap panggilan ke JS.
  void _pump() {
    if (!_disposed) _rt.executePendingJob();
  }

  void _call(JSInvokable fn, List<Object?> args) {
    if (_disposed) return;
    try {
      fn.invoke(args);
    } catch (e) {
      log?.call('JS callback error: $e');
    }
    _pump();
  }

  // ------------------------------------------------------------- API publik

  /// Muat kode plugin (hasil compile, CommonJS). Mengembalikan metadata
  /// plugin (`id`, `name`, `filters`, `hasParsePage`, ...).
  Map<String, Object?> load(String key, String code) {
    final Object? raw;
    try {
      raw = _load.invoke([key, code]);
    } catch (e) {
      throw LnPluginException('Plugin gagal dimuat: $e');
    }
    _pump();
    return (jsonDecode(raw as String) as Map).cast<String, Object?>();
  }

  /// Panggil `plugin[method](...args)`; hasilnya sudah di-decode dari JSON.
  Future<Object?> invoke(String key, String method, List<Object?> args) {
    final id = ++_callSeq;
    final completer = Completer<Object?>();
    _calls[id] = completer;
    _call(_invoke, [id, key, method, jsonEncode(args)]);
    return completer.future.timeout(callTimeout, onTimeout: () {
      _calls.remove(id);
      throw const LnPluginException('Waktu habis menunggu situs sumber.');
    });
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final t in _timers.values) {
      t.cancel();
    }
    for (final c in _calls.values) {
      if (!c.isCompleted) c.completeError(const LnPluginException('Engine ditutup.'));
    }
    _rt.dispose();
  }

  // ------------------------------------------------------------------ host

  Object? _host(String op, String payload) {
    switch (op) {
      case 'done':
        final msg = jsonDecode(payload) as Map;
        final c = _calls.remove(msg['id']);
        if (c != null && !c.isCompleted) {
          msg['ok'] == true ? c.complete(msg['value']) : c.completeError(LnPluginException('${msg['error']}'));
        }
        return null;
      case 'fetch':
        _startFetch(LnHttpRequest.fromJs((jsonDecode(payload) as Map).cast<String, Object?>()));
        return null;
      case 'abort':
        abort?.call(int.parse(payload));
        return null;
      case 'body.text':
        final body = _bodies[int.parse(payload)];
        return body == null ? '' : decodeBody(body.bytes, body.charset);
      case 'body.bytes':
        return _bodies[int.parse(payload)]?.bytes ?? Uint8List(0);
      case 'decode':
        final msg = jsonDecode(payload) as Map;
        return decodeBody(base64Decode(msg['data'] as String), msg['encoding'] as String?);
      case 'timer':
        final msg = jsonDecode(payload) as Map;
        final id = msg['id'] as int;
        _timers[id]?.cancel();
        _timers[id] = Timer(Duration(milliseconds: (msg['ms'] as num).toInt()), () {
          _timers.remove(id);
          _call(_fireTimer, [id]);
        });
        return null;
      case 'clearTimer':
        _timers.remove(int.parse(payload))?.cancel();
        return null;
      case 'storage.get':
        return store.get(payload);
      case 'storage.set':
        final msg = jsonDecode(payload) as Map;
        store.set(msg['key'] as String, msg['value'] as String);
        return null;
      case 'storage.delete':
        store.delete(payload);
        return null;
      case 'storage.keys':
        return jsonEncode(store.keys().where((k) => k.startsWith(payload)).toList());
      case 'log':
        log?.call(payload);
        return null;
    }
    log?.call('host op tidak dikenal: $op');
    return null;
  }

  Future<void> _startFetch(LnHttpRequest req) async {
    try {
      final response = await fetch(req);
      if (_disposed) return;
      _bodies[req.id] = response;
      // Plugin membaca body tepat setelah fetch selesai; simpan beberapa saja.
      while (_bodies.length > 24) {
        _bodies.remove(_bodies.keys.first);
      }
      _call(_resolveFetch, [req.id, jsonEncode(response.metaJson())]);
    } catch (e) {
      if (_disposed) return;
      _call(_rejectFetch, [req.id, e is LnNetworkException ? e.message : 'Network request failed: $e']);
    }
  }
}
