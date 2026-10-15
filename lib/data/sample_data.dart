import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'models.dart';

/// Şimdilik örnek veri. Gerçek uygulamada kıyafetler kullanıcının fotoğraflarından,
/// kombinler ise yapay zeka servisinden gelecek.
class SampleData {
  static const _female = <String, Garment>{
    'blazer': Garment(
      id: 'blazer',
      name: 'Krem blazer',
      category: 'Dış giyim',
      shape: GarmentShape.blazer,
      bg1: Color(0xFFF3E4D3),
      bg2: Color(0xFFE6CDB3),
      fill: Color(0xFFFBF3F1),
    ),
    'shirt': Garment(
      id: 'shirt',
      name: 'İpek bluz',
      category: 'Üst',
      shape: GarmentShape.top,
      bg1: Color(0xFFF7EBDD),
      bg2: Color(0xFFEFD9BF),
      fill: Color(0xFFFFFFFF),
    ),
    'trousers': Garment(
      id: 'trousers',
      name: 'Mor pantolon',
      category: 'Alt',
      shape: GarmentShape.trousers,
      bg1: Color(0xFFEAD7DD),
      bg2: Color(0xFFD9B9C3),
      fill: Color(0xFF8E5A6B),
    ),
    'shoe': Garment(
      id: 'shoe',
      name: 'Loafer',
      category: 'Ayakkabı',
      shape: GarmentShape.shoe,
      bg1: Color(0xFFDCE0DD),
      bg2: Color(0xFFC2C9C4),
      fill: Color(0xFF3B1F2B),
    ),
    'dress': Garment(
      id: 'dress',
      name: 'Gül kurusu elbise',
      category: 'Elbise',
      shape: GarmentShape.dress,
      bg1: Color(0xFFF4D9DF),
      bg2: Color(0xFFE7B9C5),
      fill: Color(0xFFB5566F),
    ),
    'skirt': Garment(
      id: 'skirt',
      name: 'Midi etek',
      category: 'Alt',
      shape: GarmentShape.skirt,
      bg1: Color(0xFFE3E5EA),
      bg2: Color(0xFFC8CCD6),
      fill: Color(0xFF5B4A63),
    ),
    'bag': Garment(
      id: 'bag',
      name: 'Deri çanta',
      category: 'Çanta',
      shape: GarmentShape.bag,
      bg1: Color(0xFFEBD9CF),
      bg2: Color(0xFFD8B9A8),
      fill: Color(0xFF7B3F3A),
    ),
    'tee': Garment(
      id: 'tee',
      name: 'Beyaz tişört',
      category: 'Üst',
      shape: GarmentShape.top,
      bg1: Color(0xFFF1E6E8),
      bg2: Color(0xFFE2CFD4),
      fill: Color(0xFFFFFFFF),
    ),
  };

  // Erkek kataloğunda aynı kimlikler erkek giyimine karşılık gelir
  // (dress -> triko, skirt -> koyu kot).
  static const _male = <String, Garment>{
    'blazer': Garment(
      id: 'blazer',
      name: 'Lacivert blazer',
      category: 'Dış giyim',
      shape: GarmentShape.blazer,
      bg1: Color(0xFFDCE4EE),
      bg2: Color(0xFFC0CEDF),
      fill: Color(0xFF25415F),
    ),
    'shirt': Garment(
      id: 'shirt',
      name: 'Beyaz gömlek',
      category: 'Üst',
      shape: GarmentShape.top,
      bg1: Color(0xFFEEF2F6),
      bg2: Color(0xFFDAE2EB),
      fill: Color(0xFFFFFFFF),
    ),
    'trousers': Garment(
      id: 'trousers',
      name: 'Bej chino',
      category: 'Alt',
      shape: GarmentShape.trousers,
      bg1: Color(0xFFF0E8DA),
      bg2: Color(0xFFE0D2BB),
      fill: Color(0xFFB59B72),
    ),
    'shoe': Garment(
      id: 'shoe',
      name: 'Deri loafer',
      category: 'Ayakkabı',
      shape: GarmentShape.shoe,
      bg1: Color(0xFFE2E2E0),
      bg2: Color(0xFFCACBC8),
      fill: Color(0xFF4A3426),
    ),
    'dress': Garment(
      id: 'dress',
      name: 'Gri triko',
      category: 'Üst',
      shape: GarmentShape.top,
      bg1: Color(0xFFE3E6EA),
      bg2: Color(0xFFCBD0D8),
      fill: Color(0xFF6B7785),
    ),
    'skirt': Garment(
      id: 'skirt',
      name: 'Koyu kot',
      category: 'Alt',
      shape: GarmentShape.trousers,
      bg1: Color(0xFFDDE3EC),
      bg2: Color(0xFFBFCADB),
      fill: Color(0xFF3C5578),
    ),
    'bag': Garment(
      id: 'bag',
      name: 'Deri çanta',
      category: 'Çanta',
      shape: GarmentShape.bag,
      bg1: Color(0xFFE9DFD6),
      bg2: Color(0xFFD4C0AE),
      fill: Color(0xFF6B4A36),
    ),
    'tee': Garment(
      id: 'tee',
      name: 'Beyaz tişört',
      category: 'Üst',
      shape: GarmentShape.top,
      bg1: Color(0xFFEDF0F4),
      bg2: Color(0xFFDCE2EA),
      fill: Color(0xFFFFFFFF),
    ),
  };

  static Map<String, Garment> _catalog(Gender g) =>
      g == Gender.male ? _male : _female;

  static const _wardrobeOrder = [
    'blazer',
    'dress',
    'trousers',
    'shirt',
    'skirt',
    'bag',
    'shoe',
    'tee',
  ];

  static List<Garment> wardrobe(Gender g) =>
      [for (final id in _wardrobeOrder) _catalog(g)[id]!];

  static List<String> categories(Gender g) => [
        'Hepsi',
        'Üst',
        'Alt',
        if (g == Gender.female) 'Elbise',
        'Dış giyim',
        'Ayakkabı',
        'Çanta',
      ];

  // Etkinlik başına iki kombin: kimlikler ve başlık her iki cinsiyette ortak,
  // açıklama notları cinsiyete göre yazıldı.
  static const _outfitIds = <EventType, List<List<String>>>{
    EventType.work: [
      ['blazer', 'shirt', 'trousers', 'shoe'],
      ['blazer', 'tee', 'skirt', 'bag'],
    ],
    EventType.date: [
      ['shirt', 'skirt', 'bag', 'shoe'],
      ['dress', 'blazer', 'bag', 'shoe'],
    ],
    EventType.party: [
      ['dress', 'blazer', 'bag', 'shoe'],
      ['shirt', 'trousers', 'blazer', 'shoe'],
    ],
    EventType.sport: [
      ['tee', 'trousers', 'shoe', 'bag'],
      ['tee', 'skirt', 'shoe', 'bag'],
    ],
  };

  static const _titles = <EventType, List<String>>{
    EventType.work: ['Ofis şıklığı', 'Toplantı günü'],
    EventType.date: ['Rahat buluşma', 'Akşam yemeği'],
    EventType.party: ['Davet gecesi', 'Kokteyl'],
    EventType.sport: ['Hareketli gün', 'Hafif yürüyüş'],
  };

  static const _notesFemale = <EventType, List<String>>{
    EventType.work: [
      'Gün boyu 18° ve akşam serinliyor. Krem blazer akşam için katman olur, mor pantolonla sakin ama kendinden emin bir görünüm verir.',
      'Blazer ve etek toplantılar için net bir silüet çiziyor. Deri çanta kombini tamamlıyor.',
    ],
    EventType.date: [
      'Parçalı bulutlu ve ılık bir gün. Midi etek ve bluz hem rahat hem zarif, deri çanta kombine bir dokunuş katıyor.',
      'Gül kurusu elbise akşam yemeği için yeterince özel. Blazer serinliğe karşı iyi bir katman.',
    ],
    EventType.party: [
      'Akşam 13°’ye düşecek. Gül kurusu elbisenin üstüne krem blazer hem şık durur hem seni üşütmez.',
      'Bluz ve pantolonun üstüne blazer: davette sade ama bakımlı bir görünüm.',
    ],
    EventType.sport: [
      'Rüzgârlı bir gün. Tişört ve pantolon rahat, çanta ve ayakkabı gün boyu yanında.',
      'Hafif bir yürüyüş için etek bile rahat, ayakkabı konforu belirliyor.',
    ],
  };

  static const _notesMale = <EventType, List<String>>{
    EventType.work: [
      'Gün boyu 18° ve akşam serinliyor. Lacivert blazer akşam için katman olur, bej chino ile derli toplu bir görünüm verir.',
      'Blazer ve koyu kot, ofiste rahat ama özenli bir denge kurar.',
    ],
    EventType.date: [
      'Parçalı bulutlu ve ılık bir gün. Gömlek ve koyu kot hem rahat hem şık, deri çanta kombine bir dokunuş katıyor.',
      'Gri triko ve blazer, akşam yemeği için sıcak ve bakımlı duruyor.',
    ],
    EventType.party: [
      'Akşam 13°’ye düşecek. Gri triko üstüne lacivert blazer hem şık durur hem seni üşütmez.',
      'Gömlek, chino ve blazer: davette klasik ve güvenli bir seçim.',
    ],
    EventType.sport: [
      'Rüzgârlı bir gün. Tişört ve chino rahat, çanta ve ayakkabı gün boyu yanında.',
      'Hafif bir yürüyüş için tişört ve koyu kot yeterli, ayakkabı konforu belirliyor.',
    ],
  };

  static List<Outfit> outfits(Gender g, EventType e) {
    final catalog = _catalog(g);
    final notes = g == Gender.male ? _notesMale : _notesFemale;
    final ids = _outfitIds[e]!;
    return [
      for (var i = 0; i < ids.length; i++)
        Outfit(
          title: _titles[e]![i],
          note: notes[e]![i],
          items: [for (final id in ids[i]) catalog[id]!],
        ),
    ];
  }

  static ShopScan shopScan(Gender g) {
    final catalog = _catalog(g);
    final scanned = g == Gender.male
        ? const Garment(
            id: 'scan',
            name: 'Zeytin yeşili ceket',
            category: 'Dış giyim',
            shape: GarmentShape.blazer,
            bg1: Color(0xFFD9E1D3),
            bg2: Color(0xFFB7C6AD),
            fill: Color(0xFF4E6340),
          )
        : const Garment(
            id: 'scan',
            name: 'Bordo kadife ceket',
            category: 'Dış giyim',
            shape: GarmentShape.blazer,
            bg1: Color(0xFFE9C3CA),
            bg2: Color(0xFFC98C9B),
            fill: Color(0xFF7A2E48),
          );
    return ShopScan(
      garment: scanned,
      detail: g == Gender.male ? 'Zeytin · Sonbahar, kış' : 'Bordo · Sonbahar, kış',
      outfitCount: 6,
      matches: [
        ShopMatch(garment: catalog['shirt']!, why: 'Işıltılı bir kontrast'),
        ShopMatch(garment: catalog['skirt']!, why: 'Tonlu, zarif bir bütün'),
        ShopMatch(garment: catalog['trousers']!, why: 'Zengin renk uyumu'),
        ShopMatch(garment: catalog['tee']!, why: 'Gündelik ve temiz'),
      ],
    );
  }
}
