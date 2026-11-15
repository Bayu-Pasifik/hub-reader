import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/ui/widgets/brightness_strip.dart';

void main() {
  test('geser ke atas menaikkan, ke bawah menurunkan', () {
    expect(brightnessFromDrag(0.5, -400, 1000), closeTo(1.0, 1e-9)); // +0.6 dijepit ke 1
    expect(brightnessFromDrag(0.5, -100, 1000), closeTo(0.65, 1e-9));
    expect(brightnessFromDrag(0.5, 100, 1000), closeTo(0.35, 1e-9));
  });

  test('hasil dijepit ke 0.05..1', () {
    expect(brightnessFromDrag(0.5, 5000, 1000), 0.05);
    expect(brightnessFromDrag(0.9, -5000, 1000), 1.0);
  });

  test('ikut sistem (0) dihitung mulai dari 0.5', () {
    expect(brightnessFromDrag(0, 0, 1000), 0.5);
    expect(brightnessFromDrag(0, -100, 1000), closeTo(0.65, 1e-9));
  });

  test('tinggi nol tidak membagi nol', () {
    expect(brightnessFromDrag(0.3, 50, 0), 0.3);
    expect(brightnessFromDrag(0, 50, 0), 0.5);
  });
}
