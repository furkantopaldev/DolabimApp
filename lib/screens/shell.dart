import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../widgets/common.dart';
import 'add_screen.dart';
import 'home_screen.dart';
import 'outfit_screen.dart';
import 'shop_screen.dart';
import 'wardrobe_screen.dart';

/// Alt menü ve sekmeler. Sekmeler: 0 ana sayfa, 1 dolap, 2 kombin, 3 mağaza.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  void _go(int i) => setState(() => _tab = i);

  Widget _page() => switch (_tab) {
        0 => HomeScreen(onNavigate: _go),
        1 => const WardrobeScreen(),
        2 => const OutfitScreen(),
        _ => const ShopScreen(),
      };

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.02),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: KeyedSubtree(key: ValueKey(_tab), child: _page()),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16 + bottom,
            child: _BottomNav(current: _tab, onSelect: _go),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.current, required this.onSelect});

  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(30),
        boxShadow: softShadow(p, blur: 30, dy: 12, alpha: 0.16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.home_rounded,
            label: 'Ana',
            selected: current == 0,
            onTap: () => onSelect(0),
          ),
          _NavItem(
            icon: Icons.checkroom_rounded,
            label: 'Dolap',
            selected: current == 1,
            onTap: () => onSelect(1),
          ),
          PressScale(
            semanticLabel: 'Kıyafet ekle',
            onTap: () => openAdd(context),
            child: Transform.translate(
              offset: const Offset(0, -26),
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: p.accent,
                  border: Border.all(color: p.bg, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: p.rose2.withValues(alpha: 0.45),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
              ),
            ),
          ),
          _NavItem(
            icon: Icons.auto_awesome_rounded,
            label: 'Kombin',
            selected: current == 2,
            onTap: () => onSelect(2),
          ),
          _NavItem(
            icon: Icons.shopping_bag_outlined,
            label: 'Mağaza',
            selected: current == 3,
            onTap: () => onSelect(3),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final color = selected ? p.act : p.muted;
    return PressScale(
      onTap: onTap,
      semanticLabel: label,
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: selected ? 1.12 : 1,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: color),
                duration: const Duration(milliseconds: 300),
                builder: (context, c, _) => Icon(icon, size: 24, color: c),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: color,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
