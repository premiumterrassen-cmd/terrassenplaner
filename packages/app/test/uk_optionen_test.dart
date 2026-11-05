import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/rahmen/berechnung_steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_schritt.dart';
import 'package:terrassenplaner_app/src/rahmen/rahmen_zustand.dart';
import 'package:terrassenplaner_app/src/rahmen/steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/unterkonstruktion.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

void main() {
  group('Untergrund (M6-04)', () {
    Future<({PlanungsSteuerung planung, List<int> aenderungen})> zeige(
      WidgetTester tester, {
      Locale sprache = const Locale('de'),
    }) async {
      final planung = PlanungsSteuerung();
      addTearDown(planung.dispose);
      final aenderungen = <int>[];
      await tester.pumpWidget(
        testApp(
          sprache: sprache,
          home: Scaffold(
            body: UntergrundWahl(
              planung: planung,
              onGeaendert: () => aenderungen.add(aenderungen.length),
            ),
          ),
        ),
      );
      return (planung: planung, aenderungen: aenderungen);
    }

    ChoiceChip chip(WidgetTester tester, Untergrund u) =>
        tester.widget(find.byKey(ValueKey('untergrund-${u.name}')));

    testWidgets('drei Untergründe, Vorgabe Schotter, Hinweis; Wahl ist ein '
        'Schritt im Verlauf', (tester) async {
      final s = await zeige(tester);
      expect(find.text(de.untergrundFrage), findsOneWidget);
      expect(find.text(de.untergrundSchotter), findsOneWidget);
      expect(find.text(de.untergrundBeton), findsOneWidget);
      expect(find.text(de.untergrundBitumen), findsOneWidget);
      expect(find.text(de.untergrundHinweis), findsOneWidget);
      expect(chip(tester, Untergrund.schotter).selected, isTrue);
      await tester.tap(find.byKey(const ValueKey('untergrund-bitumen')));
      await tester.pump();
      expect(s.planung.aktuell.untergrund, Untergrund.bitumen);
      expect(chip(tester, Untergrund.bitumen).selected, isTrue);
      expect(chip(tester, Untergrund.schotter).selected, isFalse);
      expect(s.aenderungen, [0]);
      // erneutes Tippen auf den gewählten ändert nichts
      await tester.tap(find.byKey(const ValueKey('untergrund-bitumen')));
      await tester.pump();
      expect(s.aenderungen, [0]);
      s.planung.rueckgaengig();
      await tester.pump();
      expect(chip(tester, Untergrund.schotter).selected, isTrue);
      s.planung.wiederherstellen();
      await tester.pump();
      expect(chip(tester, Untergrund.bitumen).selected, isTrue);
    });

    testWidgets('englische Texte', (tester) async {
      await zeige(tester, sprache: const Locale('en'));
      expect(find.text('Gravel (compacted)'), findsOneWidget);
      expect(find.text('Concrete'), findsOneWidget);
      expect(find.text('Bitumen sealing'), findsOneWidget);
    });

    test('Text je Untergrund', () {
      expect(untergrundText(de, Untergrund.beton), 'Beton');
      expect(untergrundText(en, Untergrund.schotter), 'Gravel (compacted)');
    });
  });

  group('Art der Terrassennutzung (M6-05)', () {
    Future<({PlanungsSteuerung planung, List<int> aenderungen})> zeige(
      WidgetTester tester, {
      Locale sprache = const Locale('de'),
    }) async {
      final planung = PlanungsSteuerung();
      addTearDown(planung.dispose);
      final aenderungen = <int>[];
      await tester.pumpWidget(
        testApp(
          sprache: sprache,
          home: Scaffold(
            body: NutzungsartWahl(
              planung: planung,
              onGeaendert: () => aenderungen.add(aenderungen.length),
            ),
          ),
        ),
      );
      return (planung: planung, aenderungen: aenderungen);
    }

    ChoiceChip chip(WidgetTester tester, Nutzungsart a) =>
        tester.widget(find.byKey(ValueKey('nutzungsart-${a.name}')));

    testWidgets('fünf Arten, Vorgabe schwimmend mit Warnung zur Verwindung; '
        'Wahl ist ein Schritt im Verlauf', (tester) async {
      final s = await zeige(tester);
      for (final a in Nutzungsart.values) {
        expect(find.text(nutzungsartText(de, a)), findsOneWidget);
      }
      expect(chip(tester, Nutzungsart.schwimmend).selected, isTrue);
      expect(find.text(de.nutzungsartVerwindung), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nutzungsart-rahmen')));
      await tester.pump();
      expect(s.planung.aktuell.nutzungsart, Nutzungsart.rahmen);
      expect(chip(tester, Nutzungsart.rahmen).selected, isTrue);
      expect(chip(tester, Nutzungsart.schwimmend).selected, isFalse);
      expect(find.byKey(const ValueKey('verwindung')), findsNothing);
      expect(s.aenderungen, [0]);
      await tester.tap(find.byKey(const ValueKey('nutzungsart-rahmen')));
      await tester.pump();
      expect(s.aenderungen, [0]);
      s.planung.rueckgaengig();
      await tester.pump();
      expect(chip(tester, Nutzungsart.schwimmend).selected, isTrue);
      expect(find.byKey(const ValueKey('verwindung')), findsOneWidget);
      s.planung.wiederherstellen();
      await tester.pump();
      expect(chip(tester, Nutzungsart.rahmen).selected, isTrue);
    });

    testWidgets('englische Texte', (tester) async {
      await zeige(tester, sprache: const Locale('en'));
      expect(find.text('Floating installation'), findsOneWidget);
      expect(find.text('Double substructure'), findsOneWidget);
    });

    test('Text je Art', () {
      expect(
        nutzungsartText(de, Nutzungsart.schwimmend),
        'schwimmende Verlegung',
      );
      expect(
        nutzungsartText(de, Nutzungsart.versteifungOhneRahmen),
        'Versteifung ohne Rahmen',
      );
      expect(nutzungsartText(de, Nutzungsart.rahmen), 'Rahmen');
      expect(
        nutzungsartText(de, Nutzungsart.versteifungMitRahmen),
        'Versteifung mit Rahmen',
      );
      expect(
        nutzungsartText(de, Nutzungsart.doppelteUk),
        'doppelte Unterkonstruktion',
      );
    });
  });

  testWidgets('Menü: 3.6 Art der Terrassennutzung; bei Hochterrasse '
      'entfällt sie, die Wahl bleibt', (tester) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final zustand = RahmenZustand()..waehle(PlanerSchritt.unterkonstruktion);
    final planung = PlanungsSteuerung();
    addTearDown(planung.dispose);
    await tester.pumpWidget(
      testApp(
        home: PlanerRahmen(
          status: const SizedBox(),
          zustand: zustand,
          planung: planung,
        ),
      ),
    );
    final doppelt = find.byKey(const ValueKey('nutzungsart-doppelteUk'));
    await tester.ensureVisible(doppelt);
    await tester.tap(doppelt);
    await tester.pump();
    expect(planung.aktuell.nutzungsart, Nutzungsart.doppelteUk);
    expect(
      zustand.unveraendert,
      isNot(contains(PlanerSchritt.unterkonstruktion)),
    );
    planung.setze(planung.aktuell.mitTerrassenart(Terrassenart.hochterrasse));
    await tester.pump();
    expect(find.byKey(const ValueKey('nutzungsart')), findsNothing);
    planung.rueckgaengig();
    await tester.pump();
    expect(find.byKey(const ValueKey('nutzungsart')), findsOneWidget);
  });

  group('Querstreben (M6-06)', () {
    /// Antwort wie vom Server: je Reihe eine Strebe, Anzahl wie gewählt
    /// oder automatisch 5 (F01).
    Future<Berechnung> server(Planung planung) async {
      final stand = planung.aktuell;
      final reihen = stand.querstreben ? stand.querstrebenReihen ?? 5 : null;
      return Berechnung(
        umriss: const [],
        flaeche: 1,
        querstrebenReihen: reihen,
        querstreben: [
          for (var r = 1; r <= (reihen ?? 0); r++)
            (von: Punkt(20, r * 500.0), bis: Punkt(380, r * 500.0)),
        ],
      );
    }

    Future<
      ({
        PlanungsSteuerung planung,
        BerechnungsSteuerung berechnung,
        List<int> aenderungen,
      })
    >
    zeige(WidgetTester tester, {Locale sprache = const Locale('de')}) async {
      final planung = PlanungsSteuerung();
      final berechnung = BerechnungsSteuerung(
        planung: planung,
        berechne: server,
      );
      addTearDown(() {
        berechnung.dispose();
        planung.dispose();
      });
      final aenderungen = <int>[];
      await tester.pumpWidget(
        testApp(
          sprache: sprache,
          home: Scaffold(
            body: QuerstrebenWahl(
              planung: planung,
              berechnung: berechnung,
              onGeaendert: () => aenderungen.add(aenderungen.length),
            ),
          ),
        ),
      );
      await tester.pump();
      return (
        planung: planung,
        berechnung: berechnung,
        aenderungen: aenderungen,
      );
    }

    final anzahl = find.descendant(
      of: find.byKey(const ValueKey('querstreben-anzahl')),
      matching: find.byType(TextField),
    );

    ChoiceChip chip(WidgetTester tester, String name) =>
        tester.widget(find.byKey(ValueKey('querstreben-$name')));

    testWidgets('Vorgabe Nein; Ja zeigt die Anzahl der Quertraversen vom '
        'Server; Eingabe, Automatisch und Rückgängig', (tester) async {
      final s = await zeige(tester);
      expect(find.text(de.querstrebenFrage), findsOneWidget);
      expect(chip(tester, 'nein').selected, isTrue);
      expect(anzahl, findsNothing);
      await tester.tap(find.byKey(const ValueKey('querstreben-ja')));
      await tester.pump();
      await tester.pump();
      expect(s.planung.aktuell.querstreben, isTrue);
      expect(find.text(de.querstrebenAbstand), findsOneWidget);
      expect(chip(tester, 'automatisch').selected, isTrue);
      expect(tester.widget<TextField>(anzahl).decoration!.hintText, '5');
      expect(
        tester.widget<TextField>(anzahl).decoration!.labelText,
        de.querstrebenAnzahl,
      );
      // erneutes Tippen ändert nichts
      await tester.tap(find.byKey(const ValueKey('querstreben-ja')));
      await tester.pump();
      expect(s.aenderungen, [0]);
      for (final falsch in ['0', '100', 'x', '2,5']) {
        await tester.enterText(anzahl, falsch);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        expect(find.text(de.querstrebenAnzahlUngueltig), findsOneWidget);
      }
      expect(s.planung.aktuell.querstrebenReihen, isNull);
      await tester.enterText(anzahl, ' 3 ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump();
      expect(s.planung.aktuell.querstrebenReihen, 3);
      expect(find.text(de.querstrebenAnzahlUngueltig), findsNothing);
      expect(tester.widget<TextField>(anzahl).controller!.text, isEmpty);
      expect(tester.widget<TextField>(anzahl).decoration!.hintText, '3');
      expect(chip(tester, 'automatisch').selected, isFalse);
      expect(s.berechnung.ergebnis!.querstreben, hasLength(3));
      await tester.tap(find.byKey(const ValueKey('querstreben-automatisch')));
      await tester.pump();
      expect(s.planung.aktuell.querstrebenReihen, isNull);
      // Automatisch erneut: nichts
      await tester.tap(find.byKey(const ValueKey('querstreben-automatisch')));
      await tester.pump();
      expect(s.aenderungen, [0, 1, 2]);
      s.planung.rueckgaengig();
      await tester.pump();
      expect(s.planung.aktuell.querstrebenReihen, 3);
      await tester.tap(find.byKey(const ValueKey('querstreben-nein')));
      await tester.pump();
      expect(s.planung.aktuell.querstreben, isFalse);
      expect(anzahl, findsNothing);
      expect(s.aenderungen, [0, 1, 2, 3]);
    });

    testWidgets('ohne Berechnung kein Platzhalter; englische Texte', (
      tester,
    ) async {
      final planung = PlanungsSteuerung();
      addTearDown(planung.dispose);
      planung.setze(planung.aktuell.mitQuerstreben(true));
      await tester.pumpWidget(
        testApp(
          sprache: const Locale('en'),
          home: Scaffold(
            body: QuerstrebenWahl(planung: planung, onGeaendert: () {}),
          ),
        ),
      );
      expect(
        find.text('Would you like to add additional cross braces?'),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(anzahl).decoration!.hintText, isNull);
    });

    testWidgets('Zeichnung: Querstreben vom Server', (tester) async {
      final s = await zeige(tester);
      expect(s.berechnung.zeichnung.querstreben, isEmpty);
      s.planung.setze(s.planung.aktuell.mitQuerstreben(true));
      await tester.pump();
      await tester.pump();
      expect(s.berechnung.zeichnung.querstreben, hasLength(5));
      expect(s.berechnung.zeichnung.querstreben.first, (
        const Offset(20, 500),
        const Offset(380, 500),
      ));
    });
  });

  testWidgets('Menü: 3.7 Querstreben', (tester) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final zustand = RahmenZustand()..waehle(PlanerSchritt.unterkonstruktion);
    final planung = PlanungsSteuerung();
    addTearDown(planung.dispose);
    await tester.pumpWidget(
      testApp(
        home: PlanerRahmen(
          status: const SizedBox(),
          zustand: zustand,
          planung: planung,
        ),
      ),
    );
    expect(find.text('3.7 ${de.unterkonstruktion7}'), findsOneWidget);
    final ja = find.byKey(const ValueKey('querstreben-ja'));
    await tester.ensureVisible(ja);
    await tester.tap(ja);
    await tester.pump();
    expect(planung.aktuell.querstreben, isTrue);
    expect(
      zustand.unveraendert,
      isNot(contains(PlanerSchritt.unterkonstruktion)),
    );
  });

  group('Nutzung privat oder gewerblich (M6-07)', () {
    /// Antwort wie vom Server: Stellfüße je Nutzung laut Regelwerk.
    Future<Berechnung> server(Planung planung) async => Berechnung(
      umriss: const [],
      flaeche: 1,
      stellfuesse: [
        if (planung.aktuell.gewerblich)
          (nummer: const Artikelnummer('70-10-002'), titel: 'Stellfuß G'),
        (nummer: const Artikelnummer('70-10-001'), titel: 'Stellfuß P'),
      ],
    );

    Future<({PlanungsSteuerung planung, List<int> aenderungen})> zeige(
      WidgetTester tester, {
      Locale sprache = const Locale('de'),
      bool mitServer = true,
    }) async {
      final planung = PlanungsSteuerung();
      final berechnung = BerechnungsSteuerung(
        planung: planung,
        berechne: server,
      );
      addTearDown(() {
        berechnung.dispose();
        planung.dispose();
      });
      final aenderungen = <int>[];
      await tester.pumpWidget(
        testApp(
          sprache: sprache,
          home: Scaffold(
            body: GewerblichWahl(
              planung: planung,
              berechnung: mitServer ? berechnung : null,
              onGeaendert: () => aenderungen.add(aenderungen.length),
            ),
          ),
        ),
      );
      await tester.pump();
      return (planung: planung, aenderungen: aenderungen);
    }

    ChoiceChip chip(WidgetTester tester, String name) =>
        tester.widget(find.byKey(ValueKey('nutzung-$name')));

    testWidgets('Vorgabe privat; gewerblich wählt die Stellfüße des '
        'Regelwerks; Rückgängig', (tester) async {
      final s = await zeige(tester);
      expect(find.text(de.nutzungPrivat), findsOneWidget);
      expect(find.text(de.nutzungGewerblich), findsOneWidget);
      expect(chip(tester, 'privat').selected, isTrue);
      expect(find.text(de.stellfuesse), findsOneWidget);
      expect(find.text('• Stellfuß P'), findsOneWidget);
      expect(find.byKey(const ValueKey('stellfuss-70-10-002')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('nutzung-gewerblich')));
      await tester.pump();
      await tester.pump();
      expect(s.planung.aktuell.gewerblich, isTrue);
      expect(chip(tester, 'gewerblich').selected, isTrue);
      expect(chip(tester, 'privat').selected, isFalse);
      expect(find.text('• Stellfuß G'), findsOneWidget);
      expect(s.aenderungen, [0]);
      await tester.tap(find.byKey(const ValueKey('nutzung-gewerblich')));
      await tester.pump();
      expect(s.aenderungen, [0]);
      s.planung.rueckgaengig();
      await tester.pump();
      expect(chip(tester, 'privat').selected, isTrue);
    });

    testWidgets('ohne Stellfüße ein Hinweis; englische Texte', (tester) async {
      await zeige(tester, sprache: const Locale('en'), mitServer: false);
      expect(find.text('Commercial use'), findsOneWidget);
      expect(
        find.text(
          'No adjustable feet are listed for the selected substructure.',
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('Menü: 3.8 Nutzung privat oder gewerblich', (tester) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final zustand = RahmenZustand()..waehle(PlanerSchritt.unterkonstruktion);
    final planung = PlanungsSteuerung();
    addTearDown(planung.dispose);
    await tester.pumpWidget(
      testApp(
        home: PlanerRahmen(
          status: const SizedBox(),
          zustand: zustand,
          planung: planung,
        ),
      ),
    );
    expect(find.text('3.8 ${de.unterkonstruktion8}'), findsOneWidget);
    final gewerblich = find.byKey(const ValueKey('nutzung-gewerblich'));
    await tester.ensureVisible(gewerblich);
    await tester.tap(gewerblich);
    await tester.pump();
    expect(planung.aktuell.gewerblich, isTrue);
    expect(
      zustand.unveraendert,
      isNot(contains(PlanerSchritt.unterkonstruktion)),
    );
  });

  testWidgets('Menü: 3.5 Untergrund mit Auswahl', (tester) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final zustand = RahmenZustand()..waehle(PlanerSchritt.unterkonstruktion);
    final planung = PlanungsSteuerung();
    addTearDown(planung.dispose);
    await tester.pumpWidget(
      testApp(
        home: PlanerRahmen(
          status: const SizedBox(),
          zustand: zustand,
          planung: planung,
        ),
      ),
    );
    expect(find.text('3.5 ${de.unterkonstruktion5}'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('untergrund-beton')));
    await tester.tap(find.byKey(const ValueKey('untergrund-beton')));
    await tester.pump();
    expect(planung.aktuell.untergrund, Untergrund.beton);
    expect(
      zustand.unveraendert,
      isNot(contains(PlanerSchritt.unterkonstruktion)),
    );
  });
}
