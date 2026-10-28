import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/design/planer_design.dart';
import 'package:terrassenplaner_app/src/rahmen/ansichtsoptionen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_schritt.dart';
import 'package:terrassenplaner_app/src/rahmen/rahmen_zustand.dart';
import 'package:terrassenplaner_app/src/rahmen/steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/zeichenflaeche.dart';
import 'package:terrassenplaner_app/src/rahmen/zeichnung.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

Future<
  ({RahmenZustand zustand, PlanungsSteuerung planung, AnsichtSteuerung ansicht})
>
_zeige(WidgetTester tester, Planungsstand anfang) async {
  tester.view
    ..physicalSize = const Size(1440, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final zustand = RahmenZustand();
  final planung = PlanungsSteuerung(anfang);
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
          FreiformGrundriss(geschlossen: false, :final punkte) => Berechnung(
            umriss: punkte,
            flaeche: 0,
            geschlossen: false,
          ),
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

IconButton _knopf(WidgetTester tester, String schluessel) =>
    tester.widget<IconButton>(find.byKey(ValueKey(schluessel)));

void main() {
  testWidgets('Rechteck drehen: ohne Rückfrage, Fläche bleibt (M4-10)', (
    tester,
  ) async {
    final s = await _zeige(tester, Planungsstand.start);
    expect(find.byTooltip('Form drehen'), findsOneWidget);
    s.zustand.vergissAenderungen();
    await tester.tap(find.byKey(const ValueKey('form-drehen')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('drehen-dialog')), findsNothing);
    final g = s.planung.aktuell.grundriss;
    expect(g, isA<FreiformGrundriss>());
    expect(g.kontur.huellrechteck.max, const Punkt(3090, 4800));
    expect(find.text('Fläche: 14,83 m²'), findsOneWidget);
    expect(s.zustand.unveraendert, isNot(contains(PlanerSchritt.grundriss)));
  });

  testWidgets('O-Form: Ausschnitte erst nach Bestätigung zurücksetzen', (
    tester,
  ) async {
    final o = Planungsstand.start.mitForm(Terrassenform.oForm);
    final s = await _zeige(tester, o);
    await tester.tap(find.byKey(const ValueKey('form-drehen')));
    await tester.pumpAndSettle();
    expect(
      find.text('Beim Drehen werden alle Ausschnitte zurückgesetzt.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('drehen-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('drehen-abbrechen')));
    await tester.pumpAndSettle();
    expect(s.planung.aktuell, o);
    await tester.tap(find.byKey(const ValueKey('form-drehen')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('drehen-bestaetigen')));
    await tester.pumpAndSettle();
    expect(s.planung.aktuell.ausschnitte, isEmpty);
    expect(s.planung.aktuell.grundriss, isA<FreiformGrundriss>());
  });

  testWidgets('Dialog schließen ohne Wahl dreht nicht', (tester) async {
    final o = Planungsstand.start.mitForm(Terrassenform.oForm);
    final s = await _zeige(tester, o);
    await tester.tap(find.byKey(const ValueKey('form-drehen')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(s.planung.aktuell, o);
  });

  testWidgets('Kreis und offene Freiform: Drehen gesperrt', (tester) async {
    final s = await _zeige(
      tester,
      Planungsstand.start.mitForm(Terrassenform.kreis),
    );
    expect(_knopf(tester, 'form-drehen').onPressed, isNull);
    s.planung.setze(Planungsstand.start.mitForm(Terrassenform.freiform));
    await tester.pumpAndSettle();
    expect(_knopf(tester, 'form-drehen').onPressed, isNull);
  });

  testWidgets('Zentrieren stellt die Zeichnung in die Mitte', (tester) async {
    final s = await _zeige(tester, Planungsstand.start);
    s.ansicht.zoomeAuf(2);
    await tester.tap(find.byKey(const ValueKey('zentrieren')));
    await tester.pumpAndSettle();
    expect(s.ansicht.zoom, 1);
    final mitte = s.ansicht.flaeche.center(Offset.zero);
    // 480 × 309 cm → 480 × 309 px, Mitte bei (240|154,5)
    expect(s.ansicht.verschiebung, mitte - const Offset(240, 154.5));
  });

  testWidgets('Zentrieren ohne Zeichnung: Ursprung oben links', (tester) async {
    final planung = PlanungsSteuerung();
    final ansicht = AnsichtSteuerung()..zoomeAuf(2);
    final optionen = AnsichtsOptionen();
    addTearDown(planung.dispose);
    await tester.pumpWidget(
      testApp(
        home: Scaffold(
          body: Werkzeugleiste(
            planung: planung,
            ansicht: ansicht,
            optionen: optionen,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('zentrieren')));
    expect(ansicht.zoom, 1);
    expect(ansicht.verschiebung, Offset.zero);
    // ohne Rückmeldung an den Rahmen dreht die Leiste trotzdem
    await tester.tap(find.byKey(const ValueKey('form-drehen')));
    await tester.pump();
    expect(planung.aktuell.grundriss, isA<FreiformGrundriss>());
    expect(Werkzeugleiste.drehwinkel, 90);
    expect(Zeichnung.leer.umriss, isEmpty);
  });

  test('englische Texte', () {
    expect(
      [
        en.formDrehen,
        en.drehenTitel,
        en.drehenText,
        en.drehenBestaetigen,
        en.abbrechen,
      ],
      [
        'Rotate shape',
        'Rotate shape?',
        'Rotating resets all cut-outs.',
        'Rotate',
        'Cancel',
      ],
    );
  });
}
