import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/design/planer_design.dart';
import 'package:terrassenplaner_app/src/rahmen/berechnung_steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/dielenliste.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_schritt.dart';
import 'package:terrassenplaner_app/src/rahmen/rahmen_zustand.dart';
import 'package:terrassenplaner_app/src/rahmen/steuerung.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

const _diele = Artikelnummer('10-10-001');
const _fliese = Artikelnummer('40-10-001');

/// Antwort wie vom Server (M5-08): zwei nummerierte Stücke, Dielenliste.
Future<Berechnung> _berechne(
  Planung planung, {
  List<Lieferposition> liste = const [
    (belag: _diele, laenge: Millimeter(4000), anzahl: 2),
    (belag: _diele, laenge: Millimeter(5000), anzahl: 48),
  ],
}) async => Berechnung(
  umriss: planung.aktuell.grundriss.ecken,
  flaeche: 1,
  dielen: const [
    [Punkt(0, 0), Punkt(100, 0), Punkt(100, 65)],
    [Punkt(0, 65), Punkt(100, 65), Punkt(100, 130)],
  ],
  nummern: const [1, 2],
).mitPlanung(1, verschnitt: 0.0341, dielenliste: liste);

BerechnungsSteuerung _steuerung(PlanungBerechnen berechne) {
  final planung = PlanungsSteuerung();
  final b = BerechnungsSteuerung(planung: planung, berechne: berechne);
  addTearDown(() {
    b.dispose();
    planung.dispose();
  });
  return b;
}

void main() {
  test('Verschnitt in Prozent mit höchstens zwei Nachkommastellen', () {
    expect(Kennzahlen.prozent(de, null), '– %');
    expect(Kennzahlen.prozent(de, 0.04), '4 %');
    expect(Kennzahlen.prozent(de, 0.0341), '3,41 %');
    expect(Kennzahlen.prozent(de, 0.227549), '22,75 %');
    expect(Kennzahlen.prozent(en, 0.0099), '0.99 %');
  });

  test('Zeile der Dielenliste in cm', () {
    expect(
      DielenlisteAnzeige.zeile(de, (
        belag: _diele,
        laenge: const Millimeter(5000),
        anzahl: 48,
      )),
      '48 × 500 cm',
    );
    expect(
      DielenlisteAnzeige.zeile(de, (
        belag: _fliese,
        laenge: const Millimeter(606),
        anzahl: 7,
      )),
      '7 × 60,6 cm',
    );
  });

  testWidgets('Kennzahlen zeigen den Verschnitt zwischen Fläche und '
      'Volumen', (tester) async {
    await tester.pumpWidget(
      testApp(home: const Kennzahlen(flaeche: 14.832, verschnitt: 0.04)),
    );
    final texte = [
      for (final t in tester.widgetList<Text>(find.byType(Text))) t.data,
    ];
    expect(texte, ['Fläche: 14,832 m²', 'Verschnitt: 4 %', 'Volumen: – m³']);
  });

  testWidgets('Steuerung reicht Nummern, Verschnitt und Dielenliste '
      'durch', (tester) async {
    final b = _steuerung(_berechne);
    expect(b.verschnitt, isNull);
    expect(b.dielenliste, isEmpty);
    await tester.pump();
    expect(b.verschnitt, 0.0341);
    expect(b.dielenliste, hasLength(2));
    expect(b.zeichnung.nummern, [1, 2]);
  });

  testWidgets('Anzeige: leer, ein Belag, mehrere Beläge', (tester) async {
    final leer = _steuerung((p) => _berechne(p, liste: const []));
    await tester.pumpWidget(
      testApp(home: DielenlisteAnzeige(berechnung: leer)),
    );
    await tester.pump();
    expect(find.text('Noch keine Dielen verlegt.'), findsOneWidget);

    final eine = _steuerung(_berechne);
    await tester.pumpWidget(
      testApp(home: DielenlisteAnzeige(berechnung: eine)),
    );
    await tester.pump();
    await tester.pumpWidget(
      testApp(home: DielenlisteAnzeige(berechnung: eine)),
    );
    expect(
      [for (final t in tester.widgetList<Text>(find.byType(Text))) t.data],
      ['Verschnitt: 3,41 %', 'Benötigte Dielen:', '2 × 400 cm', '48 × 500 cm'],
    );

    final zwei = _steuerung(
      (p) => _berechne(
        p,
        liste: const [
          (belag: _diele, laenge: Millimeter(5000), anzahl: 48),
          (belag: _fliese, laenge: Millimeter(606), anzahl: 7),
          (belag: _diele, laenge: Millimeter(6000), anzahl: 1),
        ],
      ),
    );
    await tester.pumpWidget(
      testApp(home: DielenlisteAnzeige(berechnung: zwei)),
    );
    await tester.pump();
    await tester.pumpWidget(
      testApp(home: DielenlisteAnzeige(berechnung: zwei)),
    );
    final texte = [
      for (final t in tester.widgetList<Text>(find.byType(Text))) t.data,
    ];
    expect(texte.skip(2), [
      '10-10-001',
      '48 × 500 cm',
      '1 × 600 cm',
      '40-10-001',
      '7 × 60,6 cm',
    ]);
    expect(
      tester.widget<Text>(find.text('10-10-001')).style?.fontWeight,
      FontWeight.w700,
    );
  });

  testWidgets('im Rahmen: unter 7.1 und als Kennzahl', (tester) async {
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
    expect(find.text('Verschnitt: 3,41 %'), findsOneWidget);
    expect(find.byKey(const ValueKey('dielenliste')), findsNothing);
    zustand.waehle(PlanerSchritt.verschnittoptimierung);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dielenliste')), findsOneWidget);
    expect(find.text('48 × 500 cm'), findsOneWidget);
  });
}
