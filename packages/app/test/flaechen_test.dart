import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/design/planer_design.dart';
import 'package:terrassenplaner_app/src/rahmen/berechnung_steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_schritt.dart';
import 'package:terrassenplaner_app/src/rahmen/rahmen_zustand.dart';
import 'package:terrassenplaner_app/src/rahmen/steuerung.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

final _klein = Planungsstand(
  grundriss: RechteckGrundriss(const Millimeter(2000), const Millimeter(1000)),
);

/// Rechnet wie der Server (M4-14): bearbeitete Fläche und Summe aller
/// Flächen mal Häufigkeit.
Future<Berechnung> _wieServer(Planung p) async {
  final k = p.aktuell.kontur;
  return Berechnung(
    umriss: k.punkte,
    flaeche: k.flaeche,
    gesamtflaeche: p.flaechen.fold<double>(
      0,
      (s, f) => s + f.stand.kontur.flaeche * f.haeufigkeit,
    ),
  );
}

void main() {
  group('PlanungsSteuerung mit mehreren Flächen (M4-14)', () {
    test('Stand wirkt auf die bearbeitete Fläche', () {
      final s = PlanungsSteuerung.mit(
        Planung.start.mitNeuerFlaeche().gewaehlt(0),
      );
      addTearDown(s.dispose);
      var meldungen = 0;
      s
        ..addListener(() => meldungen++)
        ..setze(_klein);
      expect(s.planung.flaechen.map((f) => f.stand), [
        _klein,
        Planungsstand.start,
      ]);
      expect(s.aktuell, _klein);
      expect(meldungen, 1);
      s.setzePlanung(s.planung.gewaehlt(1));
      expect(s.aktuell, Planungsstand.start);
      expect(meldungen, 2);
      // Ziehen: ersetzt ohne Schritt, nur in der bearbeiteten Fläche
      s.ersetze(_klein);
      expect(meldungen, 3);
      expect(s.planung.flaechen[1].stand, _klein);
      s.rueckgaengig();
      expect(s.planung.aktiv, 0);
      expect(s.aktuell, _klein);
      expect(s.planung.flaechen[1].stand, Planungsstand.start);
      s.wiederherstellen();
      expect(s.planung.aktiv, 1);
    });

    test('Zurücksetzen: eine Fläche mit Startkonfiguration', () {
      final s = PlanungsSteuerung(_klein)
        ..setzePlanung(Planung.start.mitNeuerFlaeche());
      addTearDown(s.dispose);
      expect(s.planung.flaechen, hasLength(2));
      s.zuruecksetzen();
      expect(s.planung, Planung.start);
      expect(s.kannRueckgaengig, isFalse);
      expect(PlanungsSteuerung().planung, Planung.start);
    });
  });

  group('Gesamtfläche (M4-14)', () {
    test('nur bei mehreren Flächen oder Häufigkeit über 1', () async {
      final planung = PlanungsSteuerung();
      addTearDown(planung.dispose);
      final b = BerechnungsSteuerung(planung: planung, berechne: _wieServer);
      addTearDown(b.dispose);
      expect(b.gesamtflaeche, isNull);
      await pumpEventQueue();
      expect(b.gesamtflaeche, isNull);
      expect(b.flaeche, 14.832);
      planung.setzePlanung(planung.planung.mitHaeufigkeit(2));
      await pumpEventQueue();
      expect(b.gesamtflaeche, 2 * 14.832);
      planung.setzePlanung(
        planung.planung.mitHaeufigkeit(1).mitNeuerFlaeche().mitStand(_klein),
      );
      await pumpEventQueue();
      expect(b.flaeche, 2);
      expect(b.gesamtflaeche, 16.832);
    });
  });

  group('Flächenreiter im Rahmen', () {
    Future<({RahmenZustand zustand, PlanungsSteuerung planung})> zeige(
      WidgetTester tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1440, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final zustand = RahmenZustand();
      final planung = PlanungsSteuerung();
      addTearDown(planung.dispose);
      await tester.pumpWidget(
        testApp(
          theme: planerThema(),
          home: PlanerRahmen(
            status: const Text('Status'),
            zustand: zustand,
            planung: planung,
            berechne: _wieServer,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (zustand: zustand, planung: planung);
    }

    IconButton knopf(WidgetTester tester, String schluessel) =>
        tester.widget<IconButton>(find.byKey(ValueKey(schluessel)));

    testWidgets('anlegen, wechseln, löschen mit Gesamtfläche', (tester) async {
      final s = await zeige(tester);
      expect(find.text('Fläche 1'), findsOneWidget);
      expect(find.text('Fläche 2'), findsNothing);
      expect(find.textContaining('Gesamtfläche'), findsNothing);
      expect(knopf(tester, 'flaeche-loeschen').onPressed, isNull);
      expect(s.zustand.unveraendert, contains(PlanerSchritt.grundriss));

      await tester.tap(find.byKey(const ValueKey('flaeche-hinzufuegen')));
      await tester.pumpAndSettle();
      expect(find.text('Fläche 2'), findsOneWidget);
      expect(s.planung.planung.aktiv, 1);
      expect(s.zustand.unveraendert, isNot(contains(PlanerSchritt.grundriss)));
      expect(find.text('Gesamtfläche: 29,664 m²'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('flaeche-1')))
            .selected,
        isTrue,
      );

      // zweite Fläche ändern: die erste bleibt
      s.planung.setze(_klein);
      await tester.pumpAndSettle();
      expect(find.text('Fläche: 2,000 m²'), findsOneWidget);
      expect(find.text('Gesamtfläche: 16,832 m²'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('flaeche-0')));
      await tester.pumpAndSettle();
      expect(s.planung.planung.aktiv, 0);
      expect(find.text('Fläche: 14,832 m²'), findsOneWidget);
      // gewählte Fläche noch einmal: kein neuer Schritt
      s.planung.rueckgaengig();
      await tester.pumpAndSettle();
      expect(s.planung.planung.aktiv, 1);
      await tester.tap(find.byKey(const ValueKey('flaeche-1')));
      await tester.pumpAndSettle();
      expect(s.planung.kannWiederherstellen, isTrue);

      await tester.tap(find.byKey(const ValueKey('flaeche-loeschen')));
      await tester.pumpAndSettle();
      expect(s.planung.planung.flaechen, hasLength(1));
      expect(s.planung.aktuell, Planungsstand.start);
      expect(find.text('Fläche 2'), findsNothing);
      expect(find.textContaining('Gesamtfläche'), findsNothing);
    });

    testWidgets('Häufigkeit 1 bis 99 wirkt auf die Gesamtfläche', (
      tester,
    ) async {
      final s = await zeige(tester);
      expect(
        find.byTooltip(
          'Wie oft diese Fläche gebaut wird. Die Materialmengen werden '
          'entsprechend vervielfacht.',
        ),
        findsOneWidget,
      );
      expect(knopf(tester, 'haeufigkeit-weniger').onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('haeufigkeit-mehr')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('haeufigkeit-wert')))
            .data,
        '2',
      );
      expect(s.zustand.unveraendert, isNot(contains(PlanerSchritt.grundriss)));
      expect(find.text('Gesamtfläche: 29,664 m²'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('haeufigkeit-weniger')));
      await tester.pumpAndSettle();
      expect(s.planung.planung.haeufigkeit, 1);
      expect(find.textContaining('Gesamtfläche'), findsNothing);

      s.planung.setzePlanung(s.planung.planung.mitHaeufigkeit(98));
      await tester.pumpAndSettle();
      expect(knopf(tester, 'haeufigkeit-mehr').onPressed, isNotNull);
      await tester.tap(find.byKey(const ValueKey('haeufigkeit-mehr')));
      await tester.pumpAndSettle();
      expect(s.planung.planung.haeufigkeit, 99);
      expect(knopf(tester, 'haeufigkeit-mehr').onPressed, isNull);
      expect(knopf(tester, 'haeufigkeit-weniger').onPressed, isNotNull);
    });
  });

  group('Kennzahlen', () {
    testWidgets('Gesamtfläche als eigene Zeile', (tester) async {
      await tester.pumpWidget(
        testApp(home: const Kennzahlen(flaeche: 2, gesamtflaeche: 16.832)),
      );
      expect(find.text('Fläche: 2,000 m²'), findsOneWidget);
      expect(find.text('Gesamtfläche: 16,832 m²'), findsOneWidget);
      await tester.pumpWidget(testApp(home: const Kennzahlen(flaeche: 2)));
      expect(find.textContaining('Gesamtfläche'), findsNothing);
    });
  });
}
