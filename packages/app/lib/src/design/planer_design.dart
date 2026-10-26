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

/// Thema des Planers (hell; Dunkelmodus folgt mit M3-09).
ThemeData planerThema() {
  final farben = ColorScheme.fromSeed(
    seedColor: PlanerFarben.braun,
    primary: PlanerFarben.braun,
    onPrimary: PlanerFarben.weiss,
    secondary: PlanerFarben.gruen,
    onSecondary: PlanerFarben.weiss,
    surface: PlanerFarben.weiss,
    onSurface: PlanerFarben.text,
  );
  return ThemeData(
    colorScheme: farben,
    fontFamily: planerSchrift,
    scaffoldBackgroundColor: PlanerFarben.weiss,
    dividerColor: PlanerFarben.linie,
    cardTheme: const CardThemeData(
      color: PlanerFarben.weiss,
      surfaceTintColor: PlanerFarben.weiss,
      elevation: 1,
    ),
  );
}
