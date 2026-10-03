import 'package:connectanum_router/connectanum_router.dart';

import '../zugriff/rollen.dart';
import 'auth_server_einstellungen.dart';
import 'umgebung.dart';

/// Betriebsparameter des Planer-Routers (öffentlicher WAMP-Router).
///
/// Mitarbeiter-Anmeldungen delegiert er per WAMP an den Auth-Server, der als
/// eigener Prozess läuft (siehe [AuthServerEinstellungen]). Im Betrieb setzt
/// das Deployment (Ansible) die Werte über Umgebungsvariablen.
class RouterEinstellungen {
  const RouterEinstellungen({
    required this.authToken,
    required this.dienstTicket,
    this.host = '127.0.0.1',
    this.port = 8080,
    this.webSocketPfad = '/ws',
    this.realm = standardRealm,
    this.healthListen = '127.0.0.1:8081',
    this.authAdresse = AuthServerEinstellungen.standardListen,
  });

  /// Liest `PLANER_HOST`, `PLANER_PORT`, `PLANER_WS_PFAD`, `PLANER_REALM`,
  /// `PLANER_HEALTH_LISTEN`, `PLANER_AUTH_ADRESSE` sowie die Pflicht-Geheimnisse
  /// `PLANER_AUTH_TOKEN` und `PLANER_AUTH_DIENST_TICKET`.
  factory RouterEinstellungen.ausUmgebung(Map<String, String> u) =>
      RouterEinstellungen(
        authToken: Umgebung.pflicht(u, 'PLANER_AUTH_TOKEN'),
        dienstTicket: Umgebung.pflicht(u, 'PLANER_AUTH_DIENST_TICKET'),
        host: Umgebung.wert(u, 'PLANER_HOST', '127.0.0.1'),
        port: Umgebung.port(u, 'PLANER_PORT', 8080),
        webSocketPfad: Umgebung.wert(u, 'PLANER_WS_PFAD', '/ws'),
        realm: Umgebung.wert(u, 'PLANER_REALM', standardRealm),
        healthListen: Umgebung.wert(
          u,
          'PLANER_HEALTH_LISTEN',
          '127.0.0.1:8081',
        ),
        authAdresse: Umgebung.wert(
          u,
          'PLANER_AUTH_ADRESSE',
          AuthServerEinstellungen.standardListen,
        ),
      );

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

  /// Adresse (host:port) des internen Listeners des Auth-Servers.
  final String authAdresse;

  /// Gemeinsames Geheimnis zwischen Router und Auth-Server.
  final String authToken;

  /// Ticket, mit dem sich der Router beim Auth-Server anmeldet.
  final String dienstTicket;

  /// Router-Konfiguration: Planer-Realm mit Rollen (Kunde anonym, Mitarbeiter
  /// per `wamp-scram` über den Auth-Server), WebSocket-Listener, Health.
  RouterSettings alsRouterSettings() {
    final planerRealm = RealmSettingsBuilder(realm)
      ..addAuthMethod('anonymous')
      // Der connectanum-Client meldet SCRAM als „wamp-scram“.
      ..addAuthMethod(
        'wamp-scram',
        options: {'authenticator': 'mitarbeiter-remote'},
      );
    for (final rolle in Rollen.alle()) {
      planerRealm.addRoleFromBuilder(rolle);
    }
    final webSocket = ListenerSettingsBuilder('websocket', '$host:$port')
      ..addAuthMethod('anonymous')
      ..addAuthMethod('wamp-scram')
      ..setPath(webSocketPfad);
    final auth = Uri.parse('tcp://$authAdresse');

    return RouterSettings(
      realms: [planerRealm.build(), metrikRealmSettings()],
      listeners: [webSocket.build()],
      internalRealms: [metrikIntern],
      metrics: MetricsSettings(
        openMetrics: OpenMetricsSettings(enabled: true, listen: healthListen),
      ),
      authenticators: {
        'mitarbeiter-remote': AuthenticatorDefinition(
          type: 'remote',
          options: {
            'method': 'remote',
            'allowed_roles': [Rollen.mitarbeiter],
            'auth_token': authToken,
            'rpc': {
              'realm': AuthServerEinstellungen.authRealm,
              'transport': {
                'type': 'rawsocket',
                'host': auth.host,
                'port': auth.port,
                // Nur Loopback innerhalb des Servers; nach außen schützt Traefik mit TLS.
                'tls': {'allow_insecure_transport': true},
              },
              'service_auth_method': 'ticket',
              'service_auth_id': AuthServerEinstellungen.clientId,
              'service_auth_secret': dienstTicket,
            },
          },
        ),
      },
      workerPool: const WorkerPoolSettings(minWorkers: 1),
    ).withOpenMetricsHttpRoutes();
  }

  /// Metrik-Realm mit voller Rolle für die interne Metrik-Sitzung.
  static RealmSettings metrikRealmSettings() =>
      (RealmSettingsBuilder(metrikRealm)
            ..addAuthMethod('anonymous')
            ..addRoleFromBuilder(
              RoleSettingsBuilder('metrics')..addPermissionFromBuilder(
                PermissionSettingsBuilder('')
                  ..setMatchPolicy(PermissionMatchPolicy.prefix)
                  ..allowOperations(const [
                    'subscribe',
                    'publish',
                    'call',
                    'register',
                    'unregister',
                  ]),
              ),
            ))
          .build();

  static final metrikIntern = InternalRealmSettings(
    name: metrikRealm,
    authId: 'metrics-daemon',
    authRole: 'metrics',
    services: const {'metrics'},
  );
}
