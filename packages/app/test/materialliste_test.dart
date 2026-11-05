import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/artikel/artikelbild_widget.dart';
import 'package:terrassenplaner_app/src/design/planer_design.dart';
import 'package:terrassenplaner_app/src/rahmen/berechnung_steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/materialliste.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_schritt.dart';
import 'package:terrassenplaner_app/src/rahmen/rahmen_zustand.dart';
import 'package:terrassenplaner_app/src/rahmen/steuerung.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

const _m5 = Millimeter(5000);

Artikel _artikel(
  String nummer,
  Artikelart art, {
  Mengeneinheit einheit = Mengeneinheit.stueck,
  int? preis,
}) => Artikel(
  nummer: Artikelnummer(nummer),
  titel: 'Artikel $nummer',
  art: art,
  einheit: Verkaufseinheit(einheit),
  preisBrutto: preis == null ? null : Cent(preis),
  holzart: art.istHolz ? robinie : null,
  serie: art.istHolz ? premiumSelect : null,
  bilder: [if (art.istHolz) 'diele.jpg'],
);

final _diele = _artikel(
  '10-10-073-R',
  Artikelart.diele,
  einheit: Mengeneinheit.laufmeter,
  preis: 1290,
);
final _clip = _artikel(
  '80-10-001-250',
  Artikelart.clip,
  einheit: Mengeneinheit.verpackungseinheit,
  preis: 10990,
);

/// Materialliste wie vom Server (M9-03); die Planung bringt die geänderten
/// Mengen mit, die der Server hier immer übernimmt.
Materialliste _liste(Planung planung, {bool mitOhnePreis = false}) =>
    Materialliste.aus([
      Materialbedarf([_diele], 48, laenge: _m5),
      Materialbedarf(
        [_diele],
        1,
        laenge: _m5,
        zusatz: Materialzusatz.freidiele,
      ),
      Materialbedarf([_clip], 2),
      if (mitOhnePreis)
        Materialbedarf([_artikel('50-60-001', Artikelart.gummiband)], 3),
    ], mengen: planung.mengen);

Future<Berechnung> _berechne(Planung planung) async => Berechnung(
  umriss: planung.aktuell.grundriss.ecken,
  flaeche: 1,
  materialliste: _liste(planung),
);

Future<Berechnung> _ohnePreis(Planung planung) async => Berechnung(
  umriss: const [],
  flaeche: 1,
  materialliste: _liste(planung, mitOhnePreis: true),
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

List<String?> _texte(WidgetTester tester, Finder in_) => [
  for (final t in tester.widgetList<Text>(
    find.descendant(of: in_, matching: find.byType(Text)),
  ))
    t.data,
];

void main() {
  test('Beträge, Laufmeter und Einheiten im Format der Sprache', () {
    expect(MateriallisteAnsicht.betrag(de, const Cent(206657)), '2.066,57 €');
    expect(MateriallisteAnsicht.betrag(en, const Cent(206657)), '2,066.57 €');
    expect(MateriallisteAnsicht.betrag(de, const Cent(0)), '0,00 €');
    expect(MateriallisteAnsicht.betrag(de, null), '–');
    expect(MateriallisteAnsicht.laufmeter(de, const Millimeter(240000)), '240');
    expect(MateriallisteAnsicht.laufmeter(de, const Millimeter(13500)), '13,5');
    expect(MateriallisteAnsicht.laufmeter(de, null), '–');
    expect(
      [
        for (final e in Mengeneinheit.values)
          MateriallisteAnsicht.einheit(de, e),
      ],
      ['Stück', 'lfm', 'm²', 'VPE', 'Karton', 'Set', 'Kiste', 'l'],
    );
    expect(
      [
        for (final e in Mengeneinheit.values)
          MateriallisteAnsicht.einheit(en, e),
      ],
      ['pcs', 'lin. m', 'm²', 'pack', 'carton', 'set', 'crate', 'l'],
    );
  });

  testWidgets('Steuerung reicht die Materialliste durch', (tester) async {
    final (:planung, :berechnung) = _steuerung(_berechne);
    expect(berechnung.materialliste.istLeer, isTrue);
    await tester.pump();
    expect(berechnung.materialliste, _liste(planung.planung));
  });

  testWidgets('leer, solange nichts verlegt ist', (tester) async {
    final (:planung, :berechnung) = _steuerung(_leer);
    await tester.pumpWidget(
      testApp(
        home: MateriallisteAnsicht(berechnung: berechnung, planung: planung),
      ),
    );
    await tester.pump();
    expect(
      find.text('Die Materialliste entsteht, sobald ein Belag verlegt ist.'),
      findsOneWidget,
    );
  });

  testWidgets('Kunde: Positionen mit Preisen, Summe und MwSt. (B-055)', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1440, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (:planung, :berechnung) = _steuerung(_berechne);
    await tester.pumpWidget(
      testApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MateriallisteAnsicht(
              berechnung: berechnung,
              planung: planung,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      _texte(tester, find.byType(DataTable)),
      containsAllInOrder([
        'Pos.',
        'Bild',
        'Artikel',
        'Menge',
        'Einzelpreis',
        'Preis je lfm',
        'Gesamt-lfm',
        'Positionspreis',
        '1',
        'Artikel 10-10-073-R',
        'Länge: 5000 mm',
        '48 Stück',
        '64,50 €',
        '12,90 €',
        '240',
        '3.096,00 €',
        '2',
        'Artikel 10-10-073-R',
        'Länge: 5000 mm',
        'Freidiele',
        '1 Stück',
        '0,00 €',
        '0,00 €',
        '5',
        '0,00 €',
        '3',
        'Artikel 80-10-001-250',
        '2 VPE',
        '109,90 €',
        '',
        '',
        '219,80 €',
      ]),
    );
    expect(
      tester.widget<Text>(find.text('Freidiele')).style?.fontWeight,
      FontWeight.w700,
    );
    final bilder = tester.widgetList<Artikelbild>(find.byType(Artikelbild));
    expect(
      [for (final b in bilder) (b.bild, b.titel, b.groesse)],
      [
        ('diele.jpg', 'Artikel 10-10-073-R', 48),
        ('diele.jpg', 'Artikel 10-10-073-R', 48),
        (null, 'Artikel 80-10-001-250', 48),
      ],
    );
    expect(find.text('Summe gesamt: 3.315,80 €'), findsOneWidget);
    expect(find.text('enthaltene 19 % MwSt.: 529,41 €'), findsOneWidget);
    expect(
      find.text(
        'Alle Preise inkl. MwSt. und nur zur Information – verbindlich ist '
        'unser Angebot.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('materialliste-ohne-preis')),
      findsNothing,
    );
    // Kunden ändern keine Mengen
    expect(find.byType(TextField), findsNothing);
    expect(
      find.byKey(const ValueKey('materialliste-mitarbeiter')),
      findsNothing,
    );
  });

  testWidgets('Artikel ohne Preis: Hinweis unter der Summe', (tester) async {
    tester.view
      ..physicalSize = const Size(1440, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (:planung, :berechnung) = _steuerung(_ohnePreis);
    await tester.pumpWidget(
      testApp(
        sprache: const Locale('en'),
        home: Scaffold(
          body: SingleChildScrollView(
            child: MateriallisteAnsicht(
              berechnung: berechnung,
              planung: planung,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.text(
        'Some items have no price yet; they are missing from the total.',
      ),
      findsOneWidget,
    );
    expect(find.text('3 pcs'), findsOneWidget);
    expect(find.text('–'), findsNWidgets(2));
  });

  testWidgets('Mitarbeiter: Menge ändern, übernehmen und zurück (R-D04)', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1440, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (:planung, :berechnung) = _steuerung(_berechne);
    await tester.pumpWidget(
      testApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MateriallisteAnsicht(
              berechnung: berechnung,
              planung: planung,
              mitarbeiter: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Mitarbeiter-Ansicht: Mengen änderbar'), findsOneWidget);
    final eingabe = find.byKey(const ValueKey('menge-eingabe-1'));
    expect(tester.widget<TextField>(eingabe).controller!.text, '48');
    expect(find.byKey(const ValueKey('menge-berechnet-1')), findsNothing);
    // leere Eingabe übernimmt nichts
    await tester.enterText(eingabe, '');
    await tester.tap(find.byKey(const ValueKey('menge-uebernehmen-1')));
    await tester.pump();
    expect(planung.planung.mengen, isEmpty);
    await tester.enterText(eingabe, '50');
    await tester.tap(find.byKey(const ValueKey('menge-uebernehmen-1')));
    await tester.pump();
    const schluessel = (
      nummer: Artikelnummer('10-10-073-R'),
      laenge: _m5,
      zusatz: null,
    );
    expect(planung.planung.mengen, {schluessel: 50});
    await tester.pump();
    expect(find.text('berechnet: 48'), findsOneWidget);
    expect(find.text('3.225,00 €'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('menge-eingabe-1')))
          .controller!
          .text,
      '50',
    );
    // Enter übernimmt ebenfalls; 0 wählt die Position ab
    await tester.enterText(find.byKey(const ValueKey('menge-eingabe-3')), '0');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();
    expect(planung.planung.mengen.length, 2);
    expect(find.text('219,80 €'), findsNothing);
    // zurück zur berechneten Menge
    await tester.tap(find.byKey(const ValueKey('menge-berechnet-1')));
    await tester.pump();
    await tester.pump();
    expect(planung.planung.mengen.containsKey(schluessel), isFalse);
    expect(find.text('berechnet: 48'), findsNothing);
    // rückgängig wie jede andere Änderung der Planung
    planung.rueckgaengig();
    await tester.pump();
    await tester.pump();
    expect(planung.planung.mengen[schluessel], 50);
  });

  testWidgets('im Rahmen: Knopf unter den Kennzahlen, erst der '
      'Standardwert-Hinweis (M3-05)', (tester) async {
    tester.view
      ..physicalSize = const Size(1440, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final zustand = RahmenZustand();
    final anmeldung = TestAnmeldung();
    await tester.pumpWidget(
      testApp(
        theme: planerThema(),
        home: PlanerRahmen(
          status: const Text('Status'),
          zustand: zustand,
          berechne: _berechne,
          anmeldung: anmeldung,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final knopf = find.byKey(const ValueKey('materialliste-knopf'));
    final dialog = find.byKey(const ValueKey('materialliste-dialog'));
    // „Zurück“ öffnet den ersten unveränderten Schritt statt der Liste
    await tester.tap(knopf);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('standardwert-zurueck')));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(zustand.aktiv, PlanerSchritt.grundriss);
    await tester.tap(knopf);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('standardwert-fortfahren')));
    await tester.pumpAndSettle();
    expect(dialog, findsOneWidget);
    expect(find.text('Summe gesamt: 3.315,80 €'), findsOneWidget);
    final felder = find.descendant(
      of: dialog,
      matching: find.byType(TextField),
    );
    expect(felder, findsNothing);
    // Anmeldung als Mitarbeiter (M9-10) schaltet die Mengen frei
    anmeldung.angemeldetAls.value = 'anna@example.test';
    await tester.pumpAndSettle();
    expect(felder, findsNWidgets(3));
    await tester.tap(find.byKey(const ValueKey('materialliste-schliessen')));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
  });

  testWidgets('ohne Berechnung kein Knopf; Dialog ohne Rolle = Kunde', (
    tester,
  ) async {
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
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('materialliste-knopf')), findsNothing);
    final (:planung, :berechnung) = _steuerung(_berechne);
    await tester.pumpWidget(
      testApp(
        home: MateriallisteDialog(berechnung: berechnung, planung: planung),
      ),
    );
    await tester.pump();
    expect(find.text('Materialliste'), findsWidgets);
    expect(find.byType(TextField), findsNothing);
  });
}
