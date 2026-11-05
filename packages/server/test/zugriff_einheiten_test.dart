import 'dart:convert';
import 'dart:math';

import 'package:connectanum_router/connectanum_router.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

void main() {
  group('MitarbeiterZugang', () {
    test(
      'leitet SCRAM-Schlüssel mit Argon2id aus Passwort und Salt ab',
      () async {
        final zugang = await MitarbeiterZugang.ableiten(
          authId: 'anna@example.test',
          passwort: 'geheim',
          iterationen: 1,
          speicher: 8,
          zufall: Random(1),
        );
        final erwartet = ScramAuthentication.deriveServerSecrets(
          secret: 'geheim',
          salt: zugang.salt,
          kdf: ScramAuthentication.kdfArgon,
          iterations: 1,
          memory: 8,
        );
        expect(zugang.authId, 'anna@example.test');
        expect(zugang.kdf, 'argon2id13');
        expect(zugang.iterationen, 1);
        expect(zugang.speicher, 8);
        expect(zugang.gesperrt, isFalse);
        expect(base64.decode(zugang.salt), hasLength(16));
        expect(zugang.storedKey, erwartet.storedKey);
        expect(zugang.serverKey, erwartet.serverKey);
        expect(zugang.alsJson().values, isNot(contains('geheim')));
      },
    );

    test('verschiedene Zufallsquellen ergeben verschiedene Salts', () async {
      Future<MitarbeiterZugang> mit(int saat) => MitarbeiterZugang.ableiten(
        authId: 'a',
        passwort: 'x',
        iterationen: 1,
        speicher: 8,
        zufall: Random(saat),
      );
      expect((await mit(1)).salt, isNot((await mit(2)).salt));
    });

    test('Standard: Argon2id nach OWASP, sichere Zufallsquelle', () async {
      expect(MitarbeiterZugang.standardIterationen, 2);
      expect(MitarbeiterZugang.standardSpeicher, 19456);
      const z = MitarbeiterZugang(
        authId: 'a',
        salt: 's',
        storedKey: 'k',
        serverKey: 'v',
      );
      expect(
        [z.kdf, z.iterationen, z.speicher, z.gesperrt],
        ['argon2id13', 2, 19456, false],
      );
      final zugang = await MitarbeiterZugang.ableiten(
        authId: 'a',
        passwort: 'x',
      );
      expect(zugang.iterationen, 2);
      expect(zugang.speicher, 19456);
      final erwartet = ScramAuthentication.deriveServerSecrets(
        secret: 'x',
        salt: zugang.salt,
        kdf: ScramAuthentication.kdfArgon,
        iterations: 2,
        memory: 19456,
      );
      expect(zugang.storedKey, erwartet.storedKey);
    });

    test('JSON hin und zurück (ohne Sperre)', () {
      const zugang = MitarbeiterZugang(
        authId: 'anna@example.test',
        salt: 'c2FsdA==',
        kdf: 'pbkdf2',
        iterationen: 7,
        speicher: 0,
        storedKey: 'sk',
        serverKey: 'svk',
        gesperrt: true,
      );
      final json = zugang.alsJson();
      expect(json, {
        'authid': 'anna@example.test',
        'salt': 'c2FsdA==',
        'kdf': 'pbkdf2',
        'iterationen': 7,
        'speicher': 0,
        'stored_key': 'sk',
        'server_key': 'svk',
      });
      final zurueck = MitarbeiterZugang.ausJson(json);
      expect(zurueck.alsJson(), json);
      expect(zurueck.gesperrt, isFalse);
    });

    test('E-Mail-Adresse als Anmeldename', () {
      expect(
        MitarbeiterZugang.email('  Anna.Muster@Example.TEST '),
        'anna.muster@example.test',
      );
      for (final falsch in [
        '',
        'anna',
        'anna@',
        '@example.test',
        'anna@example',
        'an na@example.test',
        'anna@@example.test',
        'anna@example.test x',
      ]) {
        expect(
          () => MitarbeiterZugang.email(falsch),
          throwsA(
            isA<ArgumentError>()
                .having((e) => e.invalidValue, 'wert', falsch)
                .having((e) => e.message, 'meldung', 'keine E-Mail-Adresse'),
          ),
          reason: falsch,
        );
      }
    });
  });

  group('PlanerZugangsdaten', () {
    late Datenbank db;
    late Mitarbeiterkonten konten;
    late PlanerZugangsdaten daten;
    var nr = 0;
    const anna = MitarbeiterZugang(
      authId: 'anna@example.test',
      salt: 'salz',
      iterationen: 3,
      speicher: 64,
      storedKey: 'stored',
      serverKey: 'server',
    );

    setUp(() {
      db = Datenbank.oeffne('memory:zugangsdaten-${nr++}', knoten: 'k');
      konten = Mitarbeiterkonten(db)..anlegen(anna);
      daten = PlanerZugangsdaten(realm: 'planer', konten: konten);
    });

    tearDown(() => db.schliesse());

    test('liefert SCRAM-Zugang mit Rolle mitarbeiter', () async {
      final c = (await daten.loadScram(
        realmUri: 'planer',
        authId: 'anna@example.test',
      ))!;
      expect(c.storedKey, 'stored');
      expect(c.serverKey, 'server');
      expect(c.salt, 'salz');
      expect(c.kdf, 'argon2id13');
      expect(c.iterations, 3);
      expect(c.memory, 64);
      expect(c.role, Rollen.mitarbeiter);
      expect(c.provider, 'planer');
      expect(c.secret, isNull);
      expect(daten.konten, same(konten));
    });

    test('anderer Realm, unbekannt oder gesperrt ergibt nichts', () async {
      expect(
        await daten.loadScram(realmUri: 'anders', authId: anna.authId),
        isNull,
      );
      expect(
        await daten.loadScram(realmUri: 'planer', authId: 'bob@example.test'),
        isNull,
      );
      konten.sperre(anna.authId, gesperrt: true);
      expect(
        await daten.loadScram(realmUri: 'planer', authId: anna.authId),
        isNull,
      );
      konten.sperre(anna.authId, gesperrt: false);
      expect(
        await daten.loadScram(realmUri: 'planer', authId: anna.authId),
        isNotNull,
      );
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
