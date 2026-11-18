// Pembantu bersama untuk sumber port keiyoushi/extensions-source (Apache-2.0).

import 'dart:convert';

import '../html_utils.dart';

/// Membuka skrip p.a.c.k.e.r (`eval(function(p,a,c,k,e,d){...}('...',a,c,'...'.split('|'),0,{}))`)
/// dan mengembalikan teks hasilnya, atau null bila bukan format itu.
String? unpackPacker(String source) {
  final m = RegExp(r"\}\('((?:[^'\\]|\\.)*)',\s*(\d+),\s*(\d+),\s*'((?:[^'\\]|\\.)*)'\.split\('\|'\)").firstMatch(source);
  if (m == null) return null;
  final payload = m[1]!.replaceAllMapped(RegExp(r"\\(.)"), (e) => e[1]!);
  final radix = int.parse(m[2]!);
  final words = m[4]!.split('|');
  String encode(int n) {
    const digits = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final prefix = n < radix ? '' : encode(n ~/ radix);
    final c = n % radix;
    return prefix + (c > 35 ? String.fromCharCode(c + 29) : digits[c]);
  }

  final map = <String, String>{};
  for (var i = 0; i < words.length; i++) {
    map[encode(i)] = words[i].isEmpty ? encode(i) : words[i];
  }
  return payload.replaceAllMapped(RegExp(r'\b\w+\b'), (e) => map[e[0]] ?? e[0]!);
}

/// Tanggal gaya "Mar 02,2026" / "Today" / "Yesterday" / "3 hours ago".
DateTime? looseDate(String? raw) {
  final t = clean(raw);
  if (t.isEmpty) return null;
  final lower = t.toLowerCase();
  final now = DateTime.now();
  if (lower.contains('today')) return DateTime(now.year, now.month, now.day);
  if (lower.contains('yesterday')) return DateTime(now.year, now.month, now.day - 1);
  return parseLooseDate(t.replaceAll(',', ', '));
}

/// Jalankan [tasks] dengan paralelisme terbatas, hasil tetap berurutan.
Future<List<T>> pooled<T>(List<Future<T> Function()> tasks, {int size = 6}) async {
  final out = <T>[];
  for (var i = 0; i < tasks.length; i += size) {
    out.addAll(await Future.wait(tasks.skip(i).take(size).map((f) => f())));
  }
  return out;
}

/// Gabungan isi `self.__next_f.push([1,"..."])` di HTML Next.js (data RSC).
String nextFlightBody(String html) {
  final buf = StringBuffer();
  for (final m in RegExp(r'self\.__next_f\.push\(\[1,("(?:[^"\\]|\\.)*")\]\)').allMatches(html)) {
    try {
      buf.write(jsonDecode(m[1]!) as String);
    } on FormatException {
      continue;
    }
  }
  return buf.toString();
}
