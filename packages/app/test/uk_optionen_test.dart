import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
