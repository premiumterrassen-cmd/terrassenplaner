/// Regeln des Terrassenanschlusses (Fachkonzept 04, M7): welche Seite
/// welche Rolle hat und was daraus für Zeichnung und Material folgt.
library;

import 'dart:math' as math;

import '../artikel/einheiten.dart';
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

/// Anschluss der bearbeiteten Fläche (M7) mit den [meldungen]:
/// angrenzende Seiten grau (M7-01, 4.1), verblendete gelb (M7-02, 4.2;
/// bei Teilverblendung je Teilstück, Planungskern v7, Regel 9.4) – beim
/// Kreis („Fläche verblenden“) der ganze Umriss als Sehnenzug –,
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
  return Anschlussergebnis(
    seiten: [
      ...linien(stand.anschluss.angrenzend, Seitenrolle.bauelement),
      if (!kreis)
        for (final seite in stand.anschluss.verblendet)
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
