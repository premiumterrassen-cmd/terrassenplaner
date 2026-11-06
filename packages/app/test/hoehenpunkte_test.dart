import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/rahmen/ansichtsoptionen.dart';
import 'package:terrassenplaner_app/src/rahmen/berechnung_steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/hoehenpunkte.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_schritt.dart';
import 'package:terrassenplaner_app/src/rahmen/rahmen_zustand.dart';
import 'package:terrassenplaner_app/src/rahmen/steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/unterkonstruktion.dart';
import 'package:terrassenplaner_app/src/rahmen/zeichenflaeche.dart';
import 'package:terrassenplaner_app/src/rahmen/zeichnung.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

({PlanungsSteuerung planung, HoehenpunktBedienung b, List<int> aenderungen})
_bedienung([Planungsstand stand = Planungsstand.start]) {
  final planung = PlanungsSteuerung()..setze(stand);
  final aenderungen = <int>[];
  return (
    planung: planung,
    b: HoehenpunktBedienung(
      planung: planung,
      onGeaendert: () => aenderungen.add(aenderungen.length),
    ),
    aenderungen: aenderungen,
  );
}

void main() {
  group('Bedienung der Höhenreferenzpunkte (M7-04)', () {
    test('hinzufügen, ändern, ziehen (ein Schritt je Zug), entfernen', () {
      final s = _bedienung();
      addTearDown(s.planung.dispose);
      s.b.fuegeHinzu();
      expect(s.planung.aktuell.hoehenpunkte, hasLength(1));
      expect(s.planung.aktuell.gefaelle, isTrue);
      s.b.aendere(
        0,
        (alt) => (x: const Millimeter(-100), y: alt.y, hoehe: alt.hoehe),
      );
      expect(s.planung.aktuell.hoehenpunkte.single.x, const Millimeter(-100));
      s.b.ziehe(0, const Punkt(10.4, 20), beginn: true);
      s.b.ziehe(0, const Punkt(50, -30.6), beginn: false);
      final p = s.planung.aktuell.hoehenpunkte.single;
      expect(p.x, const Millimeter(-50));
      expect(p.y, const Millimeter(1545 - 31));
      expect(p.hoehe, const Millimeter(86));
      expect(s.aenderungen, [0, 1, 2]);
      s.planung.rueckgaengig();
      expect(s.planung.aktuell.hoehenpunkte.single.x, const Millimeter(-100));
      s.b.entferne(0);
      expect(s.planung.aktuell.hoehenpunkte, isEmpty);
      expect(s.aenderungen, hasLength(4));
    });
  });

  group('Eingabe unter 3.2 (M7-04)', () {
    Future<
      ({
        PlanungsSteuerung planung,
        HoehenpunktBedienung b,
        List<int> aenderungen,
      })
    >
    zeige(WidgetTester tester, Planungsstand stand) async {
      final s = _bedienung(stand);
      addTearDown(s.planung.dispose);
      await tester.pumpWidget(
        testApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HoehenpunkteWahl(
                planung: s.planung,
                weitere: s.b,
                onGeaendert: () {},
              ),
            ),
          ),
        ),
      );
      return s;
    }

    Future<void> gib(
      WidgetTester tester,
      String schluessel,
      String text,
    ) async {
      final feld = find.descendant(
        of: find.byKey(ValueKey(schluessel)),
        matching: find.byType(TextField),
      );
      await tester.enterText(feld, text);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
    }

    testWidgets('nur mit Gefälle; Felder, Fehler, Entfernen', (tester) async {
      final s = await zeige(
        tester,
        Planungsstand.start.mitNeuemHoehenpunkt().mitGefaelle(false),
      );
      expect(find.byKey(const ValueKey('hoehenpunkte-weitere')), findsNothing);
      s.planung.setze(s.planung.aktuell.mitGefaelle(true));
      await tester.pump();
      expect(find.text(de.hoehenpunktName(1)), findsOneWidget);
      expect(find.text(de.hoehenpunktHilfe), findsOneWidget);
      await gib(tester, 'hoehenpunkt-0-x', '-12,5');
      await gib(tester, 'hoehenpunkt-0-y', '30');
      await gib(tester, 'hoehenpunkt-0-hoehe', '5');
      expect(s.planung.aktuell.hoehenpunkte.single, (
        x: const Millimeter(-125),
        y: const Millimeter(300),
        hoehe: const Millimeter(50),
      ));
      await gib(tester, 'hoehenpunkt-0-x', '40000');
      expect(find.text(de.hoehenpunktLageUngueltig), findsOneWidget);
      await gib(tester, 'hoehenpunkt-0-y', '-40000');
      expect(find.text(de.hoehenpunktLageUngueltig), findsNWidgets(2));
      await tester.ensureVisible(
        find.byKey(const ValueKey('hoehenpunkt-hinzufuegen')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('hoehenpunkt-hinzufuegen')));
      await tester.pump();
      expect(s.planung.aktuell.hoehenpunkte, hasLength(2));
      await tester.ensureVisible(
        find.byKey(const ValueKey('hoehenpunkt-0-entfernen')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('hoehenpunkt-0-entfernen')));
      await tester.pump();
      expect(s.planung.aktuell.hoehenpunkte, hasLength(1));
      expect(s.aenderungen, hasLength(5));
    });

    testWidgets('Kreis ja, offene Freiform nein', (tester) async {
      final kreis = await zeige(
        tester,
        Planungsstand.start.mitForm(Terrassenform.kreis).mitGefaelle(true),
      );
      expect(
        find.byKey(const ValueKey('hoehenpunkte-weitere')),
        findsOneWidget,
      );
      kreis.planung.setze(
        Planungsstand.start.mitForm(Terrassenform.freiform).mitGefaelle(true),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('hoehenpunkte-weitere')), findsNothing);
    });
  });

  testWidgets('Abläufe vom Server und Griffe in der Zeichnung (M7-04)', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1440, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = _bedienung(Planungsstand.start.mitNeuemHoehenpunkt());
    final ansicht = AnsichtSteuerung();
    final berechnung = BerechnungsSteuerung(
      planung: s.planung,
      berechne: (planung) async => Berechnung(
        umriss: const [],
        flaeche: 0,
        anschluss: Anschlussergebnis(
          hoehenpunkte: [
            for (final p in planung.aktuell.hoehenpunkte)
              (ort: planung.aktuell.ortVon(p), hoehe: p.hoehe),
          ],
        ),
      ),
    );
    addTearDown(() {
      berechnung.dispose();
      s.planung.dispose();
      ansicht.dispose();
    });
    await tester.pump();
    expect(berechnung.zeichnung.ablaeufe, [const Offset(2400, 1545)]);
    await tester.pumpWidget(
      testApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: berechnung,
            builder: (context, _) => Zeichenflaeche(
              planung: s.planung,
              ansicht: ansicht,
              optionen: AnsichtsOptionen(),
              hoehenpunkte: s.b,
              zeichnung: berechnung.zeichnung,
            ),
          ),
        ),
      ),
    );
    final ursprung = tester.getTopLeft(
      find.byKey(const ValueKey('zeichenflaeche')),
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('hoehenpunkt-griff-0'))),
      ursprung + ansicht.verschiebung + const Offset(240, 154.5),
    );
    await tester.drag(
      find.byKey(const ValueKey('hoehenpunkt-griff-0')),
      const Offset(-50, 30),
    );
    await tester.pump();
    final p = s.planung.aktuell.hoehenpunkte.single;
    expect([p.x.mm, p.y.mm], [1900, 1845]);
    // ohne Bedienung keine Griffe
    await tester.pumpWidget(
      testApp(
        home: Scaffold(
          body: Zeichenflaeche(
            planung: s.planung,
            ansicht: ansicht,
            optionen: AnsichtsOptionen(),
            zeichnung: Zeichnung(ablaeufe: const [Offset(10, 10)]),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('hoehenpunkt-griff-0')), findsNothing);
  });

  testWidgets('im Rahmen: Eingabe unter 3.2, Griffe nur im Schritt 3', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1440, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final planung = PlanungsSteuerung()
      ..setze(Planungsstand.start.mitNeuemHoehenpunkt());
    addTearDown(planung.dispose);
    final zustand = RahmenZustand()..waehle(PlanerSchritt.unterkonstruktion);
    await tester.pumpWidget(
      testApp(
        home: PlanerRahmen(
          status: const SizedBox(),
          zustand: zustand,
          planung: planung,
          zeichnung: Zeichnung(ablaeufe: const [Offset(2400, 1545)]),
        ),
      ),
    );
    expect(find.byType(HoehenpunktEingabe), findsOneWidget);
    expect(find.byKey(const ValueKey('hoehenpunkt-griff-0')), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('hoehenpunkt-0-entfernen')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hoehenpunkt-0-entfernen')));
    await tester.pump();
    expect(
      zustand.unveraendert,
      isNot(contains(PlanerSchritt.unterkonstruktion)),
    );
    zustand.waehle(PlanerSchritt.grundriss);
    await tester.pump();
    expect(find.byKey(const ValueKey('hoehenpunkt-griff-0')), findsNothing);
  });
}
