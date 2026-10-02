import 'dart:convert';
import 'dart:math';

import 'package:connectanum_auth_server/connectanum_auth_server.dart';
import 'package:connectanum_router/auth.dart';
import 'package:connectanum_router/connectanum_router.dart';

import '../zugriff/mitarbeiter_verzeichnis.dart';
import '../zugriff/planer_zugangsdaten.dart';
import '../zugriff/rollen.dart';
import 'router_einstellungen.dart';

/// Laufender WAMP-Router des Terrassenplaners (connectanum_router) mit
/// Auth-Server (connectanum_auth_server) im selben Prozess.
class PlanerRouter {
  PlanerRouter._(
    this.einstellungen,
    this._runtime,
    this._binding,
    this._healthIndex,
  );

  /// Startet native Transportschicht, Router und Auth-Server.
  static Future<PlanerRouter> starte(
    RouterEinstellungen einstellungen, {
    MitarbeiterVerzeichnis? mitarbeiter,
  }) async {
    AuthCredentialRegistry.registerProvider(
      PlanerZugangsdaten(
        realm: einstellungen.realm,
        verzeichnis: mitarbeiter ?? MitarbeiterVerzeichnis.leer(),
      ),
    );
    final authToken = _zufallsToken();
    final dienstTicket = _zufallsToken();
    final runtime = NativeTransportRuntime()..start();
    final settings = einstellungen.alsRouterSettings(
      authToken: authToken,
      dienstTicket: dienstTicket,
    );
    final binding = Router(
      RouterConfig(
        endpoints: settings.listeners
            .map(Endpoint.fromListenerSettings)
            .toList(growable: false),
      ),
      settings: settings,
    ).start(runtime);

    final authSitzung = await binding.createInternalSession(
      realmUri: RouterEinstellungen.authRealm,
      authId: RouterEinstellungen.authServerSitzung,
      authRole: RouterEinstellungen.authDienstRolle,
    );
    await AuthServerProcedureBinding.bind(
      server: AuthServer(
        settings: einstellungen.alsAuthServerSettings(),
        authTokens: [authToken],
        fakeChallengeOnHelloFailure: true,
      ),
      session: authSitzung,
    );
    // Der Health-Endpunkt hängt am Listener mit der Health-Adresse (eigener
    // HTTP-Listener oder – bei gleicher Adresse – am WebSocket-Listener).
    final healthIndex = settings.listeners.indexWhere(
      (l) => l.endpoint.trim() == einstellungen.healthListen.trim(),
    );
    return PlanerRouter._(einstellungen, runtime, binding, healthIndex);
  }

  final RouterEinstellungen einstellungen;

  final NativeTransportRuntime _runtime;
  final RouterBinding _binding;
  final int _healthIndex;

  /// Tatsächlich gebundener Port des WebSocket-Listeners.
  int get webSocketPort => _binding.listeners.first.port;

  /// Tatsächlich gebundener Port des Health-Listeners.
  int get healthPort => _binding.listeners[_healthIndex].port;

  /// Interne Sitzung für einen Backend-Dienst (Rolle `dienst`), ohne
  /// Netzwerk-Anmeldung.
  Future<RouterSession> dienstSitzung(String dienstName) =>
      _binding.createInternalSession(
        realmUri: einstellungen.realm,
        authId: dienstName,
        authRole: Rollen.dienst,
      );

  /// Beendet Sitzungen geordnet und gibt Transportschicht und Registrierungen frei.
  Future<void> stoppe() async {
    await _binding.dispose();
    _runtime
      ..shutdown()
      ..dispose();
    AuthCredentialRegistry.reset();
  }

  static String _zufallsToken() {
    final zufall = Random.secure();
    return base64Url.encode(List<int>.generate(32, (_) => zufall.nextInt(256)));
  }
}
