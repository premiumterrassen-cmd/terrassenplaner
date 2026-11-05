import 'package:connectanum_router/auth.dart';

import '../datenhaltung/mitarbeiterkonten.dart';
import 'rollen.dart';

/// Liefert dem Auth-Server die SCRAM-Zugänge der Mitarbeiter im Planer-Realm.
/// Gesperrte Konten gelten als unbekannt – der Auth-Server antwortet dann
/// mit einer Schein-Herausforderung, die Anmeldung scheitert wie bei einem
/// falschen Passwort (M9-10).
class PlanerZugangsdaten extends AuthCredentialProvider {
  const PlanerZugangsdaten({required this.realm, required this.konten});

  final String realm;
  final Mitarbeiterkonten konten;

  @override
  Future<ScramCredential?> loadScram({
    required String realmUri,
    required String authId,
  }) async {
    if (realmUri != realm) return null;
    final zugang = konten.finde(authId);
    if (zugang == null || zugang.gesperrt) return null;
    return ScramCredential(
      storedKey: zugang.storedKey,
      serverKey: zugang.serverKey,
      salt: zugang.salt,
      kdf: zugang.kdf,
      iterations: zugang.iterationen,
      memory: zugang.speicher,
      role: Rollen.mitarbeiter,
      provider: 'planer',
    );
  }
}
