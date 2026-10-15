import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dolabim/theme/palette.dart';

void main() {
  test('palet geçişi iki palet arasında ara renk üretir', () {
    final mid = AppPalette.female.lerp(AppPalette.male, 0.5);
    expect(mid.bg, Color.lerp(AppPalette.female.bg, AppPalette.male.bg, 0.5));
    expect(AppPalette.female.lerp(AppPalette.male, 1).ink, AppPalette.male.ink);
  });
}
