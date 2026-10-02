import 'package:connectanum_router/connectanum_router.dart';

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
  });

  /// Liest `PLANER_HOST`, `PLANER_PORT`, `PLANER_WS_PFAD`, `PLANER_REALM` und
  /// `PLANER_HEALTH_LISTEN`; fehlende Werte nehmen den Standard.
  factory RouterEinstellungen.ausUmgebung(Map<String, String> umgebung) {
    const standard = RouterEinstellungen();
    final port = umgebung['PLANER_PORT'];
    return RouterEinstellungen(
      host: umgebung['PLANER_HOST'] ?? standard.host,
      port: port == null ? standard.port : _alsPort(port),
      webSocketPfad: umgebung['PLANER_WS_PFAD'] ?? standard.webSocketPfad,
      realm: umgebung['PLANER_REALM'] ?? standard.realm,
      healthListen: umgebung['PLANER_HEALTH_LISTEN'] ?? standard.healthListen,
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

  /// Router-Konfiguration: ein Realm, WebSocket-Listener, Health-Endpunkt.
  ///
  /// Vorläufig mit anonymer Anmeldung und vollen Rechten im Planer-Realm;
  /// Rollen und Rechte kommen mit M0-08 (#8).
  RouterSettings alsRouterSettings() {
    final planerRealm = RealmSettingsBuilder(realm)
      ..addAuthMethod('anonymous')
      ..addRoleFromBuilder(_rolleMitAllenRechten('anonymous'));
    final metrikRealmBuilder = RealmSettingsBuilder(metrikRealm)
      ..addAuthMethod('anonymous')
      ..addRoleFromBuilder(_rolleMitAllenRechten('metrics'));
    final webSocket = ListenerSettingsBuilder('websocket', '$host:$port')
      ..addAuthMethod('anonymous')
      ..setPath(webSocketPfad);

    return RouterSettings(
      realms: [planerRealm.build(), metrikRealmBuilder.build()],
      listeners: [webSocket.build()],
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
      authenticators: const {
        'anonymous': AuthenticatorDefinition(type: 'anonymous'),
      },
      workerPool: const WorkerPoolSettings(minWorkers: 1),
    ).withOpenMetricsHttpRoutes();
  }

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
