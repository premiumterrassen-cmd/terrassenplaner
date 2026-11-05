import 'dart:convert';
import 'dart:math';

import 'package:connectanum_core/connectanum_core.dart';

/// SCRAM-Zugang eines Mitarbeiters – nur abgeleitete Schlüssel, nie das
/// Passwort (docs/architektur/datenmodell.md). Die Schlüssel entstehen im
/// Verwaltungswerkzeug (`bin/mitarbeiter.dart`); zum Auth-Server reisen nur
/// sie, das Passwort verlässt das Werkzeug nicht (M9-10).
///
/// Verfahren: SCRAM aus connectanum mit **Argon2id** (`argon2id13`) als
/// Schlüsselableitung – speicherhart, Empfehlung von OWASP und RFC 9106;
/// der Browser rechnet es im Web Worker von connectanum (hash-wasm).
class MitarbeiterZugang {
  const MitarbeiterZugang({
    required this.authId,
    required this.salt,
    required this.storedKey,
    required this.serverKey,
    this.kdf = ScramAuthentication.kdfArgon,
    this.iterationen = standardIterationen,
    this.speicher = standardSpeicher,
    this.gesperrt = false,
  });

  factory MitarbeiterZugang.ausJson(Map<String, Object?> json) =>
      MitarbeiterZugang(
        authId: json['authid']! as String,
        salt: json['salt']! as String,
        kdf: json['kdf']! as String,
        iterationen: json['iterationen']! as int,
        speicher: json['speicher']! as int,
        storedKey: json['stored_key']! as String,
        serverKey: json['server_key']! as String,
      );

  /// Leitet aus einem Passwort die SCRAM-Schlüssel ab (zufälliges Salt aus
  /// 16 Byte).
  static Future<MitarbeiterZugang> ableiten({
    required String authId,
    required String passwort,
    int iterationen = standardIterationen,
    int speicher = standardSpeicher,
    Random? zufall,
  }) async {
    final quelle = zufall ?? Random.secure();
    final salt = base64.encode(
      List<int>.generate(16, (_) => quelle.nextInt(256)),
    );
    final schluessel = await ScramAuthentication.deriveServerSecretsAsync(
      secret: passwort,
      salt: salt,
      kdf: ScramAuthentication.kdfArgon,
      iterations: iterationen,
      memory: speicher,
    );
    return MitarbeiterZugang(
      authId: authId,
      salt: salt,
      iterationen: iterationen,
      speicher: speicher,
      storedKey: schluessel.storedKey,
      serverKey: schluessel.serverKey,
    );
  }

  /// Argon2id nach OWASP (Password Storage Cheat Sheet): 19 MiB, 2 Durchläufe.
  static const standardIterationen = 2;
  static const standardSpeicher = 19456;

  /// E-Mail-Adresse als Anmeldename: ohne Leerraum am Rand, klein
  /// geschrieben, mit `@` und Punkt im Domänenteil.
  static String email(String text) {
    final wert = text.trim().toLowerCase();
    if (!_email.hasMatch(wert)) {
      throw ArgumentError.value(text, 'email', 'keine E-Mail-Adresse');
    }
    return wert;
  }

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  final String authId;
  final String salt;
  final String kdf;
  final int iterationen;
  final int speicher;
  final String storedKey;
  final String serverKey;
  final bool gesperrt;

  /// Schlüssel zum Übertragen an den Auth-Server (ohne Sperre – die setzt
  /// nur der Auth-Server).
  Map<String, Object?> alsJson() => {
    'authid': authId,
    'salt': salt,
    'kdf': kdf,
    'iterationen': iterationen,
    'speicher': speicher,
    'stored_key': storedKey,
    'server_key': serverKey,
  };
}
