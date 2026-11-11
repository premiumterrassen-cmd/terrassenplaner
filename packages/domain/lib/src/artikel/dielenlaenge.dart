import 'dart:math' as math;

import '../regeln/planungsregeln.dart';
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

/// Stücke einer UK-Linie der Länge [laenge] aus den Lieferlängen [laengen]
/// (aufsteigend; Planungsregeln Alexander (Planungskern v6, 11.11.2026),
/// Regel 3.5): bis zur längsten Lieferlänge ein Stück, länger ganze
/// längste Lieferlängen und der Rest. Wäre der Rest kürzer als
/// [ukMindestReststueck], wird das letzte ganze Stück so weit gekürzt, dass
/// der Rest gerade so lang ist: 610 cm → 560 + 50 cm statt 600 + 10 cm. Der
/// Stoß liegt auf einem Auflager. Liefert die UK die Wunschlänge [fest],
/// wird nur sie verwendet. Bei Lieferlängen unter dem doppelten
/// Mindestrest gilt höchstens die halbe längste Länge als Rest.
List<Millimeter> ukStueckelung(
  Millimeter laenge,
  List<Millimeter> laengen, {
  Millimeter? fest,
}) {
  if (laenge.mm <= 0) return const [];
  if (laengen.isEmpty) return [laenge];
  final laengste = (laengen.contains(fest) ? fest! : laengen.last).mm;
  final mindest = math.min(ukMindestReststueck.mm, laengste ~/ 2);
  final stuecke = <Millimeter>[];
  var rest = laenge.mm;
  while (rest > laengste) {
    final stueck = laengste - math.max<int>(0, mindest - rest + laengste);
    stuecke.add(Millimeter(stueck));
    rest -= stueck;
  }
  return [...stuecke, Millimeter(rest)];
}

/// Dielenstücke einer Reihe von [von] bis [bis], geschnitten an den
/// Stoßlinien [stoesse] der Verlegeart (M5-03, Fachkonzept 2.3).
///
/// Mit [verbinden] („Sollen kurze Dielenstücke miteinander verbunden
/// werden?“ = Ja) ersetzt eine ganze Diele ein Endstück samt Nachbarstück,
/// wenn beide zusammen in die längste erlaubte Länge [laengste] passen; der
/// Stoß ist dann nicht mehr durchgehend (R-B12). Beim Rechteck liegen die
/// Stöße eine ganze Lieferlänge auseinander, dort wirkt das nie (F13).
List<Millimeter> reihenstuecke(
  Millimeter von,
  Millimeter bis,
  Iterable<Millimeter> stoesse, {
  required Millimeter laengste,
  bool verbinden = false,
}) {
  if (bis <= von) return const [];
  final schnitte = [
    von,
    ...[
      for (final s in stoesse)
        if (s > von && s < bis) s,
    ]..sort((a, b) => a.mm.compareTo(b.mm)),
    bis,
  ];
  final stuecke = [
    for (var i = 1; i < schnitte.length; i++) schnitte[i] - schnitte[i - 1],
  ];
  if (!verbinden || stuecke.length < 2) return stuecke;
  if (stuecke[0] + stuecke[1] <= laengste) {
    stuecke.replaceRange(0, 2, [stuecke[0] + stuecke[1]]);
  }
  final n = stuecke.length;
  if (n > 1 && stuecke[n - 2] + stuecke[n - 1] <= laengste) {
    stuecke.replaceRange(n - 2, n, [stuecke[n - 2] + stuecke[n - 1]]);
  }
  return stuecke;
}
