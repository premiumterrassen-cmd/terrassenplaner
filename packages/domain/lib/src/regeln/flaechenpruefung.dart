/// Plausibilität der Fläche in m² – Planungsregeln Alexander (Planungskern
/// v6, 11.11.2026) Regel 1.7. Die Grenzen der Seitenlängen bei der Eingabe
/// (`Grundriss.kleinsteSeite`, `Grundriss.groessteSeite`) bleiben daneben
/// bestehen.
library;

/// Meldung zur Größe einer Fläche. [fehler] = die Maße sind so nicht
/// brauchbar; sonst ein Hinweis in der Prüfliste.
enum Flaechenmeldung {
  /// Höchstens [kleinsteFlaeche] m²: „Maße fehlen oder sind falsch“.
  masseFalsch(fehler: true),

  /// Über [groessteFlaeche] m²: „unplausibel groß“.
  unplausibelGross(fehler: true),

  /// Außerhalb der üblichen [ueblicheFlaeche] m².
  ungewoehnlich(fehler: false);

  const Flaechenmeldung({required this.fehler});

  final bool fehler;
}

/// Bis hierher (m²) fehlen Maße oder sind falsch.
const kleinsteFlaeche = 0.05;

/// Über dieser Fläche (m²) ist die Eingabe unplausibel.
const groessteFlaeche = 1000;

/// Übliche Flächen in m²; außerhalb gibt es einen Hinweis.
const ueblicheFlaeche = (von: 1, bis: 300);

/// Meldung zur Fläche von [quadratmeter] m²; `null`, wenn sie im üblichen
/// Bereich liegt.
Flaechenmeldung? pruefeFlaeche(double quadratmeter) {
  if (quadratmeter <= kleinsteFlaeche) return Flaechenmeldung.masseFalsch;
  if (quadratmeter > groessteFlaeche) return Flaechenmeldung.unplausibelGross;
  if (quadratmeter < ueblicheFlaeche.von ||
      quadratmeter > ueblicheFlaeche.bis) {
    return Flaechenmeldung.ungewoehnlich;
  }
  return null;
}
