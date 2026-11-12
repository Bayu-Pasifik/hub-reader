import 'dart:async';
import 'dart:isolate';

import 'http_bridge.dart';
import 'js_engine.dart';

/// Engine plugin LNReader yang berjalan di isolate latar.
///
/// QuickJS + cheerio memparsing HTML cukup lama (ribuan bab bisa beberapa
/// detik), jadi [LnJsEngine] dijalankan di isolate sendiri. Request jaringan
/// tetap dikerjakan di isolate utama oleh [LnFetcher] (cookie & User-Agent
/// bersama sumber komik), storage plugin dicerminkan ke [PluginKeyValueStore]
/// milik isolate utama.
class LnEngine {
  LnEngine._(this._fetcher, this._store);

  final LnFetcher _fetcher;
  final PluginKeyValueStore _store;
  final _receive = ReceivePort();
  final _errors = ReceivePort();
  late final Isolate _isolate;
  late final SendPort _send;
  final _pending = <int, Completer<Object?>>{};
  int _seq = 0;
  bool _closed = false;

  static Future<LnEngine> spawn({
    required String runtimeCode,
    required LnFetcher fetcher,
    required PluginKeyValueStore store,
    void Function(String message)? log,
  }) async {
    final engine = LnEngine._(fetcher, store);
    final ready = Completer<SendPort>();
    engine._receive.listen((msg) => engine._onMessage(msg as List, ready, log));
    engine._errors.listen((e) {
      final error = LnPluginException('Engine plugin berhenti: ${(e as List).first}');
      if (!ready.isCompleted) ready.completeError(error);
      engine._failAll(error);
    });
    engine._isolate = await Isolate.spawn(
      _isolateMain,
      [engine._receive.sendPort, runtimeCode, {for (final k in store.keys()) k: store.get(k)!}],
      onError: engine._errors.sendPort,
      debugName: 'lnreader-engine',
    );
    engine._send = await ready.future;
    return engine;
  }

  /// Muat kode plugin; hasilnya metadata plugin dari JS.
  Future<Map<String, Object?>> load(String key, String code) async =>
      ((await _request(['load', key, code])) as Map).cast<String, Object?>();

  Future<Object?> invoke(String key, String method, List<Object?> args) =>
      _request(['invoke', key, method, args]);

  Future<Object?> _request(List<Object?> message) {
    if (_closed) return Future.error(const LnPluginException('Engine ditutup.'));
    final id = ++_seq;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    _send.send([message.first, id, ...message.skip(1)]);
    return completer.future;
  }

  void _onMessage(List msg, Completer<SendPort> ready, void Function(String)? log) {
    switch (msg[0]) {
      case 'ready':
        ready.complete(msg[1] as SendPort);
      case 'result':
        final c = _pending.remove(msg[1]);
        if (c == null) return;
        msg[2] == true ? c.complete(msg[3]) : c.completeError(LnPluginException(msg[3] as String));
      case 'fetch':
        _fetch(LnHttpRequest.fromJs((msg[1] as Map).cast<String, Object?>()));
      case 'abort':
        _fetcher.abort(msg[1] as int);
      case 'storage.set':
        _store.set(msg[1] as String, msg[2] as String);
      case 'storage.delete':
        _store.delete(msg[1] as String);
      case 'log':
        log?.call(msg[1] as String);
    }
  }

  Future<void> _fetch(LnHttpRequest req) async {
    try {
      final res = await _fetcher.fetch(req);
      if (_closed) return;
      _send.send(['fetchResult', req.id, res.metaJson(), TransferableTypedData.fromList([res.bytes])]);
    } catch (e) {
      if (_closed) return;
      _send.send(['fetchError', req.id, e is LnNetworkException ? e.message : '$e']);
    }
  }

  void _failAll(Object error) {
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(error);
    }
    _pending.clear();
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    _send.send(['dispose']);
    _failAll(const LnPluginException('Engine ditutup.'));
    _receive.close();
    _errors.close();
    _isolate.kill(priority: Isolate.beforeNextEvent);
  }
}

/// Storage di isolate engine: salinan lokal untuk baca sinkron, tulisan
/// diteruskan ke isolate utama untuk disimpan permanen.
class _MirrorStore extends MemoryKeyValueStore {
  _MirrorStore(super.initial, this._main);

  final SendPort _main;

  @override
  void set(String key, String value) {
    super.set(key, value);
    _main.send(['storage.set', key, value]);
  }

  @override
  void delete(String key) {
    super.delete(key);
    _main.send(['storage.delete', key]);
  }
}

Future<void> _isolateMain(List args) async {
  final main = args[0] as SendPort;
  final inbox = ReceivePort();
  final fetches = <int, Completer<LnHttpResponse>>{};

  final engine = LnJsEngine(
    runtimeCode: args[1] as String,
    store: _MirrorStore((args[2] as Map).cast<String, String>(), main),
    log: (m) => main.send(['log', m]),
    abort: (id) {
      fetches.remove(id)?.completeError(const LnNetworkException('Aborted'));
      main.send(['abort', id]);
    },
    fetch: (req) {
      final c = Completer<LnHttpResponse>();
      fetches[req.id] = c;
      main.send([
        'fetch',
        {
          'id': req.id,
          'url': req.url,
          'method': req.method,
          'headers': req.headers,
          'body': {'type': req.bodyType, 'value': req.bodyText, 'fields': req.bodyFields},
          'redirect': req.followRedirects ? 'follow' : 'manual',
        },
      ]);
      return c.future;
    },
  );

  void reply(int id, Future<Object?> Function() run) {
    run().then(
      (v) => main.send(['result', id, true, v]),
      onError: (Object e) => main.send(['result', id, false, '$e']),
    );
  }

  inbox.listen((raw) {
    final msg = raw as List;
    switch (msg[0]) {
      case 'load':
        reply(msg[1] as int, () async => engine.load(msg[2] as String, msg[3] as String));
      case 'invoke':
        reply(msg[1] as int, () => engine.invoke(msg[2] as String, msg[3] as String, msg[4] as List<Object?>));
      case 'fetchResult':
        final meta = (msg[2] as Map).cast<String, Object?>();
        fetches.remove(msg[1])?.complete(LnHttpResponse(
              status: meta['status'] as int,
              statusText: meta['statusText'] as String,
              url: meta['url'] as String,
              redirected: meta['redirected'] as bool,
              headers: (meta['headers'] as Map).cast<String, String>(),
              bytes: (msg[3] as TransferableTypedData).materialize().asUint8List(),
            ));
      case 'fetchError':
        fetches.remove(msg[1])?.completeError(LnNetworkException(msg[2] as String));
      case 'dispose':
        engine.dispose();
        inbox.close();
    }
  });
  main.send(['ready', inbox.sendPort]);
}
