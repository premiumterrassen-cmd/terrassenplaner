import '../sprache/sprache.dart';

/// Die sieben Schritte des Planers mit ihren nummerierten Unterpunkten
/// (Fachkonzept 00–07). Frei anklickbar, keine Pflichtreihenfolge. Die
/// Texte stehen in den Übersetzungsdateien (M3-07).
enum PlanerSchritt {
  grundriss,
  terrassenbelag,
  unterkonstruktion,
  terrassenanschluss,
  treppen,
  zubehoer,
  verschnittoptimierung;

  String titel(PlanerTexte t) => switch (this) {
    grundriss => t.schrittGrundriss,
    terrassenbelag => t.schrittTerrassenbelag,
    unterkonstruktion => t.schrittUnterkonstruktion,
    terrassenanschluss => t.schrittTerrassenanschluss,
    treppen => t.schrittTreppen,
    zubehoer => t.schrittZubehoer,
    verschnittoptimierung => t.schrittVerschnittoptimierung,
  };

  /// Titel für schmale Stationen: lange Wörter getrennt auf zwei Zeilen.
  String getrennterTitel(PlanerTexte t) => switch (this) {
    terrassenbelag => t.schrittTerrassenbelagGetrennt,
    unterkonstruktion => t.schrittUnterkonstruktionGetrennt,
    terrassenanschluss => t.schrittTerrassenanschlussGetrennt,
    verschnittoptimierung => t.schrittVerschnittoptimierungGetrennt,
    _ => titel(t),
  };

  List<String> unterpunkte(PlanerTexte t) => switch (this) {
    grundriss => [t.grundriss1, t.grundriss2, t.grundriss3, t.grundriss4],
    terrassenbelag => [
      t.terrassenbelag1,
      t.terrassenbelag2,
      t.terrassenbelag3,
      t.terrassenbelag4,
      t.terrassenbelag5,
    ],
    unterkonstruktion => [
      t.unterkonstruktion1,
      t.unterkonstruktion2,
      t.unterkonstruktion3,
      t.unterkonstruktion4,
      t.unterkonstruktion5,
      t.unterkonstruktion6,
      t.unterkonstruktion7,
      t.unterkonstruktion8,
    ],
    terrassenanschluss => [
      t.terrassenanschluss1,
      t.terrassenanschluss2,
      t.terrassenanschluss3,
    ],
    treppen => [t.treppen1],
    zubehoer => [
      t.zubehoer1,
      t.zubehoer2,
      t.zubehoer3,
      t.zubehoer4,
      t.zubehoer5,
      t.zubehoer6,
      t.zubehoer7,
      t.zubehoer8,
    ],
    verschnittoptimierung => [t.verschnittoptimierung1],
  };

  /// Nummer ab 1 („1. GRUNDRISS“).
  int get nummer => index + 1;

  /// Nummerierte Unterpunkte, z. B. „1.2 Terrassenmaße“.
  List<String> nummerierteUnterpunkte(PlanerTexte t) => [
    for (final (i, text) in unterpunkte(t).indexed) '$nummer.${i + 1} $text',
  ];
}
