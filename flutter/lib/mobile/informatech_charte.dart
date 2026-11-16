// InformaTech (OPMD Android, A1, D-229): the Hub charter on Android, same tokens as « InformaTech Admin »
// (mobile-admin/src/styles.css, graphite D-218 / D-221). Graphite in light and dark alike (the pocket app has no light
// variant). Colours and font only: upstream screens keep their layout.
import 'package:flutter/material.dart';

import '../common.dart';

class Charte {
  static const fond = Color(0xFF141415);
  static const surface = Color(0xFF19191B);
  static const surface2 = Color(0xFF232325);
  static const creux = Color(0xFF0F0F10);
  static const texte = Color(0xFFEDEDED);
  static const texte2 = Color(0xFFA1A1A6);
  static const texte3 = Color(0xFF6E6E73);
  static const trait = Color(0x14EDEDED); // rgb(237 237 237 / .08)
  static const traitFort = Color(0x29EDEDED); // .16
  static const accent = Color(0xFF6FF3D6);
  static const surAccent = Color(0xFF05060F);
  static const ambre = Color(0xFFFFD28A);
  static const erreur = Color(0xFFFF8A80);

  /// The iridescent primary of the pocket app (`--primaire`), for primary actions only.
  static const primaire = LinearGradient(
    begin: Alignment(-0.9, -0.4),
    end: Alignment(0.9, 0.4),
    colors: [Color(0xFF6FF3D6), Color(0xFF4CC9F0), Color(0xFF8B7CF6), Color(0xFFE7A6FF)],
    stops: [0, .35, .70, 1],
  );

  static const police = 'Poppins';

  static ThemeData theme() {
    final base = MyTheme.darkTheme;
    TextStyle? p(TextStyle? s, {FontWeight? poids}) => s?.copyWith(fontFamily: police, fontWeight: poids ?? s.fontWeight);
    final t = base.textTheme.apply(fontFamily: police, bodyColor: texte, displayColor: texte);
    return base.copyWith(
      scaffoldBackgroundColor: fond,
      dialogBackgroundColor: surface,
      cardColor: surface,
      canvasColor: fond,
      dividerColor: trait,
      hoverColor: surface2,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: accent,
        onPrimary: surAccent,
        secondary: accent,
        onSecondary: surAccent,
        surface: surface,
        onSurface: texte,
        error: erreur,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: fond,
        foregroundColor: texte,
        elevation: 0,
        shadowColor: Colors.transparent,
        titleTextStyle: TextStyle(fontFamily: police, fontWeight: FontWeight.w600, fontSize: 17, color: texte),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: traitFort),
        ),
        titleTextStyle: const TextStyle(fontFamily: police, fontWeight: FontWeight.w600, fontSize: 17, color: texte),
        contentTextStyle: const TextStyle(fontFamily: police, fontSize: 14, height: 1.4, color: texte2),
      ),
      textTheme: t.copyWith(
        titleLarge: p(t.titleLarge, poids: FontWeight.w600),
        titleMedium: p(t.titleMedium, poids: FontWeight.w600),
        titleSmall: p(t.titleSmall, poids: FontWeight.w500),
        bodyMedium: p(t.bodyMedium)?.copyWith(color: texte2),
        labelLarge: p(t.labelLarge, poids: FontWeight.w600)?.copyWith(color: accent),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent, textStyle: const TextStyle(fontFamily: police, fontWeight: FontWeight.w600)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: surAccent,
          textStyle: const TextStyle(fontFamily: police, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: accent),
      snackBarTheme: const SnackBarThemeData(backgroundColor: surface2, contentTextStyle: TextStyle(fontFamily: police, color: texte)),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.all(Radius.circular(8))),
        textStyle: TextStyle(fontFamily: police, color: texte, fontSize: 12),
      ),
    );
  }
}
