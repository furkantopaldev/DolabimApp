import 'package:flutter/material.dart';

import '../data/models.dart';
import 'common.dart';
import 'garment_tile.dart';

/// Bir kombinin parçalarını (2 ile 5 arası) düzenli bir kolaj olarak gösterir.
/// Bulunduğu alanı doldurur, yüksekliği çağıran taraf verir.
class OutfitCollage extends StatelessWidget {
  const OutfitCollage({super.key, required this.items, this.labels = false});

  final List<Garment> items;
  final bool labels;

  @override
  Widget build(BuildContext context) {
    final n = items.length;
    const gap = SizedBox(width: 10, height: 10);

    Widget tile(int i, {double icon = 52, double radius = 20}) => Rise(
          delay: Duration(milliseconds: 70 * i),
          child: GarmentTile(
            garment: items[i],
            iconSize: icon,
            radius: radius,
            label: labels ? items[i].name : null,
          ),
        );

    if (n <= 2) {
      return Row(
        children: [
          for (var i = 0; i < n; i++) ...[
            if (i > 0) gap,
            Expanded(child: tile(i, icon: 72, radius: 22)),
          ],
        ],
      );
    }
    if (n == 3) {
      return Row(
        children: [
          Expanded(flex: 115, child: tile(0, icon: 92, radius: 22)),
          gap,
          Expanded(
            flex: 100,
            child: Column(
              children: [
                Expanded(child: tile(1)),
                gap,
                Expanded(child: tile(2)),
              ],
            ),
          ),
        ],
      );
    }
    if (n == 4) {
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: tile(0, icon: 58)),
                gap,
                Expanded(child: tile(1, icon: 58)),
              ],
            ),
          ),
          gap,
          Expanded(
            child: Row(
              children: [
                Expanded(child: tile(2, icon: 58)),
                gap,
                Expanded(child: tile(3, icon: 58)),
              ],
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(flex: 100, child: tile(0, icon: 80, radius: 22)),
        gap,
        Expanded(
          flex: 130,
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: tile(1, icon: 40, radius: 18)),
                    gap,
                    Expanded(child: tile(2, icon: 40, radius: 18)),
                  ],
                ),
              ),
              gap,
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: tile(3, icon: 40, radius: 18)),
                    gap,
                    Expanded(child: tile(4, icon: 40, radius: 18)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Kombinler örnek parçalarla hazırlandığında gösterilen küçük bilgi notu.
class SampleNotice extends StatelessWidget {
  const SampleNotice({super.key, required this.color, required this.textColor});

  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'Örnek parçalarla gösteriliyor. En az bir üst ile bir alt (ya da bir elbise) ekleyince kombinler sana özel olur.',
        style: TextStyle(fontSize: 12, height: 1.45, color: textColor),
      ),
    );
  }
}
