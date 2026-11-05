/// Freidielen der ganzen Planung (M8-04, R-B09): feste Regel im Planer
/// (B-228, früher B-079) – eine eigene Position mit Preis 0, nicht im
/// Warenkorb-Link.
library;

import '../artikel/artikel.dart';
import '../konfiguration/berechnung.dart';
import 'planungsregeln.dart';

/// Freidielen zur [dielenliste] der ganzen Planung (M8-04): Hauptdiele ist
/// der Belag mit den meisten Dielen – nur Dielen, keine Holzfliesen
/// ([istDiele]); gezählt werden alle seine Dielen (Anfangs- und Enddielen
/// sind normale Dielen, B-033) und die Staffel aus [freidielen] (R-B09).
/// Geliefert werden sie in der längsten Lieferlänge, die die Planung von
/// der Hauptdiele braucht (B-228 „der längsten Länge“; wie im alten
/// Planer, F13: 4000 mm bei fester Länge 400 cm). Bei gleich vielen Dielen
/// zählt der zuerst geplante Belag. `null` unter 25 Dielen.
Lieferposition? freidielenposition(
  List<Lieferposition> dielenliste, {
  required bool Function(Artikelnummer) istDiele,
}) {
  final anzahl = <Artikelnummer, int>{};
  final laengste = <Artikelnummer, Lieferposition>{};
  for (final p in dielenliste) {
    if (!istDiele(p.belag)) continue;
    anzahl.update(p.belag, (n) => n + p.anzahl, ifAbsent: () => p.anzahl);
    laengste.update(
      p.belag,
      (l) => p.laenge > l.laenge ? p : l,
      ifAbsent: () => p,
    );
  }
  if (anzahl.isEmpty) return null;
  final haupt = anzahl.entries.reduce((a, b) => b.value > a.value ? b : a);
  final frei = freidielen(haupt.value);
  if (frei == 0) return null;
  return (belag: haupt.key, laenge: laengste[haupt.key]!.laenge, anzahl: frei);
}
