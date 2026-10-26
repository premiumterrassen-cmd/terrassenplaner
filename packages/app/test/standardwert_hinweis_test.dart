import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/design/planer_design.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_schritt.dart';
import 'package:terrassenplaner_app/src/rahmen/rahmen_zustand.dart';
import 'package:terrassenplaner_app/src/rahmen/standardwert_hinweis.dart';

/// Knopf „Weiter zum Ergebnis“ für den Test – in der App ab M3-06/M9.
Future<List<bool>> _zeige(WidgetTester tester, RahmenZustand zustand) async {
  final ergebnisse = <bool>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: planerThema(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async =>
                ergebnisse.add(await pruefeStandardwerte(context, zustand)),
            child: const Text('Weiter'),
          ),
        ),
      ),
    ),
  );
  return ergebnisse;
}

void main() {
  group('RahmenZustand', () {
    test('anfangs alle Schritte unverändert, in Reihenfolge', () {
      final z = RahmenZustand();
      expect(z.unveraendert, PlanerSchritt.values);
      var meldungen = 0;
      z
        ..addListener(() => meldungen++)
        ..markiereGeaendert(PlanerSchritt.treppen)
        ..markiereGeaendert(PlanerSchritt.grundriss)
        ..markiereGeaendert(PlanerSchritt.treppen);
      expect(z.unveraendert, [
        PlanerSchritt.terrassenbelag,
        PlanerSchritt.unterkonstruktion,
        PlanerSchritt.terrassenanschluss,
        PlanerSchritt.zubehoer,
        PlanerSchritt.verschnittoptimierung,
      ]);
      expect(meldungen, 2, reason: 'zweites Markieren meldet nichts');
      z.vergissAenderungen();
      expect(z.unveraendert, PlanerSchritt.values);
      expect(meldungen, 3);
    });

    test('Ansehen allein zählt nicht als Ändern', () {
      final z = RahmenZustand()..waehle(PlanerSchritt.zubehoer);
      expect(z.unveraendert, contains(PlanerSchritt.zubehoer));
    });
  });

  group('Hinweis', () {
    testWidgets('listet genau die unveränderten Schritte', (tester) async {
      final z = RahmenZustand();
      for (final s in PlanerSchritt.values) {
        if (s != PlanerSchritt.unterkonstruktion &&
            s != PlanerSchritt.zubehoer) {
          z.markiereGeaendert(s);
        }
      }
      await _zeige(tester, z);
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
      expect(find.text(StandardwertHinweis.titel), findsOneWidget);
      expect(find.text(StandardwertHinweis.text), findsOneWidget);
      expect(find.text(StandardwertHinweis.frage), findsOneWidget);
      expect(find.text('• 3. UNTERKONSTRUKTION'), findsOneWidget);
      expect(find.text('• 6. ZUBEHÖR'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('standardwert-zubehoer')))
            .data,
        '• 6. ZUBEHÖR',
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('standardwert-hinweis')),
          matching: find.textContaining('• '),
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('Fortfahren: weiter, Schritt bleibt', (tester) async {
      final z = RahmenZustand()..waehle(PlanerSchritt.treppen);
      final ergebnisse = await _zeige(tester, z);
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('standardwert-fortfahren')));
      await tester.pumpAndSettle();
      expect(ergebnisse, [true]);
      expect(z.aktiv, PlanerSchritt.treppen);
    });

    testWidgets('Zurück: nicht weiter, erster unveränderter Schritt offen', (
      tester,
    ) async {
      final z = RahmenZustand()
        ..markiereGeaendert(PlanerSchritt.grundriss)
        ..waehle(PlanerSchritt.zubehoer);
      final ergebnisse = await _zeige(tester, z);
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('standardwert-zurueck')));
      await tester.pumpAndSettle();
      expect(ergebnisse, [false]);
      expect(z.aktiv, PlanerSchritt.terrassenbelag);
    });

    testWidgets('Tippen daneben zählt als Zurück', (tester) async {
      final z = RahmenZustand();
      final ergebnisse = await _zeige(tester, z);
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(ergebnisse, [false]);
      expect(z.aktiv, PlanerSchritt.grundriss);
    });

    testWidgets('alles geändert: kein Hinweis, direkt weiter', (tester) async {
      final z = RahmenZustand();
      for (final s in PlanerSchritt.values) {
        z.markiereGeaendert(s);
      }
      final ergebnisse = await _zeige(tester, z);
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('standardwert-hinweis')), findsNothing);
      expect(ergebnisse, [true]);
    });

    test('Texte', () {
      expect(StandardwertHinweis.titel, 'Standardwerte beibehalten');
      expect(
        StandardwertHinweis.text,
        'In diesen Schritten haben Sie nichts verändert – dort gelten die '
        'Standardwerte des Planers:',
      );
      expect(StandardwertHinweis.frage, 'Möchten Sie trotzdem fortfahren?');
      expect(StandardwertHinweis.zurueck, 'Zurück');
      expect(StandardwertHinweis.fortfahren, 'Fortfahren');
    });
  });

  testWidgets('Zurücksetzen der Planung vergisst die Änderungen', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1440, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final z = RahmenZustand()..markiereGeaendert(PlanerSchritt.grundriss);
    await tester.pumpWidget(
      MaterialApp(
        home: PlanerRahmen(status: const Text('x'), zustand: z),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('zuruecksetzen')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('zuruecksetzen-bestaetigen')));
    await tester.pumpAndSettle();
    expect(z.unveraendert, PlanerSchritt.values);
  });
}
