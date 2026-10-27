import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/design/planer_design.dart';
import 'package:terrassenplaner_app/src/rahmen/berechnung_steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/grundriss_eingabe.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_schritt.dart';
import 'package:terrassenplaner_app/src/rahmen/rahmen_zustand.dart';
import 'package:terrassenplaner_app/src/rahmen/steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/zeichnung.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

/// Rechnet wie der Server (M4-02): Umriss und Fläche aus dem Grundriss.
Future<Berechnung> _wieServer(Planungsstand stand) async {
  final k = stand.grundriss.kontur;
  return Berechnung(umriss: k.punkte, flaeche: k.flaeche);
}

RechteckGrundriss _rechteck(Planungsstand stand) => switch (stand.grundriss) {
  final RechteckGrundriss r => r,
};

void main() {
  group('BerechnungsSteuerung', () {
    test('fragt sofort und bei jeder Änderung', () async {
      final planung = PlanungsSteuerung();
      final gefragt = <Planungsstand>[];
      final b = BerechnungsSteuerung(
        planung: planung,
        berechne: (stand) {
          gefragt.add(stand);
          return _wieServer(stand);
        },
      );
      var meldungen = 0;
      b.addListener(() => meldungen++);
      expect([b.ergebnis, b.flaeche, b.fehler], [null, null, null]);
      expect(b.zeichnung.umriss, isEmpty);
      await pumpEventQueue();
      expect(b.flaeche, 14.832);
      expect(b.zeichnung.umriss, const [
        Offset.zero,
        Offset(4800, 0),
        Offset(4800, 3090),
        Offset(0, 3090),
      ]);
      final neu = planung.aktuell.mitGrundriss(
        RechteckGrundriss(const Millimeter(5400), const Millimeter(3600)),
      );
      planung.setze(neu);
      await pumpEventQueue();
      expect(b.flaeche, 19.44);
      expect(gefragt, [Planungsstand.start, neu]);
      expect(meldungen, 2);
      b.dispose();
      planung
        ..rueckgaengig()
        ..dispose();
      expect(gefragt, hasLength(2));
    });

    test('verwirft Antworten zu älteren Ständen', () async {
      final planung = PlanungsSteuerung();
      final antworten = <Completer<Berechnung>>[];
      final b = BerechnungsSteuerung(
        planung: planung,
        berechne: (_) => (antworten..add(Completer())).last.future,
      );
      planung.setze(
        planung.aktuell.mitGrundriss(
          RechteckGrundriss(const Millimeter(5400), const Millimeter(3600)),
        ),
      );
      antworten[1].complete(_wieServer(planung.aktuell));
      await pumpEventQueue();
      expect(b.flaeche, 19.44);
      antworten[0].complete(_wieServer(Planungsstand.start));
      await pumpEventQueue();
      expect(b.flaeche, 19.44);
      planung.setze(Planungsstand.start);
      antworten[2].completeError(StateError('weg'));
      planung.rueckgaengig();
      antworten[3].complete(_wieServer(planung.aktuell));
      await pumpEventQueue();
      expect(b.fehler, isNull);
      b.dispose();
      planung.dispose();
    });

    test('Fehler: letzter gültiger Stand bleibt', () async {
      final planung = PlanungsSteuerung();
      var fehlschlagen = false;
      final b = BerechnungsSteuerung(
        planung: planung,
        berechne: (stand) =>
            fehlschlagen ? Future.error(StateError('weg')) : _wieServer(stand),
      );
      await pumpEventQueue();
      fehlschlagen = true;
      planung.setze(
        planung.aktuell.mitGrundriss(
          RechteckGrundriss(const Millimeter(5400), const Millimeter(3600)),
        ),
      );
      await pumpEventQueue();
      expect(b.fehler, isA<StateError>());
      expect(b.flaeche, 14.832);
      fehlschlagen = false;
      planung.rueckgaengig();
      await pumpEventQueue();
      expect(b.fehler, isNull);
      b.dispose();
      planung.dispose();
    });

    test('nach dem Beenden keine Meldungen mehr', () async {
      final planung = PlanungsSteuerung();
      final antwort = Completer<Berechnung>();
      final b = BerechnungsSteuerung(
        planung: planung,
        berechne: (_) => antwort.future,
      );
      b.dispose();
      antwort.complete(_wieServer(Planungsstand.start));
      await pumpEventQueue();
      expect(b.ergebnis, isNull);
      planung.dispose();
    });
  });

  group('Rechteckmaße', () {
    Future<({PlanungsSteuerung planung, List<int> geaendert})> zeige(
      WidgetTester tester,
    ) async {
      final planung = PlanungsSteuerung();
      addTearDown(planung.dispose);
      final geaendert = <int>[];
      await tester.pumpWidget(
        testApp(
          home: Scaffold(
            body: RechteckMasse(
              planung: planung,
              onGeaendert: () => geaendert.add(geaendert.length),
            ),
          ),
        ),
      );
      return (planung: planung, geaendert: geaendert);
    }

    testWidgets('Platzhalter wie im alten Planer', (tester) async {
      await zeige(tester);
      expect(find.text('A — B: cm'), findsOneWidget);
      expect(find.text('B — C: cm'), findsOneWidget);
    });

    testWidgets('Enter übernimmt A — B und B — C, Feld wird geleert', (
      tester,
    ) async {
      final s = await zeige(tester);
      await tester.enterText(find.byKey(const ValueKey('mass-0')), ' 540 ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(_rechteck(s.planung.aktuell).ab, const Millimeter(5400));
      expect(_rechteck(s.planung.aktuell).bc, const Millimeter(3090));
      expect(find.text('540'), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('mass-1')), '360,5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(_rechteck(s.planung.aktuell).ab, const Millimeter(5400));
      expect(_rechteck(s.planung.aktuell).bc, const Millimeter(3605));
      expect(s.geaendert, [0, 1]);
      expect(s.planung.kannRueckgaengig, isTrue);
    });

    testWidgets('ungültige Eingaben: Hinweis, Planung bleibt', (tester) async {
      final s = await zeige(tester);
      for (final text in ['abc', '49', '2001', '']) {
        await tester.enterText(find.byKey(const ValueKey('mass-1')), text);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        expect(find.text('Bitte 50 bis 2000 cm eingeben'), findsOneWidget);
      }
      expect(s.planung.aktuell, Planungsstand.start);
      expect(s.geaendert, isEmpty);
      await tester.enterText(find.byKey(const ValueKey('mass-1')), '50');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text('Bitte 50 bis 2000 cm eingeben'), findsNothing);
      expect(_rechteck(s.planung.aktuell).bc, const Millimeter(500));
      await tester.enterText(find.byKey(const ValueKey('mass-0')), '2000');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(_rechteck(s.planung.aktuell).ab, const Millimeter(20000));
    });
  });

  group('Rahmen mit Berechnung', () {
    Future<({RahmenZustand zustand, PlanungsSteuerung planung})> zeige(
      WidgetTester tester,
      PlanungBerechnen berechne,
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
            berechne: berechne,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (zustand: zustand, planung: planung);
    }

    testWidgets('Fläche und Zeichnung folgen den Maßen (M4-02)', (
      tester,
    ) async {
      final s = await zeige(tester, _wieServer);
      expect(find.text('Fläche: 14,83 m²'), findsOneWidget);
      // gelungene Berechnung: kein Fehlerhinweis
      expect(
        find.text('Berechnung nicht möglich – bitte Verbindung prüfen'),
        findsNothing,
      );
      expect(s.zustand.unveraendert, contains(PlanerSchritt.grundriss));
      await tester.enterText(find.byKey(const ValueKey('mass-0')), '540');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.enterText(find.byKey(const ValueKey('mass-1')), '360');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Fläche: 19,44 m²'), findsOneWidget);
      expect(s.zustand.unveraendert, isNot(contains(PlanerSchritt.grundriss)));
      // die Zeichnung zeigt den Umriss vom Server
      final maler = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((c) => c.painter)
          .whereType<ZeichnungsMaler>()
          .single;
      expect(maler.zeichnung.umriss[2], const Offset(5400, 3600));
      expect(maler.texte().map((t) => t.text), contains('540 cm'));
    });

    testWidgets('Felder nur unter 1.2 Terrassenmaße', (tester) async {
      final s = await zeige(tester, _wieServer);
      expect(find.byType(RechteckMasse), findsOneWidget);
      s.zustand.waehle(PlanerSchritt.terrassenbelag);
      await tester.pumpAndSettle();
      expect(find.byType(RechteckMasse), findsNothing);
    });

    testWidgets('Fehler der Berechnung als Hinweis', (tester) async {
      var fehlschlagen = false;
      final s = await zeige(
        tester,
        (stand) =>
            fehlschlagen ? Future.error(StateError('weg')) : _wieServer(stand),
      );
      fehlschlagen = true;
      s.planung.setze(
        s.planung.aktuell.mitGrundriss(
          RechteckGrundriss(const Millimeter(5400), const Millimeter(3600)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Berechnung nicht möglich – bitte Verbindung prüfen'),
        findsOneWidget,
      );
      expect(find.text('Fläche: 14,83 m²'), findsOneWidget);
    });

    testWidgets('ohne Berechnung: leere Kennzahlen', (tester) async {
      tester.view
        ..physicalSize = const Size(1440, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testApp(
          theme: planerThema(),
          home: const PlanerRahmen(status: Text('Status')),
        ),
      );
      expect(find.text('Fläche: – m²'), findsOneWidget);
    });
  });

  test('englische Texte der Maßeingabe', () {
    expect(en.massPlatzhalter('A — B'), 'A — B: cm');
    expect(en.massUngueltig(50, 2000), 'Please enter 50 to 2000 cm');
    expect(
      en.berechnungFehler,
      'Calculation not possible – please check the connection',
    );
  });
}
