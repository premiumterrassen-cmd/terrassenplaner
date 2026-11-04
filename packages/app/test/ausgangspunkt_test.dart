import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/design/planer_design.dart';
import 'package:terrassenplaner_app/src/rahmen/ansichtsoptionen.dart';
import 'package:terrassenplaner_app/src/rahmen/ausgangspunkt.dart';
import 'package:terrassenplaner_app/src/rahmen/berechnung_steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_schritt.dart';
import 'package:terrassenplaner_app/src/rahmen/rahmen_zustand.dart';
import 'package:terrassenplaner_app/src/rahmen/steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/zeichenflaeche.dart';
import 'package:terrassenplaner_app/src/rahmen/zeichnung.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

/// Antwort wie vom Server: Grenzen 480 × 6,5 cm, kurze Zuschnitte nur ohne
/// Verschiebung nach unten.
Future<Berechnung> _berechne(Planung planung) async {
  final stand = planung.aktuell;
  return Berechnung(
    umriss: stand.grundriss.ecken,
    flaeche: 1,
    dielen: const [
      [Punkt(0, 0), Punkt(100, 0), Punkt(100, 65)],
    ],
    ausgangspunkt:
        stand.ausgangspunkt +
        Punkt(
          stand.verschiebungX.mm.toDouble(),
          stand.verschiebungY.mm.toDouble(),
        ),
    grenzeLinksRechts: const Millimeter(4800),
    grenzeObenUnten: const Millimeter(65),
    kurzeZuschnitte: stand.verschiebungY.mm == 0,
  );
}

Future<Berechnung> _ohneDielen(Planung planung) async =>
    Berechnung(umriss: planung.aktuell.grundriss.ecken, flaeche: 1);

typedef _Aufbau = ({
  PlanungsSteuerung planung,
  BerechnungsSteuerung berechnung,
  AusgangspunktBedienung bedienung,
  List<int> aenderungen,
});

_Aufbau _aufbau([PlanungBerechnen berechne = _berechne]) {
  final planung = PlanungsSteuerung();
  final berechnung = BerechnungsSteuerung(planung: planung, berechne: berechne);
  final aenderungen = <int>[];
  addTearDown(() {
    berechnung.dispose();
    planung.dispose();
  });
  return (
    planung: planung,
    berechnung: berechnung,
    bedienung: AusgangspunktBedienung(
      planung: planung,
      berechnung: berechnung,
      onGeaendert: () => aenderungen.add(aenderungen.length),
    ),
    aenderungen: aenderungen,
  );
}

Finder _feld(String achse) => find.descendant(
  of: find.byKey(ValueKey('verschiebung-$achse')),
  matching: find.byKey(const ValueKey('feld')),
);

Finder _regler(String achse) => find.descendant(
  of: find.byKey(ValueKey('verschiebung-$achse')),
  matching: find.byKey(const ValueKey('regler')),
);

void main() {
  group('Bedienung', () {
    test('ohne Berechnung keine Grenzen, Verschiebung bleibt 0', () {
      final planung = PlanungsSteuerung();
      addTearDown(planung.dispose);
      var aenderungen = 0;
      final b = AusgangspunktBedienung(
        planung: planung,
        onGeaendert: () => aenderungen++,
      );
      expect(b.grenzeLinksRechts, const Millimeter(0));
      expect(b.grenzeObenUnten, const Millimeter(0));
      expect(b.kurzeZuschnitte, isFalse);
      b.verschiebe(x: const Millimeter(100), y: const Millimeter(-100));
      expect(planung.aktuell.verschiebungX, const Millimeter(0));
      expect(planung.aktuell.verschiebungY, const Millimeter(0));
      expect(aenderungen, 1);
      b.waehleEcke(2);
      expect(planung.aktuell.ausgangsecke, 2);
      expect(aenderungen, 2);
    });

    test('Verschiebung begrenzt, Ziehen ein Schritt im Verlauf', () async {
      final s = _aufbau();
      await pumpEventQueue();
      final b = s.bedienung;
      expect(b.grenzeLinksRechts, const Millimeter(4800));
      expect(b.grenzeObenUnten, const Millimeter(65));
      expect(b.kurzeZuschnitte, isTrue);
      b.verschiebe(x: const Millimeter(9000));
      expect(s.planung.aktuell.verschiebungX, const Millimeter(4800));
      expect(s.planung.aktuell.verschiebungY, const Millimeter(0));
      b.verschiebe(x: const Millimeter(-9000), y: const Millimeter(-70));
      expect(s.planung.aktuell.verschiebungX, const Millimeter(-4800));
      expect(s.planung.aktuell.verschiebungY, const Millimeter(-65));
      b.verschiebe(y: const Millimeter(20));
      expect(s.planung.aktuell.verschiebungX, const Millimeter(-4800));
      expect(s.planung.aktuell.verschiebungY, const Millimeter(20));
      expect(s.aenderungen, hasLength(3));
      // Ziehen: Beginn ist ein Schritt, danach wird nur ersetzt
      b
        ..ziehe(const Punkt(100.4, 9.6), beginn: true)
        ..ziehe(const Punkt(200, 30), beginn: false);
      expect(s.planung.aktuell.verschiebungX, const Millimeter(-4600));
      expect(s.planung.aktuell.verschiebungY, const Millimeter(50));
      expect(s.aenderungen, hasLength(4));
      s.planung.rueckgaengig();
      expect(s.planung.aktuell.verschiebungX, const Millimeter(-4800));
      expect(s.planung.aktuell.verschiebungY, const Millimeter(20));
      s.planung.wiederherstellen();
      expect(s.planung.aktuell.verschiebungX, const Millimeter(-4600));
    });
  });

  group('Eingabe', () {
    Future<_Aufbau> zeige(
      WidgetTester tester, {
      PlanungBerechnen berechne = _berechne,
      Locale sprache = const Locale('de'),
    }) async {
      final s = _aufbau(berechne);
      await tester.pumpWidget(
        testApp(
          sprache: sprache,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AusgangspunktWahl(bedienung: s.bedienung),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return s;
    }

    testWidgets('Ecken A bis D, Vorgabe A', (tester) async {
      final s = await zeige(tester);
      expect(
        find.text(
          'Welcher Punkt soll der Ausgangspunkt des Terrassenbelages sein?',
        ),
        findsOneWidget,
      );
      bool gewaehlt(int i) => tester
          .widget<ChoiceChip>(find.byKey(ValueKey('ausgangsecke-$i')))
          .selected;
      for (final (i, name) in ['A', 'B', 'C', 'D'].indexed) {
        expect(find.text(name), findsOneWidget);
        expect(gewaehlt(i), i == 0);
      }
      expect(find.byKey(const ValueKey('ausgangsecke-4')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('ausgangsecke-0')));
      await tester.pumpAndSettle();
      expect(s.aenderungen, isEmpty);
      await tester.tap(find.byKey(const ValueKey('ausgangsecke-2')));
      await tester.pumpAndSettle();
      expect(s.planung.aktuell.ausgangsecke, 2);
      expect(gewaehlt(2), isTrue);
      expect(gewaehlt(0), isFalse);
      expect(s.aenderungen, hasLength(1));
      // L-Form: sechs Ecken
      s.planung.setze(s.planung.aktuell.mitForm(Terrassenform.lForm));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ausgangsecke-5')), findsOneWidget);
    });

    testWidgets('Eingabefeld in cm mit Grenze und Warnung', (tester) async {
      final s = await zeige(tester);
      expect(
        find.text(
          'Verschieben Sie die erste ganze Diele mit dem Mauszeiger oder dem '
          'Eingabefeld nach:',
        ),
        findsOneWidget,
      );
      expect(find.text('links/rechts um'), findsOneWidget);
      expect(find.text('oben/unten um'), findsOneWidget);
      expect(find.text('in cm, negativ = links'), findsOneWidget);
      expect(find.text('in cm, negativ = oben'), findsOneWidget);
      final warnung = find.byKey(const ValueKey('zuschnitt-warnung'));
      expect(warnung, findsOneWidget);
      expect(
        find.text(
          'Achtung: Es entstehen Zuschnitte unter 5 cm. Verschieben Sie die '
          'erste ganze Diele, damit keine so schmalen oder kurzen Stücke '
          'entstehen.',
        ),
        findsOneWidget,
      );
      InputDecoration deko(String achse) =>
          tester.widget<TextField>(_feld(achse)).decoration!;
      expect(deko('x').hintText, '0 cm');
      for (final (achse, falsch) in [
        ('x', '480,1'),
        ('x', '-481'),
        ('y', '6,6'),
        ('y', 'x'),
      ]) {
        await tester.enterText(_feld(achse), falsch);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(
          deko(achse).errorText,
          'Bitte eine Zahl von −${achse == 'x' ? '480' : '6,5'} bis '
          '${achse == 'x' ? '480' : '6,5'} cm eingeben',
          reason: falsch,
        );
      }
      expect(s.aenderungen, isEmpty);
      await tester.enterText(_feld('x'), ' -480 ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(s.planung.aktuell.verschiebungX, const Millimeter(-4800));
      expect(deko('x').errorText, isNull);
      expect(deko('x').hintText, '-480 cm');
      expect(tester.widget<TextField>(_feld('x')).controller!.text, isEmpty);
      await tester.enterText(_feld('y'), '6,5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(s.planung.aktuell.verschiebungY, const Millimeter(65));
      expect(deko('y').hintText, '6,5 cm');
      expect(s.aenderungen, hasLength(2));
      // mit Verschiebung nach unten keine kurzen Zuschnitte mehr
      expect(warnung, findsNothing);
      await tester.enterText(_feld('y'), '-0.4');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(s.planung.aktuell.verschiebungY, const Millimeter(-4));
    });

    testWidgets('Schieberegler in ganzen cm, ein Zug ein Schritt', (
      tester,
    ) async {
      final s = await zeige(tester);
      final x = tester.widget<Slider>(_regler('x'));
      expect([x.min, x.max, x.value, x.divisions], [-4800, 4800, 0, 960]);
      expect(x.label, '0 cm');
      final y = tester.widget<Slider>(_regler('y'));
      expect([y.min, y.max, y.divisions], [-65, 65, 13]);
      // vom Mittelpunkt ganz nach rechts
      await tester.drag(_regler('y'), const Offset(2000, 0));
      await tester.pumpAndSettle();
      expect(s.planung.aktuell.verschiebungY, const Millimeter(65));
      expect(s.aenderungen, hasLength(1));
      // Antippen links der Mitte: ein Schritt nach links
      final links = tester.getRect(_regler('x'));
      await tester.tapAt(links.centerLeft + Offset(links.width / 4, 0));
      await tester.pumpAndSettle();
      expect(s.planung.aktuell.verschiebungX.mm, lessThan(0));
      expect(s.planung.aktuell.verschiebungX.mm % 10, 0);
      expect(s.aenderungen, hasLength(2));
      s.planung.rueckgaengig();
      await tester.pumpAndSettle();
      expect(s.planung.aktuell.verschiebungY, const Millimeter(65));
      s.planung.rueckgaengig();
      await tester.pumpAndSettle();
      expect(s.planung.aktuell, Planungsstand.start);
      // Wert außerhalb der Grenzen (vor der Antwort des Servers): am Rand
      s.planung.setze(
        s.planung.aktuell.mitAusgangspunkt(y: const Millimeter(-300)),
      );
      await tester.pump();
      expect(tester.widget<Slider>(_regler('y')).value, -65);
      expect(tester.widget<Slider>(_regler('y')).label, '-30 cm');
    });

    testWidgets('ohne Dielen keine Verschiebung', (tester) async {
      await zeige(tester, berechne: _ohneDielen);
      expect(
        find.text(
          'Verschieben lässt sich die erste Diele, sobald ein Belag aus '
          'Dielen verlegt ist.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('verschiebung-x')), findsNothing);
      expect(find.byKey(const ValueKey('zuschnitt-warnung')), findsNothing);
    });

    testWidgets('Texte auf Englisch', (tester) async {
      await zeige(tester, sprache: const Locale('en'));
      for (final text in [
        'Which point should be the starting point of the decking?',
        'Move the first full board with the mouse pointer or the input field:',
        'left/right by',
        'up/down by',
        'in cm, negative = left',
        'in cm, negative = up',
        'Caution: there are cuts under 5 cm. Move the first full board so '
            'that no such narrow or short pieces are left.',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(
        en.verschiebungUngueltig('6.5'),
        'Please enter a number from −6.5 to 6.5 cm',
      );
      expect(
        en.verschiebungOhneDielen,
        'The first board can be moved as soon as decking boards are laid.',
      );
    });
  });

  testWidgets('Griff in der Zeichnung verschiebt die erste ganze Diele', (
    tester,
  ) async {
    final s = _aufbau();
    final ansicht = AnsichtSteuerung();
    final optionen = AnsichtsOptionen();
    addTearDown(ansicht.dispose);
    addTearDown(optionen.dispose);
    Widget flaeche({AusgangspunktBedienung? bedienung, Offset? punkt}) =>
        testApp(
          home: Scaffold(
            body: Zeichenflaeche(
              planung: s.planung,
              ansicht: ansicht,
              optionen: optionen,
              ausgangspunkt: bedienung,
              zeichnung: Zeichnung(
                umriss: const [
                  Offset(0, 0),
                  Offset(4800, 0),
                  Offset(4800, 3090),
                  Offset(0, 3090),
                ],
                ausgangspunkt: punkt,
              ),
            ),
          ),
        );
    final griff = find.byKey(const ValueKey('ausgangspunkt-griff'));
    await tester.pumpWidget(flaeche(punkt: const Offset(100, 200)));
    expect(griff, findsNothing);
    await tester.pumpWidget(flaeche(bedienung: s.bedienung));
    expect(griff, findsNothing);
    await tester.pumpWidget(
      flaeche(bedienung: s.bedienung, punkt: const Offset(100, 200)),
    );
    await tester.pumpAndSettle();
    final ursprung = tester.getTopLeft(
      find.byKey(const ValueKey('zeichenflaeche')),
    );
    // 100|200 mm = 10|20 px
    expect(tester.getCenter(griff), ursprung + const Offset(10, 20));
    await tester.drag(griff, const Offset(30, 4));
    await tester.pump();
    expect(s.planung.aktuell.verschiebungX, const Millimeter(300));
    expect(s.planung.aktuell.verschiebungY, const Millimeter(40));
    expect(s.aenderungen, hasLength(1));
    // Zoom 200 %: dieselbe Strecke ist die halbe Verschiebung
    ansicht.value = Matrix4.identity()..scaleByDouble(2, 2, 2, 1);
    await tester.pump();
    expect(tester.getCenter(griff), ursprung + const Offset(20, 40));
    await tester.drag(griff, const Offset(-30, 0));
    await tester.pump();
    expect(s.planung.aktuell.verschiebungX, const Millimeter(150));
    expect(s.aenderungen, hasLength(2));
  });

  testWidgets('im Rahmen: Unterpunkt 2.5 und Griff nur im Schritt '
      'Terrassenbelag', (tester) async {
    tester.view
      ..physicalSize = const Size(1440, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final zustand = RahmenZustand();
    await tester.pumpWidget(
      testApp(
        theme: planerThema(),
        home: PlanerRahmen(
          status: const Text('Status'),
          zustand: zustand,
          berechne: _berechne,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final griff = find.byKey(const ValueKey('ausgangspunkt-griff'));
    expect(griff, findsNothing);
    expect(find.byKey(const ValueKey('ausgangspunkt')), findsNothing);
    zustand.waehle(PlanerSchritt.terrassenbelag);
    await tester.pumpAndSettle();
    expect(griff, findsOneWidget);
    final ecke = find.byKey(const ValueKey('ausgangsecke-1'));
    await tester.scrollUntilVisible(
      ecke,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('bearbeitungsmenue')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(ecke);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(ecke).selected, isTrue);
    expect(zustand.unveraendert, isNot(contains(PlanerSchritt.terrassenbelag)));
    // Griff liegt jetzt an B
    final ursprung = tester.getTopLeft(
      find.byKey(const ValueKey('zeichenflaeche')),
    );
    final ansicht = tester
        .widget<Zeichenflaeche>(find.byType(Zeichenflaeche))
        .ansicht;
    expect(
      tester.getCenter(griff),
      ursprung + ansicht.verschiebung + const Offset(480, 0) * ansicht.zoom,
    );
    zustand.waehle(PlanerSchritt.grundriss);
    await tester.pumpAndSettle();
    expect(griff, findsNothing);
  });
}
