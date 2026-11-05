/// Die acht Gruppen im Schritt „Zubehör“ (M8-01, Fachkonzept 06) in der
/// Reihenfolge des alten Planers. Welche Artikel in welche Gruppe gehören,
/// steht in der Spalte `Zubehoergruppe` der Upload-Datei (B-122).
enum Zubehoergruppe {
  /// Werkzeug und Montagehilfen; in den Daten Artikeltyp `Zubehoer` ohne
  /// eigene Gruppe.
  allgemein('Allgemein'),
  anlieferung('Anlieferung'),
  clipsSchrauben('Clips & Schrauben'),
  hoehenausgleich('Höhenausgleich'),
  padsEpdmBaender('Pads & EPDM Bänder'),

  /// Im alten Planer vorhanden, aber leer (Fachkonzept 09).
  rhombusleisten('Rhombusleisten'),
  terrassenfliesen('Terrassenfliesen'),
  terrassenoel('Terrassenöl RIBOL');

  const Zubehoergruppe(this.datenname);

  /// Eintrag der Spalte `Zubehoergruppe` der Upload-Datei.
  final String datenname;

  /// Gruppe zum Eintrag der Upload-Datei; `null`, wenn unbekannt.
  static Zubehoergruppe? lies(String text) {
    final t = text.trim();
    return values.where((g) => g.datenname == t).firstOrNull;
  }
}
