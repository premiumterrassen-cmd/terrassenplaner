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

  /// Belagauswahl (M5-01): alle Beläge in Datenreihenfolge mit Preisen je
  /// lfm und je m²; der erste ist die Vorgabe.
  static const belagAuswahl = '${kunde}belag.auswahl';

  /// 3D-Modell (M3-10): GLB einer Rechteck-Terrasse (Prototyp).
  static const modell3dRechteck = '${kunde}modell3d.rechteck';

  /// Planungsdienst (M4-02): berechnet aus einem Planungsstand Umriss und
  /// Kennzahlen; beides als typisierte FlatBuffers (Packed PPT, #110).
  static const planungBerechnen = '${kunde}planung.berechnen';

  /// Fehler-URI für ungültige Maße.
  static const masseUngueltig = '${kunde}fehler.masse_ungueltig';

  /// Fehler-URI für einen Planungsstand, der sich nicht lesen oder nicht
  /// berechnen lässt (z. B. Maße außerhalb der Grenzen).
  static const planungUngueltig = '${kunde}fehler.planung_ungueltig';

  /// Fehler-URI für unbekannte Artikelnummern.
  static const artikelUnbekannt = '${kunde}fehler.artikel_unbekannt';

  /// Fehler-URI für Filter mit unbekannten Werten.
  static const artikelFilterUngueltig = '${kunde}fehler.filter_ungueltig';

  /// Payload-Passthrough (PPT) für typisierte FlatBuffers-Nutzlasten (#110):
  /// eigenes Anwendungsschema (`x_`-Präfix nach WAMP-Spezifikation).
  static const pptSchema = 'x_terrassenplaner';
  static const pptSerializer = 'flatbuffers';
}
