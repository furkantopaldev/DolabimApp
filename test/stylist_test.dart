import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dolabim/data/models.dart';
import 'package:dolabim/services/weather_service.dart';
import 'package:dolabim/stylist/stylist.dart';

Garment g(
  String id,
  String category,
  Color color, {
  Set<EventType> events = const {},
}) =>
    Garment.user(
      id: id,
      name: id,
      category: category,
      photoPath: '/yok/$id.jpg',
      color: color,
      events: events,
    );

const black = Color(0xFF111111);
const white = Color(0xFFFFFFFF);
const navy = Color(0xFF1F2F5C);
const red = Color(0xFFD02020);
const green = Color(0xFF2E9B3A);
const orange = Color(0xFFE88A1A);

Weather weather(double temp, {double? evening, int rain = 0}) => Weather(
      temp: temp,
      eveningTemp: evening ?? temp,
      min: temp - 3,
      max: temp + 3,
      rainChance: rain,
      code: 2,
    );

void main() {
  group('renk uyumu', () {
    test('nötr renkler her şeyle uyumludur', () {
      final s = Stylist.pairScore(g('a', 'Üst', black), g('b', 'Alt', red));
      expect(s, greaterThanOrEqualTo(2.0));
    });

    test('gerçek zıt renkler (kırmızı-turkuaz) kırmızı-yeşilden daha uyumlu', () {
      final complementary =
          Stylist.pairScore(g('a', 'Üst', red), g('b', 'Alt', const Color(0xFF20C0C0)));
      final weaker = Stylist.pairScore(g('a', 'Üst', red), g('b', 'Alt', green));
      expect(complementary, 2.4);
      expect(weaker, 1.2);
      expect(complementary, greaterThan(weaker));
    });

    test('aynı renk ailesi en yüksek puanı alır', () {
      final s = Stylist.pairScore(g('a', 'Üst', red), g('b', 'Alt', const Color(0xFFB02030)));
      expect(s, 2.6);
    });
  });

  group('kombin üretimi', () {
    final wardrobe = [
      g('bluz', 'Üst', white),
      g('tisort', 'Üst', navy),
      g('pantolon', 'Alt', black),
      g('ceket', 'Dış giyim', navy),
      g('ayakkabi', 'Ayakkabı', black),
      g('canta', 'Çanta', const Color(0xFF8B5A2B)),
    ];

    test('dolap yetmiyorsa kombin çıkmaz', () {
      expect(Stylist.canForm([g('bluz', 'Üst', white)]), isFalse);
      expect(Stylist.canForm([g('elbise', 'Elbise', red)]), isTrue);
      expect(
        Stylist.suggest(wardrobe: [g('bluz', 'Üst', white)], event: EventType.work),
        isEmpty,
      );
    });

    test('her kombin üst ile alt ya da elbise içerir', () {
      final out = Stylist.suggest(wardrobe: wardrobe, event: EventType.work);
      expect(out, isNotEmpty);
      for (final o in out) {
        final cats = o.items.map((i) => i.category).toList();
        expect(cats.contains('Elbise') || (cats.contains('Üst') && cats.contains('Alt')), isTrue);
      }
    });

    test('soğuk havada dış parça eklenir, sıcakta eklenmez', () {
      final cold = Stylist.suggest(
        wardrobe: wardrobe,
        event: EventType.work,
        weather: weather(8),
      );
      expect(cold.every((o) => o.items.any((i) => i.category == 'Dış giyim')), isTrue);

      final hot = Stylist.suggest(
        wardrobe: wardrobe,
        event: EventType.work,
        weather: weather(30),
      );
      expect(hot.any((o) => o.items.any((i) => i.category == 'Dış giyim')), isFalse);
    });

    test('akşam serinse sıcaklık akşama göre değerlendirilir', () {
      final out = Stylist.suggest(
        wardrobe: wardrobe,
        event: EventType.work,
        weather: weather(24, evening: 10),
      );
      expect(out.every((o) => o.items.any((i) => i.category == 'Dış giyim')), isTrue);
    });

    test('etiketlenmiş parça uymadığı etkinlikte geri düşer', () {
      final tagged = [
        g('spor-tisort', 'Üst', white, events: {EventType.sport}),
        g('resmi-gomlek', 'Üst', white, events: {EventType.work}),
        g('pantolon', 'Alt', black),
      ];
      final out = Stylist.suggest(wardrobe: tagged, event: EventType.work);
      expect(out.first.items.first.id, 'resmi-gomlek');
      final sport = Stylist.suggest(wardrobe: tagged, event: EventType.sport);
      expect(sport.first.items.first.id, 'spor-tisort');
    });

    test('spor için elbise yerine üst ve alt tercih edilir', () {
      final w = [
        g('elbise', 'Elbise', black),
        g('tisort', 'Üst', white),
        g('esofman', 'Alt', black),
      ];
      final out = Stylist.suggest(wardrobe: w, event: EventType.sport);
      expect(out.first.items.any((i) => i.id == 'tisort'), isTrue);
    });

    test('limit ve not metni', () {
      final out = Stylist.suggest(
        wardrobe: wardrobe,
        event: EventType.date,
        weather: weather(20),
        limit: 1,
      );
      expect(out.length, 1);
      expect(out.first.note, contains('birlikte iyi duruyor'));
      expect(out.first.title, isNotEmpty);
    });
  });

  group('alışveriş', () {
    final wardrobe = [
      g('bluz', 'Üst', white),
      g('pantolon', 'Alt', black),
      g('ayakkabi', 'Ayakkabı', black),
    ];

    test('ürünle eşleşen parçalar tamamlayıcı türlerden gelir', () {
      final item = g('ceket', 'Dış giyim', navy);
      final m = Stylist.matches(item, wardrobe);
      expect(m.map((x) => x.garment.category).toSet(), {'Üst', 'Alt', 'Ayakkabı'});
      expect(m.first.why, isNotEmpty);
    });

    test('ürün eklenince çıkan kombin sayısı hesaplanır', () {
      final item = g('ceket', 'Dış giyim', navy);
      expect(Stylist.outfitCountWith(item, wardrobe), greaterThan(0));
    });

    test('boş dolapta eşleşme ve kombin yoktur', () {
      final item = g('ceket', 'Dış giyim', navy);
      expect(Stylist.matches(item, const []), isEmpty);
      expect(Stylist.outfitCountWith(item, const []), 0);
    });
  });
}
