import 'konfigurationskennung.dart';

/// Konfigurationsnummer `JJJJ-MM-TT-NNNN` (Fachkonzept 08, Datenmodell),
/// z. B. `2026-10-08-1511`.
extension type const Konfigurationsnummer(String wert) implements Object {
  /// Prüft Format und Datum; Leerraum am Rand wird entfernt.
  factory Konfigurationsnummer.pruefe(String text) {
    final wert = text.trim();
    final teile = _muster.firstMatch(wert);
    if (teile == null) {
      throw ArgumentError.value(text, 'text', 'Format JJJJ-MM-TT-NNNN');
    }
    final [jahr, monat, tag] = [
      for (final i in [1, 2, 3]) int.parse(teile.group(i)!),
    ];
    final datum = DateTime.utc(jahr, monat, tag);
    if (datum.month != monat || datum.day != tag) {
      throw ArgumentError.value(text, 'text', 'kein gültiges Datum');
    }
    return Konfigurationsnummer(wert);
  }

  /// Nummer [laufend] (1 … [hoechsteLaufende]) des Kalendertags von [zeit]
  /// (M9-05): der Konfigurationsdienst zählt je Tag ab 1.
  factory Konfigurationsnummer.vergib(DateTime zeit, int laufend) {
    RangeError.checkValueInInterval(laufend, 1, hoechsteLaufende, 'laufend');
    return Konfigurationsnummer(
      '${tagAus(zeit)}-${laufend.toString().padLeft(4, '0')}',
    );
  }

  /// Kalendertag `JJJJ-MM-TT` von [zeit] – der Teil vor der laufenden Nummer.
  static String tagAus(DateTime zeit) =>
      '${zeit.year.toString().padLeft(4, '0')}-'
      '${zeit.month.toString().padLeft(2, '0')}-'
      '${zeit.day.toString().padLeft(2, '0')}';

  /// Mehr als vierstellig geht nicht (Format `NNNN`).
  static const hoechsteLaufende = 9999;

  /// Kalendertag `JJJJ-MM-TT` der Nummer.
  String get tag => wert.substring(0, 10);

  /// Laufende Nummer des Tages (`NNNN`).
  int get laufend => int.parse(wert.substring(11));

  static final _muster = RegExp(r'^(\d{4})-(\d{2})-(\d{2})-\d{4}$');
}

/// Eine bestimmte Version einer gespeicherten Konfiguration (ab 1), mit
/// der Kennung aus Nummer und Prüfcode (M9-05b).
final class KonfigurationsStand {
  KonfigurationsStand(this.kennung, this.version) {
    if (version < 1) {
      throw ArgumentError.value(version, 'version', 'ab 1');
    }
  }

  final Konfigurationskennung kennung;
  final int version;

  Konfigurationsnummer get nummer => kennung.nummer;

  @override
  bool operator ==(Object other) =>
      other is KonfigurationsStand &&
      other.kennung == kennung &&
      other.version == version;

  @override
  int get hashCode => Object.hash(kennung, version);

  @override
  String toString() => '${kennung.wert} v$version';
}
