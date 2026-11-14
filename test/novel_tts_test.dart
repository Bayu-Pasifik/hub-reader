import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/novels/novel_tts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('splitForTts keeps short text and splits long text by sentence', () {
    expect(splitForTts('Halo dunia.'), ['Halo dunia.']);
    final long = List.generate(50, (i) => 'Kalimat nomor $i cukup panjang untuk diuji. ').join();
    final parts = splitForTts(long, max: 200);
    expect(parts.length, greaterThan(1));
    expect(parts.every((p) => p.length <= 200), isTrue);
    expect(parts.join(), long);
  });

  test('ttsLanguageFor maps plugin language codes', () {
    expect(ttsLanguageFor('id'), 'id-ID');
    expect(ttsLanguageFor('en'), 'en-US');
    expect(ttsLanguageFor('all'), isNull);
  });

  test('timer tidur bisa dipasang dan dibatalkan', () {
    final tts = NovelTts();
    expect(tts.sleepActive, isFalse);
    tts.setSleep(after: const Duration(minutes: 15));
    expect(tts.sleepActive, isTrue);
    expect(tts.sleepAt, isNotNull);
    tts.setSleep(atChapterEnd: true);
    expect(tts.sleepAt, isNull);
    expect(tts.sleepAtChapterEnd, isTrue);
    tts.setSleep();
    expect(tts.sleepActive, isFalse);
  });
}
