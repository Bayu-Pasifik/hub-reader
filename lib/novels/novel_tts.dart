import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Pembaca suara (TTS) untuk satu bab novel: membacakan paragraf satu per
/// satu, menandai paragraf aktif, dan memberi tahu saat bab selesai.
class NovelTts extends ChangeNotifier {
  NovelTts({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _ready = false;

  /// Teks per blok bab (null = blok tanpa teks, mis. gambar; dilewati).
  List<String?> _texts = const [];
  int _index = 0;
  bool _playing = false;
  int _run = 0;

  /// Dipanggil saat paragraf terakhir selesai dibacakan.
  VoidCallback? onChapterEnd;

  bool get playing => _playing;

  /// Blok yang sedang/akan dibacakan; -1 bila TTS tidak aktif.
  int get index => _active ? _index : -1;
  bool _active = false;
  bool get active => _active;

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    await _tts.awaitSpeakCompletion(true);
  }

  Future<void> configure({required double rate, required double pitch, String? language}) async {
    await _init();
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    if (language != null) {
      try {
        if (await _tts.isLanguageAvailable(language) == true) await _tts.setLanguage(language);
      } catch (_) {
        // bahasa tidak tersedia: pakai bawaan mesin TTS
      }
    }
  }

  /// Mulai membacakan [texts] dari blok [from].
  Future<void> start(List<String?> texts, {int from = 0}) async {
    await _init();
    _texts = texts;
    _index = from.clamp(0, texts.isEmpty ? 0 : texts.length - 1);
    _active = true;
    await _play();
  }

  Future<void> _play() async {
    final run = ++_run;
    _playing = true;
    notifyListeners();
    while (run == _run && _index < _texts.length) {
      final text = _texts[_index]?.trim();
      if (text != null && text.isNotEmpty) {
        for (final chunk in splitForTts(text)) {
          if (run != _run) return;
          await _tts.speak(chunk);
        }
      }
      if (run != _run) return;
      if (_index >= _texts.length - 1) break;
      _index++;
      notifyListeners();
    }
    if (run != _run) return;
    _playing = false;
    _active = false;
    notifyListeners();
    onChapterEnd?.call();
  }

  Future<void> pause() async {
    _run++;
    _playing = false;
    notifyListeners();
    await _tts.stop();
  }

  Future<void> resume() async {
    if (!_active || _playing) return;
    await _play();
  }

  /// Lompat ke paragraf sebelum/sesudah.
  Future<void> skip(int delta) async {
    if (!_active) return;
    final wasPlaying = _playing;
    _run++;
    await _tts.stop();
    _index = (_index + delta).clamp(0, _texts.length - 1);
    notifyListeners();
    if (wasPlaying) await _play();
  }

  Future<void> stop() async {
    _run++;
    _playing = false;
    _active = false;
    notifyListeners();
    await _tts.stop();
  }

  @override
  void dispose() {
    _run++;
    _tts.stop();
    super.dispose();
  }
}

/// Mesin TTS Android menolak teks yang terlalu panjang (~4000 karakter);
/// potong per kalimat menjadi bagian ≤ [max].
List<String> splitForTts(String text, {int max = 3000}) {
  if (text.length <= max) return [text];
  final out = <String>[];
  final buf = StringBuffer();
  for (final sentence in RegExp(r'[^.!?。！？\n]+[.!?。！？\n]*').allMatches(text).map((m) => m[0]!)) {
    if (buf.length + sentence.length > max && buf.isNotEmpty) {
      out.add(buf.toString());
      buf.clear();
    }
    if (sentence.length > max) {
      for (var i = 0; i < sentence.length; i += max) {
        out.add(sentence.substring(i, (i + max).clamp(0, sentence.length)));
      }
    } else {
      buf.write(sentence);
    }
  }
  if (buf.isNotEmpty) out.add(buf.toString());
  return out;
}

/// Locale TTS dari kode bahasa plugin (`NovelPluginInfo.lang`, mis. `id`).
String? ttsLanguageFor(String lang) => switch (lang) {
      'id' => 'id-ID',
      'en' => 'en-US',
      'es' => 'es-ES',
      'pt' => 'pt-BR',
      'fr' => 'fr-FR',
      'ru' => 'ru-RU',
      'tr' => 'tr-TR',
      'vi' => 'vi-VN',
      'ja' => 'ja-JP',
      'ko' => 'ko-KR',
      'zh' => 'zh-CN',
      'ar' => 'ar',
      'th' => 'th-TH',
      'pl' => 'pl-PL',
      'uk' => 'uk-UA',
      'bn' => 'bn-IN',
      _ => null,
    };
