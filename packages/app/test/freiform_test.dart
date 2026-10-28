import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/design/planer_design.dart';
import 'package:terrassenplaner_app/src/rahmen/ansichtsoptionen.dart';
import 'package:terrassenplaner_app/src/rahmen/freiform.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/rahmen/rahmen_zustand.dart';
import 'package:terrassenplaner_app/src/rahmen/steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/zeichenflaeche.dart';
import 'package:terrassenplaner_app/src/rahmen/zeichnung.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

FreiformGrundriss _f(PlanungsSteuerung p) =>
    p.aktuell.grundriss as FreiformGrundriss;

({
  PlanungsSteuerung planung,
  ZeichenModus modus,
  FreiformBedienung b,
  List<int> geaendert,
})
_bedienung() {
  final planung = PlanungsSteuerung(
    Planungsstand.start.mitForm(Terrassenform.freiform),
  );
  final modus = ZeichenModus();
  final geaendert = <int>[];
  return (
    planung: planung,
    modus: modus,
    geaendert: geaendert,
    b: FreiformBedienung(
      planung: planung,
      modus: modus,
      onGeaendert: () => geaendert.add(geaendert.length),
    ),
  );
}

void main() {
  group('ZeichenModus', () {
    test('Vorgaben und Meldungen', () {
      final m = ZeichenModus();
      var meldungen = 0;
      m.addListener(() => meldungen++);
      expect([m.einrasten, m.zeichnungshilfe], [true, true]);
      expect(m.eingabe, Masseingabe.strecke);
      m
        ..einrasten = false
        ..zeichnungshilfe = false
        ..eingabe = Masseingabe.koordinaten;
      expect([m.einrasten, m.zeichnungshilfe], [false, false]);
      expect(m.eingabe, Masseingabe.koordinaten);
      expect(meldungen, 3);
    });
  });

  group('FreiformBedienung', () {
    test('Punkte mit Einrasten und Zeichnungshilfe', () {
      final s = _bedienung();
      expect(s.b.setzePunkt(const Punkt(149, 151)), isNull);
      expect(_f(s.planung).punkte, [const Punkt(100, 200)]);
      // 3 cm „schief“: Zeichnungshilfe richtet waagrecht aus, dann Raster
      expect(s.b.setzePunkt(const Punkt(2130, 230)), isNull);
      expect(_f(s.planung).punkte.last, const Punkt(2100, 200));
      expect(s.geaendert, [0, 1]);
    });

    test('ohne Hilfen bleibt der Punkt, wo er ist', () {
      final s = _bedienung();
      s.modus
        ..einrasten = false
        ..zeichnungshilfe = false;
      s.b
        ..setzePunkt(const Punkt(149, 151))
        ..setzePunkt(const Punkt(2130, 230));
      expect(_f(s.planung).punkte, const [Punkt(149, 151), Punkt(2130, 230)]);
    });

    test('nur Einrasten, nur Zeichnungshilfe', () {
      final s = _bedienung();
      s.modus.zeichnungshilfe = false;
      s.b
        ..setzePunkt(Punkt.ursprung)
        ..setzePunkt(const Punkt(2130, 230));
      expect(_f(s.planung).punkte.last, const Punkt(2100, 200));
      final t = _bedienung();
      t.modus.einrasten = false;
      t.b
        ..setzePunkt(Punkt.ursprung)
        ..setzePunkt(const Punkt(2000, 30));
      expect(_f(t.planung).punkte.last.y, closeTo(0, 1e-9));
    });

    test('Rückmeldungen: 3 Punkte, kreuzen, Kantenlänge', () {
      final s = _bedienung();
      s.b.setzePunkt(Punkt.ursprung);
      expect(s.b.setzePunkt(const Punkt(40, 0)), FreiformFehler.kante);
      s.b.setzePunkt(const Punkt(3000, 0));
      expect(s.b.schliesse(), FreiformFehler.mindestens3);
      s.modus.zeichnungshilfe = false;
      s.b
        ..setzePunkt(const Punkt(0, 2000))
        ..setzePunkt(const Punkt(3000, 2000));
      expect(s.b.schliesse(), FreiformFehler.kreuzt);
      s.b.entferneLetzten();
      expect(s.b.schliesse(), isNull);
      expect(_f(s.planung).geschlossen, isTrue);
      expect(s.b.offen, isNull);
      // zurück in die offene Form
      s.b.entferneLetzten();
      expect(s.b.offen, isNotNull);
      // drei Punkte auf einer Linie umschließen nichts
      final t = _bedienung();
      t.b
        ..setzePunkt(Punkt.ursprung)
        ..setzePunkt(const Punkt(1000, 0))
        ..setzePunkt(const Punkt(2000, 0));
      expect(t.b.schliesse(), FreiformFehler.kreuzt);
    });

    test('Zeichnungshilfe per Maß: letzter Punkt', () {
      final s = _bedienung();
      s.b
        ..setzePunkt(Punkt.ursprung)
        ..setzePunkt(const Punkt(1000, 0));
      expect(s.b.korrigiere(const Punkt(2500, 0)), isNull);
      expect(_f(s.planung).punkte.last, const Punkt(2500, 0));
      expect(s.b.korrigiere(const Punkt(50, 0)), FreiformFehler.kante);
    });

    test('Meldungstexte', () {
      expect(
        FreiformBedienung.meldung(de, FreiformFehler.mindestens3),
        'Die Form braucht mindestens 3 Punkte.',
      );
      expect(
        FreiformBedienung.meldung(de, FreiformFehler.kreuzt),
        'Die Kanten dürfen sich nicht kreuzen.',
      );
      expect(
        FreiformBedienung.meldung(de, FreiformFehler.kante),
        'Kanten müssen 10 bis 3000 cm lang sein.',
      );
      expect(
        FreiformBedienung.meldung(en, FreiformFehler.kante),
        'Edges must be 10 to 3000 cm long.',
      );
      expect(en.freiformHinweis, 'Set points – [x] to close the shape');
      expect(
        [en.einrastfunktion, en.zeichnungshilfe, en.formFreiform],
        ['Snap to grid', 'Drawing aid', 'Freeform'],
      );
    });
  });

  group('FreiformEingabe', () {
    Future<({PlanungsSteuerung planung, ZeichenModus modus})> zeige(
      WidgetTester tester, {
      List<Punkt> punkte = const [Punkt(0, 0), Punkt(1000, 0)],
    }) async {
      final s = _bedienung();
      addTearDown(s.planung.dispose);
      addTearDown(s.modus.dispose);
      s.planung.setze(
        s.planung.aktuell.mitGrundriss(FreiformGrundriss(punkte)),
      );
      await tester.pumpWidget(
        testApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: s.planung,
              builder: (context, _) =>
                  SingleChildScrollView(child: FreiformEingabe(bedienung: s.b)),
            ),
          ),
        ),
      );
      return (planung: s.planung, modus: s.modus);
    }

    Future<void> gib(
      WidgetTester tester,
      String schluessel,
      String text,
    ) async {
      await tester.enterText(find.byKey(ValueKey(schluessel)), text);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
    }

    testWidgets('Strecke: Länge und Winkel vom vorletzten Punkt', (
      tester,
    ) async {
      final s = await zeige(tester);
      expect(find.text('Länge: cm'), findsOneWidget);
      expect(find.text('Winkel: °'), findsOneWidget);
      await gib(tester, 'freiform-0', '250');
      expect(_f(s.planung).punkte.last.x, closeTo(2500, 1e-6));
      await gib(tester, 'freiform-1', '90');
      final p = _f(s.planung).punkte.last;
      expect(p.x, closeTo(0, 1e-6));
      expect(p.y, closeTo(2500, 1e-6));
    });

    testWidgets('Koordinaten: X und Y des letzten Punkts', (tester) async {
      final s = await zeige(tester);
      await tester.tap(find.text('Koordinaten'));
      await tester.pump();
      expect(s.modus.eingabe, Masseingabe.koordinaten);
      expect(find.text('X: cm'), findsOneWidget);
      await gib(tester, 'freiform-0', '300');
      expect(_f(s.planung).punkte.last, const Punkt(3000, 0));
      await gib(tester, 'freiform-1', '-150');
      expect(_f(s.planung).punkte.last, const Punkt(3000, -1500));
      // 3 cm neben dem vorletzten Punkt (0|0): Kante zu kurz
      await gib(tester, 'freiform-0', '0');
      await gib(tester, 'freiform-1', '3');
      expect(
        find.text('Kanten müssen 10 bis 3000 cm lang sein.'),
        findsOneWidget,
      );
    });

    testWidgets('Strecke mit nur einem Punkt: Hinweis', (tester) async {
      await zeige(tester, punkte: const [Punkt(0, 0)]);
      await gib(tester, 'freiform-0', '250');
      expect(find.text('Bitte 10 bis 3000 cm eingeben'), findsOneWidget);
    });

    testWidgets('Schalter, schließen, entfernen', (tester) async {
      final s = await zeige(tester);
      await tester.tap(find.text('Einrastfunktion'));
      await tester.tap(find.text('Zeichnungshilfe'));
      await tester.pump();
      expect([s.modus.einrasten, s.modus.zeichnungshilfe], [false, false]);
      await tester.tap(find.byKey(const ValueKey('form-schliessen')));
      await tester.pump();
      expect(
        find.text('Die Form braucht mindestens 3 Punkte.'),
        findsOneWidget,
      );
      s.planung.setze(
        s.planung.aktuell.mitGrundriss(
          _f(s.planung).mitPunkt(const Punkt(0, 1000)),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('form-schliessen')));
      await tester.pump();
      expect(_f(s.planung).geschlossen, isTrue);
      expect(find.byKey(const ValueKey('form-geschlossen')), findsOneWidget);
      expect(find.byKey(const ValueKey('masseingabe')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('punkt-entfernen')));
      await tester.pump();
      expect(_f(s.planung).punkte, hasLength(2));
      expect(_f(s.planung).geschlossen, isFalse);
    });

    testWidgets('ohne Punkte nichts zu entfernen', (tester) async {
      await zeige(tester, punkte: const []);
      final knopf = tester.widget<TextButton>(
        find.byKey(const ValueKey('punkt-entfernen')),
      );
      expect(knopf.onPressed, isNull);
    });
  });

  group('Zeichnen auf der Zeichenfläche', () {
    Future<
      ({
        RahmenZustand zustand,
        PlanungsSteuerung planung,
        AnsichtSteuerung ansicht,
      })
    >
    zeige(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(1440, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final zustand = RahmenZustand();
      final planung = PlanungsSteuerung();
      final ansicht = AnsichtSteuerung();
      addTearDown(planung.dispose);
      addTearDown(ansicht.dispose);
      await tester.pumpWidget(
        testApp(
          theme: planerThema(),
          home: PlanerRahmen(
            status: const Text('Status'),
            zustand: zustand,
            planung: planung,
            ansicht: ansicht,
            berechne: (stand) async => switch (stand.grundriss) {
              FreiformGrundriss(geschlossen: false, :final punkte) =>
                Berechnung(umriss: punkte, flaeche: 0, geschlossen: false),
              final g => Berechnung(
                umriss: g.kontur.vieleck(),
                ecken: g.ecken,
                flaeche: g.kontur.flaeche,
              ),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (zustand: zustand, planung: planung, ansicht: ansicht);
    }

    testWidgets('Freiform: tippen setzt Punkte, x schließt', (tester) async {
      final s = await zeige(tester);
      await tester.tap(find.byKey(const ValueKey('form-freiform')));
      await tester.pumpAndSettle();
      expect(find.text('Fläche: – m²'), findsOneWidget);
      expect(
        find.text('Punkte setzen – [x] zum Schließen der Form'),
        findsOneWidget,
      );
      final flaeche = find.byKey(const ValueKey('freiform-zeichnen'));
      final ursprung = tester.getTopLeft(flaeche);
      // 100 px = 1 m bei 100 %
      for (final p in const [
        Offset(100, 100),
        Offset(400, 100),
        Offset(400, 300),
      ]) {
        await tester.tapAt(ursprung + p);
        await tester.pumpAndSettle();
      }
      expect(_f(s.planung).punkte, const [
        Punkt(1000, 1000),
        Punkt(4000, 1000),
        Punkt(4000, 3000),
      ]);
      final maler = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((c) => c.painter)
          .whereType<ZeichnungsMaler>()
          .single;
      expect(maler.zeichnung.geschlossen, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
      await tester.pumpAndSettle();
      expect(_f(s.planung).geschlossen, isTrue);
      expect(find.text('Fläche: 3,000 m²'), findsOneWidget);
      expect(find.byKey(const ValueKey('freiform-zeichnen')), findsNothing);
    });

    testWidgets('x mit zu wenig Punkten: Rückmeldung', (tester) async {
      final s = await zeige(tester);
      await tester.tap(find.byKey(const ValueKey('form-freiform')));
      await tester.pumpAndSettle();
      await tester.tapAt(
        tester.getTopLeft(find.byKey(const ValueKey('freiform-zeichnen'))) +
            const Offset(100, 100),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
      await tester.pumpAndSettle();
      expect(
        find.text('Die Form braucht mindestens 3 Punkte.'),
        findsOneWidget,
      );
      expect(_f(s.planung).geschlossen, isFalse);
    });

    testWidgets('x wirkt beim Drücken; Antippen holt den Fokus zurück', (
      tester,
    ) async {
      final s = await zeige(tester);
      await tester.tap(find.byKey(const ValueKey('form-freiform')));
      await tester.pumpAndSettle();
      // Fokus erst in ein Eingabefeld des Menüs
      await tester.tap(find.byKey(const ValueKey('freiform-0')));
      await tester.pump();
      final ursprung = tester.getTopLeft(
        find.byKey(const ValueKey('freiform-zeichnen')),
      );
      for (final p in const [
        Offset(100, 100),
        Offset(400, 100),
        Offset(400, 300),
      ]) {
        await tester.tapAt(ursprung + p);
        await tester.pumpAndSettle();
      }
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyX);
      await tester.pump();
      expect(_f(s.planung).geschlossen, isTrue);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyX);
      await tester.pumpAndSettle();
    });

    test('Bildschirm in mm', () {
      final ansicht = AnsichtSteuerung()..zoomeAuf(2);
      final z = Zeichenflaeche(
        planung: PlanungsSteuerung(),
        ansicht: ansicht,
        optionen: AnsichtsOptionen(),
        zeichnung: Zeichnung.leer,
      );
      final p = z.inMillimeter(ansicht.verschiebung + const Offset(200, 100));
      expect(p.x, closeTo(1000, 1e-9));
      expect(p.y, closeTo(500, 1e-9));
    });
  });
}
