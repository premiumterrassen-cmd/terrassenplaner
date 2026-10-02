import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:connectanum_router/connectanum_router.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

void main() {
  group('MitarbeiterZugang', () {
    test('leitet SCRAM-Schlüssel aus Passwort und Salt ab', () async {
      final zugang = await MitarbeiterZugang.ableiten(
        authId: 'anna',
        passwort: 'geheim',
        iterationen: 4096,
        zufall: Random(1),
      );
      final erwartet = ScramAuthentication.deriveServerSecrets(
        secret: 'geheim',
        salt: zugang.salt,
        iterations: 4096,
      );
      expect(zugang.authId, 'anna');
      expect(zugang.iterationen, 4096);
      expect(base64.decode(zugang.salt), hasLength(16));
      expect(zugang.storedKey, erwartet.storedKey);
      expect(zugang.serverKey, erwartet.serverKey);
      expect(zugang.alsJson().values, isNot(contains('geheim')));
    });

    test('verschiedene Zufallsquellen ergeben verschiedene Salts', () async {
      final a = await MitarbeiterZugang.ableiten(
        authId: 'a',
        passwort: 'x',
        iterationen: 4096,
        zufall: Random(1),
      );
      final b = await MitarbeiterZugang.ableiten(
        authId: 'a',
        passwort: 'x',
        iterationen: 4096,
        zufall: Random(2),
      );
      expect(a.salt, isNot(b.salt));
    });

    test(
      'ohne Angabe: sichere Zufallsquelle und Standard-Iterationen',
      () async {
        final zugang = await MitarbeiterZugang.ableiten(
          authId: 'a',
          passwort: 'x',
        );
        expect(zugang.iterationen, MitarbeiterZugang.standardIterationen);
        expect(MitarbeiterZugang.standardIterationen, 100000);
      },
    );

    test('JSON hin und zurück', () {
      const zugang = MitarbeiterZugang(
        authId: 'anna',
        salt: 'c2FsdA==',
        iterationen: 7,
        storedKey: 'sk',
        serverKey: 'svk',
      );
      final json = zugang.alsJson();
      expect(json, {
        'authid': 'anna',
        'salt': 'c2FsdA==',
        'iterationen': 7,
        'stored_key': 'sk',
        'server_key': 'svk',
      });
      final zurueck = MitarbeiterZugang.ausJson(json);
      expect(zurueck.alsJson(), json);
    });
  });

  group('MitarbeiterVerzeichnis', () {
    const anna = MitarbeiterZugang(
      authId: 'anna',
      salt: 's',
      iterationen: 1,
      storedKey: 'a',
      serverKey: 'b',
    );

    test('findet Zugänge nach authid', () {
      final v = MitarbeiterVerzeichnis([anna]);
      expect(v.finde('anna'), same(anna));
      expect(v.finde('bob'), isNull);
      expect(v.anzahl, 1);
    });

    test('leeres Verzeichnis', () {
      final v = MitarbeiterVerzeichnis.leer();
      expect(v.anzahl, 0);
      expect(v.finde('anna'), isNull);
    });

    test('liest eine JSON-Datei', () {
      final ordner = Directory.systemTemp.createTempSync('mitarbeiter');
      addTearDown(() => ordner.deleteSync(recursive: true));
      final datei = File('${ordner.path}/mitarbeiter.json')
        ..writeAsStringSync(jsonEncode([anna.alsJson()]));
      final v = MitarbeiterVerzeichnis.ausDatei(datei.path);
      expect(v.anzahl, 1);
      expect(v.finde('anna')!.alsJson(), anna.alsJson());
    });
  });

  group('PlanerZugangsdaten', () {
    const anna = MitarbeiterZugang(
      authId: 'anna',
      salt: 'salz',
      iterationen: 4096,
      storedKey: 'stored',
      serverKey: 'server',
    );
    final daten = PlanerZugangsdaten(
      realm: 'planer',
      verzeichnis: MitarbeiterVerzeichnis([anna]),
    );

    test('liefert SCRAM-Zugang mit Rolle mitarbeiter', () async {
      final c = (await daten.loadScram(realmUri: 'planer', authId: 'anna'))!;
      expect(c.storedKey, 'stored');
      expect(c.serverKey, 'server');
      expect(c.salt, 'salz');
      expect(c.iterations, 4096);
      expect(c.role, Rollen.mitarbeiter);
      expect(c.provider, 'planer');
      expect(c.secret, isNull);
    });

    test('anderer Realm oder unbekannte authid ergibt nichts', () async {
      expect(await daten.loadScram(realmUri: 'anders', authId: 'anna'), isNull);
      expect(await daten.loadScram(realmUri: 'planer', authId: 'bob'), isNull);
    });
  });

  group('Rollen', () {
    final rollen = {for (final r in Rollen.alle()) r.build().name: r.build()};

    test('Rollennamen und URI-Bereiche', () {
      expect(Rollen.kunde, 'anonymous');
      expect(Rollen.mitarbeiter, 'mitarbeiter');
      expect(Rollen.dienst, 'dienst');
      expect(Rollen.kundeUri, 'de.robinienwelt.terrassenplaner.kunde.');
      expect(
        Rollen.mitarbeiterUri,
        'de.robinienwelt.terrassenplaner.mitarbeiter.',
      );
      expect(rollen.keys, ['anonymous', 'mitarbeiter', 'dienst']);
    });

    test('Kunde: nur Kunden-Bereich nutzen', () {
      final recht = rollen['anonymous']!.permissions.single;
      expect(recht.uri, Rollen.kundeUri);
      expect(recht.matchPolicy, PermissionMatchPolicy.prefix);
      expect(recht.allow, ['call', 'subscribe']);
    });

    test('Mitarbeiter: Kunden- und Mitarbeiter-Bereich nutzen', () {
      final rechte = rollen['mitarbeiter']!.permissions;
      expect(rechte.map((r) => r.uri), [
        Rollen.kundeUri,
        Rollen.mitarbeiterUri,
      ]);
      for (final r in rechte) {
        expect(r.allow, ['call', 'subscribe']);
        expect(r.matchPolicy, PermissionMatchPolicy.prefix);
      }
    });

    test('Dienst: im ganzen Planer-Bereich anbieten', () {
      final recht = rollen['dienst']!.permissions.single;
      expect(recht.uri, Rollen.uriBasis);
      expect(recht.matchPolicy, PermissionMatchPolicy.prefix);
      expect(recht.allow, [
        'register',
        'unregister',
        'publish',
        'call',
        'subscribe',
      ]);
    });
  });
}
