import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../stylist/stylist.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import '../widgets/outfit_collage.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/weather_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onNavigate});

  /// Sekme değiştirmek için (2: kombin).
  final ValueChanged<int> onNavigate;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  EventType _event = EventType.work;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final app = AppScope.of(context);
    final suggestions = Stylist.suggest(
      wardrobe: app.stylistWardrobe,
      event: _event,
      weather: app.weather,
      limit: 1,
    );
    final outfit = suggestions.isEmpty ? null : suggestions.first;
    final now = DateTime.now();
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
                  eyebrow: trDate(now),
                  title: greeting(now),
                  trailing: CircleIconButton(
                    icon: Icons.settings_outlined,
                    semanticLabel: 'Ayarlar',
                    onTap: () => showSettingsSheet(context),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Rise(
                delay: Duration(milliseconds: 80),
                child: WeatherCard(),
              ),
              const SizedBox(height: 16),
              Rise(
                delay: const Duration(milliseconds: 160),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bugün ne var?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: p.muted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final e in EventType.values) ...[
                            PillChip(
                              label: e.label,
                              selected: e == _event,
                              onTap: () => setState(() => _event = e),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Rise(
                delay: const Duration(milliseconds: 240),
                child: _OutfitCard(
                  outfit: outfit,
                  eventKey: _event,
                  usingSamples: app.usingSamples,
                  onAnother: () => widget.onNavigate(2),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OutfitCard extends StatelessWidget {
  const _OutfitCard({
    required this.outfit,
    required this.eventKey,
    required this.usingSamples,
    required this.onAnother,
  });

  final Outfit? outfit;
  final EventType eventKey;
  final bool usingSamples;
  final VoidCallback onAnother;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final o = outfit;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: softShadow(p),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Bugünün kombini',
                  style: serif(24, weight: FontWeight.w700),
                ),
              ),
              const AiBadge(label: 'Stilist önerisi'),
            ],
          ),
          const SizedBox(height: 14),
          if (o == null)
            Text(
              'Kombin için dolabına en az bir üst ile bir alt ya da bir elbise ekle.',
              style: TextStyle(fontSize: 13.5, height: 1.5, color: p.body),
            )
          else ...[
            SizedBox(
              height: 176,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                switchInCurve: Curves.easeOutCubic,
                child: KeyedSubtree(
                  key: ValueKey('${eventKey.name}_${o.items.map((g) => g.id).join()}'),
                  child: OutfitCollage(items: o.items),
                ),
              ),
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: Text(
                o.note,
                key: ValueKey('${eventKey.name}_${o.note}'),
                style: TextStyle(fontSize: 13.5, height: 1.5, color: p.body),
              ),
            ),
            if (usingSamples) ...[
              const SizedBox(height: 12),
              SampleNotice(color: p.gold, textColor: p.goldText),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GradientButton(
                    label: 'Bunu giyiyorum',
                    height: 48,
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Güzel seçim, bugünün kombini kaydedildi.')),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                CircleIconButton(
                  icon: Icons.refresh_rounded,
                  semanticLabel: 'Başka kombin öner',
                  outlined: true,
                  onTap: onAnother,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
