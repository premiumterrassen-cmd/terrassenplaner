import 'package:connectanum_router/auth.dart';

import 'mitarbeiter_verzeichnis.dart';
import 'rollen.dart';

/// Liefert dem Auth-Server die SCRAM-Zugänge der Mitarbeiter im Planer-Realm.
class PlanerZugangsdaten extends AuthCredentialProvider {
  const PlanerZugangsdaten({required this.realm, required this.verzeichnis});

  final String realm;
  final MitarbeiterQuelle verzeichnis;

  @override
  Future<ScramCredential?> loadScram({
    required String realmUri,
    required String authId,
  }) async {
    if (realmUri != realm) return null;
    final zugang = verzeichnis.finde(authId);
    if (zugang == null) return null;
    return ScramCredential(
      storedKey: zugang.storedKey,
      serverKey: zugang.serverKey,
      salt: zugang.salt,
      iterations: zugang.iterationen,
      role: Rollen.mitarbeiter,
      provider: 'planer',
    );
  }
}
