import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/ui/screens/sources/source_webview_screen.dart';

void main() {
  test('judul tantangan Cloudflare dikenali lintas bahasa', () {
    for (final t in ['Just a moment...', 'Un instant…', 'Einen Moment…', 'Один момент…', 'Attention Required! | Cloudflare']) {
      expect(isCloudflareChallengeTitle(t), isTrue, reason: t);
    }
    expect(isCloudflareChallengeTitle('One Piece Chapter 1100 - Komiku'), isFalse);
  });
}
