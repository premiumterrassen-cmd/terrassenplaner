import 'dart:math' as math;

import '../artikel/dielenlaenge.dart';
import '../artikel/einheiten.dart';
import '../geometrie/flaeche.dart';
import '../geometrie/kontur.dart';
import '../geometrie/mengen.dart';
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

  /// Breite quer zur Verlegerichtung in mm, Fuge eingeschlossen: die
  /// Ausdehnung des Umrisses – am Rand und an Ausklinkungen weniger als die
  /// Dielenbreite plus Fuge (M5-07, M5-08).
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
/// ([stossraster]: längste oder erzwungene Länge, höchstens die Ausdehnung,
/// mit [ueberlaenge]), die andere Dielenbreite plus [fuge] (R-B06).
({Millimeter x, Millimeter y}) verschiebungsgrenzen(
  Kontur kontur, {
  required double winkel,
  required Millimeter dielenbreite,
  required Millimeter laengste,
  Millimeter ueberlaenge = const Millimeter(0),
  Millimeter fuge = fuge,
}) {
  final drehung = -winkel * math.pi / 180;
  final huelle = _lokal(kontur, Punkt.ursprung, drehung).huellrechteck;
  final laenge = stossraster(
    Millimeter(huelle.max.x.round()) - Millimeter(huelle.min.x.round()),
    laengste,
    ueberlaenge: ueberlaenge,
  );
  final breite = dielenbreite + fuge;
  // in Grad (0 bis 179) verglichen: bei 45° wären cos und sin im Bogenmaß
  // nicht gleich
  return winkel <= 45 || winkel >= 135
      ? (x: laenge, y: breite)
      : (x: breite, y: laenge);
}

/// Anfang des Stoßrasters in lokalen Koordinaten (Ausgangspunkt bei
/// (0|0)) für die Ausgangsecke [ecke] (lokal) der Fläche [lokal]: an der
/// Ecke, wenn dort eine gerade Kante quer zur Verlegerichtung liegt – der
/// Stoß folgt ihr (L-Form ab B, Referenzfall 2026-06-07-4340) –, sonst am
/// näheren Rand der Fläche (135° im Rechteck, Alexander 13.11.2026). Wie
/// weit der Ausgangspunkt gegenüber der Ecke verschoben ist (M5-07), so
/// weit wandert das Raster mit.
Millimeter _rasteranfang(Flaeche lokal, Punkt ecke) {
  final kontur = lokal.kontur;
  final n = kontur.punkte.length;
  var quer = false;
  for (var i = 0; i < n; i++) {
    if (!kontur.punkte[i].gleich(ecke, 1)) continue;
    for (final (nachbar, woelbung) in [
      (kontur.punkte[(i + 1) % n], kontur.woelbungen[i]),
      (kontur.punkte[(i + n - 1) % n], kontur.woelbungen[(i + n - 1) % n]),
    ]) {
      quer = quer || (woelbung == 0 && (nachbar.x - ecke.x).abs() < 1);
    }
  }
  final huelle = lokal.huellrechteck;
  final rand = quer
      ? ecke.x
      : ecke.x - huelle.min.x <= huelle.max.x - ecke.x
      ? huelle.min.x
      : huelle.max.x;
  return Millimeter((rand - ecke.x).round());
}

/// So weit muss eine feste Stoßlinie mindestens vom Anfang und Ende der
/// Fläche in Verlegerichtung entfernt sein (Planungskern v13, Regel 15):
/// 20 cm – näher am Rand entfällt sie.
const stosslinieRandabstand = Millimeter(200);

/// Feste Stoßlinien der Vorgabe „Stoßlinie durch Eckpunkt“ (Planungsregeln
/// Alexander (Planungskern v13, 13.11.2026), Regel 15, R-B20) für die
/// Fläche [kontur]: je Punkt der [punkte] eine Linie quer zu den Dielen
/// (Winkel [winkel]) genau durch ihn, als Lage in Verlegerichtung ab dem
/// [ausgangspunkt] wie in `verlegeDielen` (auf ganze mm, doppelte
/// zusammengefasst, aufsteigend).
///
/// - `fest`: die Linien, die mehr als [stosslinieRandabstand] im Inneren
///   der Fläche liegen; eine Ecke am Anfang oder Ende hat keine.
/// - `zusatz`: Wäre ein Stück zwischen zwei festen Linien (oder Linie und
///   Rand) länger als [hoechstlaenge] (längste zulässige Lieferlänge plus
///   Überlänge), wird es in gleich lange Stücke geteilt – gleichmäßig
///   verteilte zusätzliche Stöße, die die Planung nennt.
///
/// Passt die ganze Fläche in eine Diele, gibt es keine Linie.
({List<Millimeter> fest, List<Millimeter> zusatz}) festeStosslinien(
  Kontur kontur, {
  required double winkel,
  required Punkt ausgangspunkt,
  required List<Punkt> punkte,
  required Millimeter hoechstlaenge,
}) {
  final drehung = -winkel * math.pi / 180;
  final huelle = _lokal(kontur, ausgangspunkt, drehung).huellrechteck;
  final von = huelle.min.x.round();
  final bis = huelle.max.x.round();
  if (bis - von <= hoechstlaenge.mm) return (fest: const [], zusatz: const []);
  final fest = {
    for (final p in punkte)
      if (_gerundet((p - ausgangspunkt).gedreht(drehung)).x.round() case final x
          when x > von + stosslinieRandabstand.mm &&
              x < bis - stosslinieRandabstand.mm)
        x,
  }.toList()..sort();
  if (fest.isEmpty) return (fest: const [], zusatz: const []);
  final zusatz = <Millimeter>[];
  final grenzen = [von, ...fest, bis];
  for (var i = 1; i < grenzen.length; i++) {
    final (a, b) = (grenzen[i - 1], grenzen[i]);
    final n = ((b - a) / hoechstlaenge.mm).ceil();
    for (var k = 1; k < n; k++) {
      zusatz.add(Millimeter(a + ((b - a) * k / n).round()));
    }
  }
  return (fest: [for (final x in fest) Millimeter(x)], zusatz: zusatz);
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
/// Die Reihen sind [dielenbreite] plus [fuge] (R-B06) breit und beginnen am
/// [ausgangspunkt], auch zur anderen Seite hin. Liegt ein Teil der Fläche
/// in einem Reihenstreifen, ist er eine Dielenreihe von seinem ersten bis zu
/// seinem letzten Punkt in Verlegerichtung (F03: 437 + 6,5 cm bei 45°).
/// Geschnitten wird an den Stoßlinien der [verlegeart] im Raster ab dem
/// [ausgangspunkt]; mit der Ausgangsecke [ecke] ab der Ecke, wenn dort eine
/// Kante quer zur Verlegerichtung liegt, sonst ab dem näheren Rand der
/// Fläche (135°: keine Stoßlinie durch A wie im alten Planer, F04;
/// Alexander 13.11.2026). Die Verschiebung des Ausgangspunkts gegenüber
/// der Ecke (M5-07) verschiebt das Raster mit.
///
/// Feste [stosslinien] (Lage in Verlegerichtung ab dem [ausgangspunkt],
/// `festeStosslinien`, Planungskern v13 Regel 15, R-B20) ersetzen Raster
/// und Verband: Gestoßen wird nur ein Reihenabschnitt, der länger als die
/// längste Lieferlänge samt Überlänge ist, dann an allen Linien in ihm;
/// kürzere bleiben ganz, und kurze Stücke werden nicht über eine feste
/// Linie hinweg verbunden.
///
/// Die Linien wählt Reihe für Reihe [Verbandwahl] (R-B18: im
/// Verband Stücke ab [mindeststueck], 40 cm); [laengste], [verbinden] und
/// [ueberlaenge] wie bei [reihenstuecke] – mit Überlänge ist ein Stoß erst
/// über der längsten Lieferlänge plus Überlänge nötig ([stossraster]).
///
/// [aussparungen] (leere Ausschnitte und Teilflächen mit anderem Belag,
/// M5-08) bleiben frei; Raster und Reihen richten sich weiter nach der
/// ganzen [kontur]. Ragt eine Aussparung nur in einen Teil einer Reihe,
/// wird die Diele ausgeklinkt und bleibt ein Stück; liegt sie ganz in einer
/// Reihe, endet die Diele an ihr.
List<Dielenstueck> verlegeDielen(
  Kontur kontur, {
  required double winkel,
  required Punkt ausgangspunkt,
  required Millimeter dielenbreite,
  required Verlegeart verlegeart,
  required Millimeter laengste,
  bool verbinden = false,
  Millimeter ueberlaenge = const Millimeter(0),
  List<Kontur> aussparungen = const [],
  Millimeter fuge = fuge,
  Millimeter mindeststueck = verbandMindeststueck,
  Punkt? ecke,
  List<Millimeter> stosslinien = const [],
}) {
  final drehung = -winkel * math.pi / 180;
  final lokal = _lokal(kontur, ausgangspunkt, drehung);
  final huelle = lokal.huellrechteck;
  final ausgang = switch (ecke) {
    null => const Millimeter(0),
    final e => _rasteranfang(
      lokal,
      _gerundet((e - ausgangspunkt).gedreht(drehung)),
    ),
  };
  final frei = [
    for (final a in aussparungen) _lokal(a, ausgangspunkt, drehung),
  ];
  final von = Millimeter(huelle.min.x.round());
  final bis = Millimeter(huelle.max.x.round());
  final raster = stossraster(bis - von, laengste, ueberlaenge: ueberlaenge);
  final verband = Verbandwahl(
    verlegeart,
    von: von,
    bis: bis,
    raster: raster,
    hoechstlaenge: laengste + ueberlaenge,
    mindeststueck: mindeststueck,
    ausgang: ausgang,
  );
  final breite = (dielenbreite + fuge).mm;
  final stuecke = <Dielenstueck>[];
  for (
    var reihe = (huelle.min.y / breite).floor();
    reihe * breite < huelle.max.y;
    reihe++
  ) {
    final y0 = (reihe * breite).toDouble();
    final y1 = ((reihe + 1) * breite).toDouble();
    final streifen = _rechteck(huelle.min.x - 1, huelle.max.x + 1, y0, y1);
    // nur die Aussparungen, die in die Reihe reichen – meist keine
    final imStreifen = [
      for (final f in frei)
        if (f.huellrechteck.max.y > y0 && f.huellrechteck.min.y < y1) f,
    ];
    final teile = lokal.geschnitten(streifen);
    final reihenteile = [
      for (final t
          in imStreifen.isEmpty
              ? teile
              : verknuepfe(teile, imStreifen, Verknuepfung.differenz))
        for (final teil in _ohneLoecher(t, y0, y1))
          if (teil.huellrechteck.hoehe >= mindestreihenbreite.mm) teil,
    ];
    final abschnitte = [
      for (final teil in reihenteile)
        (
          Millimeter(teil.huellrechteck.min.x.round()),
          Millimeter(teil.huellrechteck.max.x.round()),
        ),
    ];
    final stoesse = stosslinien.isEmpty
        ? verband.stoesse(reihe, abschnitte)
        : [
            for (final (a, b) in abschnitte)
              b - a > laengste + ueberlaenge
                  ? stosslinien
                  : const <Millimeter>[],
          ];
    for (final (n, teil) in reihenteile.indexed) {
      final (anfangMm, endeMm) = abschnitte[n];
      final laengen = reihenstuecke(
        anfangMm,
        endeMm,
        stoesse[n],
        laengste: laengste,
        verbinden: verbinden && stosslinien.isEmpty,
        ueberlaenge: ueberlaenge,
      );
      final zug = teil.kontur.vieleck();
      var anfang = anfangMm.mm;
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
          ], breite: Huellrechteck.um(umriss).hoehe),
        );
        anfang = ende;
      }
    }
  }
  return stuecke;
}

/// Teil [teil] eines Reihenstreifens von [y0] bis [y1] ohne Löcher: Liegt
/// eine Aussparung ganz in der Reihe, wird die Reihe über ihre Länge
/// unterbrochen – eine Diele mit Loch gibt es nicht.
List<Flaeche> _ohneLoecher(Flaeche teil, double y0, double y1) {
  if (teil.loecher.isEmpty) return [teil];
  return verknuepfe(
    [teil],
    [
      for (final h in [for (final l in teil.loecher) l.huellrechteck])
        _rechteck(h.min.x, h.max.x, y0 - 1, y1 + 1),
    ],
    Verknuepfung.differenz,
  );
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
