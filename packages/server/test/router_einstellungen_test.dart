import 'package:connectanum_router/connectanum_router.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

void main() {
  group('RouterEinstellungen.ausUmgebung', () {
    test('ohne Variablen gelten die Standardwerte', () {
      final e = RouterEinstellungen.ausUmgebung(const {});
      expect(e.host, '127.0.0.1');
      expect(e.port, 8080);
      expect(e.webSocketPfad, '/ws');
      expect(e.realm, 'de.robinienwelt.terrassenplaner');
      expect(e.healthListen, '127.0.0.1:8081');
      expect(e.authListen, '127.0.0.1:8082');
    });

    test('übernimmt alle Variablen', () {
      final e = RouterEinstellungen.ausUmgebung(const {
        'PLANER_HOST': '0.0.0.0',
        'PLANER_PORT': '9000',
        'PLANER_WS_PFAD': '/wamp',
        'PLANER_REALM': 'test.realm',
        'PLANER_HEALTH_LISTEN': '0.0.0.0:9001',
        'PLANER_AUTH_LISTEN': '127.0.0.1:9002',
      });
      expect(e.host, '0.0.0.0');
      expect(e.port, 9000);
      expect(e.webSocketPfad, '/wamp');
      expect(e.realm, 'test.realm');
      expect(e.healthListen, '0.0.0.0:9001');
      expect(e.authListen, '127.0.0.1:9002');
    });

    test('Port 0 und 65535 sind gültig', () {
      expect(
        RouterEinstellungen.ausUmgebung(const {'PLANER_PORT': '0'}).port,
        0,
      );
      expect(
        RouterEinstellungen.ausUmgebung(const {'PLANER_PORT': '65535'}).port,
        65535,
      );
    });

    for (final ungueltig in ['abc', '-1', '65536']) {
      test('ungültiger Port "$ungueltig" wird abgewiesen', () {
        expect(
          () => RouterEinstellungen.ausUmgebung({'PLANER_PORT': ungueltig}),
          throwsA(
            isA<FormatException>()
                .having(
                  (e) => e.message,
                  'message',
                  'Ungültiger Port in PLANER_PORT',
                )
                .having((e) => e.source, 'source', ungueltig),
          ),
        );
      });
    }
  });

  group('alsRouterSettings', () {
    final settings = const RouterEinstellungen(
      host: '0.0.0.0',
      port: 9000,
      webSocketPfad: '/wamp',
      realm: 'test.realm',
      healthListen: '127.0.0.1:9001',
      authListen: '127.0.0.1:9002',
    ).alsRouterSettings(authToken: 'geheim', dienstTicket: 'ticket');
    final realms = {for (final r in settings.realms) r.name: r};
    final listener = {for (final l in settings.listeners) l.endpoint: l};

    test('öffentlicher WebSocket-Listener: Pfad, anonym und wamp-scram', () {
      final ws = listener['0.0.0.0:9000']!;
      expect(ws.type, 'websocket');
      expect(Endpoint.fromListenerSettings(ws).webSocketPath, '/wamp');
      expect(ws.authmethods, ['anonymous', 'wamp-scram']);
    });

    test('interner Auth-Listener: RawSocket, nur Ticket', () {
      final auth = listener['127.0.0.1:9002']!;
      expect(auth.type, 'rawsocket');
      expect(auth.authmethods, ['ticket']);
      expect(auth.options['max_rawsocket_size_exponent'], 16);
    });

    test('eigener HTTP-Listener für den Health-Endpunkt', () {
      expect(settings.listeners, hasLength(3));
      expect(listener['127.0.0.1:9001']!.type, 'http');
    });

    test('Planer-Realm: anonym und wamp-scram über den Auth-Server', () {
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

    test('Auth-Realm: Ticket, Rollen auth-client und auth-dienst', () {
      final auth = realms[RouterEinstellungen.authRealm]!;
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
      expect(dienst.allow, ['register', 'unregister']);
    });

    test('Dienst-Ticket für den Router', () {
      final ticket = settings.authenticators['dienst-ticket']!;
      expect(ticket.type, 'ticket');
      expect(ticket.options['secrets'], {
        'router': {'ticket': 'ticket', 'role': 'auth-client'},
      });
    });

    test(
      'Mitarbeiter-Anmeldung wird per WAMP an den Auth-Server delegiert',
      () {
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
      },
    );

    test('Metrik-Realm, Metriken und Worker-Pool', () {
      expect(realms['connectanum.metrics']!.roles.single.name, 'metrics');
      final recht =
          realms['connectanum.metrics']!.roles.single.permissions.single;
      expect(recht.uri, '');
      expect(
        recht.allow,
        containsAll(['subscribe', 'publish', 'call', 'register', 'unregister']),
      );
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

  test('Kennungen für Auth-Server und Router-Dienstzugang', () {
    expect(RouterEinstellungen.authRealm, 'connectanum.authenticate');
    expect(RouterEinstellungen.authServerSitzung, 'auth-server');
    expect(RouterEinstellungen.authDienstRolle, 'auth-dienst');
    expect(RouterEinstellungen.authClientId, 'router');
    expect(RouterEinstellungen.authClientRolle, 'auth-client');
  });

  test('Auth-Server-Einstellungen: SCRAM unter dem Namen wamp-scram', () {
    final settings = const RouterEinstellungen(realm: 'test.realm')
        .alsAuthServerSettings();
    final realm = settings.realms.single;
    expect(realm.name, 'test.realm');
    expect(realm.auth.methods, ['wamp-scram']);
    expect(realm.auth.optionsFor('wamp-scram'), {
      'authenticator': 'mitarbeiter-scram',
    });
    expect(settings.authenticators['mitarbeiter-scram']!.type, 'scram');
  });
}
