@Timeout(Duration(minutes: 3))
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:connectanum_client/connectanum.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

import 'hilfen.dart';

const _kundeEcho = '${Rollen.kundeUri}echo';

const _mitarbeiterEcho = '${Rollen.mitarbeiterUri}echo';

const _anna = 'anna@example.test';

/// Für den Sperr-Test, damit die übrigen Tests nicht gesperrt werden.
const _bob = 'bob@example.test';
const _carla = 'carla@example.test';

Uint8List _planung(int laenge) => Planung([
  Terrassenflaeche(
    Planungsstand(
      grundriss: RechteckGrundriss(Millimeter(laenge), const Millimeter(3000)),
    ),
  ),
]).zuBytes();

void main() {
  late PlanerRouter router;
  late Process authServer;
  late String authAdresse;
  late Datenbank db;
  late Directory ordner;
  late KonfigurationsDienst konfigurationen;

  setUpAll(() async {
    // Kleine Argon2id-Kosten, damit der Test schnell bleibt.
    Future<MitarbeiterZugang> zugang(String email) =>
        MitarbeiterZugang.ableiten(
          authId: email,
          passwort: 'richtig',
          iterationen: 1,
          speicher: 64,
        );
    authAdresse = await freieAdresse();
    authServer = await starteAuthServerProzess(
      listen: authAdresse,
      mitarbeiter: [
        for (final email in [_anna, _bob, _carla]) await zugang(email),
      ],
    );
    router = PlanerRouter.starte(
      await testEinstellungen(authAdresse: authAdresse),
    );
    await Future<void>.delayed(const Duration(milliseconds: 500));
    ordner = Directory.systemTemp.createTempSync('planer-zugriff-');
    db = Datenbank.oeffne('${ordner.path}/daten', knoten: 'k');
    konfigurationen = await KonfigurationsDienst.starte(
      router,
      Konfigurationsablage(db),
    );
    final dienst = await router.dienstSitzung('echo-dienst');
    for (final prozedur in [_kundeEcho, _mitarbeiterEcho]) {
      (await dienst.register(prozedur))
          .onInvoke((aufruf) => aufruf.respondWith(arguments: [prozedur]));
    }
  });

  tearDownAll(() async {
    await konfigurationen.stoppe();
    db.schliesse();
    ordner.deleteSync(recursive: true);
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
      // wie die App: FlatBuffers über WebSocket
      transport: WebSocketTransport.withFlatBuffersSerializer(
        'ws://127.0.0.1:${router.webSocketPort}/ws',
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
      final anna = await verbinde(authId: _anna, passwort: 'richtig');
      expect(anna.authRole, Rollen.mitarbeiter);
      expect(anna.authId, _anna);
      await anna.close();
    });

    test('darf Kunden- und Mitarbeiter-Prozeduren aufrufen', () async {
      final anna = await verbinde(authId: _anna, passwort: 'richtig');
      expect((await anna.callSingle(_kundeEcho)).arguments, [_kundeEcho]);
      expect((await anna.callSingle(_mitarbeiterEcho)).arguments, [
        _mitarbeiterEcho,
      ]);
      await anna.close();
    });

    test('falsches Passwort wird abgewiesen', () async {
      await expectLater(
        verbinde(authId: _anna, passwort: 'falsch'),
        throwsA(anything),
      );
    });

    test('unbekannter Mitarbeiter wird abgewiesen', () async {
      await expectLater(
        verbinde(authId: 'unbekannt@example.test', passwort: 'richtig'),
        throwsA(anything),
      );
    });

    test(
      'nach fünf Fehlversuchen gesperrt, auch mit richtigem Passwort',
      () async {
        expect(RouterEinstellungen.anmeldeGrenzen.maxFailedAuth, 5);
        expect(RouterEinstellungen.anmeldeGrenzen.lockoutMs, 900000);
        for (var i = 0; i < 4; i++) {
          await expectLater(
            verbinde(authId: _bob, passwort: 'falsch'),
            throwsA(anything),
          );
        }
        // ein Erfolg vor der Grenze setzt den Zähler zurück
        await (await verbinde(authId: _bob, passwort: 'richtig')).close();
        for (var i = 0; i < 5; i++) {
          await expectLater(
            verbinde(authId: _bob, passwort: 'falsch'),
            throwsA(anything),
          );
        }
        await expectLater(
          verbinde(authId: _bob, passwort: 'richtig'),
          throwsA(anything),
        );
        // andere Konten bleiben frei
        await (await verbinde(authId: _anna, passwort: 'richtig')).close();
      },
    );

    test(
      'gesperrtes Konto wird abgewiesen, entsperrt wieder zugelassen',
      () async {
        final verwaltung = await MitarbeiterWerkzeug.verbinde({
          'PLANER_AUTH_ADRESSE': authAdresse,
          'PLANER_AUTH_DIENST_TICKET': testTicket,
        });
        addTearDown(verwaltung.schliesse);
        await verwaltung.rufe(MitarbeiterVerwaltung.sperren, [_carla]);
        await expectLater(
          verbinde(authId: _carla, passwort: 'richtig'),
          throwsA(anything),
        );
        await verwaltung.rufe(MitarbeiterVerwaltung.entsperren, [_carla]);
        await (await verbinde(authId: _carla, passwort: 'richtig')).close();
      },
    );
  });

  group('Laden ohne Prüfcode (M9-10)', () {
    test('Mitarbeiter laden mit Nummer allein, Kunden nicht', () async {
      final kunde = await verbinde();
      final [kennung as String, _] = (await kunde.callSingle(
        WampNamen.konfigurationSpeichern,
        arguments: [_planung(4000)],
      )).arguments!;
      final nummer = kennung.substring(0, 15);
      await expectLater(
        kunde.callSingle(WampNamen.konfigurationLaden, arguments: [nummer, 1]),
        throwsA(anything),
      );
      await kunde.close();

      final anna = await verbinde(authId: _anna, passwort: 'richtig');
      for (final text in [nummer, '$nummer-AAAAA', kennung]) {
        final antwort = await anna.callSingle(
          WampNamen.konfigurationLaden,
          arguments: [text, 1],
        );
        // vollständige Kennung zurück, damit SPEICHERN weiterführen kann
        expect(antwort.arguments, [_planung(4000), kennung], reason: text);
      }
      await expectLater(
        anna.callSingle(WampNamen.konfigurationLaden, arguments: [nummer, 2]),
        throwsA(anything),
      );
      await anna.close();
    });
  });
}
