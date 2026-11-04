import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/rahmen/berechnung_steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/materialliste.dart';
import 'package:terrassenplaner_app/src/rahmen/steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/stueckliste.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

const _uk = Artikelnummer('50-10-001');

Planstueck _stueck(int laenge, [Stuecklage lage = Stuecklage.laengs]) =>
    Planstueck(
      _uk,
      'RELO C Schiene',
      Millimeter(laenge),
      ganzeLaenge: const Millimeter(2000),
      lage: lage,
    );

/// Antwort wie vom Server (M9-04): Stückliste und Farbe je Dielenstück.
Future<Berechnung> _berechne(Planung planung) async => Berechnung(
  umriss: const [],
  flaeche: 1,
  dielen: const [
    [Punkt(0, 0), Punkt(1, 0)],
    [Punkt(0, 1), Punkt(1, 1)],
  ],
  stueckliste: Stueckliste.aus([
    _stueck(2000),
    _stueck(870),
    _stueck(355, Stuecklage.quer),
  ]),
  stueckfarben: const [Stueckfarbe.rot, Stueckfarbe.blau],
);

Future<Berechnung> _leer(Planung planung) async =>
    Berechnung(umriss: const [], flaeche: 1);

({PlanungsSteuerung planung, BerechnungsSteuerung berechnung}) _steuerung(
  PlanungBerechnen berechne,
) {
  final planung = PlanungsSteuerung();
  final b = BerechnungsSteuerung(planung: planung, berechne: berechne);
  addTearDown(() {
    b.dispose();
    planung.dispose();
  });
  return (planung: planung, berechnung: b);
}

void main() {
  test('Farben und Namen', () {
    expect(StuecklisteAnsicht.farbe(Stueckfarbe.rot), const Color(0xFFD32F2F));
    expect(
      [for (final f in Stueckfarbe.values) StuecklisteAnsicht.farbname(de, f)],
      ['rot – ganze Länge', 'blau – zugeschnitten', 'grün – Querstück'],
    );
    expect(
      [for (final f in Stueckfarbe.values) StuecklisteAnsicht.farbname(en, f)],
      ['red – full length', 'blue – cut to length', 'green – cross piece'],
    );
  });

  testWidgets('Steuerung: Stückliste und dieselben Farben in der Zeichnung', (
    tester,
  ) async {
    final (:planung, :berechnung) = _steuerung(_berechne);
    expect(berechnung.stueckliste.istLeer, isTrue);
    expect(berechnung.zeichnung.dielenfarben, isEmpty);
    await tester.pump();
    expect(berechnung.stueckliste.zeilen, hasLength(3));
    expect(berechnung.zeichnung.dielenfarben, [
      StuecklisteAnsicht.farbe(Stueckfarbe.rot),
      StuecklisteAnsicht.farbe(Stueckfarbe.blau),
    ]);
  });

  testWidgets('leer, solange nichts verlegt ist', (tester) async {
    final (:planung, :berechnung) = _steuerung(_leer);
    await tester.pumpWidget(
      testApp(home: StuecklisteAnsicht(berechnung: berechnung)),
    );
    await tester.pump();
    expect(find.text(de.stuecklisteLeer), findsOneWidget);
  });

  testWidgets('Zeilen mit Länge in cm, Stück und Farbfeld', (tester) async {
    tester.view
      ..physicalSize = const Size(1440, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (:planung, :berechnung) = _steuerung(_berechne);
    await tester.pumpWidget(
      testApp(
        home: Scaffold(body: StuecklisteAnsicht(berechnung: berechnung)),
      ),
    );
    await tester.pump();
    final texte = [
      for (final t in tester.widgetList<Text>(
        find.descendant(
          of: find.byType(DataTable),
          matching: find.byType(Text),
        ),
      ))
        t.data,
    ];
    expect(texte, [
      'Artikel',
      'Länge (cm)',
      'Stück',
      'Farbe im Plan',
      'RELO C Schiene',
      '200',
      '1',
      'rot – ganze Länge',
      'RELO C Schiene',
      '87',
      '1',
      'blau – zugeschnitten',
      'RELO C Schiene',
      '35,5',
      '1',
      'grün – Querstück',
    ]);
    for (final (i, f) in Stueckfarbe.values.indexed) {
      expect(
        tester.widget<Container>(find.byKey(ValueKey('stueckfarbe-$i'))).color,
        StuecklisteAnsicht.farbe(f),
      );
    }
    expect(find.text(de.stuecklisteHinweis), findsOneWidget);
  });

  testWidgets('im Dialog umschaltbar zwischen Material- und Stückliste', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1440, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (:planung, :berechnung) = _steuerung(_berechne);
    await tester.pumpWidget(
      testApp(
        home: MateriallisteDialog(berechnung: berechnung, planung: planung),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('materialliste-leer')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('zur-stueckliste')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stueckliste')), findsOneWidget);
    expect(find.byKey(const ValueKey('materialliste-leer')), findsNothing);
    await tester.tap(find.text(de.materialliste));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('materialliste-leer')), findsOneWidget);
  });
}
