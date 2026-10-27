import 'package:flutter/material.dart';

/// Markenfarben von RobinienWelt / ALTO HOLZ (M3-01).
abstract final class PlanerFarben {
  static const braun = Color(0xFFB0864B);
  static const gruen = Color(0xFF95C11C);
  static const sand = Color(0xFFF5F0E8);
  static const text = Color(0xFF3A3A3A);
  static const linie = Color(0xFFDCDCDC);
  static const weiss = Color(0xFFFFFFFF);
}

/// Abstände im Raster von 4 px.
abstract final class PlanerAbstand {
  static const klein = 8.0;
  static const mittel = 16.0;
  static const gross = 24.0;
}

/// Breakpoints: Tablet ab 600 px, Desktop ab 1024 px Breite.
abstract final class PlanerLayout {
  static const tabletAb = 600.0;
  static const desktopAb = 1024.0;

  /// Breite des Bearbeitungsmenüs.
  static const menuBreite = 320.0;

  static bool istDesktop(double breite) => breite >= desktopAb;
}

/// Schriftfamilie – mitgeliefert, kein Abruf von Google-Servern.
const planerSchrift = 'Roboto';

/// Flächenfarben der dunklen Darstellung (M3-09): warme Grautöne passend
/// zu Braun und Grün, die Markenfarben bleiben.
abstract final class PlanerFarbenDunkel {
  static const grund = Color(0xFF1F1D1A);
  static const leiste = Color(0xFF2B2824);
  static const text = Color(0xFFE9E3D9);
  static const linie = Color(0xFF4A453F);
}

/// Thema des Planers, hell oder dunkel (M3-09). Flächen über das
/// Farbschema: `surface` Grund, `surfaceContainer` Leisten (Sand),
/// `onSurface` Text, `outlineVariant` Linien.
ThemeData planerThema([Brightness helligkeit = Brightness.light]) {
  final hell = helligkeit == Brightness.light;
  final grund = hell ? PlanerFarben.weiss : PlanerFarbenDunkel.grund;
  final linie = hell ? PlanerFarben.linie : PlanerFarbenDunkel.linie;
  final farben = ColorScheme.fromSeed(
    seedColor: PlanerFarben.braun,
    brightness: helligkeit,
    primary: PlanerFarben.braun,
    onPrimary: PlanerFarben.weiss,
    secondary: PlanerFarben.gruen,
    onSecondary: PlanerFarben.weiss,
    surface: grund,
    surfaceContainer: hell ? PlanerFarben.sand : PlanerFarbenDunkel.leiste,
    onSurface: hell ? PlanerFarben.text : PlanerFarbenDunkel.text,
    outlineVariant: linie,
  );
  return ThemeData(
    colorScheme: farben,
    fontFamily: planerSchrift,
    scaffoldBackgroundColor: grund,
    dividerColor: linie,
    cardTheme: CardThemeData(
      color: grund,
      surfaceTintColor: grund,
      elevation: 1,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: grund,
      surfaceTintColor: grund,
    ),
  );
}

/// Kurzer Zugriff auf die Farben des aktuellen Themas.
extension FarbenImKontext on BuildContext {
  ColorScheme get farben => Theme.of(this).colorScheme;
}
