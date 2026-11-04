import 'dart:math';

import 'konfigurationsnummer.dart';

/// Prüfcode einer Konfiguration (M9-05b, Alexander 04.11.2026): fünf
/// zufällige Zeichen aus [alphabet], damit niemand fremde Konfigurationen
/// über die fortlaufende Nummer errät. Gilt für alle Versionen einer Nummer.
extension type const Pruefcode(String wert) implements Object {
  /// Prüft Länge und Zeichen; Kleinbuchstaben und Leerraum am Rand sind
  /// erlaubt.
  factory Pruefcode.pruefe(String text) {
    final wert = text.trim().toUpperCase();
    if (!_muster.hasMatch(wert)) {
      throw ArgumentError.value(text, 'pruefcode', 'kein Prüfcode');
    }
    return Pruefcode(wert);
  }

  /// Neuer Prüfcode aus [zufall] – im Server `Random.secure()`.
  factory Pruefcode.zufaellig(Random zufall) => Pruefcode(
    String.fromCharCodes([
      for (var i = 0; i < laenge; i++)
        alphabet.codeUnitAt(zufall.nextInt(alphabet.length)),
    ]),
  );

  /// Großbuchstaben und Ziffern ohne die verwechselbaren 0, O, 1, I und L.
  static const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  static const laenge = 5;

  /// Vergleich in konstanter Zeit: die Dauer verrät nicht, wie viele
  /// Zeichen übereinstimmen. Die Länge ist kein Geheimnis.
  bool gleicht(Pruefcode anderer) {
    final a = wert.codeUnits;
    final b = anderer.wert.codeUnits;
    if (a.length != b.length) return false;
    var unterschied = 0;
    for (var i = 0; i < a.length; i++) {
      unterschied |= a[i] ^ b[i];
    }
    return unterschied == 0;
  }

  static final _muster = RegExp('^[$alphabet]{$laenge}\$');
}

/// Kennung einer gespeicherten Konfiguration: Konfigurationsnummer und
/// Prüfcode, angezeigt und eingegeben als `JJJJ-MM-TT-NNNN-XXXXX`
/// (M9-05b). Laden verlangt beides.
final class Konfigurationskennung {
  const Konfigurationskennung(this.nummer, this.pruefcode);

  /// Liest eine eingegebene Kennung tolerant: Kleinbuchstaben, Leerzeichen
  /// und Trenner (`-`, `–`, `_`, `.`, `/`) dürfen fehlen oder zusätzlich
  /// stehen. Fehler in der Nummer melden `text`; ist die Nummer lesbar,
  /// aber der Prüfcode fehlt oder ist falsch geschrieben:
  /// [PruefcodeUngueltig].
  factory Konfigurationskennung.lies(String text) {
    final teile = _muster.firstMatch(
      text.toUpperCase().replaceAll(_trenner, ''),
    );
    if (teile == null) {
      throw ArgumentError.value(text, 'text', 'Format JJJJ-MM-TT-NNNN-XXXXX');
    }
    final nummer = Konfigurationsnummer.pruefe(
      [
        for (final i in [1, 2, 3, 4]) teile.group(i),
      ].join('-'),
    );
    final code = teile.group(5)!;
    if (code.isEmpty) throw PruefcodeUngueltig(nummer, text, 'Prüfcode fehlt');
    try {
      return Konfigurationskennung(nummer, Pruefcode.pruefe(code));
    } on ArgumentError {
      throw PruefcodeUngueltig(nummer, code, 'kein Prüfcode');
    }
  }

  final Konfigurationsnummer nummer;
  final Pruefcode pruefcode;

  /// `JJJJ-MM-TT-NNNN-XXXXX`.
  String get wert => '${nummer.wert}-${pruefcode.wert}';

  @override
  bool operator ==(Object other) =>
      other is Konfigurationskennung &&
      other.nummer == nummer &&
      other.pruefcode == pruefcode;

  @override
  int get hashCode => Object.hash(nummer, pruefcode);

  @override
  String toString() => wert;

  static final _trenner = RegExp(r'[\s\-–—_./]');
  static final _muster = RegExp(r'^(\d{4})(\d{2})(\d{2})(\d{4})(.*)$');
}

/// Eine Kennung mit lesbarer [nummer], deren Prüfcode fehlt oder falsch
/// geschrieben ist. App und Server behandeln sie wie eine unbekannte
/// Konfiguration – ohne Auskunft, ob es die Nummer gibt.
final class PruefcodeUngueltig extends ArgumentError {
  PruefcodeUngueltig(this.nummer, Object? wert, String meldung)
    : super.value(wert, 'pruefcode', meldung);

  final Konfigurationsnummer nummer;
}
