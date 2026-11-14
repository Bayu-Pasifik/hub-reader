import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

/// Server OPDS milik pengguna (Komga, Kavita, Calibre-Web, dll).
class OpdsServer {
  const OpdsServer({required this.id, required this.name, required this.url, this.username = '', this.password = ''});

  final String id;
  final String name;

  /// URL katalog akar (mis. `http://192.168.1.5:25600/opds/v1.2/catalog`).
  final String url;
  final String username;
  final String password;

  bool get hasAuth => username.isNotEmpty;

  /// Header `Authorization: Basic ...` bila server memakai login.
  Map<String, String> get headers =>
      hasAuth ? {'Authorization': 'Basic ${base64Encode(utf8.encode('$username:$password'))}'} : const {};

  Map<String, String> toJson() => {'id': id, 'name': name, 'url': url, 'user': username, 'pass': password};

  factory OpdsServer.fromJson(Map<String, Object?> j) => OpdsServer(
        id: '${j['id']}',
        name: '${j['name']}',
        url: '${j['url']}',
        username: '${j['user'] ?? ''}',
        password: '${j['pass'] ?? ''}',
      );
}

/// Satu tautan unduhan (satu format) dari entri OPDS.
class OpdsAcquisition {
  const OpdsAcquisition({required this.url, required this.type});

  final String url;
  final String type;

  /// Ekstensi file dari tipe MIME; null bila format tak didukung untuk impor.
  String? get extension => switch (type.toLowerCase().split(';').first.trim()) {
        'application/epub+zip' => 'epub',
        'application/vnd.comicbook+zip' || 'application/x-cbz' || 'application/zip' => 'cbz',
        'application/pdf' => 'pdf',
        _ => null,
      };

  /// Bisa diimpor ke perpustakaan lokal (EPUB atau CBZ).
  bool get importable => extension == 'epub' || extension == 'cbz';

  String get formatLabel => (extension ?? type.split('/').last).toUpperCase();
}

/// Entri dalam feed: sub-katalog (navigasi) atau buku/komik (akuisisi).
class OpdsEntry {
  const OpdsEntry({
    required this.title,
    this.author,
    this.summary,
    this.thumbnail,
    this.navigateTo,
    this.acquisitions = const [],
  });

  final String title;
  final String? author;
  final String? summary;
  final String? thumbnail;

  /// URL feed berikutnya bila ini sub-katalog.
  final String? navigateTo;
  final List<OpdsAcquisition> acquisitions;

  bool get isBook => acquisitions.isNotEmpty;
}

class OpdsFeed {
  const OpdsFeed({required this.title, required this.entries, this.next, this.searchTemplate});

  final String title;
  final List<OpdsEntry> entries;

  /// Halaman berikutnya (rel="next").
  final String? next;

  /// Templat pencarian dengan `{searchTerms}`; null bila server tak mendukung.
  final String? searchTemplate;
}

/// Parser & klien OPDS 1.x (Atom).
class OpdsClient {
  OpdsClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              responseType: ResponseType.plain,
            ));

  final Dio _dio;

  Future<OpdsFeed> fetch(OpdsServer server, String url) async {
    final res = await _dio.get<String>(
      url,
      options: Options(headers: {'Accept': 'application/atom+xml, application/xml, text/xml, */*', ...server.headers}),
    );
    return parse(res.data ?? '', Uri.parse(res.realUri.toString()));
  }

  /// Unduh [url] ke [path] dengan login server (mengikuti redirect).
  Future<void> download(OpdsServer server, String url, String path) async {
    await _dio.download(url, path, options: Options(headers: server.headers, responseType: ResponseType.bytes));
  }

  static const _acq = 'http://opds-spec.org/acquisition';
  static const _imageRels = {'http://opds-spec.org/image/thumbnail', 'http://opds-spec.org/thumbnail', 'http://opds-spec.org/image'};

  static OpdsFeed parse(String xml, Uri base) {
    final doc = XmlDocument.parse(xml);
    final feed = doc.rootElement;
    String? href(XmlElement e) {
      final h = e.getAttribute('href');
      return h == null || h.isEmpty ? null : base.resolve(h).toString();
    }

    String? text(XmlElement e, String name) {
      final t = e.getElement(name)?.innerText.trim();
      return t == null || t.isEmpty ? null : t;
    }

    final feedLinks = feed.findElements('link').toList();
    String? next;
    String? search;
    for (final l in feedLinks) {
      final rel = l.getAttribute('rel');
      final type = l.getAttribute('type') ?? '';
      if (rel == 'next') next = href(l);
      if (rel == 'search' && type.contains('atom+xml')) {
        final h = l.getAttribute('href') ?? '';
        if (h.contains('{searchTerms}')) search = base.resolve(h.replaceAll('{searchTerms}', '__Q__')).toString().replaceAll('__Q__', '{searchTerms}');
      }
    }

    final entries = <OpdsEntry>[];
    for (final e in feed.findElements('entry')) {
      final links = e.findElements('link').toList();
      final acquisitions = <OpdsAcquisition>[];
      String? thumb;
      String? nav;
      for (final l in links) {
        final rel = l.getAttribute('rel') ?? '';
        final type = l.getAttribute('type') ?? '';
        final h = href(l);
        if (h == null) continue;
        if (rel.startsWith(_acq)) {
          acquisitions.add(OpdsAcquisition(url: h, type: type));
        } else if (_imageRels.contains(rel)) {
          if (thumb == null || rel.contains('thumbnail')) thumb = h;
        } else if (nav == null &&
            type.contains('atom+xml') &&
            !rel.contains('self') &&
            !rel.contains('search') &&
            rel != 'alternate') {
          nav = h;
        }
      }
      entries.add(OpdsEntry(
        title: text(e, 'title') ?? '(tanpa judul)',
        author: e.getElement('author')?.getElement('name')?.innerText.trim(),
        summary: text(e, 'summary') ?? text(e, 'content'),
        thumbnail: thumb,
        navigateTo: acquisitions.isEmpty ? nav : null,
        acquisitions: acquisitions,
      ));
    }
    return OpdsFeed(title: text(feed, 'title') ?? 'OPDS', entries: entries, next: next, searchTemplate: search);
  }
}
