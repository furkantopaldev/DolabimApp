import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../data/models.dart';
import '../theme/palette.dart';

// Tasarımdaki silüetlerle aynı 64x64'lük SVG yolları.
const _paths = <GarmentShape, String>{
  GarmentShape.top:
      'M20 10 L28 14 Q32 18 36 14 L44 10 L56 20 L48 28 L44 25 V54 H20 V25 L16 28 L8 20 Z',
  GarmentShape.skirt: 'M22 12 H42 L54 54 H10 Z',
  GarmentShape.trousers: 'M18 8 H46 L48 56 H36 L32 28 L28 56 H16 Z',
  GarmentShape.dress: 'M24 6 H28 Q32 12 36 6 H40 L42 24 L50 56 H14 L22 24 Z',
  GarmentShape.bag: 'M12 24 H52 L55 54 H9 Z',
  GarmentShape.shoe: 'M6 24 H20 L28 38 H54 Q58 38 58 44 V50 H6 Z',
  GarmentShape.blazer:
      'M20 8 L28 12 L32 20 L36 12 L44 8 L56 18 L50 30 L45 27 V56 H19 V27 L14 30 L8 18 Z',
};

class GarmentIcon extends StatelessWidget {
  const GarmentIcon({
    super.key,
    required this.shape,
    required this.color,
    this.size = 64,
  });

  final GarmentShape shape;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ShapePainter(shape, color)),
    );
  }
}

/// Kullanıcının fotoğrafı. Web'de geçici adresten, mobilde dosyadan okunur.
/// Dosya açılamazsa boş kalır, altındaki silüet görünür.
class PhotoImage extends StatelessWidget {
  const PhotoImage({super.key, required this.path, this.fit = BoxFit.cover});

  final String path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    const empty = SizedBox.expand();
    if (kIsWeb) {
      return Image.network(
        path,
        fit: fit,
        errorBuilder: (_, __, ___) => empty,
      );
    }
    return Image.file(
      File(path),
      fit: fit,
      cacheWidth: 600,
      errorBuilder: (_, __, ___) => empty,
    );
  }
}

class _ShapePainter extends CustomPainter {
  _ShapePainter(this.shape, this.color);

  final GarmentShape shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = parseSvgPathData(_paths[shape]!);
    canvas.save();
    canvas.scale(size.width / 64, size.height / 64);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShapePainter old) =>
      old.shape != shape || old.color != color;
}

/// Degrade zeminli kıyafet kartı. Genişlik ve yükseklik verilmezse bulunduğu
/// alanı doldurur.
class GarmentTile extends StatelessWidget {
  const GarmentTile({
    super.key,
    required this.garment,
    this.iconSize = 64,
    this.radius = 22,
    this.width,
    this.height,
    this.label,
    this.badge,
  });

  final Garment garment;
  final double iconSize;
  final double radius;
  final double? width;
  final double? height;
  final String? label;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [garment.bg1, garment.bg2],
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: GarmentIcon(
              shape: garment.shape,
              color: garment.fill,
              size: iconSize,
            ),
          ),
          if (garment.photoPath != null)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: PhotoImage(path: garment.photoPath!),
              ),
            ),
          if (label != null)
            Positioned(
              left: 10,
              bottom: 8,
              right: 10,
              child: Text(
                label!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                ),
              ),
            ),
          if (badge != null) Positioned(top: 10, right: 10, child: badge!),
        ],
      ),
    );
  }
}
