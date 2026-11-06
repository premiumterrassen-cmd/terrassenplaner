/// „Auf welchem Untergrund wird die Terrasse aufgebaut?“ (Fachkonzept 3.5,
/// M6-04). Nur eine Information für die Planer, damit sie dem Kunden die
/// richtigen Unterbauhinweise geben – ohne Wirkung auf die Berechnung
/// (R-C07, Alexander Frage 6).
enum Untergrund {
  /// Schotter (verdichtet) – Vorgabe wie im alten Planer (F01).
  schotter(0),

  /// Beton.
  beton(1),

  /// Bitumenabdichtung.
  bitumen(2);

  const Untergrund(this.nummer);

  /// Nummer im Transportformat (Planungsstand).
  final int nummer;

  /// Untergrund zur [nummer] aus dem Transportformat.
  static Untergrund ausNummer(int nummer) => values.firstWhere(
    (u) => u.nummer == nummer,
    orElse: () => throw FormatException('unbekannter Untergrund $nummer'),
  );
}
