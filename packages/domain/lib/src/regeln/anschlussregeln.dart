/// Regeln des Terrassenanschlusses (Fachkonzept 04, M7): welche Seite
/// welche Rolle hat und was daraus für Zeichnung und Material folgt.
library;

import 'dart:math' as math;

import '../artikel/einheiten.dart';
import '../ergebnisse/planbild.dart';
import '../geometrie/kontur.dart';
import '../geometrie/punkt.dart';
import '../konfiguration/anschlussergebnis.dart';
import '../konfiguration/ausschnitt.dart';
import '../konfiguration/grundriss.dart';
import '../konfiguration/planungsstand.dart';
import 'treppen.dart';

/// Strecke der Seite [seite] von ihrer Ecke zur nächsten in mm – gerade von
/// Eckpunkt zu Eckpunkt wie die Seitenlänge der Beschriftung.
({Punkt von, Punkt bis}) seitenstrecke(Planungsstand stand, int seite) {
  final ecken = stand.grundriss.ecken;
  return (von: ecken[seite], bis: ecken[(seite + 1) % ecken.length]);
}

/// Gerades Stück der Seite [seite] zwischen den Bögen abgerundeter Ecken
/// (Planungsregeln Alexander (Planungskern v15, 13.11.2026), Regel 17.1:
/// die Nachbarkanten sind um t gekürzt); ohne Rundung [seitenstrecke].
({Punkt von, Punkt bis}) geradeStrecke(Planungsstand stand, int seite) {
  final (:von, :bis) = seitenstrecke(stand, seite);
  final boegen = stand.rundungen.eckboegen(stand.grundriss);
  return (
    von: boegen[seite]?.ende ?? von,
    bis: boegen[(seite + 1) % stand.seitenzahl]?.start ?? bis,
  );
}

/// Verblendete Stücke der Seite [seite]: ohne Teilstücke die ganze Seite,
/// sonst jedes Teilstück auf die Seite gekürzt (leere fallen weg;
/// Planungskern v7, Regel 9.4) – an abgerundeten Ecken nur das gerade
/// Stück ([geradeStrecke]). [ecke]: das Stück beginnt oder endet an einer
/// Ecke der Seite.
List<({Punkt von, Punkt bis, bool ecke})> blendenstuecke(
  Planungsstand stand,
  int seite,
) {
  final (:von, :bis) = geradeStrecke(stand, seite);
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

/// Verblendete Kanten der Aussparungen von [stand] (Planungsregeln
/// Alexander (Planungskern v14, 13.11.2026), Regel 16.6) als Strecken –
/// nur gewählte Kanten leerer Ausschnitte mit Ecken.
List<({Punkt von, Punkt bis})> aussparungsblendenStrecken(
  Planungsstand stand,
) => [
  for (final k in stand.anschluss.aussparungsblenden)
    if (stand.ausschnitte.elementAtOrNull(k.ausschnitt) case final a?
        when a.funktion == Ausschnittfunktion.leer &&
            a.form != Ausschnittform.kreis &&
            k.kante < a.kontur.punkte.length)
      (
        von: a.kontur.punkte[k.kante],
        bis: a.kontur.punkte[(k.kante + 1) % a.kontur.punkte.length],
      ),
];

/// Die Strecken des Sehnenzugs [zug] als verblendete [Seitenlinie]n der
/// Seite [seite].
Iterable<Seitenlinie> _zuglinien(List<Punkt> zug, int seite) sync* {
  for (var i = 1; i < zug.length; i++) {
    yield (
      seite: seite,
      rolle: Seitenrolle.verblendung,
      von: zug[i - 1],
      bis: zug[i],
    );
  }
}

/// Verblendete Teile der Seite [seite] am Bogen [b] als Sehnenzug.
Iterable<Seitenlinie> _bogenlinien(
  Planungsstand stand,
  int seite,
  Kante b,
) sync* {
  for (final (von, bis) in bogenteile(stand, seite, b.laenge)) {
    yield* _zuglinien(bogenzug(b, von, bis), seite);
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
      // Planungskern v15 Regel 17.3 / v14 Regel 16.6: nur gewählte
      for (final MapEntry(key: ecke, value: b)
          in stand.rundungen.eckboegen(stand.grundriss).entries)
        if (stand.anschluss.eckblendeAn(ecke))
          ..._zuglinien(bogenzug(b, 0, b.laenge), eckbogenSeite(ecke)),
      for (final (:von, :bis) in aussparungsblendenStrecken(stand))
        (
          seite: aussparungsseite,
          rolle: Seitenrolle.verblendung,
          von: von,
          bis: bis,
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
