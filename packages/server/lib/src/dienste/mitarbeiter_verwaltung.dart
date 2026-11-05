import 'package:connectanum_router/connectanum_router.dart';

import '../datenhaltung/mitarbeiterkonten.dart';
import '../zugriff/mitarbeiter_zugang.dart';

/// Verwaltung der Mitarbeiter-Konten (M9-10) als WAMP-Prozeduren im
/// Auth-Realm des Auth-Servers – erreichbar nur über dessen internen
/// Listener (Loopback bzw. internes Container-Netz) mit Ticket, genutzt vom
/// Kommandozeilenwerkzeug `bin/mitarbeiter.dart`. ObjectBox erlaubt einen
/// Prozess je Datenbank, deshalb schreibt nur der Auth-Server selbst.
///
/// - anlegen `[zugang]` / passwort `[zugang]` (Schlüssel als JSON, nie das
///   Passwort) → `[]`
/// - sperren / entsperren `[email]` → `[]`
/// - liste `[]` → `[[email, gesperrt], …]`
abstract final class MitarbeiterVerwaltung {
  static const uriBasis = 'verwaltung.mitarbeiter.';
  static const anlegen = '${uriBasis}anlegen';
  static const passwort = '${uriBasis}passwort';
  static const sperren = '${uriBasis}sperren';
  static const entsperren = '${uriBasis}entsperren';
  static const liste = '${uriBasis}liste';

  /// Fehler-URI: Konto unbekannt bzw. schon vorhanden, ungültige Angaben.
  static const fehler = '${uriBasis}fehler';

  /// Registriert die Prozeduren über die interne [sitzung] des Auth-Servers.
  static Future<void> registriere(
    RouterSession sitzung,
    Mitarbeiterkonten konten,
  ) async {
    for (final (prozedur, arbeit)
        in <(String, List<Object?> Function(List<Object?>))>[
          (anlegen, (a) => _mitZugang(a, konten.anlegen)),
          (passwort, (a) => _mitZugang(a, konten.setzePasswort)),
          (
            sperren,
            (a) => _mitEmail(a, (e) => konten.sperre(e, gesperrt: true)),
          ),
          (
            entsperren,
            (a) => _mitEmail(a, (e) => konten.sperre(e, gesperrt: false)),
          ),
          (
            liste,
            (_) => [
              for (final k in konten.liste()) [k.authId, k.gesperrt],
            ],
          ),
        ]) {
      (await sitzung.register(prozedur)).onInvoke((aufruf) {
        try {
          aufruf.respondWith(
            arguments: arbeit(aufruf.arguments ?? const <Object?>[]),
          );
        } on Object catch (f) {
          aufruf.respondWith(
            isError: true,
            errorUri: fehler,
            arguments: ['$f'],
          );
        }
      });
    }
  }

  static List<Object?> _mitZugang(
    List<Object?> argumente,
    void Function(MitarbeiterZugang zugang) arbeit,
  ) {
    final zugang = switch (argumente) {
      [final Map<Object?, Object?> json] => MitarbeiterZugang.ausJson(
        json.cast<String, Object?>(),
      ),
      _ => throw FormatException('unerwartete Argumente', argumente),
    };
    // Der Anmeldename muss genau so ankommen, wie die App ihn sendet.
    if (MitarbeiterZugang.email(zugang.authId) != zugang.authId) {
      throw ArgumentError.value(zugang.authId, 'authid', 'nicht normiert');
    }
    arbeit(zugang);
    return const [];
  }

  static List<Object?> _mitEmail(
    List<Object?> argumente,
    void Function(String email) arbeit,
  ) {
    switch (argumente) {
      case [final String email]:
        arbeit(MitarbeiterZugang.email(email));
      default:
        throw FormatException('unerwartete Argumente', argumente);
    }
    return const [];
  }
}
