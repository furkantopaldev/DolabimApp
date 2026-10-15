import 'package:flutter/painting.dart';

import '../data/models.dart';
import '../services/weather_service.dart';

/// Kombin üreten kural tabanlı stilist. Dolaptaki parçaların renk uyumuna,
/// etkinliğe ve havaya bakarak puanlar, en iyilerini önerir. Yapay zeka
/// kullanmaz, tamamen cihazda çalışır.
class Stylist {
  const Stylist._();

  static const _titles = <EventType, List<String>>{
    EventType.work: ['Ofis şıklığı', 'Toplantı günü', 'Derli toplu bir gün'],
    EventType.date: ['Rahat buluşma', 'Akşam yemeği', 'Şık bir kahve'],
    EventType.party: ['Davet gecesi', 'Kokteyl', 'Gece çıkışı'],
    EventType.sport: ['Hareketli gün', 'Hafif yürüyüş', 'Spor günü'],
  };

  static List<Garment> _of(List<Garment> w, String category) =>
      [for (final g in w) if (g.category == category) g];

  /// Dolap en az bir kombin kurmaya yetiyor mu (elbise ya da üst + alt)?
  static bool canForm(List<Garment> wardrobe) =>
      _of(wardrobe, 'Elbise').isNotEmpty ||
      (_of(wardrobe, 'Üst').isNotEmpty && _of(wardrobe, 'Alt').isNotEmpty);

  /// Bir kombinin gövdesi: tek elbise ya da üst + alt çifti.
  static List<List<Garment>> _bases(List<Garment> w) => [
        for (final d in _of(w, 'Elbise')) [d],
        for (final t in _of(w, 'Üst'))
          for (final b in _of(w, 'Alt')) [t, b],
      ];

  static bool _neutral(Color c) {
    final h = HSLColor.fromColor(c);
    return h.saturation < 0.18 || h.lightness < 0.14 || h.lightness > 0.9;
  }

  static double _hueDiff(Color a, Color b) {
    final d = (HSLColor.fromColor(a).hue - HSLColor.fromColor(b).hue).abs();
    return d > 180 ? 360 - d : d;
  }

  /// İki parçanın renk uyumu, 0.8 (zayıf) ile 2.6 (çok uyumlu) arasında.
  static double pairScore(Garment a, Garment b) {
    final ca = a.tone;
    final cb = b.tone;
    if (_neutral(ca) && _neutral(cb)) return 2.0;
    if (_neutral(ca) || _neutral(cb)) return 2.2;
    final d = _hueDiff(ca, cb);
    if (d <= 25) return 2.6;
    if (d <= 60) return 2.0;
    if (d >= 150) return 2.4;
    if (d >= 100) return 1.2;
    return 0.8;
  }

  /// Parça grubunun ortalama renk uyumu.
  static double harmony(List<Garment> items) {
    if (items.length < 2) return 2.0;
    var sum = 0.0;
    var n = 0;
    for (var i = 0; i < items.length; i++) {
      for (var j = i + 1; j < items.length; j++) {
        sum += pairScore(items[i], items[j]);
        n++;
      }
    }
    return sum / n;
  }

  /// İki parçanın neden uyduğunu anlatan kısa cümle.
  static String why(Garment a, Garment b) {
    if (_neutral(a.tone) || _neutral(b.tone)) return 'Nötr ton, her şeyle gider';
    final d = _hueDiff(a.tone, b.tone);
    if (d <= 25) return 'Aynı renk ailesinden';
    if (d <= 60) return 'Yakın tonlar, sakin bir bütün';
    if (d >= 150) return 'Zıt renk, canlı kontrast';
    return 'İlginç bir renk dengesi';
  }

  static double _eventScore(List<Garment> items, EventType e) {
    var s = 0.0;
    for (final g in items) {
      if (g.events.isNotEmpty) s += g.events.contains(e) ? 1.0 : -2.0;
      if (e == EventType.sport && g.category == 'Elbise') s -= 1.5;
      if (e == EventType.sport && g.category == 'Dış giyim') s -= 0.5;
      if (e == EventType.party && g.category == 'Elbise') s += 1.0;
      if (e == EventType.work && g.category == 'Dış giyim') s += 0.5;
    }
    return s;
  }

  static Garment? _best(List<Garment> options, List<Garment> current, EventType e) {
    Garment? best;
    var bestScore = double.negativeInfinity;
    for (final o in options) {
      var s = 0.0;
      for (final c in current) {
        s += pairScore(o, c);
      }
      s = s / current.length + _eventScore([o], e);
      if (s > bestScore) {
        bestScore = s;
        best = o;
      }
    }
    return best;
  }

  /// Etkinliğe ve havaya göre en iyi kombinleri puan sırasıyla döndürür.
  /// Her gövde (elbise ya da üst + alt) için en iyi dış parça, ayakkabı ve
  /// çanta seçilir.
  static List<Outfit> suggest({
    required List<Garment> wardrobe,
    required EventType event,
    Weather? weather,
    int limit = 6,
  }) {
    final temp = weather?.effectiveTemp ?? 20;
    final cold = temp < 17;
    final hot = temp > 25;
    final outers = _of(wardrobe, 'Dış giyim');
    final shoes = _of(wardrobe, 'Ayakkabı');
    final bags = _of(wardrobe, 'Çanta');

    final scored = <_Scored>[];
    for (final base in _bases(wardrobe)) {
      final outerOptions = <Garment?>[
        if (!cold || outers.isEmpty) null,
        if (!hot) ...outers,
      ];
      for (final outer in outerOptions) {
        final core = [...base, if (outer != null) outer];
        final shoe = _best(shoes, core, event);
        final withShoe = [...core, if (shoe != null) shoe];
        final bag = _best(bags, withShoe, event);
        final all = [...withShoe, if (bag != null) bag];
        var score = harmony(all) * 2 + _eventScore(all, event);
        if (outer != null) {
          score += cold ? 1.5 : 0.3;
        } else if (hot) {
          score += 0.5;
        }
        score += 0.6 * ((shoe != null ? 1 : 0) + (bag != null ? 1 : 0));
        // Gösterim sırası: büyük karede en belirgin parça (dış parça ya da elbise).
        final ordered = <Garment>[
          if (base.length == 1) base.first,
          if (outer != null) outer,
          if (base.length == 2) ...base,
          if (shoe != null) shoe,
          if (bag != null) bag,
        ];
        scored.add(_Scored(base.map((g) => g.id).join('+'), ordered, score));
      }
    }
    scored.sort((a, b) => b.score.compareTo(a.score));

    final seen = <String>{};
    final result = <Outfit>[];
    for (final s in scored) {
      if (!seen.add(s.baseKey)) continue;
      final i = result.length;
      result.add(
        Outfit(
          title: _titles[event]![i % 3],
          note: _note(s.items, weather),
          items: s.items,
          score: s.score,
        ),
      );
      if (result.length >= limit) break;
    }
    return result;
  }

  static String _note(List<Garment> items, Weather? weather) {
    final main = [
      for (final g in items)
        if (g.category == 'Üst' ||
            g.category == 'Alt' ||
            g.category == 'Elbise' ||
            g.category == 'Dış giyim')
          g,
    ];
    final lead = main.length >= 2
        ? '${main[0].name} ile ${main[1].name} birlikte iyi duruyor.'
        : '${main.first.name} tek başına yeterince şık.';
    final h = harmony(items);
    final tone = h >= 2.4
        ? 'Renkler birbiriyle çok uyumlu.'
        : (h >= 1.8
            ? 'Tonlar dengeli ve uyumlu.'
            : 'Renk kontrastı canlı bir görünüm veriyor.');
    return [if (weather != null) weather.advice, lead, tone].join(' ');
  }

  // ---- Alışveriş: "bu neyle gider?" ----

  static const _partners = <String, List<String>>{
    'Üst': ['Alt', 'Dış giyim', 'Ayakkabı', 'Çanta'],
    'Alt': ['Üst', 'Dış giyim', 'Ayakkabı', 'Çanta'],
    'Elbise': ['Dış giyim', 'Ayakkabı', 'Çanta'],
    'Dış giyim': ['Üst', 'Alt', 'Elbise', 'Ayakkabı'],
    'Ayakkabı': ['Alt', 'Elbise', 'Üst', 'Dış giyim'],
    'Çanta': ['Üst', 'Alt', 'Elbise', 'Dış giyim'],
  };

  /// Taranan ürünle en iyi uyan dolap parçaları, uyum puanına göre.
  static List<ShopMatch> matches(
    Garment item,
    List<Garment> wardrobe, {
    int limit = 6,
  }) {
    final cats = _partners[item.category] ?? const [];
    final candidates = [
      for (final g in wardrobe)
        if (cats.contains(g.category)) g,
    ]..sort((a, b) => pairScore(item, b).compareTo(pairScore(item, a)));
    return [
      for (final g in candidates.take(limit)) ShopMatch(garment: g, why: why(item, g)),
    ];
  }

  /// Ürün dolaba eklenirse kaç farklı uyumlu kombin çıkar.
  static int outfitCountWith(Garment item, List<Garment> wardrobe) {
    final all = [...wardrobe, item];
    final outers = _of(all, 'Dış giyim');
    final shoes = _of(all, 'Ayakkabı');
    final bags = _of(all, 'Çanta');
    var count = 0;
    for (final base in _bases(all)) {
      for (final outer in <Garment?>[null, ...outers]) {
        final core = [...base, if (outer != null) outer];
        final inCore = core.any((g) => g.id == item.id);
        if (inCore) {
          if (harmony(core) >= 1.9) count++;
        } else if (item.category == 'Ayakkabı' || item.category == 'Çanta') {
          final extra = item.category == 'Ayakkabı' ? shoes : bags;
          if (extra.any((g) => g.id == item.id) && harmony([...core, item]) >= 1.9) {
            count++;
          }
        }
      }
    }
    return count;
  }
}

class _Scored {
  const _Scored(this.baseKey, this.items, this.score);

  final String baseKey;
  final List<Garment> items;
  final double score;
}
