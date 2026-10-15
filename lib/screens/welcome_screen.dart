import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import 'shell.dart';

/// İlk açılışta cinsiyet seçimi. Seçim anında tüm uygulamanın paleti
/// yumuşakça değişir.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _continue(BuildContext context) async {
    final state = AppScope.of(context);
    await state.finishOnboarding();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(fadeRoute(const AppShell()));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final state = AppScope.of(context);
    return Scaffold(
      body: Stack(
        children: [
          const SoftBlob(top: -110, right: -90, size: 320),
          const SoftBlob(bottom: -120, left: -100, size: 300),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(26, 40, 26, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Rise(
                    child: Row(
                      children: [
                        Icon(Icons.checkroom_rounded, color: p.act, size: 30),
                        const SizedBox(width: 10),
                        Text('Dolabım', style: serif(26, weight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Rise(
                    delay: const Duration(milliseconds: 80),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Seni\ntanıyalım', style: serif(46, height: 1.02)),
                        const SizedBox(height: 14),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 300),
                          child: Text(
                            'Stilistin sana uygun kombinleri ve renkleri önerebilsin diye başlayalım. Uygulamanın görünümü de buna göre şekillenir.',
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.55,
                              color: p.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Rise(
                    delay: const Duration(milliseconds: 160),
                    child: Row(
                      children: [
                        Expanded(
                          child: _GenderCard(
                            label: 'Kadın',
                            icon: Icons.female_rounded,
                            palette: AppPalette.female,
                            selected: state.gender == Gender.female,
                            onTap: () => state.setGender(Gender.female),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _GenderCard(
                            label: 'Erkek',
                            icon: Icons.male_rounded,
                            palette: AppPalette.male,
                            selected: state.gender == Gender.male,
                            onTap: () => state.setGender(Gender.male),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Rise(
                    delay: const Duration(milliseconds: 240),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: softShadow(p, blur: 22, dy: 8, alpha: 0.08),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Senin paletin',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: p.muted,
                            ),
                          ),
                          const Spacer(),
                          for (final c in [p.rose1, p.rose2, p.deep2, p.ink])
                            Container(
                              width: 26,
                              height: 26,
                              margin: const EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: c,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  GradientButton(
                    label: 'Devam et',
                    height: 56,
                    onTap: () => _continue(context),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: TextButton(
                      onPressed: () => _continue(context),
                      child: Text(
                        'Daha sonra seçerim',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: p.muted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GenderCard extends StatelessWidget {
  const _GenderCard({
    required this.label,
    required this.icon,
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return PressScale(
      onTap: onTap,
      semanticLabel: label,
      scale: 0.97,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        height: 168,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? palette.rose2 : p.border,
            width: 2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: palette.rose2.withValues(alpha: 0.28),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? palette.w2 : palette.w1,
              ),
              child: Icon(icon, size: 34, color: palette.deep2),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: p.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
