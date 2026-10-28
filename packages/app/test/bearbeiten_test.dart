import 'package:flutter/material.dart';
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

Planungsstand _rechteck() => Planungsstand(
  grundriss: RechteckGrundriss(const Millimeter(4000), const Millimeter(3000)),
);

({
  PlanungsSteuerung planung,
  ZeichenModus modus,
  FreiformBedienung b,
  List<int> geaendert,
})
_bedienung([Planungsstand? stand]) {
  final planung = PlanungsSteuerung(stand ?? _rechteck());
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
  test('Steuerung: ersetzen ohne neuen Schritt, Auswahl im Modus', () {
    final p = PlanungsSteuerung();
    var meldungen = 0;
    p.addListener(() => meldungen++);
    p.ersetze(_rechteck());
    expect(p.aktuell, _rechteck());
    expect(p.kannRueckgaengig, isFalse);
    expect(meldungen, 1);
    final m = ZeichenModus();
    var modusMeldungen = 0;
    m.addListener(() => modusMeldungen++);
    expect(m.auswahl, isNull);
    m.auswahl = 2;
    expect(m.auswahl, 2);
    expect(modusMeldungen, 1);
  });

  group('FreiformBedienung beim Bearbeiten (M4-09)', () {
    test('bearbeitbar: feste Formen und geschlossene Freiform', () {
      expect(_bedienung().b.bearbeitbar!.punkte, hasLength(4));
      expect(
        _bedienung(Planungsstand.start.mitForm(Terrassenform.kreis))
            .b
            .bearbeitbar,
        isNull,
      );
      expect(
        _bedienung(Planungsstand.start.mitForm(Terrassenform.freiform))
            .b
            .bearbeitbar,
        isNull,
      );
    });

    test('Ecke ziehen: ein Rückgängig-Schritt, Rechteck wird Freiform', () {
      final s = _bedienung();
      s.modus.einrasten = false;
      s.b
        ..ziehePunkt(2, const Punkt(100, 0), beginn: true)
        ..ziehePunkt(2, const Punkt(503, 201), beginn: false);
      expect(_f(s.planung).punkte[2], const Punkt(4503, 3201));
      expect(_f(s.planung).geschlossen, isTrue);
      expect(s.geaendert, [0]);
      s.planung.rueckgaengig();
      expect(s.planung.aktuell, _rechteck());
      expect(s.planung.kannRueckgaengig, isFalse);
    });

    test('Einrasten beim Ziehen, ungültige Zwischenstände bleiben aus', () {
      final s = _bedienung();
      s.b.ziehePunkt(2, const Punkt(503, 201), beginn: true);
      expect(_f(s.planung).punkte[2], const Punkt(4500, 3200));
      // auf Ecke A gezogen: kreuzt – der letzte gültige Stand bleibt
      s.b.ziehePunkt(2, const Punkt(-4000, -3000), beginn: false);
      expect(_f(s.planung).punkte[2], const Punkt(4500, 3200));
      // ungültiger Beginn legt keinen Schritt an
      final t = _bedienung();
      t.b.ziehePunkt(2, const Punkt(-4000, -3000), beginn: true);
      expect(t.planung.aktuell, _rechteck());
      expect(t.geaendert, isEmpty);
    });

    test('Kante parallel verschieben', () {
      final s = _bedienung();
      s.b
        ..zieheKante(1, const Punkt(100, 30), beginn: true)
        ..zieheKante(1, const Punkt(500, 900), beginn: false);
      expect(_f(s.planung).punkte[1], const Punkt(4500, 0));
      expect(_f(s.planung).punkte[2], const Punkt(4500, 3000));
      s.planung.rueckgaengig();
      expect(s.planung.aktuell, _rechteck());
    });

    test('Punkt einfügen, entfernen bis drei, korrigieren', () {
      final s = _bedienung();
      expect(s.b.fuegePunktEin(0), isNull);
      expect(_f(s.planung).punkte[1], const Punkt(2000, 0));
      s.modus.auswahl = 1;
      expect(s.b.entfernePunkt(1), isNull);
      expect(s.modus.auswahl, isNull);
      expect(s.b.entfernePunkt(0), isNull);
      s.modus.auswahl = 0;
      expect(s.b.entfernePunkt(0), FreiformFehler.mindestens3);
      expect(s.modus.auswahl, 0);
      expect(_f(s.planung).punkte, hasLength(3));
      expect(s.b.korrigierePunkt(0, const Punkt(5000, 0)), isNull);
      expect(_f(s.planung).punkte[0], const Punkt(5000, 0));
    });
  });

  group('Ausgewählte Ecke im Menü', () {
    Future<({PlanungsSteuerung planung, ZeichenModus modus})> zeige(
      WidgetTester tester,
    ) async {
      final s = _bedienung(
        Planungsstand(grundriss: _rechteck().grundriss.alsFreiform!),
      );
      addTearDown(s.planung.dispose);
      addTearDown(s.modus.dispose);
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

    testWidgets('ohne Auswahl ein Hinweis', (tester) async {
      await zeige(tester);
      expect(find.byKey(const ValueKey('ecke-antippen')), findsOneWidget);
      expect(find.byKey(const ValueKey('punkt-ausgewaehlt')), findsNothing);
    });

    testWidgets('Koordinaten und Strecke der Ecke C (Abnahme M4-09)', (
      tester,
    ) async {
      final s = await zeige(tester);
      s.modus.auswahl = 2;
      await tester.pump();
      expect(find.text('Punkt C'), findsOneWidget);
      expect(find.byKey(const ValueKey('punkt-ausgewaehlt')), findsOneWidget);
      // Strecke von B: Länge 400 cm, Winkel bleibt 90°
      await gib(tester, 'freiform-0', '400');
      var c = _f(s.planung).punkte[2];
      expect(c.x, closeTo(4000, 1e-6));
      expect(c.y, closeTo(4000, 1e-6));
      // Winkel 45° von B
      await gib(tester, 'freiform-1', '45');
      c = _f(s.planung).punkte[2];
      expect(c.x, closeTo(4000 + 4000 * 0.7071067811865476, 1e-6));
      // Koordinaten
      await tester.tap(find.text('Koordinaten'));
      await tester.pump();
      await gib(tester, 'freiform-0', '500');
      await gib(tester, 'freiform-1', '350');
      expect(_f(s.planung).punkte[2], const Punkt(5000, 3500));
      // Ecke A: Strecke von der letzten Ecke D
      s.modus.auswahl = 0;
      await tester.tap(find.text('Strecke'));
      await tester.pump();
      await gib(tester, 'freiform-0', '200');
      final a = _f(s.planung).punkte[0];
      expect(a.x, closeTo(0, 1e-6));
      expect(a.y, closeTo(1000, 1e-6));
    });

    testWidgets('Punkt entfernen bis drei, dann Rückmeldung', (tester) async {
      final s = await zeige(tester);
      s.modus.auswahl = 3;
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('ecke-entfernen')));
      await tester.pump();
      expect(_f(s.planung).punkte, hasLength(3));
      expect(find.byKey(const ValueKey('ecke-antippen')), findsOneWidget);
      s.modus.auswahl = 0;
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('ecke-entfernen')));
      await tester.pump();
      expect(
        find.text('Die Form braucht mindestens 3 Punkte.'),
        findsOneWidget,
      );
    });
  });

  group('Ziehpunkte auf der Zeichenfläche', () {
    Future<({RahmenZustand zustand, PlanungsSteuerung planung})> zeige(
      WidgetTester tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1440, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final zustand = RahmenZustand();
      final planung = PlanungsSteuerung(_rechteck());
      addTearDown(planung.dispose);
      await tester.pumpWidget(
        testApp(
          theme: planerThema(),
          home: PlanerRahmen(
            status: const Text('Status'),
            zustand: zustand,
            planung: planung,
            berechne: (stand) async {
              final g = stand.grundriss;
              return Berechnung(
                umriss: g.kontur.vieleck(),
                ecken: g.ecken,
                flaeche: g.kontur.flaeche,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (zustand: zustand, planung: planung);
    }

    testWidgets('Ecke ziehen: Rechteck wird Freiform, ein Schritt', (
      tester,
    ) async {
      final s = await zeige(tester);
      expect(find.byKey(const ValueKey('ecke-3')), findsOneWidget);
      // 100 px = 1 m bei 100 %
      await tester.drag(
        find.byKey(const ValueKey('ecke-2')),
        const Offset(50, 0),
      );
      await tester.pumpAndSettle();
      expect(_f(s.planung).punkte[2].x, 4500);
      // Trapez: 4 × 3 m plus Dreieck 0,5 × 3 m / 2
      expect(find.text('Fläche: 12,750 m²'), findsOneWidget);
      s.planung.rueckgaengig();
      await tester.pumpAndSettle();
      expect(s.planung.aktuell, _rechteck());
    });

    testWidgets('Ecke antippen wählt aus, Kantenmitte fügt ein', (
      tester,
    ) async {
      final s = await zeige(tester);
      await tester.tap(find.byKey(const ValueKey('kante-0')));
      await tester.pumpAndSettle();
      expect(_f(s.planung).punkte, hasLength(5));
      await tester.tap(find.byKey(const ValueKey('ecke-1')));
      await tester.pumpAndSettle();
      expect(find.text('Punkt B'), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('kante-2')),
        const Offset(70, 30),
      );
      await tester.pumpAndSettle();
      // Kante C—D (rechts, senkrecht) nur waagrecht verschoben
      expect(_f(s.planung).punkte[2].x, closeTo(4700, 1e-6));
      expect(_f(s.planung).punkte[3].x, closeTo(4700, 1e-6));
    });

    testWidgets('Kreis: keine Ziehpunkte', (tester) async {
      final s = await zeige(tester);
      s.planung.setze(Planungsstand.start.mitForm(Terrassenform.kreis));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ecke-0')), findsNothing);
    });
  });

  group('Ziehpunkte bei Zoom 200 % und verschobener Ansicht', () {
    const rechteck = [
      Offset(0, 0),
      Offset(4000, 0),
      Offset(4000, 3000),
      Offset(0, 3000),
    ];

    Future<({PlanungsSteuerung planung, Offset ursprung})> zeige(
      WidgetTester tester, {
      Planungsstand? stand,
      Zeichnung? zeichnung,
    }) async {
      tester.view
        ..physicalSize = const Size(1440, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = _bedienung(stand);
      final ansicht = AnsichtSteuerung()
        ..value = (Matrix4.identity()
          ..translateByDouble(30, 40, 0, 1)
          ..scaleByDouble(2, 2, 2, 1));
      final optionen = AnsichtsOptionen();
      addTearDown(s.planung.dispose);
      addTearDown(ansicht.dispose);
      await tester.pumpWidget(
        testApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: s.planung,
              builder: (context, _) => Zeichenflaeche(
                planung: s.planung,
                ansicht: ansicht,
                optionen: optionen,
                freiform: s.b,
                zeichnung:
                    zeichnung ??
                    Zeichnung(
                      umriss: [
                        for (final p in s.planung.aktuell.grundriss.ecken)
                          Offset(p.x, p.y),
                      ],
                    ),
              ),
            ),
          ),
        ),
      );
      return (
        planung: s.planung,
        ursprung: tester.getTopLeft(
          find.byKey(const ValueKey('zeichenflaeche')),
        ),
      );
    }

    testWidgets('Lage der Griffe folgt Zoom und Verschiebung', (tester) async {
      final s = await zeige(tester);
      // 4000 mm · 0,1 px/mm · 2 = 800 px, dazu die Verschiebung (30|40)
      expect(
        tester.getCenter(find.byKey(const ValueKey('ecke-1'))),
        s.ursprung + const Offset(830, 40),
      );
      expect(
        tester.getCenter(find.byKey(const ValueKey('ecke-2'))),
        s.ursprung + const Offset(830, 640),
      );
      expect(
        tester.getCenter(find.byKey(const ValueKey('kante-0'))),
        s.ursprung + const Offset(430, 40),
      );
      expect(
        tester.getCenter(find.byKey(const ValueKey('kante-3'))),
        s.ursprung + const Offset(30, 340),
      );
    });

    testWidgets('Ziehen bei 200 %: 100 px sind 50 cm', (tester) async {
      final s = await zeige(tester);
      await tester.drag(
        find.byKey(const ValueKey('ecke-2')),
        const Offset(100, 0),
      );
      await tester.pump();
      expect(_f(s.planung).punkte[2], const Punkt(4500, 3000));
    });

    testWidgets('keine Griffe für Kreis oder offenen Umriss', (tester) async {
      await zeige(
        tester,
        stand: Planungsstand.start.mitForm(Terrassenform.kreis),
        zeichnung: Zeichnung(umriss: rechteck),
      );
      expect(find.byKey(const ValueKey('ecke-0')), findsNothing);
      await zeige(
        tester,
        zeichnung: Zeichnung(umriss: rechteck, geschlossen: false),
      );
      expect(find.byKey(const ValueKey('ecke-0')), findsNothing);
      await zeige(
        tester,
        zeichnung: Zeichnung(umriss: rechteck.take(2).toList()),
      );
      expect(find.byKey(const ValueKey('ecke-0')), findsNothing);
    });

    testWidgets('Bildschirm in mm mit Verschiebung', (tester) async {
      final s = _bedienung();
      final ansicht = AnsichtSteuerung()
        ..value = (Matrix4.identity()
          ..translateByDouble(30, 40, 0, 1)
          ..scaleByDouble(2, 2, 2, 1));
      final z = Zeichenflaeche(
        planung: s.planung,
        ansicht: ansicht,
        optionen: AnsichtsOptionen(),
        zeichnung: Zeichnung.leer,
      );
      final p = z.inMillimeter(const Offset(230, 140));
      expect(p, const Punkt(1000, 500));
    });
  });

  test('Texte der Eckenbearbeitung', () {
    expect(en.punktAusgewaehlt('B'), 'Point B');
    expect(en.punktEntfernen, 'Remove point');
    expect(en.eckeAntippen, startsWith('Tap a corner'));
  });
}
