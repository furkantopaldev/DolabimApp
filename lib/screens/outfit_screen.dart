import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../stylist/stylist.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import '../widgets/outfit_collage.dart';
import '../widgets/weather_widgets.dart';

class OutfitScreen extends StatefulWidget {
  const OutfitScreen({super.key});

  @override
  State<OutfitScreen> createState() => _OutfitScreenState();
}

class _OutfitScreenState extends State<OutfitScreen> {
  EventType _event = EventType.work;
  int _variant = 0;
  bool _saved = false;

  void _pick(EventType e) => setState(() {
        _event = e;
        _variant = 0;
        _saved = false;
      });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final app = AppScope.of(context);
    final options = Stylist.suggest(
      wardrobe: app.stylistWardrobe,
      event: _event,
      weather: app.weather,
      limit: 5,
    );
    final outfit = options.isEmpty ? null : options[_variant % options.length];
    final bottom = MediaQuery.of(context).padding.bottom;
    final key = ValueKey('${_event.name}_${_variant}_${outfit?.items.map((g) => g.id).join()}');
    final n = outfit?.items.length ?? 0;
    final collageHeight = n <= 2 ? 130.0 : (n == 3 ? 200.0 : 226.0);

    return Stack(
      children: [
        const SoftBlob(top: -90, left: -80),
        SafeArea(
          bottom: false,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(22, 18, 22, 130 + bottom),
            children: [
              const Rise(
                child: ScreenHeader(
                  eyebrow: 'Hava ve etkinliğe göre',
                  title: 'Kombin öner',
                ),
              ),
              const SizedBox(height: 14),
              Rise(
                delay: const Duration(milliseconds: 80),
                child: Column(
                  children: [
                    const WeatherPill(),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (var i = 0; i < EventType.values.length; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          Expanded(
                            child: PillChip(
                              label: EventType.values[i].label,
                              horizontal: 4,
                              selected: EventType.values[i] == _event,
                              onTap: () => _pick(EventType.values[i]),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Rise(
                delay: const Duration(milliseconds: 160),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: softShadow(p),
                  ),
                  child: outfit == null
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Kombin için dolabına en az bir üst ile bir alt ya da bir elbise ekle.',
                            style: TextStyle(fontSize: 13.5, height: 1.5, color: p.body),
                          ),
                        )
                      : _OutfitBody(
                          outfit: outfit,
                          itemKey: key,
                          collageHeight: collageHeight,
                          saved: _saved,
                          usingSamples: app.usingSamples,
                          count: options.length,
                          index: _variant % options.length,
                          onSave: () => setState(() => _saved = !_saved),
                          onAnother: () {
                            if (options.length < 2) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Başka kombin yok, dolabına yeni parça ekleyebilirsin.'),
                                ),
                              );
                              return;
                            }
                            setState(() {
                              _variant = (_variant + 1) % options.length;
                              _saved = false;
                            });
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OutfitBody extends StatelessWidget {
  const _OutfitBody({
    required this.outfit,
    required this.itemKey,
    required this.collageHeight,
    required this.saved,
    required this.usingSamples,
    required this.count,
    required this.index,
    required this.onSave,
    required this.onAnother,
  });

  final Outfit outfit;
  final Key itemKey;
  final double collageHeight;
  final bool saved;
  final bool usingSamples;
  final int count;
  final int index;
  final VoidCallback onSave;
  final VoidCallback onAnother;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Align(
                  key: itemKey,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    outfit.title,
                    style: serif(24, weight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            if (count > 1)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  '${index + 1}/$count',
                  style: TextStyle(fontSize: 12.5, color: p.muted, fontWeight: FontWeight.w600),
                ),
              ),
            PressScale(
              semanticLabel: 'Kombini kaydet',
              onTap: onSave,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: p.border),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: Icon(
                    saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    key: ValueKey(saved),
                    size: 18,
                    color: p.act,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: collageHeight,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: KeyedSubtree(
              key: itemKey,
              child: OutfitCollage(items: outfit.items, labels: true),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: p.bg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(Icons.auto_awesome_rounded, size: 16, color: p.goldText),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    outfit.note,
                    key: itemKey,
                    style: TextStyle(fontSize: 12.5, height: 1.5, color: p.body),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (usingSamples) ...[
          const SizedBox(height: 10),
          SampleNotice(color: p.gold, textColor: p.goldText),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GradientButton(
                label: 'Bunu seç',
                height: 48,
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kombin bugüne eklendi.')),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GhostButton(label: 'Başka öner', height: 48, onTap: onAnother),
          ],
        ),
      ],
    );
  }
}
