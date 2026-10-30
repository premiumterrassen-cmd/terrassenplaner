import 'artikel.dart';
import 'einheiten.dart';

/// Ob man beim Belag eine Lieferlänge erzwingen kann (M5-02): nur bei Dielen
/// mit mehreren Längen, nicht bei Holzfliesen und dem Längenmix der
/// Systemdielen (R-A06).
bool dielenlaengeWaehlbar(Artikel belag) =>
    belag.art == Artikelart.diele && belag.abmessungen.laengen.length > 1;

/// Lieferlängen für eine Dielenreihe der Länge [reihe] aus den [laengen]
/// des Belags, aufsteigend sortiert (M5-02, R-B10).
///
/// Automatisch reicht die kürzeste Länge, die die Reihe abdeckt (480 cm →
/// 5000 mm). Längere Reihen beginnen mit der längsten Lieferlänge, der Rest
/// bekommt wieder die kürzeste passende (800 cm → 6000 + 4000 mm). Liefert
/// der Belag die Wunschlänge [fest], wird nur sie verwendet; sonst gilt die
/// Automatik. Das Verteilen von Reststücken auf mehrere Reihen gehört zur
/// Verlegung (M5-08).
List<Millimeter> lieferlaengenFuer(
  Millimeter reihe,
  List<Millimeter> laengen, {
  Millimeter? fest,
}) {
  final moeglich = laengen.contains(fest) ? [fest!] : laengen;
  if (moeglich.isEmpty || reihe.mm <= 0) return const [];
  final laengste = moeglich.last;
  final ganze = (reihe.mm - 1) ~/ laengste.mm;
  final rest = reihe.mm - ganze * laengste.mm;
  return [
    ...List.filled(ganze, laengste),
    moeglich.firstWhere((l) => l.mm >= rest),
  ];
}
