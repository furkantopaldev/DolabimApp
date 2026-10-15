import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dolabim/services/color_analysis.dart';
import 'package:dolabim/services/weather_service.dart';

Uint8List solid(int w, int h, Color c) {
  final data = Uint8List(w * h * 4);
  for (var i = 0; i < w * h; i++) {
    data[i * 4] = (c.r * 255).round();
    data[i * 4 + 1] = (c.g * 255).round();
    data[i * 4 + 2] = (c.b * 255).round();
    data[i * 4 + 3] = 255;
  }
  return data;
}

void main() {
  group('renk analizi', () {
    test('ortadaki baskın renk kenardaki arka plana baskın çıkar', () {
      const w = 20;
      const h = 20;
      final data = solid(w, h, const Color(0xFFEEEEEE));
      // Ortadaki kare lacivert.
      for (var y = 5; y < 15; y++) {
        for (var x = 5; x < 15; x++) {
          final i = (y * w + x) * 4;
          data[i] = 20;
          data[i + 1] = 30;
          data[i + 2] = 90;
        }
      }
      final c = ColorAnalysis.dominantFromRgba(data, w, h)!;
      expect(ColorAnalysis.nameOf(c), 'Lacivert');
    });

    test('piksel yoksa null döner', () {
      expect(ColorAnalysis.dominantFromRgba(Uint8List(0), 0, 0), isNull);
    });

    test('Türkçe renk adları', () {
      expect(ColorAnalysis.nameOf(const Color(0xFF000000)), 'Siyah');
      expect(ColorAnalysis.nameOf(const Color(0xFFFFFFFF)), 'Beyaz');
      expect(ColorAnalysis.nameOf(const Color(0xFF808080)), 'Gri');
      expect(ColorAnalysis.nameOf(const Color(0xFFC62828)), 'Kırmızı');
      expect(ColorAnalysis.nameOf(const Color(0xFF2E7D32)), 'Yeşil');
      expect(ColorAnalysis.nameOf(const Color(0xFF1565C0)), 'Mavi');
      expect(ColorAnalysis.nameOf(const Color(0xFF6D4C41)), 'Kahverengi');
    });

    test('gökyüzü mavisi Açık mavi, lacivert Lacivert olur', () {
      // Gerçek fotoğraftaki açık mavi blazer tonu.
      expect(ColorAnalysis.nameOf(const Color(0xFF90B4E8)), 'Açık mavi');
      expect(ColorAnalysis.nameOf(const Color(0xFF1C2A52)), 'Lacivert');
    });

    test('koyu zeytin tonu Haki, açık sarımsı ton Krem, canlı sarı Sarı olur', () {
      expect(ColorAnalysis.nameOf(const Color(0xFF4F4A28)), 'Haki');
      expect(ColorAnalysis.nameOf(const Color(0xFFF1E7C8)), 'Krem');
      expect(ColorAnalysis.nameOf(const Color(0xFFE8C21A)), 'Sarı');
    });
  });

  group('hava durumu', () {
    Map<String, dynamic> body({int code = 2, int? rain = 20}) => {
          'current': {'temperature_2m': 17.5, 'weather_code': code},
          'hourly': {
            'time': [
              for (var h = 0; h < 24; h++) '2026-10-15T${h.toString().padLeft(2, '0')}:00',
            ],
            'temperature_2m': [for (var h = 0; h < 24; h++) 10.0 + h * 0.5],
          },
          'daily': {
            'temperature_2m_max': [21.0],
            'temperature_2m_min': [11.0],
            'precipitation_probability_max': [rain],
          },
        };

    test('yanıt çözülür ve akşam sıcaklığı 20:00 saatinden alınır', () {
      final w = WeatherService.parse(body());
      expect(w.temp, 17.5);
      expect(w.eveningTemp, 20.0);
      expect(w.min, 11);
      expect(w.max, 21);
      expect(w.rainChance, 20);
      expect(w.summary, 'Parçalı bulutlu');
      expect(w.kind, WeatherKind.partly);
      expect(w.effectiveTemp, 17.5);
    });

    test('yağış ihtimali yoksa sıfır sayılır, yağmur kodu yağışlı sayılır', () {
      expect(WeatherService.parse(body(rain: null)).rainChance, 0);
      final rainy = WeatherService.parse(body(code: 63));
      expect(rainy.kind, WeatherKind.rain);
      expect(rainy.rainy, isTrue);
      expect(rainy.advice, contains('Yağış'));
    });

    test('bozuk yanıt anlaşılır bir hata verir', () {
      expect(
        () => WeatherService.parse({'current': 1}),
        throwsA(isA<WeatherException>()),
      );
    });

    test('şehir etiketi ve JSON', () {
      const c = City(name: 'Kadıköy', lat: 40.99, lon: 29.03, region: 'İstanbul');
      expect(c.label, 'Kadıköy, İstanbul');
      expect(City.fromJson(c.toJson()).label, 'Kadıköy, İstanbul');
      expect(City.istanbul.label, 'İstanbul');
    });
  });
}
