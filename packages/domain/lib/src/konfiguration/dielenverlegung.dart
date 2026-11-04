import 'dart:math' as math;

import '../artikel/dielenlaenge.dart';
import '../artikel/einheiten.dart';
import '../geometrie/flaeche.dart';
import '../geometrie/kontur.dart';
import '../geometrie/punkt.dart';
import '../regeln/planungsregeln.dart';
import 'verlegeart.dart';

/// Schmalere Restreihen am Rand werden nicht verlegt: Der alte Planer lässt
/// eine 14 mm breite Ecke bei 45° (F03) und 11 mm bei 30° (F05) weg, eine
/// 18 mm breite Reihe dagegen nicht (Referenzfall 2026-05-29-3162).
const mindestreihenbreite = Millimeter(15);

/// Zuschnitte unter 5 cm – ein Dielenstück, das kürzer ist, oder eine
/// Randreihe, die schmaler ist – meldet die Oberfläche unter 2.5 (M5-07).
const mindestzuschnitt = Millimeter(50);

/// Ein Dielenstück der Verlegung (M5-05): Reihe, Länge in Verlegerichtung,
/// Breite und Umriss für die Zeichnung.
final class Dielenstueck {
  Dielenstueck(
    this.reihe,
    this.laenge,
    List<Punkt> umriss, {
    required this.breite,
  }) : umriss = List.unmodifiable(umriss);

  /// 0 = Reihe am Ausgangspunkt, negative Nummern auf der anderen Seite.
  final int reihe;

  /// Länge in Verlegerichtung: so lang muss die Diele sein – bei schrägen
  /// Rändern also die längere Kante.
  final Millimeter laenge;

  /// Breite quer zur Verlegerichtung in mm: die Breite des Teils der Reihe,
  /// in dem das Stück liegt – am Rand weniger als die Dielenbreite plus
  /// Fuge (M5-07).
  final double breite;

  /// Umriss in Planungskoordinaten (mm) für die Zeichnung.
  final List<Punkt> umriss;

  /// Ob das Stück kürzer oder schmaler als [mindestzuschnitt] ist (M5-07).
  bool get kurzerZuschnitt =>
      laenge < mindestzuschnitt || breite < mindestzuschnitt.mm;
}

/// Wie weit die erste ganze Diele höchstens verschoben werden kann (M5-07,
/// Fachkonzept 2.5), je Bildschirmachse in mm: Die Achse, die eher in
/// Verlegerichtung liegt (|cos w| ≥ |sin w|), bekommt das Raster der Stöße
/// ([stossraster]: längste oder erzwungene Länge, höchstens die Ausdehnung),
/// die andere Dielenbreite plus Fuge.
({Millimeter x, Millimeter y}) verschiebungsgrenzen(
  Kontur kontur, {
  required double winkel,
  required Millimeter dielenbreite,
  required Millimeter laengste,
}) {
  final drehung = -winkel * math.pi / 180;
  final huelle = _lokal(kontur, Punkt.ursprung, drehung).huellrechteck;
  final laenge = stossraster(
    Millimeter(huelle.max.x.round()) - Millimeter(huelle.min.x.round()),
    laengste,
  );
  final breite = dielenbreite + fuge;
  // in Grad (0 bis 179) verglichen: bei 45° wären cos und sin im Bogenmaß
  // nicht gleich
  return winkel <= 45 || winkel >= 135
      ? (x: laenge, y: breite)
      : (x: breite, y: laenge);
}

/// [kontur] in Verlegerichtung gedreht: [ausgangspunkt] bei (0|0), Dielen
/// längs x; gerundet, damit 90° keine Kanten knapp neben den Reihengrenzen
/// erzeugt.
Flaeche _lokal(Kontur kontur, Punkt ausgangspunkt, double drehung) => Flaeche(
  Kontur([
    for (final p in kontur.punkte)
      _gerundet((p - ausgangspunkt).gedreht(drehung)),
  ], woelbungen: kontur.woelbungen),
);

/// Verlegt Dielenreihen im Winkel [winkel] (Grad, Fachkonzept 2.4) über die
/// [kontur] (M5-05).
///
/// Die Reihen sind [dielenbreite] plus Fuge breit und beginnen am
/// [ausgangspunkt], auch zur anderen Seite hin. Liegt ein Teil der Fläche
/// in einem Reihenstreifen, ist er eine Dielenreihe von seinem ersten bis zu
/// seinem letzten Punkt in Verlegerichtung (F03: 437 + 6,5 cm bei 45°).
/// Geschnitten wird an den Stoßlinien der [verlegeart] im Raster ab dem
/// Ausgangspunkt; [laengste] und [verbinden] wie bei [reihenstuecke].
List<Dielenstueck> verlegeDielen(
  Kontur kontur, {
  required double winkel,
  required Punkt ausgangspunkt,
  required Millimeter dielenbreite,
  required Verlegeart verlegeart,
  required Millimeter laengste,
  bool verbinden = false,
}) {
  final drehung = -winkel * math.pi / 180;
  final lokal = _lokal(kontur, ausgangspunkt, drehung);
  final huelle = lokal.huellrechteck;
  final von = Millimeter(huelle.min.x.round());
  final bis = Millimeter(huelle.max.x.round());
  final raster = stossraster(bis - von, laengste);
  final breite = (dielenbreite + fuge).mm;
  final stuecke = <Dielenstueck>[];
  for (
    var reihe = (huelle.min.y / breite).floor();
    reihe * breite < huelle.max.y;
    reihe++
  ) {
    final streifen = _rechteck(
      huelle.min.x - 1,
      huelle.max.x + 1,
      (reihe * breite).toDouble(),
      ((reihe + 1) * breite).toDouble(),
    );
    final stoesse = verlegeart.stoesse(
      reihe,
      von,
      bis,
      raster,
      ausgang: const Millimeter(0),
    );
    for (final teil in lokal.geschnitten(streifen)) {
      final h = teil.huellrechteck;
      if (h.hoehe < mindestreihenbreite.mm) continue;
      final laengen = reihenstuecke(
        Millimeter(h.min.x.round()),
        Millimeter(h.max.x.round()),
        stoesse,
        laengste: laengste,
        verbinden: verbinden,
      );
      final zug = teil.kontur.vieleck();
      var anfang = h.min.x.round();
      for (final (i, laenge) in laengen.indexed) {
        final ende = anfang + laenge.mm;
        // erstes und letztes Stück bis zum Rand, dazwischen an den Stößen
        final umriss = _zwischen(
          zug,
          i == 0 ? double.negativeInfinity : anfang.toDouble(),
          i == laengen.length - 1 ? double.infinity : ende.toDouble(),
        );
        stuecke.add(
          Dielenstueck(reihe, laenge, [
            for (final p in umriss) p.gedreht(-drehung) + ausgangspunkt,
          ], breite: h.hoehe),
        );
        anfang = ende;
      }
    }
  }
  return stuecke;
}

/// Teil des geschlossenen Linienzugs [zug] mit [a] ≤ x ≤ [b]
/// (Sutherland-Hodgman). Innerhalb eines Reihenstreifens schneidet der
/// Stoß nur quer; das ist einfacher und robuster als die Mengenoperation,
/// wenn ein Stoß durch einen Eckpunkt läuft (Kreis ab Punkt A).
List<Punkt> _zwischen(List<Punkt> zug, double a, double b) =>
    _abgeschnitten(_abgeschnitten(zug, (p) => p.x - a), (p) => b - p.x);

/// Teil von [zug], in dem [seite] nicht negativ ist.
List<Punkt> _abgeschnitten(List<Punkt> zug, double Function(Punkt) seite) {
  final ergebnis = <Punkt>[];
  for (var i = 0; i < zug.length; i++) {
    final p = zug[i];
    final q = zug[(i + 1) % zug.length];
    final sp = seite(p);
    final sq = seite(q);
    if (sp >= 0) ergebnis.add(p);
    if ((sp >= 0) != (sq >= 0)) ergebnis.add(p + (q - p) * (sp / (sp - sq)));
  }
  return ergebnis;
}

/// Achsparalleles Rechteck in lokalen Koordinaten.
Flaeche _rechteck(double x0, double x1, double y0, double y1) =>
    Flaeche(Kontur.rechteck(x1 - x0, y1 - y0, Punkt(x0, y0)));

/// Auf 1/1000 mm gerundet (über den Text, damit eine falsche Skalierung
/// nicht unbemerkt Millionen Reihen erzeugt).
Punkt _gerundet(Punkt p) => Punkt(_tausendstel(p.x), _tausendstel(p.y));

double _tausendstel(double mm) => double.parse(mm.toStringAsFixed(3));
