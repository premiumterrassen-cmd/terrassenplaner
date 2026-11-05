/// „Art der Terrassennutzung“ (Fachkonzept 3.6, M6-05): wie die
/// Unterkonstruktion zusammengehalten wird. Nur bei der normalen Terrasse
/// wählbar (`Terrassenart.mitNutzungsart`, M6-01); bei Hochterrasse und
/// vorhandener UK entfällt der Unterpunkt.
enum Nutzungsart {
  /// Schwimmende Verlegung (Vorgabe wie im alten Planer, F01): UK-Linien
  /// lose auf den Auflagen, ohne Bodenbefestigung.
  schwimmend(0),

  /// Versteifung ohne Rahmen (F31): Leiterverband aus Querstreben zwischen
  /// den UK-Hölzern.
  versteifungOhneRahmen(1),

  /// Rahmen (F32): je ein UK-Holz quer über die Enden der UK-Linien.
  rahmen(2),

  /// Versteifung mit Rahmen (F33): Rahmen und Leiterverband.
  versteifungMitRahmen(3),

  /// Doppelte Unterkonstruktion (F34): eine zweite Lage UK-Hölzer quer
  /// unter der ersten (Lattenkreuz).
  doppelteUk(4);

  const Nutzungsart(this.nummer);

  /// Nummer im Transportformat (Planungsstand).
  final int nummer;

  /// Ob ein Rahmen um die UK läuft.
  bool get mitRahmen => this == rahmen || this == versteifungMitRahmen;

  /// Ob Querstreben die UK versteifen (Leiterverband, R-C03).
  bool get versteift =>
      this == versteifungOhneRahmen || this == versteifungMitRahmen;

  /// Ob die schwimmend verlegte UK ohne Bodenbefestigung und ohne
  /// Versteifung sich verwinden kann – dann erscheint die Warnung.
  bool get verwindungsgefahr => this == schwimmend;

  /// Art zur [nummer] aus dem Transportformat.
  static Nutzungsart ausNummer(int nummer) => values.firstWhere(
    (a) => a.nummer == nummer,
    orElse: () => throw FormatException('unbekannte Nutzungsart $nummer'),
  );
}
