import 'package:flutter/material.dart';

enum GarmentShape { top, skirt, trousers, dress, bag, shoe, blazer }

enum EventType {
  work('İş'),
  date('Buluşma'),
  party('Davet'),
  sport('Spor');

  const EventType(this.label);
  final String label;
}

class Garment {
  const Garment({
    required this.id,
    required this.name,
    required this.category,
    required this.shape,
    required this.bg1,
    required this.bg2,
    required this.fill,
    this.photoPath,
    this.color,
    this.events = const {},
  });

  /// Kullanıcının çektiği ya da galeriden seçtiği fotoğrafla oluşturulan parça.
  /// Fotoğraf yüklenemezse nötr renkli silüet gösterilir.
  factory Garment.user({
    required String id,
    required String name,
    required String category,
    required String photoPath,
    Color? color,
    Set<EventType> events = const {},
  }) =>
      Garment(
        id: id,
        name: name,
        category: category,
        shape: shapeForCategory(category),
        bg1: const Color(0xFFF1E9EA),
        bg2: const Color(0xFFE2D6D8),
        fill: const Color(0xFF8E7F84),
        photoPath: photoPath,
        color: color,
        events: events,
      );

  factory Garment.fromJson(Map<String, dynamic> json) => Garment.user(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        photoPath: json['photoPath'] as String,
        color: json['color'] == null ? null : Color(json['color'] as int),
        events: {
          for (final e in (json['events'] as List<dynamic>? ?? const []))
            ...EventType.values.where((v) => v.name == e),
        },
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'photoPath': photoPath,
        'color': color?.toARGB32(),
        'events': [for (final e in events) e.name],
      };

  /// Adı, türü ve etkinlikleri değiştirilmiş kopya (kullanıcı parçaları için).
  Garment edited({
    required String name,
    required String category,
    required Set<EventType> events,
  }) =>
      Garment.user(
        id: id,
        name: name,
        category: category,
        photoPath: photoPath!,
        color: color,
        events: events,
      );

  static GarmentShape shapeForCategory(String category) => switch (category) {
        'Alt' => GarmentShape.trousers,
        'Elbise' => GarmentShape.dress,
        'Dış giyim' => GarmentShape.blazer,
        'Ayakkabı' => GarmentShape.shoe,
        'Çanta' => GarmentShape.bag,
        _ => GarmentShape.top,
      };

  final String id;
  final String name;
  final String category;
  final GarmentShape shape;
  final Color bg1;
  final Color bg2;
  final Color fill;
  final String? photoPath;

  /// Fotoğraftan çıkarılan baskın renk. Yoksa silüetin rengi kullanılır.
  final Color? color;

  /// Parçanın uygun olduğu etkinlikler. Boşsa her etkinliğe uygun sayılır.
  final Set<EventType> events;

  Color get tone => color ?? fill;
}

class Outfit {
  const Outfit({
    required this.title,
    required this.note,
    required this.items,
    this.score = 0,
  });

  final String title;
  final String note;
  final List<Garment> items;
  final double score;
}

class ShopScan {
  const ShopScan({
    required this.garment,
    required this.detail,
    required this.matches,
    required this.outfitCount,
  });

  final Garment garment;
  final String detail;
  final List<ShopMatch> matches;
  final int outfitCount;
}

class ShopMatch {
  const ShopMatch({required this.garment, required this.why});

  final Garment garment;
  final String why;
}
