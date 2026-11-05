import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/rahmen/berechnung_steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/materialliste.dart';
import 'package:terrassenplaner_app/src/rahmen/steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/zuschnittplan.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

Artikel _artikel(String nummer, String titel) => Artikel(
  nummer: Artikelnummer(nummer),
  titel: titel,
  art: Artikelart.diele,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  holzart: robinie,
  serie: basic,
);

Lieferdiele _d(int laenge, List<int> schnitte) =>
    Lieferdiele(Millimeter(laenge), [for (final s in schnitte) Millimeter(s)]);

final _belag = Zuschnittplan.aus([
  (
    artikel: _artikel('10-10-073-R', 'Terrassendiele'),
    stueck: _d(6000, [6000]),
    anzahl: 48,
  ),
  (
    artikel: _artikel('10-10-073-R', 'Terrassendiele'),
    stueck: _d(4000, [2000, 2000]),
    anzahl: 24,
  ),
]);
final _uk = Zuschnittplan.aus([
  (
    artikel: _artikel('10-10-031', 'Unterkonstruktionsholz'),
    stueck: _d(4000, [3090]),
    anzahl: 22,
  ),
  (
    artikel: _artikel('10-10-031', 'Unterkonstruktionsholz'),
    stueck: _d(4000, [401, 1355]),
    anzahl: 1,
  ),
]);

BerechnungsSteuerung _steuerung({bool belag = true, bool uk = true}) {
  final planung = PlanungsSteuerung();
  final b = BerechnungsSteuerung(
    planung: planung,
    berechne: (p) async => Berechnung(umriss: const [], flaeche: 1).mitPlanung(
      1,
      zuschnittBelag: belag ? _belag : null,
      zuschnittUk: uk ? _uk : null,
    ),
  );
  addTearDown(() {
    b.dispose();
    planung.dispose();
  });
  return b;
}

List<String?> _texte(WidgetTester tester) => [
  for (final t in tester.widgetList<Text>(find.byType(Text))) t.data,
];

void main() {
  test('Schnittmaße in cm im Format der Sprache', () {
    expect(ZuschnittplanAnsicht.schnitte(de, _uk.zeilen.last), '40,1 | 135,5');
    expect(ZuschnittplanAnsicht.schnitte(en, _uk.zeilen.last), '40.1 | 135.5');
  });

  testWidgets('Steuerung reicht beide Pläne durch, vorher leer', (
    tester,
  ) async {
    final b = _steuerung();
    expect(b.zuschnittBelag.istLeer, isTrue);
    expect(b.zuschnittUk.istLeer, isTrue);
    await tester.pump();
    expect(b.zuschnittBelag, _belag);
    expect(b.zuschnittUk, _uk);
  });

  testWidgets('Belag und UK je mit Ausgangslänge, Menge und Schnittmaßen', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1440, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final b = _steuerung();
    await tester.pumpWidget(
      testApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ZuschnittplanAnsicht(berechnung: b),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(_texte(tester), [
      'Zuschnitt Belag',
      'Artikel',
      'Ausgangslänge (cm)',
      'Menge',
      'Schnittmaße (cm)',
      'Terrassendiele',
      '600',
      '48',
      '600',
      'Terrassendiele',
      '400',
      '24',
      '200 | 200',
      'Zuschnitt Unterkonstruktion',
      'Artikel',
      'Ausgangslänge (cm)',
      'Menge',
      'Schnittmaße (cm)',
      'Unterkonstruktionsholz',
      '400',
      '22',
      '309',
      'Unterkonstruktionsholz',
      '400',
      '1',
      '40,1 | 135,5',
      de.zuschnittHinweis,
    ]);
    expect(find.byKey(const ValueKey('zuschnitt-belag')), findsOneWidget);
    expect(find.byKey(const ValueKey('zuschnitt-uk')), findsOneWidget);
  });

  testWidgets('nur Belag: ohne UK-Tabelle; leer: Hinweis', (tester) async {
    final nurBelag = _steuerung(uk: false);
    await tester.pumpWidget(
      testApp(
        home: SingleChildScrollView(
          child: ZuschnittplanAnsicht(berechnung: nurBelag),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('zuschnitt-belag')), findsOneWidget);
    expect(find.byKey(const ValueKey('zuschnitt-uk')), findsNothing);
    final leer = _steuerung(belag: false, uk: false);
    await tester.pumpWidget(
      testApp(
        sprache: const Locale('en'),
        home: ZuschnittplanAnsicht(berechnung: leer),
      ),
    );
    await tester.pump();
    expect(
      find.text('The cutting plan appears as soon as decking has been laid.'),
      findsOneWidget,
    );
  });

  testWidgets('im Dialog umschaltbar auf „Zuschnitt“', (tester) async {
    tester.view
      ..physicalSize = const Size(1440, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final b = _steuerung();
    await tester.pumpWidget(
      testApp(
        home: MateriallisteDialog(berechnung: b, planung: b.planung),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('zum-zuschnitt')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('zuschnittplan')), findsOneWidget);
  });
}
