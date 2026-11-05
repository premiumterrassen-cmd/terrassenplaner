import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/rahmen/anschluss.dart';
import 'package:terrassenplaner_app/src/rahmen/berechnung_steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_schritt.dart';
import 'package:terrassenplaner_app/src/rahmen/rahmen_zustand.dart';
import 'package:terrassenplaner_app/src/rahmen/steuerung.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

void main() {
  test('Seitenname wie in der Zeichnung', () {
    expect(seitenname(0, 4), 'A — B');
    expect(seitenname(3, 4), 'D — A');
  });

  group('Angrenzende Bauelemente (M7-01)', () {
    Future<({PlanungsSteuerung planung, List<int> aenderungen})> zeige(
      WidgetTester tester, {
      Locale sprache = const Locale('de'),
      Planungsstand stand = Planungsstand.start,
    }) async {
      final planung = PlanungsSteuerung()..setze(stand);
      addTearDown(planung.dispose);
      final aenderungen = <int>[];
      await tester.pumpWidget(
        testApp(
          sprache: sprache,
          home: Scaffold(
            body: AngrenzendWahl(
              planung: planung,
              onGeaendert: () => aenderungen.add(aenderungen.length),
            ),
          ),
        ),
      );
      return (planung: planung, aenderungen: aenderungen);
    }

    FilterChip chip(WidgetTester tester, int seite) =>
        tester.widget(find.byKey(ValueKey('angrenzend-$seite')));

    testWidgets('je Seite ein Schalter; Wahl ist ein Schritt im Verlauf', (
      tester,
    ) async {
      final s = await zeige(tester);
      expect(find.text(de.angrenzendFrage), findsOneWidget);
      for (final name in ['A — B', 'B — C', 'C — D', 'D — A']) {
        expect(find.text(name), findsOneWidget);
      }
      expect(chip(tester, 0).selected, isFalse);
      await tester.tap(find.byKey(const ValueKey('angrenzend-0')));
      await tester.pump();
      expect(s.planung.aktuell.anschluss.angrenzend, [0]);
      expect(chip(tester, 0).selected, isTrue);
      expect(s.aenderungen, [0]);
      await tester.tap(find.byKey(const ValueKey('angrenzend-0')));
      await tester.pump();
      expect(s.planung.aktuell.anschluss.angrenzend, isEmpty);
      s.planung.rueckgaengig();
      await tester.pump();
      expect(chip(tester, 0).selected, isTrue);
    });

    testWidgets('Kreis: keine Seiten, englische Texte', (tester) async {
      await zeige(
        tester,
        sprache: const Locale('en'),
        stand: Planungsstand.start.mitForm(Terrassenform.kreis),
      );
      expect(find.text(en.angrenzendFrage), findsOneWidget);
      expect(find.byKey(const ValueKey('angrenzend-leer')), findsOneWidget);
      expect(find.text(en.ohneSeiten), findsOneWidget);
    });

    testWidgets('im Bearbeitungsmenü unter 4.1', (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final planung = PlanungsSteuerung();
      addTearDown(planung.dispose);
      final zustand = RahmenZustand()..waehle(PlanerSchritt.terrassenanschluss);
      await tester.pumpWidget(
        testApp(
          home: PlanerRahmen(
            status: const SizedBox(),
            zustand: zustand,
            planung: planung,
          ),
        ),
      );
      expect(find.byType(AngrenzendWahl), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('angrenzend-1')));
      await tester.pump();
      expect(planung.aktuell.anschluss.angrenzend, [1]);
      expect(
        zustand.unveraendert,
        isNot(contains(PlanerSchritt.terrassenanschluss)),
      );
    });
  });

  testWidgets('Seiten mit Rolle vom Server in der Zeichnung (M7)', (
    tester,
  ) async {
    final planung = PlanungsSteuerung();
    final berechnung = BerechnungsSteuerung(
      planung: planung,
      berechne: (_) async => Berechnung(
        umriss: const [],
        flaeche: 0,
        anschluss: Anschlussergebnis(
          seiten: const [
            (
              seite: 0,
              rolle: Seitenrolle.bauelement,
              von: Punkt(0, 0),
              bis: Punkt(4800, 0),
            ),
          ],
        ),
      ),
    );
    addTearDown(() {
      berechnung.dispose();
      planung.dispose();
    });
    await tester.pump();
    expect(berechnung.zeichnung.seiten, [
      (Offset.zero, const Offset(4800, 0), Seitenrolle.bauelement),
    ]);
  });
}
