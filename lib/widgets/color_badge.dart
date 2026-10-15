import 'package:flutter/material.dart';

import '../services/color_analysis.dart';
import '../theme/palette.dart';

/// Fotoğraftan algılanan rengi gösterir. Renk yoksa (henüz hesaplanıyor ya da
/// okunamadı) buna uygun bir metin gösterir.
class ColorBadge extends StatelessWidget {
  const ColorBadge({super.key, required this.color, this.pending = false});

  final Color? color;

  /// Renk hâlâ hesaplanıyorsa true.
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final c = color;
    return Row(
      children: [
        Text(
          'Algılanan renk',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: p.muted,
          ),
        ),
        const SizedBox(width: 12),
        if (c != null) ...[
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c,
              border: Border.all(color: p.border, width: 1.5),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            ColorAnalysis.nameOf(c),
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
        ] else
          Text(
            pending ? 'Hesaplanıyor' : 'Algılanamadı',
            style: TextStyle(fontSize: 13, color: p.muted),
          ),
      ],
    );
  }
}
