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

RechteckGrundriss _rechteck(Planungsstand stand) =>
    stand.grundriss as RechteckGrundriss;

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
            body: GrundrissMasse(
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
      for (final text in ['abc', '49', '3001', '', '-']) {
        await tester.enterText(find.byKey(const ValueKey('mass-1')), text);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        expect(find.text('Bitte 50 bis 3000 cm eingeben'), findsOneWidget);
      }
      expect(s.planung.aktuell, Planungsstand.start);
      expect(s.geaendert, isEmpty);
      await tester.enterText(find.byKey(const ValueKey('mass-1')), '50');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text('Bitte 50 bis 3000 cm eingeben'), findsNothing);
      expect(_rechteck(s.planung.aktuell).bc, const Millimeter(500));
      await tester.enterText(find.byKey(const ValueKey('mass-0')), '3000');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(_rechteck(s.planung.aktuell).ab, const Millimeter(30000));
    });
  });

  group('Formwahl (M4-03)', () {
    Future<({PlanungsSteuerung planung, List<int> geaendert})> zeige(
      WidgetTester tester,
    ) async {
      final planung = PlanungsSteuerung();
      addTearDown(planung.dispose);
      final geaendert = <int>[];
      await tester.pumpWidget(
        testApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: planung,
              builder: (context, _) => Column(
                children: [
                  FormWahl(
                    planung: planung,
                    onGeaendert: () => geaendert.add(geaendert.length),
                  ),
                  GrundrissMasse(
                    key: ValueKey(planung.aktuell.grundriss.form),
                    planung: planung,
                    onGeaendert: () => geaendert.add(geaendert.length),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return (planung: planung, geaendert: geaendert);
    }

    ChoiceChip chip(WidgetTester tester, Terrassenform form) =>
        tester.widget(find.byKey(ValueKey('form-${form.name}')));

    testWidgets('L-Form mit Vorgabemaßen und vier Feldern', (tester) async {
      final s = await zeige(tester);
      expect(chip(tester, Terrassenform.rechteck).selected, isTrue);
      expect(chip(tester, Terrassenform.lForm).selected, isFalse);
      expect(find.byType(TextField), findsNWidgets(2));
      await tester.tap(find.text('L-Form'));
      await tester.pump();
      expect(s.planung.aktuell.grundriss, LGrundriss.vorgabe);
      expect(chip(tester, Terrassenform.lForm).selected, isTrue);
      expect(find.byType(TextField), findsNWidgets(4));
      expect(find.text('C — D: cm'), findsOneWidget);
      expect(find.text('D — E: cm'), findsOneWidget);
      expect(s.geaendert, [0]);
      // dieselbe Form erneut: keine Änderung
      await tester.tap(find.text('L-Form'));
      await tester.pump();
      expect(s.geaendert, [0]);
      expect(s.planung.kannRueckgaengig, isTrue);
      await tester.enterText(find.byKey(const ValueKey('mass-2')), '100');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(
        s.planung.aktuell.grundriss,
        LGrundriss.vorgabe.mitMass(2, const Millimeter(1000)),
      );
      expect(s.geaendert, [0, 1]);
      // abgeleitete Seite E—F zu lang
      await tester.enterText(find.byKey(const ValueKey('mass-0')), '2950');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text('Bitte 50 bis 3000 cm eingeben'), findsOneWidget);
      // zurück zum Rechteck: dessen Vorgabe
      await tester.tap(find.text('Rechteck'));
      await tester.pump();
      expect(s.planung.aktuell.grundriss, RechteckGrundriss.start);
      expect(find.byType(TextField), findsNWidgets(2));
    });

    test('Formnamen in beiden Sprachen', () {
      expect(FormWahl.name(de, Terrassenform.rechteck), 'Rechteck');
      expect(FormWahl.name(de, Terrassenform.lForm), 'L-Form');
      expect(FormWahl.name(en, Terrassenform.rechteck), 'Rectangle');
      expect(FormWahl.name(en, Terrassenform.lForm), 'L-shape');
      expect(FormWahl.name(de, Terrassenform.tForm), 'T-Form');
      expect(FormWahl.name(en, Terrassenform.tForm), 'T-shape');
      expect(FormWahl.name(de, Terrassenform.uForm), 'U-Form');
      expect(FormWahl.name(en, Terrassenform.uForm), 'U-shape');
    });
  });

  group('O-Form und Ausschnitt (M4-06)', () {
    Future<PlanungsSteuerung> zeige(WidgetTester tester) async {
      final planung = PlanungsSteuerung(
        Planungsstand.start.mitForm(Terrassenform.oForm),
      );
      addTearDown(planung.dispose);
      await tester.pumpWidget(
        testApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: planung,
              builder: (context, _) => SingleChildScrollView(
                child: AusschnittMasse(planung: planung, onGeaendert: () {}),
              ),
            ),
          ),
        ),
      );
      return planung;
    }

    testWidgets('Block „Ausschnitt A1“ mit X, Y, Länge, Breite', (
      tester,
    ) async {
      final planung = await zeige(tester);
      expect(find.text('Ausschnitt A1'), findsOneWidget);
      for (final name in ['X', 'Y', 'Länge', 'Breite']) {
        expect(find.text('$name: cm'), findsOneWidget);
      }
      await tester.enterText(
        find.byKey(const ValueKey('ausschnitt-0-0')),
        '-20',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(
        planung.aktuell.ausschnitte.single,
        Ausschnitt.oForm.mitMass(0, const Millimeter(-200)),
      );
      await tester.enterText(find.byKey(const ValueKey('ausschnitt-0-3')), '9');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text('Bitte 10 bis 3000 cm eingeben'), findsOneWidget);
      expect(planung.aktuell.ausschnitte.single.breite, const Millimeter(1800));
    });

    testWidgets('ohne Ausschnitte kein Block', (tester) async {
      final planung = PlanungsSteuerung();
      addTearDown(planung.dispose);
      await tester.pumpWidget(
        testApp(
          home: Scaffold(
            body: AusschnittMasse(planung: planung, onGeaendert: () {}),
          ),
        ),
      );
      expect(find.byType(TextField), findsNothing);
    });

    test('englische Feldnamen', () {
      expect(en.ausschnittTitel('A1'), 'Cut-out A1');
      expect([en.feldLaenge, en.feldBreite], ['Length', 'Width']);
      expect(FormWahl.name(de, Terrassenform.oForm), 'O-Form');
      expect(FormWahl.name(en, Terrassenform.oForm), 'O-shape');
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

    testWidgets('L-Form: Zeichnung mit sechs Ecken', (tester) async {
      final s = await zeige(tester, _wieServer);
      await tester.tap(find.byKey(const ValueKey('form-lForm')));
      await tester.pumpAndSettle();
      expect(find.text('Fläche: 14,58 m²'), findsOneWidget);
      expect(find.byKey(const ValueKey('mass-3')), findsOneWidget);
      expect(s.zustand.unveraendert, isNot(contains(PlanerSchritt.grundriss)));
      s.planung.rueckgaengig();
      await tester.pumpAndSettle();
      expect(find.text('Fläche: 14,83 m²'), findsOneWidget);
      expect(find.byKey(const ValueKey('mass-3')), findsNothing);
    });

    testWidgets('O-Form: Ausschnitt gezeichnet, Fläche außen', (tester) async {
      final s = await zeige(tester, (stand) async {
        final k = stand.grundriss.kontur;
        return Berechnung(
          umriss: k.punkte,
          flaeche: k.flaeche,
          ausschnitte: [for (final a in stand.ausschnitte) a.kontur.punkte],
        );
      });
      await tester.tap(find.byKey(const ValueKey('form-oForm')));
      await tester.pumpAndSettle();
      expect(find.text('Fläche: 19,44 m²'), findsOneWidget);
      expect(s.planung.aktuell.ausschnitte, [Ausschnitt.oForm]);
      final maler = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((c) => c.painter)
          .whereType<ZeichnungsMaler>()
          .single;
      expect(maler.zeichnung.ausschnitte.single.first, const Offset(1500, 900));
      await tester.scrollUntilVisible(
        find.text('Ausschnitt A1'),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('bearbeitungsmenue')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Ausschnitt A1'), findsOneWidget);
      // Eingabe im Ausschnitt zählt als Änderung im Grundriss
      s.zustand.vergissAenderungen();
      await tester.enterText(
        find.byKey(const ValueKey('ausschnitt-0-0')),
        '100',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(s.zustand.unveraendert, isNot(contains(PlanerSchritt.grundriss)));
      expect(s.planung.aktuell.ausschnitte.single.x, const Millimeter(1000));
    });

    testWidgets('Felder nur unter 1.1 und 1.2', (tester) async {
      final s = await zeige(tester, _wieServer);
      expect(find.byType(FormWahl), findsOneWidget);
      expect(find.byType(GrundrissMasse), findsOneWidget);
      s.zustand.waehle(PlanerSchritt.terrassenbelag);
      await tester.pumpAndSettle();
      expect(find.byType(GrundrissMasse), findsNothing);
      expect(find.byType(FormWahl), findsNothing);
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
    expect(en.massUngueltig(50, 3000), 'Please enter 50 to 3000 cm');
    expect(
      en.berechnungFehler,
      'Calculation not possible – please check the connection',
    );
  });
}
