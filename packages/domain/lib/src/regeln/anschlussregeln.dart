/// Regeln des Terrassenanschlusses (Fachkonzept 04, M7): welche Seite
/// welche Rolle hat und was daraus für Zeichnung und Material folgt.
library;

import 'dart:math' as math;

import '../artikel/einheiten.dart';
import '../geometrie/kontur.dart';
import '../geometrie/punkt.dart';
import '../konfiguration/anschlussergebnis.dart';
import '../konfiguration/grundriss.dart';
import '../konfiguration/planungsstand.dart';
import 'treppen.dart';

/// Strecke der Seite [seite] von ihrer Ecke zur nächsten in mm – gerade von
/// Eckpunkt zu Eckpunkt wie die Seitenlänge der Beschriftung.
({Punkt von, Punkt bis}) seitenstrecke(Planungsstand stand, int seite) {
  final ecken = stand.grundriss.ecken;
  return (von: ecken[seite], bis: ecken[(seite + 1) % ecken.length]);
}

/// Verblendete Stücke der Seite [seite]: ohne Teilstücke die ganze Seite,
/// sonst jedes Teilstück auf die Seite gekürzt (leere fallen weg;
/// Planungskern v7, Regel 9.4). [ecke]: das Stück beginnt oder endet an
/// einer Ecke der Seite.
List<({Punkt von, Punkt bis, bool ecke})> blendenstuecke(
  Planungsstand stand,
  int seite,
) {
  final (:von, :bis) = seitenstrecke(stand, seite);
  final teile = stand.anschluss.teileAn(seite);
  if (teile.isEmpty) return [(von: von, bis: bis, ecke: true)];
  final laenge = von.abstand(bis);
  final richtung = (bis - von).einheit;
  return [
    for (final t in teile)
      if ((
            math.min(t.von.mm.toDouble(), laenge),
            math.min(t.bis.mm.toDouble(), laenge),
          )
          case (final a, final b) when b - a >= 1)
        (
          von: von + richtung * a,
          bis: von + richtung * b,
          ecke: a <= 0 || b >= laenge,
        ),
  ];
}

/// Verblendete Teile (von, bis längs des Bogens in mm ab seinem Anfang)
/// der Seite [seite], deren Bogen [laenge] lang ist (Planungsregeln
/// Alexander (Planungskern v12, 12.11.2026), Regel 14.3): ohne Teilstücke
/// der ganze Bogen, sonst jedes Teilstück auf den Bogen gekürzt (leere
/// fallen weg).
List<(double, double)> bogenteile(
  Planungsstand stand,
  int seite,
  double laenge,
) {
  final teile = stand.anschluss.teileAn(seite);
  if (teile.isEmpty) return [(0, laenge)];
  return [
    for (final t in teile)
      if ((
            math.min(t.von.mm.toDouble(), laenge),
            math.min(t.bis.mm.toDouble(), laenge),
          )
          case (final a, final b) when b - a >= 1)
        (a, b),
  ];
}

/// Punkt des Bogens [b] nach [s] mm ab seinem Anfang.
Punkt punktAufBogen(Kante b, double s) =>
    b.start.gedreht(b.winkel * s / b.laenge, b.mittelpunkt);

/// Sehnenzug des Bogens [b] von [von] bis [bis] (mm ab seinem Anfang),
/// höchstens [bogenToleranz] daneben – für die Zeichnung.
List<Punkt> bogenzug(Kante b, double von, double bis) {
  final teil = Kante(
    punktAufBogen(b, von),
    punktAufBogen(b, bis),
    math.tan(b.winkel * (bis - von) / b.laenge / 4),
  );
  return [...teil.zwischenpunkte(bogenToleranz), teil.ende];
}

/// Verblendete Teile der Seite [seite] am Bogen [b] als Sehnenzug.
Iterable<Seitenlinie> _bogenlinien(
  Planungsstand stand,
  int seite,
  Kante b,
) sync* {
  for (final (von, bis) in bogenteile(stand, seite, b.laenge)) {
    final zug = bogenzug(b, von, bis);
    for (var i = 1; i < zug.length; i++) {
      yield (
        seite: seite,
        rolle: Seitenrolle.verblendung,
        von: zug[i - 1],
        bis: zug[i],
      );
    }
  }
}

/// Anschluss der bearbeiteten Fläche (M7) mit den [meldungen]:
/// angrenzende Seiten grau (M7-01, 4.1), verblendete gelb (M7-02, 4.2;
/// bei Teilverblendung je Teilstück, Planungskern v7, Regel 9.4) – beim
/// Kreis („Fläche verblenden“) der ganze Umriss, am Bogen einer Seite der
/// Bogen als Sehnenzug (Planungskern v12) –,
/// Seiten mit Rinne blau (M7-03, 4.3).
///
/// Mit den geprüften [hoehen] (Ecken, dann die weiteren Höhenreferenzpunkte,
/// `pruefeHoehen`) kommen die wirksamen Höhenreferenzpunkte mit Ort und
/// Höhe dazu (M7-04).
Anschlussergebnis anschlussergebnis(
  Planungsstand stand, {
  List<Anschlussmeldung> meldungen = const [],
  List<Millimeter> hoehen = const [],
}) {
  Iterable<Seitenlinie> linien(List<int> seiten, Seitenrolle rolle) sync* {
    for (final seite in seiten) {
      final (:von, :bis) = seitenstrecke(stand, seite);
      yield (seite: seite, rolle: rolle, von: von, bis: bis);
    }
  }

  final kreis = stand.grundriss is KreisGrundriss;
  final umriss = stand.kontur.vieleck();
  final boegen = stand.rundungen.seitenboegen(stand.grundriss);
  return Anschlussergebnis(
    seiten: [
      ...linien(stand.anschluss.angrenzend, Seitenrolle.bauelement),
      if (!kreis)
        for (final seite in stand.anschluss.verblendet)
          if (boegen[seite] case final b?)
            ..._bogenlinien(stand, seite, b)
          else
            for (final (:von, :bis, ecke: _) in blendenstuecke(stand, seite))
              (seite: seite, rolle: Seitenrolle.verblendung, von: von, bis: bis)
      else if (stand.anschluss.verblendetAn(0))
        for (var i = 0; i < umriss.length; i++)
          (
            seite: 0,
            rolle: Seitenrolle.verblendung,
            von: umriss[i],
            bis: umriss[(i + 1) % umriss.length],
          ),
      ...linien([
        for (final r in stand.anschluss.rinnen) r.seite,
      ], Seitenrolle.rinne),
    ],
    meldungen: meldungen,
    hoehenpunkte: [
      for (final (i, p) in stand.wirksameHoehenpunkte.indexed)
        (
          ort: stand.ortVon(p),
          hoehe: hoehen.elementAtOrNull(stand.hoehen.length + i) ?? p.hoehe,
        ),
    ],
    treppen: treppenbilder(stand),
  );
}
