import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models.dart';
import '../data/sample_data.dart';
import '../services/color_analysis.dart';
import '../state/app_state.dart';
import '../stylist/stylist.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import '../widgets/garment_tile.dart';

/// Alışverişte taranan ürünün dolapla uyumu. Mağazada ürünün fotoğrafını çek,
/// türünü seç; renk uyumuna göre dolabındaki parçalarla eşleşir.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  bool _wish = false;
  Garment? _scanned;
  bool _busy = false;

  Future<void> _scan() async {
    if (_busy) return;
    final app = AppScope.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => const _SourceSheet(),
    );
    if (source == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1400,
        imageQuality: 85,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      final color = await ColorAnalysis.dominantColor(bytes);
      if (!mounted) return;
      final categories = SampleData.categories(app.gender).skip(1).toList();
      // Yapay zekâ açıksa tür ve ad ondan gelir, hata olursa
      // tür kullanıcıya sorulur.
      String? category;
      String? aiName;
      if (app.aiReady) {
        try {
          final a = await app.analyzeGarment(bytes, categories);
          category = a.category;
          aiName = a.name;
        } catch (_) {
          // Tür aşağıda elle sorulacak.
        }
      }
      if (!mounted) return;
      category ??= await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.35),
        builder: (_) => _CategorySheet(categories: categories),
      );
      if (category == null || !mounted) return;
      final colorName = color == null ? '' : '${ColorAnalysis.nameOf(color)} ';
      final chosen = category;
      setState(() {
        _scanned = Garment.user(
          id: 'scan',
          name: aiName ?? '$colorName${chosen.toLowerCase()}',
          category: chosen,
          photoPath: file.path,
          color: color,
        );
        _wish = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fotoğrafa erişilemedi. Kamera ve galeri iznini kontrol et.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  ShopScan _result(AppState app) {
    final scanned = _scanned;
    if (scanned == null) return SampleData.shopScan(app.gender);
    // Kullanıcı dolabı boşsa örnek dolapla karşılaştırılır.
    final wardrobe = app.wardrobe.isNotEmpty
        ? app.wardrobe
        : SampleData.wardrobe(app.gender);
    final color = scanned.color;
    return ShopScan(
      garment: scanned,
      detail: color == null
          ? scanned.category
          : '${ColorAnalysis.nameOf(color)} · ${scanned.category}',
      matches: Stylist.matches(scanned, wardrobe),
      outfitCount: Stylist.outfitCountWith(scanned, wardrobe),
    );
  }

  static String _verdict(ShopScan s) {
    if (s.matches.isEmpty) {
      return 'Dolabında bununla eşleşecek parça yok. Önce dolabına parça ekle.';
    }
    final n = s.matches.length;
    if (s.outfitCount >= 5) return 'Dolabındaki $n parçayla çok iyi gider. Alınabilir.';
    if (s.outfitCount >= 2) return 'Dolabındaki $n parçayla iyi gider.';
    if (s.outfitCount == 1) return 'Tek bir uyumlu kombin çıkıyor, bir daha düşün.';
    return 'Dolabındaki parçalarla renk uyumu yakalayamadım.';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final app = AppScope.of(context);
    final scan = _result(app);
    final isSample = _scanned == null;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Stack(
      children: [
        const SoftBlob(top: -90, right: -70),
        SafeArea(
          bottom: false,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(22, 18, 22, 130 + bottom),
            children: [
              Rise(
                child: ScreenHeader(
                  eyebrow: 'Alışverişte yanında',
                  title: 'Neyle gider?',
                  trailing: CircleIconButton(
                    icon: Icons.center_focus_strong_outlined,
                    semanticLabel: 'Yeni ürün tara',
                    onTap: _scan,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Rise(
                delay: const Duration(milliseconds: 80),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: softShadow(p),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 104,
                        height: 120,
                        child: GarmentTile(garment: scan.garment, iconSize: 72),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 26,
                              padding: const EdgeInsets.symmetric(horizontal: 11),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: p.gold,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Text(
                                isSample ? 'Örnek ürün' : 'Mağazada tarandı',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: p.goldText,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isSample
                                  ? scan.garment.name
                                  : _capitalize(scan.garment.name),
                              style: serif(25, weight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              scan.detail,
                              style: TextStyle(fontSize: 12.5, color: p.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isSample) ...[
                const SizedBox(height: 10),
                Rise(
                  delay: const Duration(milliseconds: 120),
                  child: Text(
                    'Henüz ürün taramadın, örnek bir sonuç gösteriliyor. Sağ üstteki düğmeyle mağazadaki bir ürünü tara.',
                    style: TextStyle(fontSize: 12.5, height: 1.45, color: p.muted),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Rise(
                delay: const Duration(milliseconds: 160),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [p.deep3, p.deep2],
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${scan.outfitCount}',
                        style: serif(
                          56,
                          weight: FontWeight.w700,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              scan.outfitCount == 0 ? 'kombin çıkmıyor' : 'kombin çıkıyor',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _verdict(scan),
                              style: TextStyle(fontSize: 12.5, height: 1.45, color: p.w1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (scan.matches.isNotEmpty) ...[
                const SizedBox(height: 14),
                Rise(
                  delay: const Duration(milliseconds: 240),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dolabından eşleşenler',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: p.muted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final m in scan.matches)
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: SizedBox(
                                  width: 148,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      GarmentTile(
                                        garment: m.garment,
                                        height: 128,
                                        iconSize: 68,
                                      ),
                                      const SizedBox(height: 8),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              m.garment.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              m.why,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontSize: 12, color: p.muted),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Rise(
                delay: const Duration(milliseconds: 320),
                child: Row(
                  children: [
                    Expanded(
                      child: PressScale(
                        onTap: () => setState(() => _wish = !_wish),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _wish ? p.ink : null,
                            gradient: _wish ? null : p.accent,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: p.rose2.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Text(
                            _wish ? 'İstek listesinde' : 'İstek listesine ekle',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GhostButton(
                      label: isSample ? 'Ürünü tara' : 'Tekrar tara',
                      height: 50,
                      onTap: _scan,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
      ),
      padding: EdgeInsets.fromLTRB(24, 14, 24, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: p.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(title, style: serif(26, weight: FontWeight.w700)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SourceSheet extends StatelessWidget {
  const _SourceSheet();

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    Widget option(IconData icon, String label, ImageSource source) => Expanded(
          child: PressScale(
            onTap: () => Navigator.of(context).pop(source),
            semanticLabel: label,
            child: Container(
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: p.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 30, color: p.act),
                  const SizedBox(height: 10),
                  Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        );

    return _SheetFrame(
      title: 'Ürünü nasıl ekleyelim?',
      child: Row(
        children: [
          option(Icons.photo_camera_outlined, 'Kamerayla çek', ImageSource.camera),
          const SizedBox(width: 12),
          option(Icons.photo_library_outlined, 'Galeriden seç', ImageSource.gallery),
        ],
      ),
    );
  }
}

class _CategorySheet extends StatelessWidget {
  const _CategorySheet({required this.categories});

  final List<String> categories;

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Bu ne tür bir parça?',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in categories)
            PillChip(
              label: c,
              height: 42,
              selected: false,
              onTap: () => Navigator.of(context).pop(c),
            ),
        ],
      ),
    );
  }
}
