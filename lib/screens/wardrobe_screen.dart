import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/sample_data.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import '../widgets/edit_garment_sheet.dart';
import '../widgets/garment_tile.dart';

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key});

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  String _cat = 'Hepsi';
  String _query = '';
  final Set<String> _favorites = {};

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final app = AppScope.of(context);
    final gender = app.gender;
    // Kullanıcının kendi parçaları başta, altında örnek parçalar.
    final all = [...app.wardrobe, ...SampleData.wardrobe(gender)];
    final q = _query.trim().toLowerCase();
    final items = all
        .where((g) =>
            (_cat == 'Hepsi' || g.category == _cat) &&
            (q.isEmpty || g.name.toLowerCase().contains(q)))
        .toList();
    final bottom = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Rise(
                  child: ScreenHeader(
                    eyebrow: '${all.length} parça',
                    title: 'Dolabım',
                    trailing: CircleIconButton(
                      icon: Icons.tune_rounded,
                      semanticLabel: 'Filtrele',
                      onTap: () {},
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Rise(
                  delay: const Duration(milliseconds: 60),
                  child: _SearchField(
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(height: 16),
                Rise(
                  delay: const Duration(milliseconds: 120),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final c in SampleData.categories(gender)) ...[
                          PillChip(
                            label: c,
                            height: 38,
                            selected: c == _cat,
                            onTap: () => setState(() => _cat = c),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ]),
            ),
          ),
          if (items.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    'Bu aramaya uygun parça yok.',
                    style: TextStyle(color: p.muted, fontSize: 14),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(22, 0, 22, 130 + bottom),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.8,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final g = items[i];
                    return Rise(
                      key: ValueKey('${_cat}_${g.id}'),
                      delay: Duration(milliseconds: 60 * i),
                      child: _GarmentCard(
                        garment: g,
                        // Sadece kullanıcının kendi parçaları düzenlenebilir.
                        onTap: g.photoPath == null
                            ? null
                            : () => showEditGarmentSheet(context, g),
                        favorite: _favorites.contains(g.id),
                        onFavorite: () => setState(() {
                          if (!_favorites.add(g.id)) _favorites.remove(g.id);
                        }),
                      ),
                    );
                  },
                  childCount: items.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: softShadow(p, blur: 18, dy: 6, alpha: 0.06),
      ),
      child: TextField(
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: p.ink),
        cursorColor: p.act,
        decoration: InputDecoration(
          hintText: 'Kıyafet, renk veya etiket ara',
          hintStyle: TextStyle(fontSize: 14, color: p.muted),
          prefixIcon: Icon(Icons.search_rounded, color: p.muted, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}

class _GarmentCard extends StatelessWidget {
  const _GarmentCard({
    required this.garment,
    required this.onTap,
    required this.favorite,
    required this.onFavorite,
  });

  final Garment garment;
  final VoidCallback? onTap;
  final bool favorite;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return PressScale(
      scale: 0.97,
      semanticLabel: onTap == null ? null : '${garment.name}, düzenle',
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GarmentTile(
              garment: garment,
              iconSize: 80,
              radius: 24,
              badge: PressScale(
                onTap: onFavorite,
                semanticLabel: 'Favorilere ekle',
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                    child: Icon(
                      favorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      key: ValueKey(favorite),
                      size: 16,
                      color: p.heart,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  garment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                Text(
                  garment.category,
                  style: TextStyle(fontSize: 12, color: p.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
