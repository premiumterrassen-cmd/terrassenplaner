import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/design/planer_design.dart';
import 'package:terrassenplaner_app/src/rahmen/ansichtsoptionen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_schritt.dart';
import 'package:terrassenplaner_app/src/rahmen/rahmen_zustand.dart';
import 'package:terrassenplaner_app/src/rahmen/rundung.dart';
import 'package:terrassenplaner_app/src/rahmen/steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/zeichenflaeche.dart';
import 'package:terrassenplaner_app/src/rahmen/zeichnung.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

final _rechteck = Planungsstand(
  grundriss: RechteckGrundriss(const Millimeter(5400), const Millimeter(3600)),
);

({PlanungsSteuerung planung, RundungsBedienung b, List<int> geaendert})
_bedienung([Planungsstand? stand]) {
  final planung = PlanungsSteuerung(stand ?? _rechteck);
  final geaendert = <int>[];
  return (
    planung: planung,
    geaendert: geaendert,
    b: RundungsBedienung(
      planung: planung,
      onGeaendert: () => geaendert.add(geaendert.length),
    ),
  );
}

/// Richtung von Ecke A nach innen (Winkelhalbierende) in mm.
final _innenA = const Punkt(1, 1) * (1 / math.sqrt2);

void main() {
  group('RundungsBedienung', () {
    test('möglich nur mit Ecken und geschlossen', () {
      expect(_bedienung().b.moeglich, isTrue);
      expect(
        _bedienung(Planungsstand.start.mitForm(Terrassenform.kreis)).b.moeglich,
        isFalse,
      );
      expect(
        _bedienung(Planungsstand.start.mitForm(Terrassenform.freiform))
            .b
            .moeglich,
        isFalse,
      );
    });

    test('öffnen, setzen, übernehmen', () {
      final s = _bedienung();
      var meldungen = 0;
      s.b.addListener(() => meldungen++);
      expect(s.b.aktiv, isFalse);
      s.b.oeffne();
      expect(s.b.aktiv, isTrue);
      s.b.waehle((ecke: true, nummer: 0));
      expect(s.b.auswahl, (ecke: true, nummer: 0));
      expect(
        s.b.setze((ecke: true, nummer: 0), const Millimeter(1261)),
        isTrue,
      );
      expect(s.planung.aktuell.kontur.flaeche / 1e6, closeTo(19.099, 0.001));
      expect(
        s.b.setze((ecke: false, nummer: 1), const Millimeter(300)),
        isTrue,
      );
      expect(s.planung.aktuell.rundungen.seiten, {1: const Millimeter(300)});
      // unzulässig: bleibt, wie es war
      expect(
        s.b.setze((ecke: true, nummer: 1), const Millimeter(9000)),
        isFalse,
      );
      expect(s.planung.aktuell.rundungen.ecken.keys, [0]);
      expect(s.geaendert, [0, 1]);
      s.b.uebernimm();
      expect(s.b.aktiv, isFalse);
      expect(s.b.auswahl, isNull);
      expect(s.planung.aktuell.rundungen.leer, isFalse);
      expect(meldungen, 3);
    });

    test('zurücksetzen auf den Stand beim Öffnen', () {
      final s = _bedienung();
      s.b
        ..oeffne()
        ..setze((ecke: true, nummer: 0), const Millimeter(1000))
        ..setze((ecke: true, nummer: 2), const Millimeter(500))
        ..setzeZurueck();
      expect(s.planung.aktuell, _rechteck);
      expect(s.b.aktiv, isFalse);
    });

    test('Ziehen: ein Schritt, Radius nie negativ, unzulässig bleibt aus', () {
      final s = _bedienung();
      s.b
        ..oeffne()
        ..ziehe((ecke: true, nummer: 0), _innenA * 300, _innenA, beginn: true)
        ..ziehe((ecke: true, nummer: 0), _innenA * 800, _innenA, beginn: false);
      expect(s.planung.aktuell.rundungen.ecken[0], const Millimeter(800));
      expect(s.b.auswahl, (ecke: true, nummer: 0));
      // nach außen gezogen: Radius 0 = keine Rundung
      s.b.ziehe(
        (ecke: true, nummer: 0),
        _innenA * -500,
        _innenA,
        beginn: false,
      );
      expect(s.planung.aktuell.rundungen.ecken, isEmpty);
      // viel zu groß: der letzte gültige Stand bleibt
      s.b
        ..ziehe((ecke: true, nummer: 0), _innenA * 400, _innenA, beginn: false)
        ..ziehe(
          (ecke: true, nummer: 0),
          _innenA * 9000,
          _innenA,
          beginn: false,
        );
      expect(s.planung.aktuell.rundungen.ecken[0], const Millimeter(400));
      s.planung.rueckgaengig();
      expect(s.planung.aktuell, _rechteck);
      expect(s.geaendert, [0]);
    });

    test('Seite ziehen nach außen und innen, Fortsetzung vom alten Stich', () {
      final s = _bedienung();
      const aussen = Punkt(0, -1);
      s.b.ziehe(
        (ecke: false, nummer: 0),
        const Punkt(0, -400),
        aussen,
        beginn: true,
      );
      expect(s.planung.aktuell.rundungen.seiten[0], const Millimeter(400));
      s.b.ziehe(
        (ecke: false, nummer: 0),
        const Punkt(0, 100),
        aussen,
        beginn: true,
      );
      expect(s.planung.aktuell.rundungen.seiten[0], const Millimeter(300));
      s.b.ziehe(
        (ecke: false, nummer: 0),
        const Punkt(0, 900),
        aussen,
        beginn: false,
      );
      expect(s.planung.aktuell.rundungen.seiten[0], const Millimeter(-500));
      // ungültiger Beginn: kein Schritt
      final t = _bedienung();
      t.b.ziehe((ecke: true, nummer: 0), _innenA * 9000, _innenA, beginn: true);
      expect(t.planung.kannRueckgaengig, isFalse);
    });
  });

  group('RundungsEingabe', () {
    Future<({PlanungsSteuerung planung, RundungsBedienung b})> zeige(
      WidgetTester tester, [
      Planungsstand? stand,
    ]) async {
      final s = _bedienung(stand);
      addTearDown(s.planung.dispose);
      addTearDown(s.b.dispose);
      await tester.pumpWidget(
        testApp(
          home: Scaffold(
            body: SingleChildScrollView(child: RundungsEingabe(bedienung: s.b)),
          ),
        ),
      );
      return (planung: s.planung, b: s.b);
    }

    Future<void> gib(WidgetTester tester, String text) async {
      await tester.enterText(find.byKey(const ValueKey('rundung-0')), text);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
    }

    testWidgets('Kreis: kein Abrunden', (tester) async {
      await zeige(tester, Planungsstand.start.mitForm(Terrassenform.kreis));
      final knopf = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('rundungen-hinzufuegen')),
      );
      expect(knopf.onPressed, isNull);
    });

    testWidgets('Radius und Stich per Eingabe, entfernen, übernehmen', (
      tester,
    ) async {
      final s = await zeige(tester);
      await tester.tap(find.text('Rundungen hinzufügen'));
      await tester.pump();
      expect(find.byKey(const ValueKey('rundung-hinweis')), findsOneWidget);
      expect(find.byKey(const ValueKey('rundung-auswahl')), findsNothing);
      s.b.waehle((ecke: true, nummer: 1));
      await tester.pump();
      expect(find.text('Ecke B'), findsOneWidget);
      expect(find.byKey(const ValueKey('rundung-auswahl')), findsOneWidget);
      expect(find.text('Radius: cm'), findsOneWidget);
      await gib(tester, '100');
      expect(s.planung.aktuell.rundungen.ecken[1], const Millimeter(1000));
      await gib(tester, '500');
      expect(find.text('Diese Rundung ist nicht möglich.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rundung-entfernen')));
      await tester.pump();
      expect(s.planung.aktuell.rundungen.leer, isTrue);
      s.b.waehle((ecke: false, nummer: 2));
      await tester.pump();
      expect(find.text('Seite ab C'), findsOneWidget);
      await gib(tester, '-20');
      expect(s.planung.aktuell.rundungen.seiten[2], const Millimeter(-200));
      await tester.tap(find.byKey(const ValueKey('rundungen-uebernehmen')));
      await tester.pump();
      expect(s.b.aktiv, isFalse);
      expect(find.text('Rundungen hinzufügen'), findsOneWidget);
    });

    testWidgets('zurücksetzen', (tester) async {
      final s = await zeige(tester);
      await tester.tap(find.text('Rundungen hinzufügen'));
      await tester.pump();
      s.b.setze((ecke: true, nummer: 0), const Millimeter(1000));
      await tester.tap(find.byKey(const ValueKey('rundungen-zuruecksetzen')));
      await tester.pump();
      expect(s.planung.aktuell, _rechteck);
    });
  });

  group('Rundungsmodus im Rahmen', () {
    Future<({RahmenZustand zustand, PlanungsSteuerung planung})> zeige(
      WidgetTester tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1440, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final zustand = RahmenZustand();
      final planung = PlanungsSteuerung(_rechteck);
      addTearDown(planung.dispose);
      await tester.pumpWidget(
        testApp(
          theme: planerThema(),
          home: PlanerRahmen(
            status: const Text('Status'),
            zustand: zustand,
            planung: planung,
            berechne: (p) async => Berechnung(
              umriss: p.aktuell.kontur.vieleck(),
              ecken: p.aktuell.grundriss.ecken,
              flaeche: p.aktuell.kontur.flaeche,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('rundungen-hinzufuegen')),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('bearbeitungsmenue')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(const ValueKey('rundungen-hinzufuegen')));
      await tester.pumpAndSettle();
      return (zustand: zustand, planung: planung);
    }

    testWidgets('Griffe statt Eckenbearbeitung, Ecke abrunden', (tester) async {
      final s = await zeige(tester);
      expect(find.byKey(const ValueKey('rundung-ecke-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('rundung-seite-3')), findsOneWidget);
      expect(find.byKey(const ValueKey('ecke-0')), findsNothing);
      // je 50 px = 0,5 m nach rechts und unten: entlang der Winkelhalbierenden 70,7 cm
      await tester.drag(
        find.byKey(const ValueKey('rundung-ecke-0')),
        const Offset(50, 50),
      );
      await tester.pumpAndSettle();
      final r = s.planung.aktuell.rundungen.ecken[0]!.mm;
      expect(r, closeTo(707, 1));
      expect(find.text('Ecke A'), findsOneWidget);
      // Seitengriff sitzt auf dem Bogen: nach Ziehen weiter greifbar
      await tester.drag(
        find.byKey(const ValueKey('rundung-seite-0')),
        const Offset(0, -30),
      );
      await tester.pumpAndSettle();
      expect(s.planung.aktuell.rundungen.seiten[0], const Millimeter(300));
      await tester.tap(find.byKey(const ValueKey('rundung-seite-0')));
      await tester.pumpAndSettle();
      expect(find.text('Seite ab A'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rundung-ecke-1')));
      await tester.pumpAndSettle();
      expect(find.text('Ecke B'), findsOneWidget);
    });

    testWidgets('Griffe folgen dem Zoom', (tester) async {
      tester.view
        ..physicalSize = const Size(1440, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final planung = PlanungsSteuerung(_rechteck);
      final ansicht = AnsichtSteuerung()
        ..value = (Matrix4.identity()..scaleByDouble(2, 2, 2, 1));
      final b = RundungsBedienung(planung: planung, onGeaendert: () {})
        ..oeffne();
      addTearDown(planung.dispose);
      addTearDown(ansicht.dispose);
      await tester.pumpWidget(
        testApp(
          home: Scaffold(
            body: Zeichenflaeche(
              planung: planung,
              ansicht: ansicht,
              optionen: AnsichtsOptionen(),
              rundung: b,
              zeichnung: Zeichnung(
                umriss: [
                  for (final p in _rechteck.grundriss.ecken) Offset(p.x, p.y),
                ],
              ),
            ),
          ),
        ),
      );
      final ursprung = tester.getTopLeft(
        find.byKey(const ValueKey('zeichenflaeche')),
      );
      // Seite A—B: Mitte 2700 mm · 0,1 px/mm · 2 = 540 px
      expect(
        tester.getCenter(find.byKey(const ValueKey('rundung-seite-0'))),
        ursprung + const Offset(540, 0),
      );
    });

    testWidgets('ESC übernimmt', (tester) async {
      final s = await zeige(tester);
      await tester.drag(
        find.byKey(const ValueKey('rundung-ecke-0')),
        const Offset(50, 50),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('rundung-ecke-0')), findsNothing);
      expect(s.planung.aktuell.rundungen.leer, isFalse);
      // ESC ohne offenen Modus: nichts
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(s.planung.aktuell.rundungen.leer, isFalse);
    });

    testWidgets('Schritt wechseln fragt: zurücksetzen oder übernehmen', (
      tester,
    ) async {
      final s = await zeige(tester);
      await tester.drag(
        find.byKey(const ValueKey('rundung-ecke-0')),
        const Offset(50, 50),
      );
      await tester.pumpAndSettle();
      s.zustand.waehle(PlanerSchritt.terrassenbelag);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('rundung-verlassen')), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('rundung-verlassen-zuruecksetzen')),
      );
      await tester.pumpAndSettle();
      expect(s.planung.aktuell, _rechteck);
      // erneut, diesmal übernehmen
      s.zustand.waehle(PlanerSchritt.grundriss);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('rundungen-hinzufuegen')),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('bearbeitungsmenue')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(const ValueKey('rundungen-hinzufuegen')));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('rundung-ecke-0')),
        const Offset(50, 50),
      );
      await tester.pumpAndSettle();
      s.zustand.waehle(PlanerSchritt.treppen);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('rundung-verlassen-uebernehmen')),
      );
      await tester.pumpAndSettle();
      expect(s.planung.aktuell.rundungen.leer, isFalse);
      // ohne offenen Modus kein Dialog
      s.zustand.waehle(PlanerSchritt.zubehoer);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('rundung-verlassen')), findsNothing);
    });
  });

  test('englische Texte', () {
    expect(en.rundungEcke('A'), 'Corner A');
    expect(en.rundungSeite('B'), 'Side from B');
    expect(
      [
        en.rundungenHinzufuegen,
        en.rundungenUebernehmen,
        en.rundungenZuruecksetzen,
      ],
      ['Add roundings', 'Apply roundings', 'Reset roundings'],
    );
    expect(
      [en.feldRadius, en.feldStich, en.rundungEntfernen],
      ['Radius', 'Rise', 'Remove rounding'],
    );
    expect(en.rundungUnzulaessig, 'This rounding is not possible.');
    expect(en.rundungVerlassenTitel, 'Apply roundings?');
    expect(en.rundungHinweis, contains('(ESC)'));
    expect(en.rundungVerlassenText, startsWith('You are leaving'));
  });
}
