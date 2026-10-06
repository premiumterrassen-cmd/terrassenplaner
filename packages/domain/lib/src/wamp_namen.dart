/// Namen im WAMP-Realm des Planers – gemeinsam für App und Server.
abstract final class WampNamen {
  static const realm = 'de.robinienwelt.terrassenplaner';
  static const basis = '$realm.';
  static const kunde = '${basis}kunde.';
  static const mitarbeiter = '${basis}mitarbeiter.';

  /// Hallo-Welt-Prozedur (M0-12): prüft die Verbindung App → Router → Dienst.
  static const hallo = '${kunde}hallo';
}
