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
    });

    test('übernimmt alle Variablen', () {
      final e = RouterEinstellungen.ausUmgebung(const {
        'PLANER_HOST': '0.0.0.0',
        'PLANER_PORT': '9000',
        'PLANER_WS_PFAD': '/wamp',
        'PLANER_REALM': 'test.realm',
        'PLANER_HEALTH_LISTEN': '0.0.0.0:9001',
      });
      expect(e.host, '0.0.0.0');
      expect(e.port, 9000);
      expect(e.webSocketPfad, '/wamp');
      expect(e.realm, 'test.realm');
      expect(e.healthListen, '0.0.0.0:9001');
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
    ).alsRouterSettings();

    test('WebSocket-Listener mit Adresse, Pfad und anonymer Anmeldung', () {
      final ws = settings.listeners.first;
      expect(ws.type, 'websocket');
      expect(ws.endpoint, '0.0.0.0:9000');
      expect(Endpoint.fromListenerSettings(ws).webSocketPath, '/wamp');
      expect(ws.authmethods, ['anonymous']);
    });

    test('zusätzlicher HTTP-Listener für den Health-Endpunkt', () {
      expect(settings.listeners, hasLength(2));
      final health = settings.listeners.last;
      expect(health.endpoint, '127.0.0.1:9001');
      expect(health.type, 'http');
    });

    test('Planer-Realm und Metrik-Realm mit voller Rolle', () {
      final realms = {for (final r in settings.realms) r.name: r};
      expect(realms.keys, containsAll(['test.realm', 'connectanum.metrics']));
      final rolle = realms['test.realm']!.roles.single;
      expect(rolle.name, 'anonymous');
      final recht = rolle.permissions.single;
      expect(recht.uri, '');
      expect(recht.matchPolicy, PermissionMatchPolicy.prefix);
      expect(
        recht.allow,
        containsAll(['subscribe', 'publish', 'call', 'register', 'unregister']),
      );
      expect(realms['connectanum.metrics']!.roles.single.name, 'metrics');
    });

    test('Metriken aktiv, interner Metrik-Realm, anonymer Authenticator', () {
      expect(settings.metrics!.openMetrics!.enabled, isTrue);
      expect(settings.metrics!.openMetrics!.listen, '127.0.0.1:9001');
      expect(settings.internalRealms.single.name, 'connectanum.metrics');
      expect(settings.internalRealms.single.authId, 'metrics-daemon');
      expect(settings.internalRealms.single.authRole, 'metrics');
      expect(settings.internalRealms.single.services, {'metrics'});
      expect(settings.authenticators['anonymous']!.type, 'anonymous');
      expect(settings.workerPool.minWorkers, 1);
    });
  });
}
