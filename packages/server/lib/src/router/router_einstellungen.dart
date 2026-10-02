import 'package:connectanum_router/connectanum_router.dart';

import '../zugriff/rollen.dart';

/// Betriebsparameter des WAMP-Routers; Standardwerte für die lokale Entwicklung.
///
/// Im Betrieb setzt das Deployment (Ansible) die Werte über Umgebungsvariablen,
/// siehe [RouterEinstellungen.ausUmgebung].
class RouterEinstellungen {
  const RouterEinstellungen({
    this.host = '127.0.0.1',
    this.port = 8080,
    this.webSocketPfad = '/ws',
    this.realm = standardRealm,
    this.healthListen = '127.0.0.1:8081',
    this.authListen = '127.0.0.1:8082',
  });

  /// Liest `PLANER_HOST`, `PLANER_PORT`, `PLANER_WS_PFAD`, `PLANER_REALM`,
  /// `PLANER_HEALTH_LISTEN` und `PLANER_AUTH_LISTEN`; fehlende Werte nehmen den
  /// Standard.
  factory RouterEinstellungen.ausUmgebung(Map<String, String> umgebung) {
    const standard = RouterEinstellungen();
    final port = umgebung['PLANER_PORT'];
    return RouterEinstellungen(
      host: umgebung['PLANER_HOST'] ?? standard.host,
      port: port == null ? standard.port : _alsPort(port),
      webSocketPfad: umgebung['PLANER_WS_PFAD'] ?? standard.webSocketPfad,
      realm: umgebung['PLANER_REALM'] ?? standard.realm,
      healthListen: umgebung['PLANER_HEALTH_LISTEN'] ?? standard.healthListen,
      authListen: umgebung['PLANER_AUTH_LISTEN'] ?? standard.authListen,
    );
  }

  static const standardRealm = 'de.robinienwelt.terrassenplaner';

  /// Interner Realm des Routers für Gesundheits- und Metrik-Abfragen.
  static const metrikRealm = 'connectanum.metrics';

  final String host;

  /// TCP-Port des WebSocket-Listeners; 0 = vom Betriebssystem vergeben (Tests).
  final int port;
  final String webSocketPfad;
  final String realm;

  /// Adresse des HTTP-Listeners für `/healthz` (host:port).
  final String healthListen;

  /// Interner RawSocket-Listener (host:port, fester Port) für den Auth-Server;
  /// nur lokal erreichbar, Anmeldung nur per Dienst-Ticket.
  final String authListen;

  /// Realm, in dem der Auth-Server (connectanum_auth_server) seine Prozeduren
  /// `authenticate.*` anbietet.
  static const authRealm = 'connectanum.authenticate';

  /// Router-Konfiguration: Planer-Realm mit Rollen (Kunde anonym, Mitarbeiter
  /// per SCRAM über den Auth-Server), Auth-Realm, öffentlicher
  /// WebSocket-Listener, interner Auth-Listener und Health-Endpunkt.
  ///
  /// [authToken] ist das gemeinsame Geheimnis zwischen Router und Auth-Server,
  /// [dienstTicket] das Ticket, mit dem sich der Router am Auth-Realm anmeldet.
  RouterSettings alsRouterSettings({
    required String authToken,
    required String dienstTicket,
  }) {
    final planerRealm = RealmSettingsBuilder(realm)
      ..addAuthMethod('anonymous')
      ..addAuthMethod(
        'wamp-scram',
        options: {'authenticator': 'mitarbeiter-remote'},
      );
    for (final rolle in Rollen.alle()) {
      planerRealm.addRoleFromBuilder(rolle);
    }
    final authRealmBuilder = RealmSettingsBuilder(authRealm)
      ..addAuthMethod('ticket', options: {'authenticator': 'dienst-ticket'})
      ..addRoleFromBuilder(
        RoleSettingsBuilder(authClientRolle)
          ..addPermissionFromBuilder(_recht('authenticate.', const ['call'])),
      )
      ..addRoleFromBuilder(
        RoleSettingsBuilder(authDienstRolle)..addPermissionFromBuilder(
          _recht('authenticate.', const ['register', 'unregister']),
        ),
      );
    final metrikRealmBuilder = RealmSettingsBuilder(metrikRealm)
      ..addAuthMethod('anonymous')
      ..addRoleFromBuilder(_rolleMitAllenRechten('metrics'));
    final webSocket = ListenerSettingsBuilder('websocket', '$host:$port')
      ..addAuthMethod('anonymous')
      ..addAuthMethod('wamp-scram')
      ..setPath(webSocketPfad);
    final authListener = ListenerSettingsBuilder('rawsocket', authListen)
      ..addAuthMethod('ticket')
      ..setOptions(const {'max_rawsocket_size_exponent': 16});
    final authAdresse = Uri.parse('tcp://$authListen');

    return RouterSettings(
      realms: [
        planerRealm.build(),
        authRealmBuilder.build(),
        metrikRealmBuilder.build(),
      ],
      listeners: [webSocket.build(), authListener.build()],
      internalRealms: [
        InternalRealmSettings(
          name: metrikRealm,
          authId: 'metrics-daemon',
          authRole: 'metrics',
          services: const {'metrics'},
        ),
      ],
      metrics: MetricsSettings(
        openMetrics: OpenMetricsSettings(enabled: true, listen: healthListen),
      ),
      authenticators: {
        'dienst-ticket': AuthenticatorDefinition(
          type: 'ticket',
          options: {
            'secrets': {
              authClientId: {'ticket': dienstTicket, 'role': authClientRolle},
            },
          },
        ),
        'mitarbeiter-remote': AuthenticatorDefinition(
          type: 'remote',
          options: {
            'method': 'remote',
            'allowed_roles': [Rollen.mitarbeiter],
            'auth_token': authToken,
            'rpc': {
              'realm': authRealm,
              'transport': {
                'type': 'rawsocket',
                'host': authAdresse.host,
                'port': authAdresse.port,
                // Nur Loopback innerhalb des Servers; nach außen schützt Traefik mit TLS.
                'tls': {'allow_insecure_transport': true},
              },
              'service_auth_method': 'ticket',
              'service_auth_id': authClientId,
              'service_auth_secret': dienstTicket,
            },
          },
        ),
      },
      workerPool: const WorkerPoolSettings(minWorkers: 1),
    ).withOpenMetricsHttpRoutes();
  }

  /// Anmeldename und Rolle, mit denen der Router den Auth-Server aufruft.
  static const authClientId = 'router';
  static const authClientRolle = 'auth-client';

  /// authid der internen Sitzung des Auth-Servers.
  static const authServerSitzung = 'auth-server';

  /// Rolle der internen Sitzung, über die der Auth-Server seine Prozeduren
  /// registriert.
  static const authDienstRolle = 'auth-dienst';

  /// Einstellungen des Auth-Servers: SCRAM für Mitarbeiter im Planer-Realm.
  /// Der Methodenname ist `wamp-scram`, so meldet ihn der connectanum-Client.
  RouterSettings alsAuthServerSettings() {
    final builder = RouterSettingsBuilder()
      ..addAuthenticator(
        'mitarbeiter-scram',
        const AuthenticatorDefinition(type: 'scram'),
      )
      ..addRealmFromBuilder(
        RealmSettingsBuilder(realm)..addAuthMethod(
          'wamp-scram',
          options: {'authenticator': 'mitarbeiter-scram'},
        ),
      );
    return builder.build();
  }

  static PermissionSettingsBuilder _recht(String uri, List<String> erlaubt) =>
      PermissionSettingsBuilder(uri)
        ..setMatchPolicy(PermissionMatchPolicy.prefix)
        ..allowOperations(erlaubt);

  static RoleSettingsBuilder _rolleMitAllenRechten(String rolle) =>
      RoleSettingsBuilder(rolle)..addPermissionFromBuilder(
        PermissionSettingsBuilder('')
          ..setMatchPolicy(PermissionMatchPolicy.prefix)
          ..allowOperations(const [
            'subscribe',
            'publish',
            'call',
            'register',
            'unregister',
          ]),
      );

  static int _alsPort(String wert) {
    final port = int.tryParse(wert);
    if (port == null || port < 0 || port > 65535) {
      throw FormatException('Ungültiger Port in PLANER_PORT', wert);
    }
    return port;
  }
}
