import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/einstellungen/einstellungs_speicher.dart';
import 'package:terrassenplaner_app/src/einstellungen/lokale_einstellungen.dart';
import 'package:terrassenplaner_app/src/konfiguration/konfigurations_steuerung.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

Planungsstand _stand(int laenge) => Planungsstand(
  grundriss: RechteckGrundriss(Millimeter(laenge), const Millimeter(3000)),
);

Planung _planung(int laenge) => Planung([Terrassenflaeche(_stand(laenge))]);

final _nummer = Konfigurationsnummer.vergib(DateTime(2026, 11, 4), 1);

void main() {
  late TestAblage ablage;
  late LokaleEinstellungen gedaechtnis;
  late KonfigurationsSteuerung k;
  var meldungen = 0;

  setUp(() {
    ablage = TestAblage();
    gedaechtnis = testGedaechtnis();
    meldungen = 0;
    k = KonfigurationsSteuerung(ablage: ablage, gedaechtnis: gedaechtnis)
      ..addListener(() => meldungen++);
  });

  tearDown(() => k.dispose());

  test('Vorgaben', () {
    expect(KonfigurationsSteuerung.standardVerzoegerung.inSeconds, 5);
    expect(k.verzoegerung, KonfigurationsSteuerung.standardVerzoegerung);
    expect(k.stand, isNull);
    expect(k.planung.planung, Planung.start);
    expect(
      '${KonfigurationNichtGefunden(KonfigurationsStand(_nummer, 2))}',
      'Konfiguration 2026-11-04-0001 v2 nicht gefunden',
    );
    expect(const Fund().entwurf, isFalse);
    expect(const Fund().stand, isNull);
  });

  group('speichern', () {
    test('erst neue Nummer, dann weitere Versionen; gemerkt', () async {
      k.planung.setze(_stand(4000));
      final v1 = await k.speichere();
      expect(v1, KonfigurationsStand(_nummer, 1));
      expect(k.stand, v1);
      expect(gedaechtnis.letzteKonfiguration(), v1);
      expect(meldungen, 1);
      k.planung.setze(_stand(5000));
      final v2 = await k.speichere();
      expect(v2, KonfigurationsStand(_nummer, 2));
      expect(ablage.versionen[v1], _planung(4000));
      expect(ablage.versionen[v2], _planung(5000));
    });

    test(
      'Server nicht erreichbar: Fehler, Planung und Stand bleiben',
      () async {
        k.planung.setze(_stand(4000));
        ablage.erreichbar = false;
        await expectLater(k.speichere(), throwsStateError);
        expect(k.stand, isNull);
        expect(k.planung.planung, _planung(4000));
        expect(gedaechtnis.letzteKonfiguration(), isNull);
        expect(meldungen, 0);
      },
    );
  });

  group('laden', () {
    test('ersetzt die Planung, Rückgängig beginnt neu, gemerkt', () async {
      final v1 = await ablage.speichere(_planung(6000));
      k.planung.setze(_stand(4000));
      await k.lade(v1);
      expect(k.planung.planung, _planung(6000));
      expect(k.planung.kannRueckgaengig, isFalse);
      expect(k.stand, v1);
      expect(gedaechtnis.letzteKonfiguration(), v1);
      // Weiteres Speichern legt die nächste Version derselben Nummer an.
      expect((await k.speichere()).version, 2);
    });

    test('unbekannt: Fehler, nichts ändert sich', () async {
      k.planung.setze(_stand(4000));
      await expectLater(
        k.lade(KonfigurationsStand(_nummer, 1)),
        throwsA(isA<KonfigurationNichtGefunden>()),
      );
      expect(k.planung.planung, _planung(4000));
      expect(k.stand, isNull);
      expect(meldungen, 0);
    });
  });

  group('Weiterplanen', () {
    test('nichts gefunden', () async {
      expect(await k.suche(), isNull);
    });

    test('nur gemerkte Konfiguration: lädt sie vom Server', () async {
      final v1 = await ablage.speichere(_planung(6000));
      gedaechtnis.merke(v1);
      final fund = (await k.suche())!;
      expect(fund.stand, v1);
      expect(fund.entwurf, isFalse);
      await k.weiterplanen();
      expect(k.planung.planung, _planung(6000));
      expect(k.stand, v1);
    });

    test('Entwurf geht vor und behält seinen Bezug', () async {
      final v1 = await ablage.speichere(_planung(6000));
      gedaechtnis.merke(KonfigurationsStand(_nummer, 9));
      ablage.entwuerfe[gedaechtnis.sitzungsschluessel()] = (
        planung: _planung(6100),
        bezug: v1,
      );
      final fund = (await k.suche())!;
      expect(fund.stand, v1);
      expect(fund.entwurf, isTrue);
      await k.weiterplanen();
      expect(k.planung.planung, _planung(6100));
      expect(k.stand, v1);
      expect(meldungen, 1);
    });

    test('Entwurf ohne Bezug', () async {
      ablage.entwuerfe[gedaechtnis.sitzungsschluessel()] = (
        planung: _planung(6100),
        bezug: null,
      );
      final fund = (await k.suche())!;
      expect(fund.stand, isNull);
      expect(fund.entwurf, isTrue);
    });

    test('Server nicht erreichbar: nur die gemerkte Konfiguration', () async {
      final v1 = KonfigurationsStand(_nummer, 1);
      gedaechtnis.merke(v1);
      ablage.erreichbar = false;
      final fund = (await k.suche())!;
      expect(fund.stand, v1);
      expect(fund.entwurf, isFalse);
      await expectLater(k.weiterplanen(), throwsStateError);
    });
  });

  test('neu: Startplanung ohne Nummer', () async {
    k.planung.setze(_stand(4000));
    await k.speichere();
    meldungen = 0;
    k.neu();
    expect(k.stand, isNull);
    expect(k.planung.planung, Planung.start);
    expect(meldungen, 1);
  });

  group('automatisches Zwischenspeichern', () {
    testWidgets('nach der Verzögerung als Entwurf, nicht als Version', (
      tester,
    ) async {
      final schluessel = gedaechtnis.sitzungsschluessel();
      k.planung.setze(_stand(4000));
      await tester.pump(const Duration(seconds: 4));
      k.planung.setze(_stand(4100));
      await tester.pump(const Duration(seconds: 4));
      // jede Änderung schiebt das Zwischenspeichern hinaus
      expect(ablage.entwurfAufrufe, 0);
      await tester.pump(const Duration(seconds: 1));
      expect(ablage.entwurfAufrufe, 1);
      expect(ablage.entwuerfe[schluessel], (
        planung: _planung(4100),
        bezug: null,
      ));
      expect(ablage.versionen, isEmpty);

      // nach SPEICHERN mit neuem Bezug
      final v1 = await k.speichere();
      await tester.pump(const Duration(seconds: 5));
      expect(ablage.entwurfAufrufe, 2);
      expect(ablage.entwuerfe[schluessel]!.bezug, v1);
    });

    testWidgets('unverändert: kein weiterer Aufruf', (tester) async {
      k.planung.setze(_stand(4000));
      await tester.pump(const Duration(seconds: 5));
      expect(ablage.entwurfAufrufe, 1);
      // Rückgängig und Wiederherstellen ergeben denselben Stand
      k.planung
        ..rueckgaengig()
        ..wiederherstellen();
      await tester.pump(const Duration(seconds: 5));
      expect(ablage.entwurfAufrufe, 1);
    });

    testWidgets('Weiterplanen mit Entwurf schickt ihn nicht erneut', (
      tester,
    ) async {
      ablage.entwuerfe[gedaechtnis.sitzungsschluessel()] = (
        planung: _planung(6100),
        bezug: null,
      );
      await k.suche();
      await k.weiterplanen();
      await tester.pump(const Duration(seconds: 5));
      expect(ablage.entwurfAufrufe, 0);
    });

    testWidgets('Server nicht erreichbar: still, nächste Änderung erneut', (
      tester,
    ) async {
      ablage.erreichbar = false;
      k.planung.setze(_stand(4000));
      await tester.pump(const Duration(seconds: 5));
      expect(ablage.entwurfAufrufe, 1);
      ablage.erreichbar = true;
      k.planung.setze(_stand(4000));
      await tester.pump(const Duration(seconds: 5));
      expect(ablage.entwurfAufrufe, 2);
      expect(ablage.entwuerfe.values.single.planung, _planung(4000));
    });

    testWidgets('eigene Verzögerung; nach dispose nichts mehr', (tester) async {
      final kurz = KonfigurationsSteuerung(
        ablage: ablage,
        gedaechtnis: testGedaechtnis(FluechtigerSpeicher()),
        verzoegerung: const Duration(milliseconds: 100),
      );
      kurz.planung.setze(_stand(4000));
      await tester.pump(const Duration(milliseconds: 99));
      expect(ablage.entwurfAufrufe, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(ablage.entwurfAufrufe, 1);
      kurz.planung.setze(_stand(4100));
      final planung = kurz.planung;
      kurz.dispose();
      await tester.pump(const Duration(seconds: 1));
      expect(ablage.entwurfAufrufe, 1);
      // die Planung gehört der Steuerung und ist mit ihr freigegeben
      expect(() => planung.addListener(() {}), throwsFlutterError);
    });
  });
}
