import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/utils/json.dart';
import 'tracker.dart';

/// Kitsu (kitsu.app). Login password grant dengan client publik aplikasi
/// resmi Kitsu (sama seperti Mihon); API JSON:API di `/api/edge`.
class KitsuTracker extends Tracker {
  KitsuTracker(super.prefs, {super.dio});

  @override
  String get id => 'kitsu';
  @override
  String get name => 'Kitsu';
  @override
  bool get passwordLogin => true;
  @override
  String get usernameLabel => 'Email';
  @override
  String get developerUrl => 'https://kitsu.app';
  @override
  String get redirectHint => '';
  @override
  String get defaultClientId => '';

  // Domain token masih kitsu.io; kitsu.app/api/oauth ada di balik tantangan
  // Cloudflare.
  static const _oauth = 'https://kitsu.io/api/oauth/token';
  static const _api = 'https://kitsu.app/api/edge';
  static const _clientId = 'dd031b32d2f56c990b1425efe6c42ad847e7fe3ab46bf1299f05ecd856bdb7dd';
  static const _clientSecret = '54d7307928f63414defd96399fc31ba847961ceaecef3a5fd93144e960c0e151';
  static const _jsonApi = 'application/vnd.api+json';

  String? get _userId => prefs.getString('tracker.kitsu.user_id');

  @override
  Future<void> loginWithPassword(String username, String password) async {
    await _token({'grant_type': 'password', 'username': username, 'password': password});
    final me = asList(asMap(await _get('/users', {'filter[self]': 'true'}))['data']);
    if (me.isEmpty) {
      await logout();
      throw const TrackerException('Login Kitsu gagal: profil tidak ditemukan');
    }
    final user = asMap(me.first);
    await prefs.setString('tracker.kitsu.user_id', '${user['id']}');
    final name = asString(asMap(user['attributes'])['name']);
    if (name != null) await prefs.setString('tracker.kitsu.user', name);
  }

  Future<void> _token(Map<String, String> form) async {
    try {
      final res = await dio.post<Object?>(
        _oauth,
        data: {'client_id': _clientId, 'client_secret': _clientSecret, ...form},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final body = _json(res.data);
      final access = asString(body['access_token']);
      if (access == null) throw const TrackerException('Login Kitsu gagal');
      await prefs.setString('tracker.kitsu.token', access);
      final refresh = asString(body['refresh_token']);
      if (refresh != null) await prefs.setString('tracker.kitsu.refresh', refresh);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      throw TrackerException(
        code == 400 || code == 401 ? 'Email atau password Kitsu salah' : 'Kitsu tidak bisa dihubungi (${code ?? e.type.name})',
      );
    }
  }

  static JsonMap _json(Object? data) => asMap(data is String && data.isNotEmpty ? jsonDecode(data) : data);

  Future<Object?> _send(Future<Response<Object?>> Function(Map<String, String> headers) send) async {
    Map<String, String> headers() => {
          'Accept': _jsonApi,
          if (token != null) 'Authorization': 'Bearer $token',
        };
    try {
      return _json((await send(headers())).data);
    } on DioException catch (e) {
      final refresh = prefs.getString('tracker.kitsu.refresh');
      if (e.response?.statusCode == 401 && refresh != null) {
        try {
          await _token({'grant_type': 'refresh_token', 'refresh_token': refresh});
          return _json((await send(headers())).data);
        } catch (_) {
          await logout();
          throw const TrackerException('Sesi Kitsu berakhir, login lagi.');
        }
      }
      throw TrackerException('Kitsu tidak bisa dihubungi (${e.response?.statusCode ?? e.type.name})');
    }
  }

  Future<Object?> _get(String path, [Map<String, Object?>? query]) =>
      _send((h) => dio.get<Object?>('$_api$path', queryParameters: query, options: Options(headers: h)));

  static const _statusWire = {
    TrackStatus.reading: 'current',
    TrackStatus.completed: 'completed',
    TrackStatus.onHold: 'on_hold',
    TrackStatus.dropped: 'dropped',
    TrackStatus.planning: 'planned',
    TrackStatus.rereading: 'current',
  };

  static const _novelTypes = {'novel'};

  @override
  Future<List<TrackSearchResult>> search(String query, {required bool novel}) async {
    final data = await _get('/manga', {
      'filter[text]': query,
      'page[limit]': 20,
      'fields[manga]': 'canonicalTitle,posterImage,chapterCount,subtype,slug',
    });
    final all = [
      for (final m in asList(asMap(data)['data']).map(asMap))
        if (int.tryParse('${m['id']}') case final id?) (id: id, a: asMap(m['attributes'])),
    ];
    final wanted = all.where((m) => _novelTypes.contains(m.a['subtype']) == novel).toList();
    return [
      // Seperti AniList: bila tidak ada versi yang cocok, tampilkan semua.
      for (final m in wanted.isNotEmpty ? wanted : all)
        TrackSearchResult(
          id: m.id,
          title: asString(m.a['canonicalTitle']) ?? '?',
          cover: asString(asMap(m.a['posterImage'])['small']),
          total: switch (asInt(m.a['chapterCount'])) { final n? when n > 0 => n, _ => null },
          format: asString(m.a['subtype']),
          url: 'https://kitsu.app/manga/${asString(m.a['slug']) ?? m.id}',
        ),
    ];
  }

  /// Entri pustaka pengguna untuk [mediaId]: (id entri, atribut), atau null.
  Future<({String id, JsonMap attributes})?> _libraryEntry(int mediaId) async {
    final data = await _get('/library-entries', {
      'filter[manga_id]': '$mediaId',
      'filter[user_id]': _userId ?? '',
      'fields[libraryEntries]': 'status,progress,reconsuming',
    });
    final list = asList(asMap(data)['data']);
    if (list.isEmpty) return null;
    final e = asMap(list.first);
    return (id: '${e['id']}', attributes: asMap(e['attributes']));
  }

  @override
  Future<TrackEntry?> entry(int mediaId) async {
    final manga = asMap(asMap(await _get('/manga/$mediaId', {'fields[manga]': 'chapterCount'}))['data']);
    final total = switch (asInt(asMap(manga['attributes'])['chapterCount'])) { final n? when n > 0 => n, _ => null };
    final e = await _libraryEntry(mediaId);
    if (e == null) return (progress: 0, status: null, total: total);
    final wire = asString(e.attributes['status']);
    final rereading = e.attributes['reconsuming'] == true;
    return (
      progress: asInt(e.attributes['progress']) ?? 0,
      status: rereading ? TrackStatus.rereading : _statusWire.entries.where((x) => x.value == wire).firstOrNull?.key,
      total: total,
    );
  }

  @override
  Future<void> update(int mediaId, {required int progress, required TrackStatus status}) async {
    final userId = _userId;
    if (userId == null) throw const TrackerException('Login Kitsu dulu');
    final attributes = {
      'status': _statusWire[status],
      'progress': progress,
      'reconsuming': status == TrackStatus.rereading,
    };
    final existing = await _libraryEntry(mediaId);
    final Map<String, Object?> body = existing == null
        ? {
            'data': {
              'type': 'libraryEntries',
              'attributes': attributes,
              'relationships': {
                'user': {
                  'data': {'id': userId, 'type': 'users'},
                },
                'media': {
                  'data': {'id': '$mediaId', 'type': 'manga'},
                },
              },
            },
          }
        : {
            'data': {'type': 'libraryEntries', 'id': existing.id, 'attributes': attributes},
          };
    await _send((h) {
      final options = Options(headers: h, contentType: _jsonApi);
      return existing == null
          ? dio.post<Object?>('$_api/library-entries', data: jsonEncode(body), options: options)
          : dio.patch<Object?>('$_api/library-entries/${existing.id}', data: jsonEncode(body), options: options);
    });
  }
}
