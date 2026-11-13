import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/rahmen/berechnung_steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/rahmen/rahmen_zustand.dart';
import 'package:terrassenplaner_app/src/rahmen/steuerung.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

/// Antwort wie vom Server: zwei UK-Hölzer und das Holzvolumen (M6-10).
Future<Berechnung> _server(Planung planung) async => Berechnung(
  umriss: const [Punkt(0, 0), Punkt(4800, 0), Punkt(4800, 3090)],
  flaeche: 14832000,
  volumen: 0.4272,
  unterbau: Unterbau(
    hoelzer: const [
      (von: Punkt(20, 0), bis: Punkt(20, 3090), farbe: Stueckfarbe.blau),
      (von: Punkt(4780, 0), bis: Punkt(4780, 6000), farbe: Stueckfarbe.rot),
    ],
    holzbreite: const Millimeter(40),
    auflagerpunkte: const [
      (ort: Punkt(20, 0), spalt: Millimeter(5), zeile: 0),
      (ort: Punkt(20, 515), spalt: Millimeter(300), zeile: null),
      // 25 mm neben der Achse: noch auf dem Holz (halbe Breite + 5 mm)
      (ort: Punkt(45, 1000), spalt: Millimeter(30), zeile: 1),
      (ort: Punkt(46, 1000), spalt: Millimeter(30), zeile: 1),
    ],
  ),
  planbild: Planbild(
    stoesse: const [(von: Punkt(3000, 0), bis: Punkt(3000, 66))],
    achsen: Masskette(const [
      Punkt(0, 3090),
      Punkt(20, 3090),
      Punkt(4800, 3090),
    ], const Punkt(0, 1)),
  ),
);

void main() {
  testWidgets('UK-Hölzer und Holzvolumen vom Server (M6-10)', (tester) async {
    final planung = PlanungsSteuerung();
    final berechnung = BerechnungsSteuerung(
      planung: planung,
      berechne: _server,
    );
    addTearDown(() {
      berechnung.dispose();
      planung.dispose();
    });
    expect(berechnung.volumen, isNull);
    expect(berechnung.zeichnung.ukHoelzer, isEmpty);
    planung.setze(planung.aktuell.mitGewerblich(true));
    await tester.pump();
    expect(berechnung.volumen, 0.4272);
    final z = berechnung.zeichnung;
    expect(z.ukHoelzer, [
      (
        const Offset(20, 0),
        const Offset(20, 3090),
        Color(Stueckfarbe.blau.argb),
      ),
      (
        const Offset(4780, 0),
        const Offset(4780, 6000),
        Color(Stueckfarbe.rot.argb),
      ),
    ]);
    expect(z.ukBreite, 40);
    // Auflager (M6-11): Ort, Spalt, Zeile der Höhenzuordnung und Richtung
    // der Fußhöhe quer zum Holz (Planungskern v8 Regel 10.1)
    expect(z.auflager, [
      (
        ort: const Offset(20, 0),
        spalt: const Millimeter(5),
        zeile: 0,
        richtung: const Offset(1, 0),
      ),
      (
        ort: const Offset(20, 515),
        spalt: const Millimeter(300),
        zeile: null,
        richtung: const Offset(1, 0),
      ),
      (
        ort: const Offset(45, 1000),
        spalt: const Millimeter(30),
        zeile: 1,
        richtung: const Offset(1, 0),
      ),
      (
        ort: const Offset(46, 1000),
        spalt: const Millimeter(30),
        zeile: 1,
        richtung: const Offset(0, -1),
      ),
    ]);
    // Pläne nach dem Planungskern (R-E01 bis R-E03)
    expect(z.namen, ['A', 'B', 'C']);
    expect(z.stoesse, [(const Offset(3000, 0), const Offset(3000, 66))]);
    expect(z.achsen!.marken, const [
      Offset(0, 3090),
      Offset(20, 3090),
      Offset(4800, 3090),
    ]);
    expect(z.achsen!.normale, const Offset(0, 1));
  });

  testWidgets('Fußhöhe ohne Holzbreite: Hölzer 40 mm breit', (tester) async {
    final planung = PlanungsSteuerung();
    final berechnung = BerechnungsSteuerung(
      planung: planung,
      berechne: (_) async => Berechnung(
        umriss: const [],
        flaeche: 0,
        unterbau: Unterbau(
          hoelzer: const [
            (von: Punkt(0, 0), bis: Punkt(0, 1000), farbe: Stueckfarbe.rot),
          ],
          auflagerpunkte: const [
            (ort: Punkt(25, 500), spalt: Millimeter(30), zeile: 0),
            (ort: Punkt(26, 500), spalt: Millimeter(30), zeile: 0),
          ],
        ),
      ),
    );
    addTearDown(() {
      berechnung.dispose();
      planung.dispose();
    });
    planung.setze(planung.aktuell.mitGewerblich(true));
    await tester.pump();
    expect(
      [for (final a in berechnung.zeichnung.auflager) a.richtung],
      const [Offset(1, 0), Offset(0, -1)],
    );
  });

  testWidgets('ohne Hölzer Breite 0', (tester) async {
    final planung = PlanungsSteuerung();
    final berechnung = BerechnungsSteuerung(
      planung: planung,
      berechne: (_) async => Berechnung(umriss: const [], flaeche: 0),
    );
    addTearDown(() {
      berechnung.dispose();
      planung.dispose();
    });
    planung.setze(planung.aktuell.mitGewerblich(true));
    await tester.pump();
    expect(berechnung.zeichnung.ukBreite, 0);
    expect(berechnung.zeichnung.achsen, isNull);
    expect(berechnung.zeichnung.stoesse, isEmpty);
  });

  testWidgets('Kennzahlen zeigen das Volumen der Berechnung', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final planung = PlanungsSteuerung();
    addTearDown(planung.dispose);
    await tester.pumpWidget(
      testApp(
        home: PlanerRahmen(
          status: const SizedBox(),
          zustand: RahmenZustand(),
          planung: planung,
          berechne: _server,
        ),
      ),
    );
    await tester.pump();
    expect(find.text(de.volumen('0,427 m³')), findsOneWidget);
  });
}
