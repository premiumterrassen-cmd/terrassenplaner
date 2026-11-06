/// „Auflagen“ der Unterkonstruktion (Fachkonzept 3.9, M6-08): worauf die
/// UK-Hölzer liegen.
enum Auflagen {
  /// Nur Stelzfüße (Justierkeile, Terrassenfüße) – ohne Pads.
  stelzfuesse(0),

  /// Stelzfüße und Pads (Vorgabe): niedrige Auflager bekommen Pads unter
  /// der UK, wie der alte Planer in F01 (Gummi unter der UK, R-C04).
  stelzfuesseUndPads(1);

  const Auflagen(this.nummer);

  /// Nummer im Transportformat (Planungsstand).
  final int nummer;

  /// Ob Pads (Unterlegpads der UK) als Auflager gelten.
  bool get mitPads => this == stelzfuesseUndPads;

  /// Auflagen zur [nummer] aus dem Transportformat.
  static Auflagen ausNummer(int nummer) => values.firstWhere(
    (a) => a.nummer == nummer,
    orElse: () => throw FormatException('unbekannte Auflagen $nummer'),
  );
}
