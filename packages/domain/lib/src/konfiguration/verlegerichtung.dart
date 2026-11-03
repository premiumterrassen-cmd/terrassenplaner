/// Verlegerichtung des Belags (Fachkonzept 2.4, M5-05): Winkel der Dielen
/// in Grad gegen den Uhrzeigersinn zur x-Achse (Kante A–B des Rechtecks).
/// Abgleich mit dem alten Planer: 45° und 30° beginnen an A und laufen über
/// B hinaus nach oben (F03, F05), 135° läuft von A nach links oben (F04).
enum Verlegerichtung {
  /// Längs der x-Achse (Vorgabe).
  waagrecht(0, 0),

  /// Quer zur x-Achse.
  senkrecht(1, 90),
  diagonal45(2, 45),
  diagonal135(3, 135),

  /// Winkel aus dem Feld „Winkel“ (`Planungsstand.verlegewinkel`).
  individuell(4, null);

  const Verlegerichtung(this.nummer, this.winkel);

  /// Nummer im Transportformat (FlatBuffer des Planungsstands).
  final int nummer;

  /// Fester Winkel in Grad; `null` beim individuellen Winkel.
  final int? winkel;

  /// Vorgabe des Felds „Winkel“ (Fall F05).
  static const vorgabeWinkel = 30;

  /// Ob [grad] als individueller Winkel gilt: ganze Grad von 0 bis 179 –
  /// 180° ergäbe dieselbe Verlegung wie 0°.
  static bool winkelGueltig(int grad) => grad >= 0 && grad < 180;
}
