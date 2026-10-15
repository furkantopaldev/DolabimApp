import 'package:flutter/material.dart';

import '../theme/palette.dart';
import 'common.dart';

/// Yapay zekâ ile tanımanın durumu.
/// off: anahtar yok, loading: tanıyor, done: doldurdu, error: hata aldı.
enum AiStatus { off, loading, done, error }

/// Parça ekleme panelindeki tek satırlık yapay zekâ durumu.
class AiStatusLine extends StatelessWidget {
  const AiStatusLine({
    super.key,
    required this.status,
    required this.message,
    required this.onRetry,
  });

  final AiStatus status;
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    switch (status) {
      case AiStatus.off:
        // Yapay zekâ kapalıyken kullanıcıya bir şey gösterilmez.
        return const SizedBox.shrink();
      case AiStatus.loading:
        return Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: p.act),
            ),
            const SizedBox(width: 10),
            Text('Yapay zekâ parçayı tanıyor…', style: TextStyle(fontSize: 12.5, color: p.muted)),
          ],
        );
      case AiStatus.done:
        return Text(
          'Bilgileri kontrol et, istersen değiştirebilirsin.',
          style: TextStyle(fontSize: 12.5, color: p.muted),
        );
      case AiStatus.error:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFB3261E)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message ?? 'Yapay zekâ ile tanıma başarısız oldu.',
                style: const TextStyle(fontSize: 12.5, height: 1.4, color: Color(0xFFB3261E)),
              ),
            ),
            const SizedBox(width: 8),
            PressScale(
              onTap: onRetry,
              semanticLabel: 'Tekrar dene',
              child: Text(
                'Tekrar dene',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: p.act),
              ),
            ),
          ],
        );
    }
  }
}
