import '../artikel/einheiten.dart';

/// Art der Terrasse (Fachkonzept 3.1, M6-01) mit ihrer Vorgabehöhe – der
/// Höhe von Oberkante Belag bis Boden, die der alte Planer beim Wechsel der
/// Art einsetzt (F01, F28, F29) – und ihren Auswirkungen auf die folgenden
/// Schritte.
enum Terrassenart {
  /// Normale Terrasse (Vorgabe), 8,6 cm.
  normal(0, Millimeter(86)),

  /// Hochterrasse, 54,2 cm: doppelte Unterkonstruktion (Lattenkreuz) auf
  /// Stützen und Bodenankern.
  hochterrasse(1, Millimeter(542)),

  /// Vorhandene Unterkonstruktion, 14,2 cm: die neue UK wird auf die
  /// vorhandene gebaut – UK-Holz und Bodenanker bleiben (R-C06), dazu das
  /// Feld „Spannweite“.
  vorhandeneUk(2, Millimeter(142));

  const Terrassenart(this.nummer, this.vorgabehoehe);

  /// Nummer im Transportformat (Planungsstand).
  final int nummer;

  /// Höhe von Oberkante Belag bis Boden, solange keine eingegeben ist.
  final Millimeter vorgabehoehe;

  /// Ob es den Unterpunkt „Art der Terrassennutzung“ (3.6) gibt: bei
  /// Hochterrasse und vorhandener UK entfällt er (F28, F29).
  bool get mitNutzungsart => this == normal;

  /// Ob das Feld „Spannweite der Unterkonstruktion“ gefragt wird: der
  /// Abstand der vorhandenen Träger (F29).
  bool get mitSpannweite => this == vorhandeneUk;

  /// Lagen der gewählten UK übereinander für die Aufbauhöhe (M6-02): bei
  /// der Hochterrasse zwei (Lattenkreuz), sonst eine – die vorhandene UK
  /// gehört nicht zur geplanten Konstruktion.
  int get ukLagen => this == hochterrasse ? 2 : 1;

  /// Vorgabe der Spannweite (F29: 80 cm).
  static const vorgabeSpannweite = Millimeter(800);

  /// Ob [spannweite] gilt: 10 bis 300 cm.
  static bool spannweiteGueltig(Millimeter spannweite) =>
      spannweite >= const Millimeter(100) &&
      spannweite <= const Millimeter(3000);

  /// Art zur [nummer] aus dem Transportformat.
  static Terrassenart ausNummer(int nummer) => values.firstWhere(
    (a) => a.nummer == nummer,
    orElse: () => throw FormatException('unbekannte Terrassenart $nummer'),
  );
}
