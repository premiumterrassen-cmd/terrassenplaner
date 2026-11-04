import 'package:flutter/foundation.dart';

/// E-Mail-Adresse oder Passwort falsch, Konto gesperrt oder nach
/// Fehlversuchen vorübergehend gesperrt – der Server sagt bewusst nicht,
/// was davon (M9-10).
final class AnmeldungAbgelehnt implements Exception {
  const AnmeldungAbgelehnt();

  @override
  String toString() => 'Anmeldung abgelehnt';
}

/// ANMELDEN für Mitarbeiter (M9-10, Fachkonzept 08): Nach der Anmeldung
/// laufen die Aufrufe der App über eine WAMP-Sitzung mit der Rolle
/// `mitarbeiter`. Das Passwort dient nur dem Anmelden und wird weder
/// gespeichert noch gehalten; Kunden bleiben anonym.
abstract interface class MitarbeiterAnmeldung {
  /// E-Mail-Adresse des angemeldeten Mitarbeiters oder `null`.
  ValueListenable<String?> get angemeldetAls;

  /// Meldet an; abgelehnt: [AnmeldungAbgelehnt], andere Fehler (Server
  /// nicht erreichbar) werden durchgereicht.
  Future<void> anmelden(String email, String passwort);

  /// Meldet ab; danach ist die App wieder anonym.
  Future<void> abmelden();
}

/// E-Mail-Adresse so, wie sie als Anmeldename gilt: ohne Leerraum am Rand,
/// klein geschrieben (wie im Verwaltungswerkzeug des Servers).
String anmeldename(String email) => email.trim().toLowerCase();
