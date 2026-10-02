import 'dart:convert';
import 'dart:math';

import 'package:connectanum_core/connectanum_core.dart';

/// Gespeicherter SCRAM-Zugang eines Mitarbeiters – nur abgeleitete Schlüssel,
/// nie das Passwort (docs/architektur/datenmodell.md).
class MitarbeiterZugang {
  const MitarbeiterZugang({
    required this.authId,
    required this.salt,
    required this.iterationen,
    required this.storedKey,
    required this.serverKey,
  });

  factory MitarbeiterZugang.ausJson(Map<String, Object?> json) =>
      MitarbeiterZugang(
        authId: json['authid']! as String,
        salt: json['salt']! as String,
        iterationen: json['iterationen']! as int,
        storedKey: json['stored_key']! as String,
        serverKey: json['server_key']! as String,
      );

  /// Leitet aus einem Passwort die SCRAM-Schlüssel ab (PBKDF2, zufälliges Salt).
  static Future<MitarbeiterZugang> ableiten({
    required String authId,
    required String passwort,
    int iterationen = standardIterationen,
    Random? zufall,
  }) async {
    final quelle = zufall ?? Random.secure();
    final salt = base64.encode(
      List<int>.generate(16, (_) => quelle.nextInt(256)),
    );
    final schluessel = await ScramAuthentication.deriveServerSecretsAsync(
      secret: passwort,
      salt: salt,
      iterations: iterationen,
    );
    return MitarbeiterZugang(
      authId: authId,
      salt: salt,
      iterationen: iterationen,
      storedKey: schluessel.storedKey,
      serverKey: schluessel.serverKey,
    );
  }

  static const standardIterationen = 100000;

  final String authId;
  final String salt;
  final int iterationen;
  final String storedKey;
  final String serverKey;

  Map<String, Object?> alsJson() => {
    'authid': authId,
    'salt': salt,
    'iterationen': iterationen,
    'stored_key': storedKey,
    'server_key': serverKey,
  };
}
