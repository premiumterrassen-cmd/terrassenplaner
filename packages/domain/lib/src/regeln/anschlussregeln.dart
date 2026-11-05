/// Regeln des Terrassenanschlusses (Fachkonzept 04, M7): welche Seite
/// welche Rolle hat und was daraus für Zeichnung und Material folgt.
library;

import '../geometrie/punkt.dart';
import '../konfiguration/anschlussergebnis.dart';
import '../konfiguration/grundriss.dart';
import '../konfiguration/planungsstand.dart';

/// Strecke der Seite [seite] von ihrer Ecke zur nächsten in mm – gerade von
/// Eckpunkt zu Eckpunkt wie die Seitenlänge der Beschriftung.
({Punkt von, Punkt bis}) seitenstrecke(Planungsstand stand, int seite) {
  final ecken = stand.grundriss.ecken;
  return (von: ecken[seite], bis: ecken[(seite + 1) % ecken.length]);
}

/// Anschluss der bearbeiteten Fläche (M7) mit den [meldungen]:
/// angrenzende Seiten grau (M7-01, 4.1), verblendete gelb (M7-02, 4.2) –
/// beim Kreis („Fläche verblenden“) der ganze Umriss als Sehnenzug –,
/// Seiten mit Rinne blau (M7-03, 4.3).
Anschlussergebnis anschlussergebnis(
  Planungsstand stand, {
  List<Anschlussmeldung> meldungen = const [],
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
        ...linien(stand.anschluss.verblendet, Seitenrolle.verblendung)
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
  );
}
