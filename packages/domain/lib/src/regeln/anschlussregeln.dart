/// Regeln des Terrassenanschlusses (Fachkonzept 04, M7): welche Seite
/// welche Rolle hat und was daraus für Zeichnung und Material folgt.
library;

import '../geometrie/punkt.dart';
import '../konfiguration/anschlussergebnis.dart';
import '../konfiguration/planungsstand.dart';

/// Strecke der Seite [seite] von ihrer Ecke zur nächsten in mm – gerade von
/// Eckpunkt zu Eckpunkt wie die Seitenlänge der Beschriftung.
({Punkt von, Punkt bis}) seitenstrecke(Planungsstand stand, int seite) {
  final ecken = stand.grundriss.ecken;
  return (von: ecken[seite], bis: ecken[(seite + 1) % ecken.length]);
}

/// Anschluss der bearbeiteten Fläche (M7): angrenzende Seiten grau
/// (M7-01, 4.1).
Anschlussergebnis anschlussergebnis(Planungsstand stand) => Anschlussergebnis(
  seiten: [
    for (final seite in stand.anschluss.angrenzend)
      if (seitenstrecke(stand, seite) case (:final von, :final bis))
        (seite: seite, rolle: Seitenrolle.bauelement, von: von, bis: bis),
  ],
);
