import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'palette.dart';

ThemeData buildTheme(AppPalette p) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: p.rose2,
      brightness: Brightness.light,
    ).copyWith(
      primary: p.rose2,
      onPrimary: Colors.white,
      surface: p.bg,
      onSurface: p.ink,
    ),
    scaffoldBackgroundColor: p.bg,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.ink,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    extensions: [p],
  );
  return base.copyWith(
    textTheme: GoogleFonts.manropeTextTheme(base.textTheme).apply(
      bodyColor: p.ink,
      displayColor: p.ink,
    ),
  );
}

/// Başlıklarda kullanılan zarif serif yazı tipi.
TextStyle serif(
  double size, {
  FontWeight weight = FontWeight.w600,
  Color? color,
  double height = 1.1,
}) =>
    GoogleFonts.cormorantGaramond(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );
