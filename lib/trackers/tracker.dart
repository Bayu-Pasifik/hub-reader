import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/json.dart';

/// Status baca di tracker (dipetakan ke istilah tiap layanan).
enum TrackStatus {
  reading('Sedang dibaca'),
  completed('Selesai'),
  onHold('Ditunda'),
  dropped('Berhenti'),
  planning('Rencana'),
  rereading('Baca ulang');

  const TrackStatus(this.label);

  final String label;
}

/// Hasil pencarian di tracker.
class TrackSearchResult {
  const TrackSearchResult({
    required this.id,
    required this.title,
    this.cover,
    this.total,
    this.format,
    this.url,
  });

  final int id;
  final String title;
  final String? cover;

  /// Jumlah bab (null bila belum diketahui / masih berjalan).
  final int? total;
  final String? format;
  final String? url;
}

/// Status entri di daftar pengguna.
typedef TrackEntry = ({int progress, TrackStatus? status, int? total});

class TrackerException implements Exception {
  const TrackerException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Satu layanan tracker. AniList & MyAnimeList: login OAuth di WebView dengan
/// Client ID. Kitsu & MangaUpdates: login username/password ([passwordLogin]).
abstract class Tracker {
  Tracker(this.prefs, {Dio? dio})
      : dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 30),
            ));

  final SharedPreferences prefs;
  final Dio dio;

  String get id;
  String get name;

  /// Halaman untuk membuat Client ID.
  String get developerUrl;

  /// Petunjuk redirect URL yang harus didaftarkan.
  String get redirectHint;

  /// Client ID bawaan dari `--dart-define` (mis. diisi secret CI), dipakai
  /// bila pengguna belum mengisi sendiri. Client ID OAuth publik (implicit
  /// grant / PKCE tanpa secret), jadi aman ikut di APK.
  String get defaultClientId;

  String get _p => 'tracker.$id.';
  String? get clientId {
    final own = prefs.getString('${_p}client_id');
    if (own != null && own.isNotEmpty) return own;
    return defaultClientId.isEmpty ? null : defaultClientId;
  }

  /// true bila Client ID berasal dari build, bukan isian pengguna.
  bool get usesDefaultClientId => (prefs.getString('${_p}client_id') ?? '').isEmpty && defaultClientId.isNotEmpty;

  Future<void> setClientId(String value) => prefs.setString('${_p}client_id', value.trim());
  String? get token => prefs.getString('${_p}token');
  String? get username => prefs.getString('${_p}user');
  bool get loggedIn => token != null;

  Future<void> logout() async {
    for (final k in prefs.getKeys().where((k) => k.startsWith(_p) && k != '${_p}client_id').toList()) {
      await prefs.remove(k);
    }
  }

  /// Login dengan username/password (tanpa Client ID & WebView). Password
  /// tidak disimpan; hanya token sesi.
  bool get passwordLogin => false;

  /// Label kolom username (mis. email untuk Kitsu).
  String get usernameLabel => 'Username';

  Future<void> loginWithPassword(String username, String password) =>
      throw UnsupportedError('$name tidak memakai login password');

  /// URL yang dibuka di WebView untuk login (tracker OAuth).
  Uri authorizeUrl() => throw UnsupportedError('$name tidak memakai OAuth');

  /// Dipanggil untuk setiap URL yang dibuka WebView; true bila login selesai
  /// (token tersimpan) dari URL ini.
  Future<bool> handleRedirect(Uri url) async => false;

  Future<List<TrackSearchResult>> search(String query, {required bool novel});
  Future<TrackEntry?> entry(int mediaId);
  Future<void> update(int mediaId, {required int progress, required TrackStatus status});
}

// ------------------------------------------------------------------ AniList

class AniListTracker extends Tracker {
  AniListTracker(super.prefs, {super.dio});

  @override
  String get id => 'anilist';
  @override
  String get name => 'AniList';
  @override
  String get developerUrl => 'https://anilist.co/settings/developer';
  @override
  String get redirectHint => 'https://anilist.co/api/v2/oauth/pin';
  @override
  String get defaultClientId => const String.fromEnvironment('ANILIST_CLIENT_ID');

  static const _api = 'https://graphql.anilist.co';

  @override
  Uri authorizeUrl() => Uri.parse('https://anilist.co/api/v2/oauth/authorize').replace(
        queryParameters: {'client_id': clientId ?? '', 'response_type': 'token'},
      );

  @override
  Future<bool> handleRedirect(Uri url) async {
    // Implicit grant: token ada di fragment, mis. .../pin#access_token=...
    final fragment = Uri.splitQueryString(url.fragment);
    final t = fragment['access_token'];
    if (t == null || t.isEmpty) return false;
    await prefs.setString('tracker.anilist.token', t);
    try {
      final data = await _query('query { Viewer { name } }');
      final user = asString(asMap(asMap(data)['Viewer'])['name']);
      if (user != null) await prefs.setString('tracker.anilist.user', user);
    } catch (_) {
      // nama pengguna opsional
    }
    return true;
  }

  Future<Object?> _query(String query, [Map<String, Object?> variables = const {}]) async {
    final t = token;
    try {
      final res = await dio.post<Object?>(
        _api,
        data: {'query': query, 'variables': variables},
        options: Options(headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (t != null) 'Authorization': 'Bearer $t',
        }),
      );
      final body = asMap(res.data is String ? jsonDecode(res.data as String) : res.data);
      final errors = asList(body['errors']);
      if (errors.isNotEmpty) throw TrackerException(asString(asMap(errors.first)['message']) ?? 'AniList error');
      return body['data'];
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await logout();
        throw const TrackerException('Sesi AniList berakhir, login lagi.');
      }
      throw TrackerException('AniList tidak bisa dihubungi (${e.response?.statusCode ?? e.type.name})');
    }
  }

  static const _statusWire = {
    TrackStatus.reading: 'CURRENT',
    TrackStatus.completed: 'COMPLETED',
    TrackStatus.onHold: 'PAUSED',
    TrackStatus.dropped: 'DROPPED',
    TrackStatus.planning: 'PLANNING',
    TrackStatus.rereading: 'REPEATING',
  };

  @override
  Future<List<TrackSearchResult>> search(String query, {required bool novel}) async {
    final filtered = await _search(query, novel ? ['NOVEL'] : ['MANGA', 'ONE_SHOT']);
    // Banyak web novel hanya tercatat versi komiknya; tampilkan semua format.
    return filtered.isNotEmpty ? filtered : _search(query, null);
  }

  Future<List<TrackSearchResult>> _search(String query, List<String>? formats) async {
    const fields = '{ id title { userPreferred } coverImage { medium } chapters format siteUrl }';
    // `format_in: null` membuat AniList error 500; tanpa filter = tanpa argumen.
    final data = formats == null
        ? await _query(r'query ($q: String) { Page(perPage: 25) { media(search: $q, type: MANGA) ' '$fields } }', {
            'q': query,
          })
        : await _query(
            r'query ($q: String, $f: [MediaFormat]) { Page(perPage: 25) { media(search: $q, type: MANGA, format_in: $f) '
            '$fields } }',
            {'q': query, 'f': formats},
          );
    return [
      for (final m in asList(asMap(asMap(data)['Page'])['media']).map(asMap))
        if (asInt(m['id']) case final id?)
          TrackSearchResult(
            id: id,
            title: asString(asMap(m['title'])['userPreferred']) ?? '?',
            cover: asString(asMap(m['coverImage'])['medium']),
            total: asInt(m['chapters']),
            format: asString(m['format']),
            url: asString(m['siteUrl']),
          ),
    ];
  }

  @override
  Future<TrackEntry?> entry(int mediaId) async {
    final data = await _query(
      r'query ($id: Int) { Media(id: $id) { chapters mediaListEntry { progress status } } }',
      {'id': mediaId},
    );
    final media = asMap(asMap(data)['Media']);
    final e = asMap(media['mediaListEntry']);
    final wire = asString(e['status']);
    return (
      progress: asInt(e['progress']) ?? 0,
      status: _statusWire.entries.where((x) => x.value == wire).firstOrNull?.key,
      total: asInt(media['chapters']),
    );
  }

  @override
  Future<void> update(int mediaId, {required int progress, required TrackStatus status}) async {
    await _query(
      r'mutation ($id: Int, $p: Int, $s: MediaListStatus) { SaveMediaListEntry(mediaId: $id, progress: $p, status: $s) { id } }',
      {'id': mediaId, 'p': progress, 's': _statusWire[status]},
    );
  }
}

// -------------------------------------------------------------- MyAnimeList

class MalTracker extends Tracker {
  MalTracker(super.prefs, {super.dio});

  @override
  String get id => 'mal';
  @override
  String get name => 'MyAnimeList';
  @override
  String get developerUrl => 'https://myanimelist.net/apiconfig';
  @override
  String get redirectHint => 'https://localhost/hubreader (jenis aplikasi "other")';
  @override
  String get defaultClientId => const String.fromEnvironment('MAL_CLIENT_ID');

  static const _api = 'https://api.myanimelist.net/v2';
  static const _state = 'hubreader';

  String get _verifier {
    var v = prefs.getString('tracker.mal.verifier');
    if (v == null) {
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
      final r = Random.secure();
      v = List.generate(96, (_) => chars[r.nextInt(chars.length)]).join();
      prefs.setString('tracker.mal.verifier', v);
    }
    return v;
  }

  @override
  Uri authorizeUrl() => Uri.parse('https://myanimelist.net/v1/oauth2/authorize').replace(queryParameters: {
        'response_type': 'code',
        'client_id': clientId ?? '',
        // MAL hanya mendukung PKCE "plain".
        'code_challenge': _verifier,
        'code_challenge_method': 'plain',
        'state': _state,
      });

  @override
  Future<bool> handleRedirect(Uri url) async {
    final code = url.queryParameters['code'];
    if (code == null || url.queryParameters['state'] != _state || url.host.endsWith('myanimelist.net')) return false;
    await _token({'grant_type': 'authorization_code', 'code': code, 'code_verifier': _verifier});
    await prefs.remove('tracker.mal.verifier');
    try {
      final me = await _get('/users/@me');
      final user = asString(asMap(me)['name']);
      if (user != null) await prefs.setString('tracker.mal.user', user);
    } catch (_) {
      // opsional
    }
    return true;
  }

  Future<void> _token(Map<String, String> form) async {
    try {
      final res = await dio.post<Object?>(
        'https://myanimelist.net/v1/oauth2/token',
        data: {'client_id': clientId ?? '', ...form},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final body = asMap(res.data is String ? jsonDecode(res.data as String) : res.data);
      final access = asString(body['access_token']);
      if (access == null) throw const TrackerException('Login MyAnimeList gagal');
      await prefs.setString('tracker.mal.token', access);
      final refresh = asString(body['refresh_token']);
      if (refresh != null) await prefs.setString('tracker.mal.refresh', refresh);
    } on DioException catch (e) {
      throw TrackerException('Login MyAnimeList gagal (${e.response?.statusCode ?? e.type.name})');
    }
  }

  Future<Object?> _send(Future<Response<Object?>> Function(Map<String, String> headers) send) async {
    Map<String, String> headers() => {
          if (token != null) 'Authorization': 'Bearer $token' else 'X-MAL-CLIENT-ID': clientId ?? '',
        };
    try {
      return (await send(headers())).data;
    } on DioException catch (e) {
      final refresh = prefs.getString('tracker.mal.refresh');
      if (e.response?.statusCode == 401 && refresh != null) {
        try {
          await _token({'grant_type': 'refresh_token', 'refresh_token': refresh});
          return (await send(headers())).data;
        } catch (_) {
          await logout();
          throw const TrackerException('Sesi MyAnimeList berakhir, login lagi.');
        }
      }
      throw TrackerException('MyAnimeList tidak bisa dihubungi (${e.response?.statusCode ?? e.type.name})');
    }
  }

  Future<Object?> _get(String path, [Map<String, Object?>? query]) =>
      _send((h) => dio.get<Object?>('$_api$path', queryParameters: query, options: Options(headers: h)));

  static const _statusWire = {
    TrackStatus.reading: 'reading',
    TrackStatus.completed: 'completed',
    TrackStatus.onHold: 'on_hold',
    TrackStatus.dropped: 'dropped',
    TrackStatus.planning: 'plan_to_read',
    TrackStatus.rereading: 'reading',
  };

  @override
  Future<List<TrackSearchResult>> search(String query, {required bool novel}) async {
    final data = await _get('/manga', {'q': query, 'limit': 25, 'fields': 'num_chapters,media_type'});
    const novelTypes = {'light_novel', 'novel'};
    return [
      for (final e in asList(asMap(data)['data']).map((e) => asMap(asMap(e)['node'])))
        if (asInt(e['id']) case final id?)
          if (novelTypes.contains(e['media_type']) == novel)
            TrackSearchResult(
              id: id,
              title: asString(e['title']) ?? '?',
              cover: asString(asMap(e['main_picture'])['medium']),
              total: switch (asInt(e['num_chapters'])) { final n? when n > 0 => n, _ => null },
              format: asString(e['media_type']),
              url: 'https://myanimelist.net/manga/$id',
            ),
    ];
  }

  @override
  Future<TrackEntry?> entry(int mediaId) async {
    final data = asMap(await _get('/manga/$mediaId', {'fields': 'num_chapters,my_list_status'}));
    final s = asMap(data['my_list_status']);
    final wire = asString(s['status']);
    return (
      progress: asInt(s['num_chapters_read']) ?? 0,
      status: _statusWire.entries.where((x) => x.value == wire).firstOrNull?.key,
      total: switch (asInt(data['num_chapters'])) { final n? when n > 0 => n, _ => null },
    );
  }

  @override
  Future<void> update(int mediaId, {required int progress, required TrackStatus status}) async {
    await _send((h) => dio.patch<Object?>(
          '$_api/manga/$mediaId/my_list_status',
          data: {'status': _statusWire[status], 'num_chapters_read': '$progress'},
          options: Options(headers: h, contentType: Headers.formUrlEncodedContentType),
        ));
  }
}
