import 'package:connectanum_auth_server/connectanum_auth_server.dart';
import 'package:connectanum_router/auth.dart';

import '../zugriff/mitarbeiter_verzeichnis.dart';
import '../zugriff/planer_zugangsdaten.dart';
import 'auth_server_einstellungen.dart';
import 'router_laufzeit.dart';

/// Laufender Auth-Server: eigener Router mit Auth-Realm, an dem
/// connectanum_auth_server `authenticate.*` über eine interne Sitzung anbietet.
class AuthServerProzess {
  AuthServerProzess._(this.einstellungen, this._laufzeit);

  static Future<AuthServerProzess> starte(
    AuthServerEinstellungen einstellungen, {
    MitarbeiterQuelle? mitarbeiter,
  }) async {
    AuthCredentialRegistry.registerProvider(
      PlanerZugangsdaten(
        realm: einstellungen.planerRealm,
        verzeichnis: mitarbeiter ?? MitarbeiterVerzeichnis.leer(),
      ),
    );
    final laufzeit = RouterLaufzeit.starte(
      einstellungen.alsRouterSettings(),
      einstellungen.healthListen,
    );
    final sitzung = await laufzeit.binding.createInternalSession(
      realmUri: AuthServerEinstellungen.authRealm,
      authId: AuthServerEinstellungen.sitzungId,
      authRole: AuthServerEinstellungen.sitzungRolle,
    );
    await AuthServerProcedureBinding.bind(
      server: AuthServer(
        settings: einstellungen.alsAuthServerSettings(),
        authTokens: [einstellungen.authToken],
        fakeChallengeOnHelloFailure: true,
      ),
      session: sitzung,
    );
    return AuthServerProzess._(einstellungen, laufzeit);
  }

  final AuthServerEinstellungen einstellungen;
  final RouterLaufzeit _laufzeit;

  /// Tatsächlich gebundener Port des RawSocket-Listeners.
  int get port => _laufzeit.hauptPort;

  int get healthPort => _laufzeit.healthPort;

  Future<void> stoppe() async {
    await _laufzeit.stoppe();
    AuthCredentialRegistry.reset();
  }
}
