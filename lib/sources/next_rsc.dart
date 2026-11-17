import 'dart:convert';

final _rowStart = RegExp(r'^[0-9a-f]{1,8}:');
final _textChunk = RegExp(r'^T([0-9a-f]+),');

/// Isi tiap baris respons React Server Components (`RSC: 1`) milik Next.js App Router.
/// Baris berbentuk `<id>:<json>`; potongan teks panjang berbentuk
/// `<id>:T<panjang hex>,<isi>` dan baris berikutnya bisa langsung menyambung di
/// baris yang sama (panjang dihitung dalam byte UTF-8).
Iterable<String> rscPayloads(String body) sync* {
  for (final line in const LineSplitter().convert(body)) {
    var rest = line;
    while (true) {
      final start = _rowStart.firstMatch(rest);
      if (start == null) break;
      final payload = rest.substring(start.end);
      final chunk = _textChunk.firstMatch(payload);
      if (chunk == null) {
        yield payload;
        break;
      }
      final size = int.parse(chunk[1]!, radix: 16);
      final bytes = utf8.encode(payload.substring(chunk.end));
      final take = size > bytes.length ? bytes.length : size;
      yield utf8.decode(bytes.sublist(0, take), allowMalformed: true);
      rest = utf8.decode(bytes.sublist(take), allowMalformed: true);
    }
  }
}

/// Objek pertama (di kedalaman mana pun) yang lolos [test].
Map<String, Object?>? findRscObject(String body, bool Function(Map<String, Object?> obj) test) {
  Map<String, Object?>? walk(Object? node) {
    if (node is Map) {
      final map = node.cast<String, Object?>();
      if (test(map)) return map;
      for (final v in map.values) {
        final found = walk(v);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final v in node) {
        final found = walk(v);
        if (found != null) return found;
      }
    }
    return null;
  }

  for (final payload in rscPayloads(body)) {
    if (payload.isEmpty || (payload[0] != '[' && payload[0] != '{')) continue;
    try {
      final found = walk(jsonDecode(payload));
      if (found != null) return found;
    } on FormatException {
      continue;
    }
  }
  return null;
}
