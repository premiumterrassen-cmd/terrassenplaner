@Timeout(Duration(minutes: 2))
library;

import 'dart:io';

import 'package:connectanum_client/connectanum.dart' hide SocketTransport;
import 'package:connectanum_client/json.dart';
import 'package:connectanum_client/socket.dart';
import 'package:connectanum_router/auth.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

import 'hilfen.dart';

void main() {
  late AuthServerProzess auth;

  setUpAll(() async {
    auth = await AuthServerProzess.starte(
      await testAuthEinstellungen(),
      mitarbeiter: MitarbeiterVerzeichnis([
        const MitarbeiterZugang(
          authId: 'anna',
          salt: 'c2FsdA==',
          iterationen: 4096,
          storedKey: 'stored',
          serverKey: 'server',
        ),
      ]),
    );
    await Future<void>.delayed(const Duration(milliseconds: 500));
  });

  tearDownAll(() => auth.stoppe());

  Future<Session> verbinde(String ticket) =>
      Client(
            realm: AuthServerEinstellungen.authRealm,
            authId: AuthServerEinstellungen.clientId,
            authenticationMethods: [TicketAuthentication(ticket)],
            transport: SocketTransport(
              '127.0.0.1',
              auth.port,
              Serializer(),
              SocketHelper.serializationJson,
            ),
          )
          .connect(options: ClientConnectOptions(reconnectCount: 0))
          .first
          .timeout(const Duration(seconds: 20));

  test('Router meldet sich mit Dienst-Ticket an (Rolle auth-client)', () async {
    final router = await verbinde(testTicket);
    expect(router.authRole, AuthServerEinstellungen.clientRolle);
    await router.close();
  });

  test('falsches Ticket wird abgewiesen', () async {
    await expectLater(verbinde('falsch'), throwsA(anything));
  });

  test(
    'authenticate.hello ist erreichbar und verlangt den Auth-Token',
    () async {
      final router = await verbinde(testTicket);
      final antwort = await router.callSingle(
        'authenticate.hello',
        arguments: [<String, Object?>{}],
      );
      // Ohne gültigen Auth-Token lehnt der AuthServer ab (beta.6 prüft
      // Dienst-Zugangsdaten vor allem anderen).
      expect(antwort.argumentsKeywords, {
        'status': 'failure',
        'reason': 'wamp.error.not_authorized',
        'message': 'Remote authenticator token rejected',
      });
      await router.close();
    },
  );

  test('Mitarbeiter-Zugänge stehen dem AuthServer bereit', () async {
    final zugang = await AuthCredentialRegistry.loadScram(
      realmUri: RouterEinstellungen.standardRealm,
      authId: 'anna',
    );
    expect(zugang!.storedKey, 'stored');
  });

  test('Health-Endpunkt meldet Bereitschaft', () async {
    final http = HttpClient();
    final antwort = await (await http.get(
      '127.0.0.1',
      auth.healthPort,
      '/healthz',
    )).close();
    expect(antwort.statusCode, 200);
    http.close();
  });
}
