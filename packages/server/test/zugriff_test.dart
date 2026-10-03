@Timeout(Duration(minutes: 3))
library;

import 'dart:async';
import 'dart:io';

import 'package:connectanum_client/connectanum.dart';
import 'package:connectanum_client/json.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

import 'hilfen.dart';

const _kundeEcho = '${Rollen.kundeUri}echo';

const _mitarbeiterEcho = '${Rollen.mitarbeiterUri}echo';

void main() {
  late PlanerRouter router;
  late Process authServer;

  setUpAll(() async {
    final zugang = await MitarbeiterZugang.ableiten(
      authId: 'anna',
      passwort: 'richtig',
      iterationen: 4096,
    );
    final authAdresse = await freieAdresse();
    authServer = await starteAuthServerProzess(
      listen: authAdresse,
      mitarbeiter: [zugang],
    );
    router = PlanerRouter.starte(
      await testEinstellungen(authAdresse: authAdresse),
    );
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final dienst = await router.dienstSitzung('echo-dienst');
    for (final prozedur in [_kundeEcho, _mitarbeiterEcho]) {
      (await dienst.register(prozedur))
          .onInvoke((aufruf) => aufruf.respondWith(arguments: [prozedur]));
    }
  });

  tearDownAll(() async {
    await router.stoppe();
    authServer.kill(ProcessSignal.sigterm);
    await authServer.exitCode;
  });

  Future<Session> verbinde({String? authId, String? passwort}) {
    final client = Client(
      realm: RouterEinstellungen.standardRealm,
      authId: authId,
      authenticationMethods: passwort == null
          ? null
          : [ScramAuthentication(passwort)],
      transport: WebSocketTransport(
        'ws://127.0.0.1:${router.webSocketPort}/ws',
        Serializer(),
        WebSocketSerialization.serializationJson,
      ),
    );
    return client
        .connect(options: ClientConnectOptions(reconnectCount: 0))
        .first
        .timeout(const Duration(seconds: 20));
  }

  group('Kunde (anonym)', () {
    test('erhält die Rolle kunde', () async {
      final kunde = await verbinde();
      expect(kunde.authRole, Rollen.kunde);
      await kunde.close();
    });

    test('darf Kunden-Prozeduren aufrufen', () async {
      final kunde = await verbinde();
      final ergebnis = await kunde.callSingle(_kundeEcho);
      expect(ergebnis.arguments, [_kundeEcho]);
      await kunde.close();
    });

    test('darf keine Mitarbeiter-Prozeduren aufrufen', () async {
      final kunde = await verbinde();
      await expectLater(kunde.callSingle(_mitarbeiterEcho), throwsA(anything));
      await kunde.close();
    });

    test('darf keine Prozeduren registrieren', () async {
      final kunde = await verbinde();
      await expectLater(
        kunde.register('${Rollen.kundeUri}fremd'),
        throwsA(anything),
      );
      await kunde.close();
    });
  });

  group('Mitarbeiter (SCRAM über den Auth-Server)', () {
    test('richtiges Passwort ergibt die Rolle mitarbeiter', () async {
      final anna = await verbinde(authId: 'anna', passwort: 'richtig');
      expect(anna.authRole, Rollen.mitarbeiter);
      expect(anna.authId, 'anna');
      await anna.close();
    });

    test('darf Kunden- und Mitarbeiter-Prozeduren aufrufen', () async {
      final anna = await verbinde(authId: 'anna', passwort: 'richtig');
      expect((await anna.callSingle(_kundeEcho)).arguments, [_kundeEcho]);
      expect((await anna.callSingle(_mitarbeiterEcho)).arguments, [
        _mitarbeiterEcho,
      ]);
      await anna.close();
    });

    test('falsches Passwort wird abgewiesen', () async {
      await expectLater(
        verbinde(authId: 'anna', passwort: 'falsch'),
        throwsA(anything),
      );
    });

    test('unbekannter Mitarbeiter wird abgewiesen', () async {
      await expectLater(
        verbinde(authId: 'unbekannt', passwort: 'richtig'),
        throwsA(anything),
      );
    });
  });
}
