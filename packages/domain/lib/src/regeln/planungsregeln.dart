/// Planungsregeln von ALTO HOLZ, die nicht von der Holzart abhängen (M1-04,
/// Regelkatalog `docs/fachkonzept/14-planungsregeln.md`). Holzabhängige
/// Regeln stehen in der Holzart (M2-08).
library;

import '../artikel/einheiten.dart';

/// Abstand der Querstreben (Leiterverband) (R-C03, Alexander).
const querstrebenAbstand = Millimeter(600);

/// Fuge zwischen zwei Dielen (R-B06, Alexander).
const fuge = Millimeter(5);

/// Wandabstand der Terrasse (R-C10, Alexander 19.10.2026).
const wandabstand = Millimeter(20);

/// Ab dieser Anzahl Hauptdielen gibt es Freidielen (R-B09, B-079).
const freidielenAbDielen = 25;

/// Freidielen zur Anzahl der Hauptdielen des Deckbelags (R-B09, B-079,
/// Alexander 19.10.2026): ab 25 eine, ab 50 zwei, ab 100 je weitere 50 eine.
int freidielen(int hauptdielen) => hauptdielen < freidielenAbDielen
    ? 0
    : hauptdielen < 50
    ? 1
    : hauptdielen < 100
    ? 2
    : 2 + (hauptdielen - 50) ~/ 50;

/// Stärke aus Altdaten: „22 mm“ gibt es nicht, gemeint ist 21 mm (R-A04,
/// B-032).
Millimeter normierteStaerke(Millimeter staerke) =>
    staerke == const Millimeter(22) ? const Millimeter(21) : staerke;
