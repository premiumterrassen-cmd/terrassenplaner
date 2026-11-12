/// Plausibilität der Kanten – Planungsregeln Alexander (Planungskern v7,
/// 11.11.2026) Regel 9.6: Kanten unter 10 cm oder über 30 m sind
/// vermutlich Eingabefehler und kommen als Warnung in die Prüfliste. Die
/// Grenzen der Seitenlängen bei der Eingabe (`Grundriss.kleinsteSeite`,
/// `Grundriss.groessteSeite`) bleiben daneben bestehen; diese Prüfung
/// erfasst auch Kanten, die sich erst ergeben (Freiform, Diagonalen).
library;

import '../artikel/einheiten.dart';
import '../geometrie/eckbuchstaben.dart';
import '../geometrie/punkt.dart';

/// Art der Warnung zu einer Kante.
enum Kantenmeldung {
  /// Kürzer als [kuerzesteKante].
  zuKurz,

  /// Länger als [laengsteKante].
  zuLang,
}

/// Kanten unter dieser Länge sind unplausibel (10 cm).
const kuerzesteKante = Millimeter(100);

/// Kanten über dieser Länge sind unplausibel (30 m).
const laengsteKante = Millimeter(30000);

/// Eine Maßeingabe über dieser Grenze (50 m) war vermutlich in mm statt in
/// cm gemeint: sie wird nicht angewendet, die App bittet um cm (Regel 9.6).
const groesstesEingabemass = Millimeter(50000);

/// Warnung zu einer Kante: Name von Ecke zu Ecke („A–B“), Länge und Art.
typedef Kantenwarnung = ({String kante, Millimeter laenge, Kantenmeldung art});

/// Warnungen zu den Kanten zwischen den benannten [ecken]
/// (`eckenBenennen`); geschlossen auch die Kante von der letzten zur
/// ersten Ecke. Gerundet auf ganze mm.
List<Kantenwarnung> pruefeKanten(List<Punkt> ecken, {bool geschlossen = true}) {
  final namen = eckenBenennen(ecken, geschlossen: geschlossen);
  final kanten = geschlossen && ecken.length > 2
      ? ecken.length
      : ecken.length - 1;
  final warnungen = <Kantenwarnung>[];
  for (var i = 0; i < kanten; i++) {
    final j = (i + 1) % ecken.length;
    final laenge = Millimeter(ecken[i].abstand(ecken[j]).round());
    if (_warnung(laenge) case final art?) {
      warnungen.add((
        kante: '${namen[i]}–${namen[j]}',
        laenge: laenge,
        art: art,
      ));
    }
  }
  return warnungen;
}

Kantenmeldung? _warnung(Millimeter laenge) {
  if (laenge < kuerzesteKante) return Kantenmeldung.zuKurz;
  if (laenge > laengsteKante) return Kantenmeldung.zuLang;
  return null;
}
