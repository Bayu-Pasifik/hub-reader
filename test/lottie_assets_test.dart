import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/ui/widgets/state_views.dart';
import 'package:lottie/lottie.dart';

void main() {
  test('every bundled Lottie animation decodes', () async {
    for (final a in AppAnimation.values) {
      final bytes = File(a.asset).readAsBytesSync();
      final composition = a.isDotLottie
          ? await LottieComposition.decodeZip(bytes, filePicker: (files) {
              for (final f in files) {
                if (f.name.startsWith('animations/') && f.name.endsWith('.json')) return f;
              }
              return null;
            })
          : await LottieComposition.fromBytes(bytes);
      expect(composition?.duration, greaterThan(Duration.zero), reason: a.asset);
    }
  });
}
