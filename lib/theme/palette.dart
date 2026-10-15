import 'package:flutter/material.dart';

/// Uygulamanın tüm renkleri. Kadın (pudra pembe) ve erkek (mavi) olmak üzere
/// iki palet var. ThemeExtension olduğu için palet değişince renkler
/// MaterialApp tarafından yumuşakça geçiş yapar (lerp).
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.ink,
    required this.muted,
    required this.deep,
    required this.deep2,
    required this.deep3,
    required this.rose1,
    required this.rose2,
    required this.act,
    required this.blob,
    required this.w1,
    required this.w2,
    required this.border,
    required this.gold,
    required this.goldText,
    required this.heart,
    required this.body,
    required this.shadow,
  });

  final Color bg;
  final Color ink;
  final Color muted;
  final Color deep;
  final Color deep2;
  final Color deep3;
  final Color rose1;
  final Color rose2;
  final Color act;
  final Color blob;
  final Color w1;
  final Color w2;
  final Color border;
  final Color gold;
  final Color goldText;
  final Color heart;
  final Color body;
  final Color shadow;

  static const female = AppPalette(
    bg: Color(0xFFFBF3F1),
    ink: Color(0xFF3B1F2B),
    muted: Color(0xFF7A5C66),
    deep: Color(0xFF5C2D3E),
    deep2: Color(0xFF6E3347),
    deep3: Color(0xFF4A2537),
    rose1: Color(0xFFE8A9B6),
    rose2: Color(0xFFC97B91),
    act: Color(0xFFB5566F),
    blob: Color(0xFFF3CBD3),
    w1: Color(0xFFF7DCE2),
    w2: Color(0xFFEDC3CD),
    border: Color(0xFFE9D5DA),
    gold: Color(0xFFF5E7D8),
    goldText: Color(0xFF7B5530),
    heart: Color(0xFF8E4A60),
    body: Color(0xFF5C4650),
    shadow: Color(0xFF5B283C),
  );

  static const male = AppPalette(
    bg: Color(0xFFF0F5FA),
    ink: Color(0xFF12263A),
    muted: Color(0xFF5A6B7D),
    deep: Color(0xFF1F3E5C),
    deep2: Color(0xFF2A5278),
    deep3: Color(0xFF1B3550),
    rose1: Color(0xFF8DB9E3),
    rose2: Color(0xFF3F78B5),
    act: Color(0xFF2F6AA8),
    blob: Color(0xFFCFE2F4),
    w1: Color(0xFFDCEAF7),
    w2: Color(0xFFBFD7EE),
    border: Color(0xFFD3E0EC),
    gold: Color(0xFFE1EBF5),
    goldText: Color(0xFF34506B),
    heart: Color(0xFF3C6A99),
    body: Color(0xFF3F5163),
    shadow: Color(0xFF12263A),
  );

  /// Ana butonlarda ve vurgu alanlarında kullanılan degrade.
  LinearGradient get accent => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [rose1, rose2],
      );

  @override
  AppPalette copyWith({Color? bg, Color? ink}) => AppPalette(
        bg: bg ?? this.bg,
        ink: ink ?? this.ink,
        muted: muted,
        deep: deep,
        deep2: deep2,
        deep3: deep3,
        rose1: rose1,
        rose2: rose2,
        act: act,
        blob: blob,
        w1: w1,
        w2: w2,
        border: border,
        gold: gold,
        goldText: goldText,
        heart: heart,
        body: body,
        shadow: shadow,
      );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      bg: l(bg, other.bg),
      ink: l(ink, other.ink),
      muted: l(muted, other.muted),
      deep: l(deep, other.deep),
      deep2: l(deep2, other.deep2),
      deep3: l(deep3, other.deep3),
      rose1: l(rose1, other.rose1),
      rose2: l(rose2, other.rose2),
      act: l(act, other.act),
      blob: l(blob, other.blob),
      w1: l(w1, other.w1),
      w2: l(w2, other.w2),
      border: l(border, other.border),
      gold: l(gold, other.gold),
      goldText: l(goldText, other.goldText),
      heart: l(heart, other.heart),
      body: l(body, other.body),
      shadow: l(shadow, other.shadow),
    );
  }
}

extension PaletteContext on BuildContext {
  AppPalette get pal => Theme.of(this).extension<AppPalette>()!;
}
