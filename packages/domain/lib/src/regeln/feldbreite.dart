/// Maximale Feldbreite (M6-09, Fachkonzept 3.10): der höchste Abstand der
/// UK-Hölzer (Achsabstand), über den eine Diele spannt.
library;

import '../artikel/einheiten.dart';
import '../holzart/holzart.dart';
import 'uk_zusatz.dart';

/// Feldbreiten zur Auswahl: die des alten Planers (40/50/60 cm) und die
/// sichereren unter 35 cm aus der Firmenregel (R-C01: höchstens 40 cm,
/// sicherer unter 35 cm). Wählbar sind nur die bis zur höchsten erlaubten
/// ([feldbreiten]).
const feldbreitenAuswahl = [
  Millimeter(300),
  Millimeter(350),
  Millimeter(400),
  Millimeter(500),
  Millimeter(600),
];

/// Höchste Feldbreite für einen Belag der [holzart] mit dem UK-Abstand
/// [artikel] laut Artikeldaten: der des Belags, höchstens der der Holzart
/// (R-C01, Robinie 40 cm, `ukAbstandFuer`).
Millimeter hoechsteFeldbreite(Holzart holzart, Millimeter? artikel) =>
    ukAbstandFuer(holzart, artikel);

/// Wählbare Feldbreiten bis zur [hoechste] (aufsteigend): Robinie 30, 35
/// und 40 cm – 50 und 60 cm des alten Planers verbietet die Firmenregel
/// (R-C01, Abnahme „Regel aus M1-04 umgesetzt“).
List<Millimeter> feldbreiten(Millimeter hoechste) => [
  for (final f in feldbreitenAuswahl)
    if (f <= hoechste) f,
];

/// Feldbreite, mit der gerechnet wird: die gewählte [gewaehlt], wenn sie die
/// [hoechste] nicht überschreitet; automatisch (`null`) oder darüber die
/// [hoechste].
Millimeter wirksameFeldbreite(Millimeter? gewaehlt, Millimeter hoechste) =>
    gewaehlt != null && gewaehlt <= hoechste ? gewaehlt : hoechste;
