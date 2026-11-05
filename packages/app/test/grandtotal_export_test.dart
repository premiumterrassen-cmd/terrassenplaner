import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/design/planer_design.dart';
import 'package:terrassenplaner_app/src/export/datei_angebot.dart';
import 'package:terrassenplaner_app/src/export/grandtotal_export.dart';
import 'package:terrassenplaner_app/src/konfiguration/konfigurations_steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/berechnung_steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/materialliste.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/rahmen/steuerung.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

/// Erfundener Testartikel.
final _diele = Artikel(
  nummer: const Artikelnummer('10-10-073-R'),
  titel: 'Terrassendiele Robinie',
  art: Artikelart.diele,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  preisBrutto: const Cent(1290),
  holzart: robinie,
  serie: premiumSelect,
);

Future<Berechnung> _berechne(Planung planung) async => Berechnung(
  umriss: planung.aktuell.grundriss.ecken,
  flaeche: 1,
  materialliste: Materialliste.aus([
    Materialbedarf([_diele], 48, laenge: const Millimeter(5000)),
  ]),
);

final _adresse = Uri.parse('https://planer.example/');

/// Merkt sich Anfragen und angebotene Dateien.
final class _Export {
  final anfragen = <(Planung, Uri)>[];
  final dateien = <(String, String)>[];
  Completer<String> antwort = Completer();

  Future<String> anfordern(Planung planung, Uri adresse) {
    anfragen.add((planung, adresse));
    return antwort.future;
  }

  void anbieten(String name, String inhalt) => dateien.add((name, inhalt));
}

Finder get _knopf => find.byKey(const ValueKey('export-grandtotal'));

bool _gesperrt(WidgetTester tester) =>
    tester.widget<OutlinedButton>(_knopf).onPressed == null;

void main() {
  test('außerhalb des Browsers kein Download', () {
    expect(
      () => bieteDateiAn('GrandTotal_Import.csv', 'x'),
      throwsA(
        isA<UnsupportedError>().having(
          (e) => e.message,
          'message',
          'Datei GrandTotal_Import.csv: nur im Browser',
        ),
      ),
    );
  });

  group('Knopf „Export für GrandTotal“ (M9-08)', () {
    late PlanungsSteuerung planung;
    late _Export export;

    // Der Export entsteht im Test selbst: seine Futures gehören dann zur
    // Testzone, deren Mikroaufgaben `pump` abarbeitet.
    setUp(() => planung = PlanungsSteuerung());

    tearDown(() => planung.dispose());

    Future<void> zeige(
      WidgetTester tester, {
      KonfigurationsStand? Function()? stand,
    }) => tester.pumpWidget(
      testApp(
        home: Scaffold(
          body: GrandTotalExportKnopf(
            planung: planung,
            export: GrandTotalExport(
              anfordern: export.anfordern,
              adresse: _adresse,
              anbieten: export.anbieten,
              stand: stand,
            ),
          ),
        ),
      ),
    );

    testWidgets('fordert die Datei an und bietet sie an', (tester) async {
      export = _Export();
      await zeige(tester, stand: () => stand('2026-10-08-1511-K7QXM', 3));
      expect(find.text('Export für GrandTotal'), findsOneWidget);
      expect(_gesperrt(tester), isFalse);
      await tester.tap(_knopf);
      await tester.pump();
      // während der Anfrage gesperrt
      expect(_gesperrt(tester), isTrue);
      expect(export.anfragen, [(planung.planung, _adresse)]);
      export.antwort.complete('Kopf\r\n');
      await tester.pump();
      expect(export.dateien, [
        ('GrandTotal_Import_2026-10-08-1511_v3.csv', 'Kopf\r\n'),
      ]);
      expect(_gesperrt(tester), isFalse);
      expect(
        find.text(
          de.exportGrandTotalFertig('GrandTotal_Import_2026-10-08-1511_v3.csv'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('ungespeichert: Dateiname ohne Nummer', (tester) async {
      export = _Export();
      await zeige(tester, stand: () => null);
      await tester.tap(_knopf);
      export.antwort.complete('x');
      await tester.pump();
      expect(export.dateien.single.$1, 'GrandTotal_Import.csv');
      await zeige(tester);
      export.antwort = Completer()..complete('y');
      await tester.tap(_knopf);
      await tester.pump();
      expect(export.dateien.last, ('GrandTotal_Import.csv', 'y'));
    });

    testWidgets('Fehler: Hinweis, Knopf wieder frei', (tester) async {
      export = _Export();
      await zeige(tester);
      await tester.tap(_knopf);
      export.antwort.completeError(StateError('kein Server'));
      await tester.pump();
      expect(find.text(de.exportGrandTotalFehler), findsOneWidget);
      expect(export.dateien, isEmpty);
      expect(_gesperrt(tester), isFalse);
    });

    testWidgets('Antwort nach dem Schließen: kein Fehler', (tester) async {
      export = _Export();
      await zeige(tester);
      await tester.tap(_knopf);
      await tester.pump();
      await tester.pumpWidget(testApp(home: const Scaffold()));
      export.antwort.complete('spät');
      await tester.pump();
      expect(export.dateien.single.$2, 'spät');
      expect(tester.takeException(), isNull);
    });
  });

  group('in der Materialliste (M9-08)', () {
    testWidgets('nur in der Mitarbeiter-Ansicht mit Export', (tester) async {
      tester.view
        ..physicalSize = const Size(1440, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final planung = PlanungsSteuerung();
      final berechnung = BerechnungsSteuerung(
        planung: planung,
        berechne: _berechne,
      );
      addTearDown(() {
        berechnung.dispose();
        planung.dispose();
      });
      final export = _Export();
      Future<void> zeige({required bool mitarbeiter, bool mitExport = true}) =>
          tester.pumpWidget(
            testApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: MateriallisteAnsicht(
                    berechnung: berechnung,
                    planung: planung,
                    mitarbeiter: mitarbeiter,
                    export: mitExport
                        ? GrandTotalExport(
                            anfordern: export.anfordern,
                            adresse: _adresse,
                          )
                        : null,
                  ),
                ),
              ),
            ),
          );
      await zeige(mitarbeiter: false);
      await tester.pump();
      expect(_knopf, findsNothing);
      await zeige(mitarbeiter: true, mitExport: false);
      expect(_knopf, findsNothing);
      await zeige(mitarbeiter: true);
      expect(_knopf, findsOneWidget);
    });

    testWidgets('im Rahmen: Planung, Adresse und gespeicherter Stand', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1440, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final mitarbeiter = ValueNotifier(true);
      addTearDown(mitarbeiter.dispose);
      final konfiguration = KonfigurationsSteuerung(
        ablage: TestAblage(),
        gedaechtnis: testGedaechtnis(),
      );
      addTearDown(konfiguration.dispose);
      final export = _Export()..antwort.complete('csv');
      Future<void> exportiere({
        KonfigurationsSteuerung? mit,
        Uri? adresse,
      }) async {
        await tester.pumpWidget(
          testApp(
            theme: planerThema(),
            home: PlanerRahmen(
              key: UniqueKey(),
              status: const Text('Status'),
              berechne: _berechne,
              konfiguration: mit,
              mitarbeiter: mitarbeiter,
              exportGrandTotal: export.anfordern,
              dateiAnbieten: export.anbieten,
              adresse: adresse,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('materialliste-knopf')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('standardwert-fortfahren')));
        await tester.pumpAndSettle();
        await tester.tap(_knopf);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('materialliste-schliessen')),
        );
        await tester.pumpAndSettle();
      }

      final gespeichert = await konfiguration.speichere();
      await exportiere(mit: konfiguration, adresse: _adresse);
      expect(export.anfragen.single.$2, _adresse);
      expect(export.dateien.single, (grandTotalDateiname(gespeichert), 'csv'));
      // ohne Konfiguration und Adresse: ungespeichert, Adresse der Seite
      await exportiere();
      expect(export.anfragen.last.$2, Uri.base);
      expect(export.dateien.last.$1, 'GrandTotal_Import.csv');
      // ohne Export kein Knopf
      await tester.pumpWidget(
        testApp(
          theme: planerThema(),
          home: PlanerRahmen(
            status: const Text('Status'),
            berechne: _berechne,
            mitarbeiter: mitarbeiter,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('materialliste-knopf')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('standardwert-fortfahren')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('materialliste-dialog')), findsOne);
      expect(_knopf, findsNothing);
    });
  });
}
