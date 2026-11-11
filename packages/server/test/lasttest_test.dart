@Timeout(Duration(minutes: 3))
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:connectanum_client/connectanum.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

import 'hilfen.dart';

void main() {
  group('Lastdaten', () {
    test('Artikeldatei übersteht JSON wie beim Server (artikel.json)', () {
      final datei = Artikeldatei.ausJson(
        jsonDecode(jsonEncode(Lastdaten.artikeldatei.alsJson()))
            as Map<String, Object?>,
        [robinie],
      );
      expect(datei.version, 'lasttest-1');
      expect(datei.quelle, 'lasttest');
      expect(datei.eintraege, hasLength(4));
      expect(datei[Lastdaten.diele.nummer]!.angaben, {'Abstand_UK': 400});
    });

    test('typische und große Planung', () {
      final typisch = Lastdaten.typisch();
      expect(typisch.flaechen, hasLength(3));
      expect(typisch.aktiv, 2);
      expect(typisch.flaechen.last.haeufigkeit, 2);
      expect(
        (typisch.flaechen.last.stand.grundriss as RechteckGrundriss).ab,
        const Millimeter(5400),
      );
      expect(
        (Lastdaten.typisch(5500).flaechen.last.stand.grundriss
                as RechteckGrundriss)
            .ab,
        const Millimeter(5500),
      );
      final gross = Lastdaten.gross();
      expect(gross.flaechen, hasLength(10));
      expect(gross.flaechen.map((f) => f.haeufigkeit), everyElement(10));
      expect(gross.verschnittvariante, Planung.hoechsteVerschnittvariante);
      expect(Lastdaten.freiform.kontur.flaeche, closeTo(86.25e6, 1e-3));
      expect(Lastdaten.freiform.verlegeart, Verlegeart.halbverband);
      final klein = Lastdaten.gross(flaechen: 2, haeufigkeit: 3);
      expect(klein.flaechen, hasLength(2));
      expect(klein.flaechen.first.haeufigkeit, 3);
    });
  });

  test('Lastdaten sind fest (wiederholbare Messungen)', () {
    expect(Lastdaten.diele.nummer.wert, '10-10-073');
    expect(Lastdaten.diele.titel, 'Terrassendiele Robinie 60 x 21 mm, genutet');
    expect(Lastdaten.diele.preisBrutto, const Cent(449));
    expect(Lastdaten.unterkonstruktion.nummer.wert, '10-10-031');
    expect(
      Lastdaten.unterkonstruktion.titel,
      'Unterkonstruktionsholz Robinie 45 x 60 mm',
    );
    expect(Lastdaten.unterkonstruktion.preisBrutto, const Cent(979));
    final eintraege = Lastdaten.artikeldatei.eintraege;
    expect(
      [for (final e in eintraege) e.artikel.nummer.wert],
      ['10-10-073', '10-10-031', '50-60-005', '60-55-136'],
    );
    expect(
      [for (final e in eintraege) e.artikel.preisBrutto],
      [const Cent(449), const Cent(979), const Cent(2500), const Cent(2500)],
    );
    expect(eintraege[1].angaben, {'Abstand_Stelzfuesse': 600});
    expect(eintraege[2].angaben, {'MinHoehe': 5, 'MaxHoehe': 5});
    expect(eintraege[3].angaben, {'MinHoehe': 55, 'MaxHoehe': 95});
    expect(eintraege[2].artikel.titel, 'Artikel 50-60-005');
    expect(
      (Lastdaten.typisch().flaechen.last.stand.grundriss as RechteckGrundriss)
          .bc,
      const Millimeter(3000),
    );
  });

  group('Lastprofil und Szenarien', () {
    test('Pausen streuen um die Denkzeit, Versatz bis zu einer Denkzeit', () {
      const p = Lastprofil(
        name: 'p',
        sitzungen: 1,
        dauer: Duration.zero,
        schritte: [],
        denkzeit: Duration(seconds: 2),
      );
      final zufall = Random(1);
      for (var i = 0; i < 200; i++) {
        final pause = p.pause(zufall);
        expect(pause, greaterThanOrEqualTo(const Duration(seconds: 1)));
        expect(pause, lessThan(const Duration(seconds: 3)));
        final versatz = p.versatz(zufall);
        expect(versatz, greaterThanOrEqualTo(Duration.zero));
        expect(versatz, lessThan(const Duration(seconds: 2)));
      }
      expect(p.pause(_Fest(0)), const Duration(seconds: 1));
      expect(p.pause(_Fest(0.5)), const Duration(seconds: 2));
      expect(p.versatz(_Fest(0.5)), const Duration(seconds: 1));
      const ohne = Lastprofil(
        name: 'o',
        sitzungen: 1,
        dauer: Duration.zero,
        schritte: [],
      );
      expect(ohne.denkzeit, Duration.zero);
      expect(ohne.pause(zufall), Duration.zero);
    });

    test('vier Szenarien, Sitzungen mit dem Faktor skaliert (aufgerundet)', () {
      final s = Lasttest.szenarien();
      expect(s.map((e) => e.name), [
        'nutzer',
        'sitzungen',
        'gross',
        'durchsatz',
      ]);
      expect(
        [
          for (final e in s)
            for (final p in e.profile)
              (p.name, p.sitzungen, p.dauer, p.denkzeit),
        ],
        [
          (
            'nutzer',
            50,
            const Duration(seconds: 60),
            const Duration(seconds: 1),
          ),
          (
            'sitzungen',
            100,
            const Duration(seconds: 60),
            const Duration(seconds: 5),
          ),
          ('gross', 2, const Duration(seconds: 60), Duration.zero),
          (
            'nebenher',
            20,
            const Duration(seconds: 60),
            const Duration(seconds: 1),
          ),
          ('durchsatz', 100, const Duration(seconds: 60), Duration.zero),
        ],
      );
      expect(s[0].profile.single.schritte, Lasttest.bedienrunde);
      expect(s[2].profile.first.schritte, [Vorgang.berechnenGross]);
      expect(s[3].profile.single.schritte, [Vorgang.hallo]);
      expect(s[0].beschreibung, startsWith('50 gleichzeitig'));
      expect(s[1].beschreibung, startsWith('100 verbundene'));
      expect(s[2].beschreibung, startsWith('2 Sitzungen'));
      expect(s[2].beschreibung, contains(', 20 Nutzer'));
      expect(s[3].beschreibung, startsWith('100 Sitzungen'));
      final klein = Lasttest.szenarien(
        dauer: const Duration(seconds: 3),
        faktor: 0.011,
      );
      expect(
        [
          for (final e in klein)
            for (final p in e.profile) p.sitzungen,
        ],
        [1, 2, 1, 1, 2],
      );
      expect(klein.first.profile.single.dauer, const Duration(seconds: 3));
      expect(Lasttest.bedienrunde, [
        Vorgang.berechnen,
        Vorgang.berechnen,
        Vorgang.berechnen,
        Vorgang.entwurf,
        Vorgang.speichern,
        Vorgang.laden,
      ]);
    });

    test('Vorgaben und Zusammenfassung je Profil', () {
      expect(Lastlauf.standardZeitlimit, const Duration(seconds: 60));
      expect(Lasttest.abtastTakt, const Duration(milliseconds: 250));
      Lastergebnis ergebnis(String? fehler) => Lastergebnis(
        profil: const Lastprofil(
          name: 'p',
          sitzungen: 1,
          dauer: Duration.zero,
          schritte: [Vorgang.hallo],
        ),
        laufzeit: const Duration(seconds: 2),
        zeiten: {
          Vorgang.hallo: const [Duration.zero, Duration.zero, Duration.zero],
        },
        fehler: const {Vorgang.hallo: 1},
        ersterFehler: fehler,
      );
      expect(
        Lasttest.zeile(ergebnis('hallo: weg')),
        '   p: 3 Aufrufe, 1 Fehler, 1.5/s (hallo: weg)',
      );
      expect(
        Lasttest.zeile(ergebnis(null)),
        '   p: 3 Aufrufe, 1 Fehler, 1.5/s',
      );
    });

    test('Kerne und Durchsatz', () {
      expect(
        Lasttest.kerne(const Duration(seconds: 3), const Duration(seconds: 2)),
        1.5,
      );
      expect(
        Lasttest.kerne(
          const Duration(milliseconds: 1234),
          const Duration(seconds: 1),
        ),
        1.23,
      );
      final leer = Lastergebnis(
        profil: const Lastprofil(
          name: 'x',
          sitzungen: 1,
          dauer: Duration.zero,
          schritte: [],
        ),
        laufzeit: Duration.zero,
        zeiten: const {},
        fehler: const {},
      );
      expect(leer.durchsatz, 0);
      expect(leer.aufrufe, 0);
      expect(leer.alsJson(), {
        'profil': 'x',
        'sitzungen': 1,
        'denkzeit_ms': 0,
        'laufzeit_s': 0.0,
        'aufrufe': 0,
        'fehler': 0,
        'durchsatz_je_s': 0.0,
        'vorgaenge': <String, Object?>{},
      });
    });
  });

  group('gegen den Planer-Router', () {
    late Directory ordner;
    late Datenbank db;
    late PlanerRouter router;
    late List<Future<void> Function()> stopp;
    late String url;

    Future<Session> verbinde() => Client(
      realm: WampNamen.realm,
      transport: WebSocketTransport.withFlatBuffersSerializer(url),
    ).connect().first.timeout(const Duration(seconds: 20));

    setUp(() async {
      ordner = Directory.systemTemp.createTempSync('planer-lasttest-');
      db = Datenbank.oeffne('${ordner.path}/daten', knoten: 'last');
      router = PlanerRouter.starte(await testEinstellungen());
      url = 'ws://127.0.0.1:${router.webSocketPort}/ws';
      stopp = [];
    });

    tearDown(() async {
      for (final s in stopp.reversed) {
        await s();
      }
      await router.stoppe();
      db.schliesse();
      ordner.deleteSync(recursive: true);
    });

    Future<void> starteDienste() async {
      final hallo = await HalloDienst.starte(router);
      final artikel = await ArtikelDienst.starte(
        router,
        Lastdaten.artikeldatei,
      );
      final planung = await PlanungsDienst.starte(
        router,
        belag: artikel.belag,
        regelwerk: () => artikel.regelwerk,
        unterkonstruktion: (s) =>
            artikel.unterkonstruktion(s.belag, s.unterkonstruktion),
      );
      final konfiguration = await KonfigurationsDienst.starte(
        router,
        Konfigurationsablage(db),
      );
      stopp.addAll([
        hallo.stoppe,
        artikel.stoppe,
        planung.stoppe,
        konfiguration.stoppe,
      ]);
    }

    test('die Lastdaten ergeben eine vollständige Berechnung', () async {
      await starteDienste();
      final s = await verbinde();
      final b = await Lastlauf.berechne(s, Lastdaten.typisch().zuBytes());
      final nummern = [
        for (final p in b.materialliste.positionen) p.nummer.wert,
      ];
      expect(nummern, contains(startsWith(Lastdaten.diele.nummer.wert)));
      expect(
        nummern,
        contains(startsWith(Lastdaten.unterkonstruktion.nummer.wert)),
      );
      await Lastlauf.schliesse(s);
    });

    test('Schließen einer getrennten Sitzung ist kein Fehler', () async {
      var aufgerufen = 0;
      await Lastlauf.ohneGeschlossenFehler(() async {
        aufgerufen++;
        throw StateError('WebSocket transport is not open.');
      });
      await Lastlauf.ohneGeschlossenFehler(() async => aufgerufen++);
      expect(aufgerufen, 2);
      await expectLater(
        Lastlauf.ohneGeschlossenFehler(() async => throw ArgumentError('x')),
        throwsArgumentError,
      );
    });

    test('fährt die Szenarien und meldet Ergebnisse und Zielwerte', () async {
      await starteDienste();
      final zeilen = <String>[];
      // Lastwerkzeug mit fester Messung: je Abfrage 1 s CPU mehr. `ps` misst
      // unter Linux nur ganze Sekunden, zwei echte Messungen desselben
      // Prozesses streuen in kurzen Läufen um bis zu eine Sekunde.
      var lastSekunden = 0;
      final bericht = await Lasttest.fuehreAus(
        Lauf(
          url: url,
          dauer: const Duration(milliseconds: 1500),
          faktor: 0.02,
          szenarien: const ['nutzer', 'gross', 'durchsatz'],
        ),
        verbinde,
        messe: () => Prozessmessung.lies(pid),
        messeLast: () async => Prozessmessung(
          speicherKb: 1,
          cpuZeit: Duration(seconds: lastSekunden++),
        ),
        melde: zeilen.add,
        // ein Stau im Router (connectanum, docs/abnahme/lasttest.md) darf
        // den Test nicht minutenlang aufhalten
        zeitlimit: const Duration(seconds: 10),
      );
      expect(bericht.ergebnisse.map((e) => e.szenario.name), [
        'nutzer',
        'gross',
        'durchsatz',
      ]);
      for (final e in bericht.ergebnisse) {
        // jedes Profil hat gearbeitet; Fehler zählt der Test nicht, weil
        // ein connectanum-Stau sie verursachen kann
        expect(
          e.ergebnisse.map((p) => p.aufrufe + p.fehlerSumme),
          everyElement(greaterThan(0)),
        );
        expect(e.speicherVorherMb, greaterThan(1));
        expect(e.speicherSpitzeMb, greaterThanOrEqualTo(e.speicherVorherMb!));
        expect(e.cpuKerne, greaterThanOrEqualTo(0));
        expect(e.lastCpuKerne, greaterThan(0));
      }
      final nutzer = bericht.ergebnisse.first.profil('nutzer');
      expect(
        nutzer.statistik.keys,
        unorderedEquals(Lasttest.bedienrunde.toSet()),
      );
      expect(nutzer.durchsatz, greaterThanOrEqualTo(0));
      final gross = bericht.ergebnisse[1];
      expect(gross.profil('gross').statistik.keys, [Vorgang.berechnenGross]);
      expect(bericht.ergebnisse.last.profil('durchsatz').statistik.keys, [
        Vorgang.hallo,
      ]);
      expect(zeilen, contains(startsWith('== nutzer: 1 gleichzeitig')));
      expect(zeilen, contains(startsWith('   nutzer: ')));
      expect(zeilen, contains(startsWith('     berechnen: p50 ')));
      expect(zeilen, contains(startsWith('   Server: Speicher ')));
      expect(zeilen, contains(contains('Lastwerkzeug CPU')));
      expect(zeilen, isNot(contains(startsWith('== sitzungen'))));
      expect(
        zeilen.where((z) => z.contains('nutzer.berechnen')).single,
        anyOf(startsWith('ok     nutzer.berechnen: '), startsWith('VERFEHLT')),
      );
      expect(
        bericht.zielwerte.map((z) => z.kennung),
        contains('durchsatz.aufrufe'),
      );
      expect(
        bericht.zielwerteErreicht,
        bericht.zielwerte.every((z) => z.erreicht),
      );
      final json = bericht.alsJson();
      expect(json.keys, [
        'erstellt',
        'messrechner',
        'faktor_zielserver',
        'zielwerte_erreicht',
        'zielwerte',
        'szenarien',
      ]);
      expect(
        (json['messrechner']! as Map)['kerne'],
        Platform.numberOfProcessors,
      );
      expect(json['faktor_zielserver'], Zielwerte.faktor);
      final szenario =
          (json['szenarien']! as List).first as Map<String, Object?>;
      expect(szenario['szenario'], 'nutzer');
      expect(szenario.keys, containsAll(['speicher_spitze_mb', 'cpu_kerne']));
      final profil = (szenario['profile']! as List).single as Map;
      expect(
        ((profil['vorgaenge']! as Map)['berechnen']! as Map)['fehler'],
        nutzer.fehler[Vorgang.berechnen] ?? 0,
      );
      // ohne Auswahl alle Szenarien; JSON ist kodierbar
      expect(jsonEncode(json), isNotEmpty);
      expect(
        Lastbericht(
          const [],
          erstellt: DateTime(2026, 11, 7),
        ).alsJson()['erstellt'],
        '2026-11-07T00:00:00.000',
      );
    });

    test('Bedienschritte rufen die Dienste richtig auf', () async {
      await starteDienste();
      final e = await Lastlauf.fahre(
        const Lastprofil(
          name: 'schritte',
          sitzungen: 1,
          // Dauer null: genau eine Runde, unabhängig vom Takt des Rechners
          dauer: Duration.zero,
          // LADEN ohne gespeicherte Version speichert zuerst
          schritte: [Vorgang.laden, Vorgang.entwurf, Vorgang.speichern],
        ),
        verbinde,
        zeitlimit: const Duration(seconds: 10),
      );
      expect(e.ersterFehler, isNull);
      expect(e.fehlerSumme, 0);
      expect(
        [for (final v in e.profil.schritte) e.statistik[v]!.anzahl],
        [1, 1, 1],
      );
      // eine Sitzung, Schritte nacheinander: zusammen nicht länger als der Lauf
      final summe = [for (final v in e.profil.schritte) e.statistik[v]!.hoechst]
          .fold(Duration.zero, (a, b) => a + b);
      expect(summe, lessThanOrEqualTo(e.laufzeit));
    });

    test('Fehler werden je Vorgang gezählt, der erste mit Text', () async {
      final hallo = await HalloDienst.starte(router);
      stopp.add(hallo.stoppe);
      final e = await Lastlauf.fahre(
        const Lastprofil(
          name: 'ohne-dienste',
          sitzungen: 2,
          dauer: Duration(milliseconds: 100),
          schritte: [Vorgang.hallo, Vorgang.berechnen, Vorgang.laden],
        ),
        verbinde,
        zeitlimit: const Duration(seconds: 10),
      );
      expect(e.statistik[Vorgang.berechnen]!.anzahl, 0);
      expect(e.fehler[Vorgang.berechnen], greaterThanOrEqualTo(2));
      expect(e.fehler[Vorgang.laden], greaterThanOrEqualTo(2));
      expect(e.fehlerSumme, greaterThanOrEqualTo(4));
      expect(e.ersterFehler, startsWith('berechnen: '));
      expect(e.alsJson()['erster_fehler'], e.ersterFehler);
      // Zeitlimit je Aufruf
      final langsam = await Lastlauf.fahre(
        const Lastprofil(
          name: 'zeitlimit',
          sitzungen: 1,
          dauer: Duration(milliseconds: 50),
          schritte: [Vorgang.hallo],
        ),
        verbinde,
        zeitlimit: Duration.zero,
      );
      expect(langsam.fehler[Vorgang.hallo], greaterThanOrEqualTo(1));
      expect(langsam.statistik[Vorgang.hallo]!.anzahl, 0);
      expect(langsam.ersterFehler, contains('TimeoutException'));
    });

    test('ohne Meldefunktion still, nur gewählte Szenarien', () async {
      final hallo = await HalloDienst.starte(router);
      stopp.add(hallo.stoppe);
      final bericht = await Lasttest.fuehreAus(
        Lauf(
          url: url,
          dauer: const Duration(milliseconds: 100),
          faktor: 0.01,
          szenarien: const ['durchsatz'],
        ),
        verbinde,
        zeitlimit: const Duration(seconds: 10),
      );
      expect(bericht.ergebnisse.single.szenario.name, 'durchsatz');
      expect(bericht.ergebnisse.single.profil('durchsatz').profil.sitzungen, 1);
    });

    test('Szenario ohne Messung: keine Speicher- und CPU-Werte', () async {
      final hallo = await HalloDienst.starte(router);
      stopp.add(hallo.stoppe);
      final e = await Lasttest.fahre(
        const Szenario('durchsatz', 'kurz', [
          Lastprofil(
            name: 'durchsatz',
            sitzungen: 1,
            dauer: Duration(milliseconds: 50),
            schritte: [Vorgang.hallo],
          ),
        ]),
        verbinde,
      );
      expect(e.speicherVorherMb, isNull);
      expect(e.speicherSpitzeMb, isNull);
      expect(e.cpuKerne, isNull);
      expect(e.lastCpuKerne, isNull);
      expect(e.alsJson().keys, ['szenario', 'beschreibung', 'profile']);
    });
  });
}

/// Zufall mit festem Wert.
final class _Fest implements Random {
  _Fest(this.wert);

  final double wert;

  @override
  double nextDouble() => wert;

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  int nextInt(int max) => throw UnimplementedError();
}
