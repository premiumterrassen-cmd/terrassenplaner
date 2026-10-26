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

  static final _muster = RegExp(r'^(\d{4})-(\d{2})-(\d{2})-\d{4}$');
}

/// Eine bestimmte Version einer Konfiguration (ab 1).
final class KonfigurationsStand {
  KonfigurationsStand(this.nummer, this.version) {
    if (version < 1) {
      throw ArgumentError.value(version, 'version', 'ab 1');
    }
  }

  final Konfigurationsnummer nummer;
  final int version;

  @override
  bool operator ==(Object other) =>
      other is KonfigurationsStand &&
      other.nummer == nummer &&
      other.version == version;

  @override
  int get hashCode => Object.hash(nummer, version);

  @override
  String toString() => '${nummer.wert} v$version';
}
