import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/utils/json.dart';
import 'tracker.dart';

/// MangaUpdates (Baka-Updates), API v1. Login username/password memberi
/// session token; daftar baca memakai `list_id` bawaan situs.
class MangaUpdatesTracker extends Tracker {
  MangaUpdatesTracker(super.prefs, {super.dio});

  @override
  String get id => 'mangaupdates';
  @override
  String get name => 'MangaUpdates';
  @override
  bool get passwordLogin => true;
  @override
  String get developerUrl => 'https://www.mangaupdates.com';
  @override
  String get redirectHint => '';
  @override
  String get defaultClientId => '';

  static const _api = 'https://api.mangaupdates.com/v1';

  /// `list_id` standar MangaUpdates.
  static const _reading = 0, _wish = 1, _complete = 2, _unfinished = 3, _onHold = 4;

  static int listFor(TrackStatus status) => switch (status) {
        TrackStatus.reading || TrackStatus.rereading => _reading,
        TrackStatus.planning => _wish,
        TrackStatus.completed => _complete,
        TrackStatus.dropped => _unfinished,
        TrackStatus.onHold => _onHold,
      };

  static TrackStatus? statusFor(int? listId) => switch (listId) {
        _reading => TrackStatus.reading,
        _wish => TrackStatus.planning,
        _complete => TrackStatus.completed,
        _unfinished => TrackStatus.dropped,
        _onHold => TrackStatus.onHold,
        _ => null, // daftar buatan pengguna
      };

  static JsonMap _json(Object? data) => asMap(data is String && data.isNotEmpty ? jsonDecode(data) : data);

  Future<JsonMap> _call(String method, String path, {Object? body, bool notFoundIsNull = false}) async {
    try {
      final res = await dio.request<Object?>(
        '$_api$path',
        data: body == null ? null : jsonEncode(body),
        options: Options(
          method: method,
          contentType: Headers.jsonContentType,
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
        ),
      );
      return _json(res.data);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404 && notFoundIsNull) return const {};
      if (code == 401 && token != null) {
        // Session token tidak bisa diperbarui; login ulang.
        await logout();
        throw const TrackerException('Sesi MangaUpdates berakhir, login lagi.');
      }
      final reason = asString(_json(e.response?.data)['reason']);
      throw TrackerException(reason ?? 'MangaUpdates tidak bisa dihubungi (${code ?? e.type.name})');
    }
  }

  @override
  Future<void> loginWithPassword(String username, String password) async {
    final res = await _call('PUT', '/account/login', body: {'username': username, 'password': password});
    final session = asString(asMap(res['context'])['session_token']);
    if (session == null) throw TrackerException(asString(res['reason']) ?? 'Login MangaUpdates gagal');
    await prefs.setString('tracker.mangaupdates.token', session);
    final uid = asString(asMap(res['context'])['uid']) ?? '${asMap(res['context'])['uid'] ?? ''}';
    if (uid.isNotEmpty) await prefs.setString('tracker.mangaupdates.user_id', uid);
    await prefs.setString('tracker.mangaupdates.user', username);
  }

  @override
  Future<void> logout() async {
    if (token != null) {
      try {
        await _call('POST', '/account/logout');
      } catch (_) {
        // tetap hapus sesi lokal
      }
    }
    await super.logout();
  }

  static const _novelTypes = {'novel'};

  @override
  Future<List<TrackSearchResult>> search(String query, {required bool novel}) async {
    final data = await _call('POST', '/series/search', body: {'search': query, 'perpage': 25});
    final all = [
      for (final r in asList(data['results']))
        if (asMap(asMap(r)['record']) case final rec when asInt(rec['series_id']) != null) rec,
    ];
    bool isNovel(JsonMap r) => _novelTypes.contains((asString(r['type']) ?? '').toLowerCase());
    final wanted = all.where((r) => isNovel(r) == novel).toList();
    return [
      for (final r in wanted.isNotEmpty ? wanted : all)
        TrackSearchResult(
          id: asInt(r['series_id'])!,
          title: asString(r['title']) ?? '?',
          cover: asString(asMap(asMap(r['image'])['url'])['thumb']),
          format: asString(r['type']),
          url: asString(r['url']),
        ),
    ];
  }

  @override
  Future<TrackEntry?> entry(int mediaId) async {
    final item = await _call('GET', '/lists/series/$mediaId', notFoundIsNull: true);
    if (item.isEmpty) return (progress: 0, status: null, total: null);
    return (
      progress: asInt(asMap(item['status'])['chapter']) ?? 0,
      status: statusFor(asInt(item['list_id'])),
      total: null,
    );
  }

  @override
  Future<void> update(int mediaId, {required int progress, required TrackStatus status}) async {
    final existing = await _call('GET', '/lists/series/$mediaId', notFoundIsNull: true);
    final payload = [
      {
        'series': {'id': mediaId},
        'list_id': listFor(status),
        'status': {'chapter': progress},
      },
    ];
    await _call('POST', existing.isEmpty ? '/lists/series/add' : '/lists/series/update', body: payload);
  }
}
