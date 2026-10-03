import 'package:connectanum_router/connectanum_router.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

const _geheim = {
  'PLANER_AUTH_TOKEN': 'token',
  'PLANER_AUTH_DIENST_TICKET': 'ticket',
};

Matcher _formatFehler(String message, String source) => throwsA(
  isA<FormatException>()
      .having((e) => e.message, 'message', message)
      .having((e) => e.source, 'source', source),
);

void main() {
  group('Umgebung', () {
    test('wert: Variable oder Standard', () {
      expect(Umgebung.wert(const {'A': 'x'}, 'A', 's'), 'x');
      expect(Umgebung.wert(const {}, 'A', 's'), 's');
    });

    test('pflicht: fehlend oder leer bricht ab', () {
      expect(Umgebung.pflicht(const {'A': 'x'}, 'A'), 'x');
      expect(
        () => Umgebung.pflicht(const {}, 'A'),
        _formatFehler('Pflichtvariable fehlt', 'A'),
      );
      expect(
        () => Umgebung.pflicht(const {'A': ''}, 'A'),
        _formatFehler('Pflichtvariable fehlt', 'A'),
      );
    });

    test('port: 0 bis 65535, sonst Fehler mit Variablenname', () {
      expect(Umgebung.port(const {}, 'P', 7), 7);
      expect(Umgebung.port(const {'P': '0'}, 'P', 7), 0);
      expect(Umgebung.port(const {'P': '65535'}, 'P', 7), 65535);
      for (final ungueltig in ['abc', '-1', '65536']) {
        expect(
          () => Umgebung.port({'P': ungueltig}, 'P', 7),
          _formatFehler('Ungültiger Port in P', ungueltig),
        );
      }
    });
  });

  group('RouterEinstellungen.ausUmgebung', () {
    test('Standardwerte, Geheimnisse aus der Umgebung', () {
      final e = RouterEinstellungen.ausUmgebung(_geheim);
      expect(e.authToken, 'token');
      expect(e.dienstTicket, 'ticket');
      expect(e.host, '127.0.0.1');
      expect(e.port, 8080);
      expect(e.webSocketPfad, '/ws');
      expect(e.realm, 'de.robinienwelt.terrassenplaner');
      expect(e.healthListen, '127.0.0.1:8081');
      expect(e.authAdresse, '127.0.0.1:8082');
    });

    test('übernimmt alle Variablen', () {
      final e = RouterEinstellungen.ausUmgebung({
        ..._geheim,
        'PLANER_HOST': '0.0.0.0',
        'PLANER_PORT': '9000',
        'PLANER_WS_PFAD': '/wamp',
        'PLANER_REALM': 'test.realm',
        'PLANER_HEALTH_LISTEN': '0.0.0.0:9001',
        'PLANER_AUTH_ADRESSE': '127.0.0.1:9002',
      });
      expect(e.host, '0.0.0.0');
      expect(e.port, 9000);
      expect(e.webSocketPfad, '/wamp');
      expect(e.realm, 'test.realm');
      expect(e.healthListen, '0.0.0.0:9001');
      expect(e.authAdresse, '127.0.0.1:9002');
    });

    test('ohne Geheimnisse kein Start', () {
      expect(
        () => RouterEinstellungen.ausUmgebung(const {}),
        _formatFehler('Pflichtvariable fehlt', 'PLANER_AUTH_TOKEN'),
      );
      expect(
        () => RouterEinstellungen.ausUmgebung(const {'PLANER_AUTH_TOKEN': 't'}),
        _formatFehler('Pflichtvariable fehlt', 'PLANER_AUTH_DIENST_TICKET'),
      );
    });
  });

  test('Konstruktor-Standardwerte', () {
    const e = RouterEinstellungen(authToken: 't', dienstTicket: 'k');
    expect(e.host, '127.0.0.1');
    expect(e.port, 8080);
    expect(e.webSocketPfad, '/ws');
    expect(e.realm, RouterEinstellungen.standardRealm);
    expect(e.healthListen, '127.0.0.1:8081');
    expect(e.authAdresse, '127.0.0.1:8082');
    const a = AuthServerEinstellungen(authToken: 't', dienstTicket: 'k');
    expect(a.listen, '127.0.0.1:8082');
    expect(a.healthListen, '127.0.0.1:8083');
    expect(a.planerRealm, RouterEinstellungen.standardRealm);
  });

  group('RouterEinstellungen.alsRouterSettings', () {
    final settings = const RouterEinstellungen(
      authToken: 'geheim',
      dienstTicket: 'ticket',
      host: '0.0.0.0',
      port: 9000,
      webSocketPfad: '/wamp',
      realm: 'test.realm',
      healthListen: '127.0.0.1:9001',
      authAdresse: '127.0.0.1:9002',
    ).alsRouterSettings();
    final realms = {for (final r in settings.realms) r.name: r};

    test('WebSocket-Listener: Pfad, anonym und wamp-scram', () {
      final ws = settings.listeners.first;
      expect(ws.type, 'websocket');
      expect(ws.endpoint, '0.0.0.0:9000');
      expect(Endpoint.fromListenerSettings(ws).webSocketPath, '/wamp');
      expect(ws.authmethods, ['anonymous', 'wamp-scram']);
    });

    test('eigener HTTP-Listener für den Health-Endpunkt', () {
      expect(settings.listeners, hasLength(2));
      expect(settings.listeners.last.endpoint, '127.0.0.1:9001');
      expect(settings.listeners.last.type, 'http');
    });

    test('Planer-Realm mit Rollen und Delegation von wamp-scram', () {
      final planer = realms['test.realm']!;
      expect(planer.auth.methods, ['anonymous', 'wamp-scram']);
      expect(planer.auth.optionsFor('wamp-scram'), {
        'authenticator': 'mitarbeiter-remote',
      });
      expect(planer.roles.map((r) => r.name), [
        Rollen.kunde,
        Rollen.mitarbeiter,
        Rollen.dienst,
      ]);
    });

    test('Mitarbeiter-Anmeldung per WAMP an den Auth-Server', () {
      final remote = settings.authenticators['mitarbeiter-remote']!;
      expect(remote.type, 'remote');
      expect(remote.options['method'], 'remote');
      expect(remote.options['allowed_roles'], [Rollen.mitarbeiter]);
      expect(remote.options['auth_token'], 'geheim');
      expect(remote.options['rpc'], {
        'realm': 'connectanum.authenticate',
        'transport': {
          'type': 'rawsocket',
          'host': '127.0.0.1',
          'port': 9002,
          'tls': {'allow_insecure_transport': true},
        },
        'service_auth_method': 'ticket',
        'service_auth_id': 'router',
        'service_auth_secret': 'ticket',
      });
    });

    test('Metrik-Realm, Metriken und Worker-Pool', () {
      final metrik = realms['connectanum.metrics']!;
      expect(metrik.auth.methods, ['anonymous']);
      final recht = metrik.roles.single.permissions.single;
      expect(metrik.roles.single.name, 'metrics');
      expect(recht.uri, '');
      expect(recht.matchPolicy, PermissionMatchPolicy.prefix);
      expect(recht.allow, [
        'subscribe',
        'publish',
        'call',
        'register',
        'unregister',
      ]);
      expect(settings.metrics!.openMetrics!.enabled, isTrue);
      expect(settings.metrics!.openMetrics!.listen, '127.0.0.1:9001');
      final intern = settings.internalRealms.single;
      expect(intern.name, 'connectanum.metrics');
      expect(intern.authId, 'metrics-daemon');
      expect(intern.authRole, 'metrics');
      expect(intern.services, {'metrics'});
      expect(settings.workerPool.minWorkers, 1);
    });
  });

  group('AuthServerEinstellungen', () {
    test('Standardwerte und Kennungen', () {
      final e = AuthServerEinstellungen.ausUmgebung(_geheim);
      expect(e.authToken, 'token');
      expect(e.dienstTicket, 'ticket');
      expect(e.listen, '127.0.0.1:8082');
      expect(e.healthListen, '127.0.0.1:8083');
      expect(e.planerRealm, 'de.robinienwelt.terrassenplaner');
      expect(AuthServerEinstellungen.authRealm, 'connectanum.authenticate');
      expect(AuthServerEinstellungen.clientId, 'router');
      expect(AuthServerEinstellungen.clientRolle, 'auth-client');
      expect(AuthServerEinstellungen.sitzungId, 'auth-server');
      expect(AuthServerEinstellungen.sitzungRolle, 'auth-dienst');
    });

    test('übernimmt alle Variablen, Geheimnisse sind Pflicht', () {
      final e = AuthServerEinstellungen.ausUmgebung({
        ..._geheim,
        'PLANER_AUTH_LISTEN': '127.0.0.1:9100',
        'PLANER_AUTH_HEALTH_LISTEN': '127.0.0.1:9101',
        'PLANER_REALM': 'test.realm',
      });
      expect(e.listen, '127.0.0.1:9100');
      expect(e.healthListen, '127.0.0.1:9101');
      expect(e.planerRealm, 'test.realm');
      expect(
        () => AuthServerEinstellungen.ausUmgebung(const {}),
        _formatFehler('Pflichtvariable fehlt', 'PLANER_AUTH_TOKEN'),
      );
      expect(
        () => AuthServerEinstellungen.ausUmgebung(const {
          'PLANER_AUTH_TOKEN': 't',
        }),
        _formatFehler('Pflichtvariable fehlt', 'PLANER_AUTH_DIENST_TICKET'),
      );
    });

    final e = const AuthServerEinstellungen(
      authToken: 'token',
      dienstTicket: 'ticket',
      listen: '127.0.0.1:9100',
      healthListen: '127.0.0.1:9101',
      planerRealm: 'test.realm',
    );

    test('Router des Auth-Prozesses: Auth-Realm nur mit Ticket', () {
      final settings = e.alsRouterSettings();
      final realms = {for (final r in settings.realms) r.name: r};
      final auth = realms['connectanum.authenticate']!;
      expect(auth.auth.methods, ['ticket']);
      expect(auth.auth.optionsFor('ticket'), {
        'authenticator': 'dienst-ticket',
      });
      final rollen = {for (final r in auth.roles) r.name: r};
      final client = rollen['auth-client']!.permissions.single;
      expect(client.uri, 'authenticate.');
      expect(client.matchPolicy, PermissionMatchPolicy.prefix);
      expect(client.allow, ['call']);
      final dienst = rollen['auth-dienst']!.permissions.single;
      expect(dienst.uri, 'authenticate.');
      expect(dienst.matchPolicy, PermissionMatchPolicy.prefix);
      expect(dienst.allow, ['register', 'unregister']);
      expect(realms.keys, contains('connectanum.metrics'));
      expect(settings.internalRealms.single.name, 'connectanum.metrics');
      expect(settings.metrics!.openMetrics!.listen, '127.0.0.1:9101');
      expect(settings.workerPool.minWorkers, 1);
    });

    test('RawSocket-Listener nur mit Ticket, Dienst-Ticket für den Router', () {
      final settings = e.alsRouterSettings();
      final rs = settings.listeners.first;
      expect(rs.type, 'rawsocket');
      expect(rs.endpoint, '127.0.0.1:9100');
      expect(rs.authmethods, ['ticket']);
      expect(rs.options['max_rawsocket_size_exponent'], 16);
      expect(settings.listeners.last.endpoint, '127.0.0.1:9101');
      final ticket = settings.authenticators['dienst-ticket']!;
      expect(ticket.type, 'ticket');
      expect(ticket.options['secrets'], {
        'router': {'ticket': 'ticket', 'role': 'auth-client'},
      });
    });

    test('AuthServer: SCRAM unter dem Namen wamp-scram im Planer-Realm', () {
      final settings = e.alsAuthServerSettings();
      final realm = settings.realms.single;
      expect(realm.name, 'test.realm');
      expect(realm.auth.methods, ['wamp-scram']);
      expect(realm.auth.optionsFor('wamp-scram'), {
        'authenticator': 'mitarbeiter-scram',
      });
      expect(settings.authenticators['mitarbeiter-scram']!.type, 'scram');
    });
  });
}
