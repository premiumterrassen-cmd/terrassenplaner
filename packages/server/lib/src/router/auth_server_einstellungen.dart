import 'package:connectanum_router/connectanum_router.dart';

import 'router_einstellungen.dart';
import 'umgebung.dart';

/// Betriebsparameter des Auth-Servers (connectanum_auth_server) – eigener
/// Prozess mit eigenem Router, der nur intern (127.0.0.1) lauscht.
class AuthServerEinstellungen {
  const AuthServerEinstellungen({
    required this.authToken,
    required this.dienstTicket,
    this.listen = standardListen,
    this.healthListen = '127.0.0.1:8083',
    this.planerRealm = RouterEinstellungen.standardRealm,
  });

  /// Liest `PLANER_AUTH_LISTEN`, `PLANER_AUTH_HEALTH_LISTEN`, `PLANER_REALM`
  /// sowie die Pflicht-Geheimnisse `PLANER_AUTH_TOKEN` und
  /// `PLANER_AUTH_DIENST_TICKET`.
  factory AuthServerEinstellungen.ausUmgebung(Map<String, String> u) =>
      AuthServerEinstellungen(
        authToken: Umgebung.pflicht(u, 'PLANER_AUTH_TOKEN'),
        dienstTicket: Umgebung.pflicht(u, 'PLANER_AUTH_DIENST_TICKET'),
        listen: Umgebung.wert(u, 'PLANER_AUTH_LISTEN', standardListen),
        healthListen: Umgebung.wert(
          u,
          'PLANER_AUTH_HEALTH_LISTEN',
          '127.0.0.1:8083',
        ),
        planerRealm: Umgebung.wert(
          u,
          'PLANER_REALM',
          RouterEinstellungen.standardRealm,
        ),
      );

  static const standardListen = '127.0.0.1:8082';

  /// Realm, in dem der Auth-Server `authenticate.*` anbietet.
  static const authRealm = 'connectanum.authenticate';

  /// Anmeldename und Rolle des Planer-Routers beim Auth-Server.
  static const clientId = 'router';
  static const clientRolle = 'auth-client';

  /// authid und Rolle der internen Sitzung, über die der Auth-Server seine
  /// Prozeduren registriert.
  static const sitzungId = 'auth-server';
  static const sitzungRolle = 'auth-dienst';

  /// RawSocket-Listener (host:port) für Anfragen des Planer-Routers.
  final String listen;
  final String healthListen;

  /// Realm des Planers, für den Mitarbeiter-Zugänge geprüft werden.
  final String planerRealm;
  final String authToken;
  final String dienstTicket;

  /// Router-Konfiguration des Auth-Prozesses: Auth-Realm (nur Ticket),
  /// RawSocket-Listener, Health.
  RouterSettings alsRouterSettings() {
    final realm = RealmSettingsBuilder(authRealm)
      ..addAuthMethod('ticket', options: {'authenticator': 'dienst-ticket'})
      ..addRoleFromBuilder(
        RoleSettingsBuilder(clientRolle)
          ..addPermissionFromBuilder(_recht(const ['call'])),
      )
      ..addRoleFromBuilder(
        RoleSettingsBuilder(sitzungRolle)
          ..addPermissionFromBuilder(_recht(const ['register', 'unregister'])),
      );
    final listener = ListenerSettingsBuilder('rawsocket', listen)
      ..addAuthMethod('ticket')
      ..setOptions(const {'max_rawsocket_size_exponent': 16});
    return RouterSettings(
      realms: [realm.build(), RouterEinstellungen.metrikRealmSettings()],
      listeners: [listener.build()],
      internalRealms: [RouterEinstellungen.metrikIntern],
      metrics: MetricsSettings(
        openMetrics: OpenMetricsSettings(enabled: true, listen: healthListen),
      ),
      authenticators: {
        'dienst-ticket': AuthenticatorDefinition(
          type: 'ticket',
          options: {
            'secrets': {
              clientId: {'ticket': dienstTicket, 'role': clientRolle},
            },
          },
        ),
      },
      workerPool: const WorkerPoolSettings(minWorkers: 1),
    ).withOpenMetricsHttpRoutes();
  }

  /// Einstellungen des AuthServers: SCRAM für Mitarbeiter im Planer-Realm,
  /// unter dem Namen `wamp-scram`, wie ihn der connectanum-Client meldet.
  RouterSettings alsAuthServerSettings() =>
      (RouterSettingsBuilder()
            ..addAuthenticator(
              'mitarbeiter-scram',
              const AuthenticatorDefinition(type: 'scram'),
            )
            ..addRealmFromBuilder(
              RealmSettingsBuilder(planerRealm)..addAuthMethod(
                'wamp-scram',
                options: {'authenticator': 'mitarbeiter-scram'},
              ),
            ))
          .build();

  static PermissionSettingsBuilder _recht(List<String> erlaubt) =>
      PermissionSettingsBuilder('authenticate.')
        ..setMatchPolicy(PermissionMatchPolicy.prefix)
        ..allowOperations(erlaubt);
}
