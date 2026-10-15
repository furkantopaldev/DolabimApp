import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Fotoğraftan baskın rengi çıkarır ve renge Türkçe ad verir.
/// Yapay zeka kullanmaz, tamamen cihazda çalışır.
class ColorAnalysis {
  /// Fotoğrafın ortasındaki (kıyafetin durduğu bölge) baskın renk.
  /// Okunamazsa null döner.
  static Future<Color?> dominantColor(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 64);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return null;
      return dominantFromRgba(
        data.buffer.asUint8List(),
        image.width,
        image.height,
      );
    } catch (_) {
      return null;
    }
  }

  /// RGBA piksel dizisinden baskın rengi bulur. Ortadaki %50'lik bölge
  /// taranır, renkler ton ve açıklığa göre kutulara ayrılır, en kalabalık
  /// kutunun ortalaması döner.
  static Color? dominantFromRgba(Uint8List rgba, int width, int height) {
    final counts = <int, int>{};
    final sums = <int, List<int>>{};
    final x0 = (width * 0.25).floor();
    final x1 = (width * 0.75).ceil();
    final y0 = (height * 0.25).floor();
    final y1 = (height * 0.75).ceil();
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        final i = (y * width + x) * 4;
        if (i + 3 >= rgba.length || rgba[i + 3] < 200) continue;
        final r = rgba[i];
        final g = rgba[i + 1];
        final b = rgba[i + 2];
        final hsl = HSLColor.fromColor(Color.fromARGB(255, r, g, b));
        final int bin;
        if (hsl.saturation < 0.18 || hsl.lightness < 0.12) {
          // Nötr renkler (siyah, gri, beyaz) açıklığa göre ayrılır.
          bin = 100 + (hsl.lightness * 4).floor().clamp(0, 3);
        } else {
          final band = hsl.lightness < 0.35 ? 0 : (hsl.lightness < 0.65 ? 1 : 2);
          bin = (hsl.hue / 30).floor().clamp(0, 11) * 3 + band;
        }
        counts[bin] = (counts[bin] ?? 0) + 1;
        final s = sums.putIfAbsent(bin, () => [0, 0, 0]);
        s[0] += r;
        s[1] += g;
        s[2] += b;
      }
    }
    if (counts.isEmpty) return null;
    final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final n = counts[best]!;
    final s = sums[best]!;
    return Color.fromARGB(255, s[0] ~/ n, s[1] ~/ n, s[2] ~/ n);
  }

  /// Renge Türkçe ad verir (Siyah, Bej, Lacivert gibi).
  static String nameOf(Color color) {
    final hsl = HSLColor.fromColor(color);
    final h = hsl.hue;
    final s = hsl.saturation;
    final l = hsl.lightness;
    if (l < 0.14) return 'Siyah';
    if (s < 0.12) {
      if (l > 0.88) return 'Beyaz';
      if (l > 0.7) return 'Açık gri';
      if (l > 0.35) return 'Gri';
      return 'Antrasit';
    }
    if (l > 0.92) return 'Beyaz';
    if (h < 15 || h >= 345) {
      if (l < 0.3) return 'Bordo';
      if (l > 0.75) return 'Pudra';
      return 'Kırmızı';
    }
    if (h < 40) {
      if (s < 0.5 && l > 0.55) return 'Bej';
      if (l < 0.4) return 'Kahverengi';
      return 'Turuncu';
    }
    if (h < 65) {
      if (l < 0.35) return 'Haki';
      if (l > 0.8) return 'Krem';
      if (s < 0.4) return l > 0.55 ? 'Krem' : 'Haki';
      return 'Sarı';
    }
    if (h < 165) return l < 0.3 ? 'Koyu yeşil' : 'Yeşil';
    if (h < 200) return 'Turkuaz';
    if (h < 255) {
      if (l < 0.3) return 'Lacivert';
      if (l > 0.65) return 'Açık mavi';
      return 'Mavi';
    }
    if (h < 290) return 'Mor';
    if (l < 0.35) return 'Mürdüm';
    if (l > 0.65) return 'Pembe';
    return 'Gül kurusu';
  }
}
