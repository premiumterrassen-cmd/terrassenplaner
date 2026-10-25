import 'dart:math' as math;

import '../artikel/einheiten.dart';
import '../regeln/planungsregeln.dart';

/// Art eines Bauteils im Terrassenmodell – bestimmt Material und Farbe in 2D
/// und 3D (M3-10).
enum Bauteilart { diele, unterkonstruktion }

/// Achsparalleler Quader in Millimetern (M3-10): `x` längs der Dielen,
/// `y` nach oben, `z` quer zu den Dielen; Ursprung an der Ecke der Terrasse
/// auf Höhe der Unterkante der Unterkonstruktion.
final class Quader {
  Quader({
    required this.x,
    required this.y,
    required this.z,
    required this.laenge,
    required this.hoehe,
    required this.breite,
  }) {
    for (final (name, wert) in [
      ('laenge', laenge),
      ('hoehe', hoehe),
      ('breite', breite),
    ]) {
      if (wert <= const Millimeter(0)) {
        throw ArgumentError.value(wert.mm, name, 'muss größer als 0 sein');
      }
    }
  }

  final Millimeter x;
  final Millimeter y;
  final Millimeter z;

  /// Ausdehnung in x.
  final Millimeter laenge;

  /// Ausdehnung in y.
  final Millimeter hoehe;

  /// Ausdehnung in z.
  final Millimeter breite;
}

/// Ein Bauteil des Modells: Art und Lage.
final class Bauteil {
  const Bauteil(this.art, this.quader);

  final Bauteilart art;
  final Quader quader;
}

/// Prototyp für M3-10: rechteckige Terrasse aus durchgehenden Dielen auf
/// Unterkonstruktion quer zu den Dielen. Ein Geometriemodell für 2D, 3D und
/// Berechnungen – der Geometrie-Kern (M4-01) ersetzt diese Funktion.
///
/// - Dielen liegen mit [fuge] nebeneinander; die letzte wird auf die
///   Restbreite zugeschnitten.
/// - Die Unterkonstruktion beginnt und endet bündig an den Stirnseiten,
///   dazwischen gleichmäßig mit höchstens [ukAchsabstand].
List<Bauteil> rechteckTerrasse({
  required Millimeter laenge,
  required Millimeter breite,
  required Millimeter dielenbreite,
  required Millimeter dielenstaerke,
  required Millimeter ukBreite,
  required Millimeter ukHoehe,
  required Millimeter ukAchsabstand,
}) {
  if (laenge <= ukBreite) {
    throw ArgumentError.value(
      laenge.mm,
      'laenge',
      'muss größer als die UK-Breite sein',
    );
  }
  if (ukAchsabstand <= const Millimeter(0)) {
    throw ArgumentError.value(
      ukAchsabstand.mm,
      'ukAchsabstand',
      'muss größer als 0 sein',
    );
  }
  final teile = <Bauteil>[];
  final spannweite = (laenge - ukBreite).mm;
  final felder = (spannweite / ukAchsabstand.mm).ceil();
  for (var i = 0; i <= felder; i++) {
    teile.add(
      Bauteil(
        Bauteilart.unterkonstruktion,
        Quader(
          x: Millimeter((spannweite * i / felder).round()),
          y: const Millimeter(0),
          z: const Millimeter(0),
          laenge: ukBreite,
          hoehe: ukHoehe,
          breite: breite,
        ),
      ),
    );
  }
  for (var z = const Millimeter(0); z < breite; z = z + dielenbreite + fuge) {
    final rest = breite - z;
    teile.add(
      Bauteil(
        Bauteilart.diele,
        Quader(
          x: const Millimeter(0),
          y: ukHoehe,
          z: z,
          laenge: laenge,
          hoehe: dielenstaerke,
          breite: Millimeter(math.min(rest.mm, dielenbreite.mm)),
        ),
      ),
    );
  }
  return List.unmodifiable(teile);
}
