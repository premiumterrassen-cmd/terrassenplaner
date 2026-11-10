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

const _anna = MitarbeiterZugang(
  authId: 'anna@example.test',
  salt: 'c2FsdA==',
  iterationen: 1,
  speicher: 8,
  storedKey: 'stored',
  serverKey: 'server',
);

void main() {
  late AuthServerProzess auth;
  late Datenbank db;
  late Mitarbeiterkonten konten;

  setUpAll(() async {
    db = Datenbank.oeffne('memory:auth-server-prozess', knoten: 'k');
    konten = Mitarbeiterkonten(db)..anlegen(_anna);
    auth = await AuthServerProzess.starte(
      await testAuthEinstellungen(),
      konten: konten,
    );
    await Future<void>.delayed(const Duration(milliseconds: 500));
  });

  tearDownAll(() async {
    await auth.stoppe();
    db.schliesse();
  });

  Future<Session> verbinde(String ticket, {String? authId}) =>
      Client(
            realm: AuthServerEinstellungen.authRealm,
            authId: authId ?? AuthServerEinstellungen.clientId,
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

  Map<String, String> umgebung(String adresse) => {
    'PLANER_AUTH_ADRESSE': adresse,
    'PLANER_AUTH_DIENST_TICKET': testTicket,
  };

  test('Router meldet sich mit Dienst-Ticket an (Rolle auth-client)', () async {
    final router = await verbinde(testTicket);
    expect(router.authRole, AuthServerEinstellungen.clientRolle);
    await router.close();
  });

  test('falsches Ticket wird abgewiesen', () async {
    await expectLater(verbinde('falsch'), throwsA(anything));
    await expectLater(
      verbinde('falsch', authId: AuthServerEinstellungen.verwaltungId),
      throwsA(anything),
    );
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

  test('Rollen trennen Anmeldung und Verwaltung', () async {
    final router = await verbinde(testTicket);
    await expectLater(
      router.callSingle(MitarbeiterVerwaltung.liste),
      throwsA(anything),
    );
    await router.close();
    final verwaltung = await verbinde(
      testTicket,
      authId: AuthServerEinstellungen.verwaltungId,
    );
    expect(verwaltung.authRole, AuthServerEinstellungen.verwaltungRolle);
    await expectLater(
      verwaltung.callSingle(
        'authenticate.hello',
        arguments: [<String, Object?>{}],
      ),
      throwsA(anything),
    );
    await verwaltung.close();
  });

  test('Mitarbeiter-Konten stehen dem AuthServer bereit', () async {
    final zugang = await AuthCredentialRegistry.loadScram(
      realmUri: RouterEinstellungen.standardRealm,
      authId: _anna.authId,
    );
    expect(zugang!.storedKey, 'stored');
  });

  test('Verwaltung über WAMP: anlegen, Passwort, sperren, Liste', () async {
    final v = await MitarbeiterWerkzeug.verbinde(
      umgebung('127.0.0.1:${auth.port}'),
    );
    addTearDown(v.schliesse);
    final bob = await MitarbeiterZugang.ableiten(
      authId: 'bob@example.test',
      passwort: 'x',
      iterationen: 1,
      speicher: 8,
    );
    expect(
      await v.rufe(MitarbeiterVerwaltung.anlegen, [bob.alsJson()]),
      isEmpty,
    );
    expect(konten.finde('bob@example.test')!.storedKey, bob.storedKey);
    final neu = await MitarbeiterZugang.ableiten(
      authId: 'bob@example.test',
      passwort: 'y',
      iterationen: 1,
      speicher: 8,
    );
    await v.rufe(MitarbeiterVerwaltung.passwort, [neu.alsJson()]);
    expect(konten.finde('bob@example.test')!.storedKey, neu.storedKey);
    await v.rufe(MitarbeiterVerwaltung.sperren, ['Bob@Example.test']);
    expect(await v.rufe(MitarbeiterVerwaltung.liste, []), [
      [_anna.authId, false],
      ['bob@example.test', true],
    ]);
    await v.rufe(MitarbeiterVerwaltung.entsperren, ['bob@example.test']);
    expect(konten.finde('bob@example.test')!.gesperrt, isFalse);
  });

  test('Verwaltung lehnt Ungültiges mit Meldung ab', () async {
    final v = await MitarbeiterWerkzeug.verbinde(
      umgebung('127.0.0.1:${auth.port}'),
    );
    addTearDown(v.schliesse);
    Matcher abgelehnt(Object meldung) => throwsA(
      isA<VerwaltungsFehler>().having((f) => f.meldung, 'meldung', meldung),
    );
    await expectLater(
      v.rufe(MitarbeiterVerwaltung.anlegen, [_anna.alsJson()]),
      abgelehnt('Konto anna@example.test gibt es schon'),
    );
    await expectLater(
      v.rufe(MitarbeiterVerwaltung.sperren, ['carla@example.test']),
      abgelehnt('Konto carla@example.test gibt es nicht'),
    );
    final gross = {..._anna.alsJson(), 'authid': 'Dora@example.test'};
    await expectLater(
      v.rufe(MitarbeiterVerwaltung.anlegen, [gross]),
      // Name, Grund und Wert an der richtigen Stelle
      abgelehnt(contains('(authid): nicht normiert: "Dora@example.test"')),
    );
    for (final (prozedur, argumente) in <(String, List<Object?>)>[
      (MitarbeiterVerwaltung.anlegen, []),
      (MitarbeiterVerwaltung.passwort, ['x']),
      (MitarbeiterVerwaltung.sperren, []),
      (MitarbeiterVerwaltung.entsperren, [1]),
    ]) {
      await expectLater(
        v.rufe(prozedur, argumente),
        abgelehnt(contains('unerwartete Argumente')),
        reason: prozedur,
      );
    }
    await expectLater(
      v.rufe(MitarbeiterVerwaltung.sperren, ['keine-adresse']),
      abgelehnt(contains('keine E-Mail-Adresse')),
    );
    expect(konten.finde('dora@example.test'), isNull);
  });

  test('Werkzeug findet den Auth-Server über PLANER_AUTH_LISTEN', () async {
    for (final u in [
      {
        'PLANER_AUTH_LISTEN': '0.0.0.0:${auth.port}',
        'PLANER_AUTH_DIENST_TICKET': testTicket,
      },
      {
        'PLANER_AUTH_ADRESSE': '127.0.0.1:${auth.port}',
        'PLANER_AUTH_LISTEN': '127.0.0.1:1',
        'PLANER_AUTH_DIENST_TICKET': testTicket,
      },
    ]) {
      final v = await MitarbeiterWerkzeug.verbinde(u);
      expect(await v.rufe(MitarbeiterVerwaltung.liste, []), isNotEmpty);
      await v.schliesse();
    }
    expect(
      () => MitarbeiterWerkzeug.verbinde({
        'PLANER_AUTH_ADRESSE': '127.0.0.1:${auth.port}',
      }),
      throwsA(isA<FormatException>()),
    );
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
