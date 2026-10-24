/// Namen im WAMP-Realm des Planers – gemeinsam für App und Server.
abstract final class WampNamen {
  static const realm = 'de.robinienwelt.terrassenplaner';
  static const basis = '$realm.';
  static const kunde = '${basis}kunde.';
  static const mitarbeiter = '${basis}mitarbeiter.';

  /// Hallo-Welt-Prozedur (M0-12): prüft die Verbindung App → Router → Dienst.
  static const hallo = '${kunde}hallo';

  /// Artikeldienst (M2-06): Versionskennung, Artikel je Filter, Regeln je
  /// Artikel; Ereignis mit der neuen Version, wenn Artikeldaten wechseln.
  static const artikelVersion = '${kunde}artikel.version';
  static const artikelListe = '${kunde}artikel.liste';
  static const artikelRegeln = '${kunde}artikel.regeln';
  static const artikelGeaendert = '${kunde}artikel.geaendert';

  /// Fehler-URI für unbekannte Artikelnummern.
  static const artikelUnbekannt = '${kunde}fehler.artikel_unbekannt';

  /// Fehler-URI für Filter mit unbekannten Werten.
  static const artikelFilterUngueltig = '${kunde}fehler.filter_ungueltig';

  /// Payload-Passthrough (PPT) für typisierte FlatBuffers-Nutzlasten (#110):
  /// eigenes Anwendungsschema (`x_`-Präfix nach WAMP-Spezifikation).
  static const pptSchema = 'x_terrassenplaner';
  static const pptSerializer = 'flatbuffers';
}
