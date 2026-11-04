import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/design/planer_design.dart';
import 'package:terrassenplaner_app/src/konfiguration/konfigurations_steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_schritt.dart';
import 'package:terrassenplaner_app/src/rahmen/rahmen_zustand.dart';
import 'package:terrassenplaner_app/src/rahmen/steuerung.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

Planung _planung(int laenge) => Planung([
  Terrassenflaeche(
    Planungsstand(
      grundriss: RechteckGrundriss(Millimeter(laenge), const Millimeter(3000)),
    ),
  ),
]);

final _v1 = stand('2026-11-04-0001-K7QXM', 1);

/// Rahmen mit SPEICHERN/LADEN (M9-05) bei 1920 px (Knöpfe mit Text).
Future<
  ({KonfigurationsSteuerung k, RahmenZustand zustand, AnsichtSteuerung ansicht})
>
_zeige(WidgetTester tester, TestAblage ablage) async {
  tester.view
    ..physicalSize = const Size(1920, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final k = KonfigurationsSteuerung(
    ablage: ablage,
    gedaechtnis: testGedaechtnis(),
  );
  addTearDown(k.dispose);
  final zustand = RahmenZustand();
  final ansicht = AnsichtSteuerung();
  addTearDown(ansicht.dispose);
  await tester.pumpWidget(
    testApp(
      theme: planerThema(),
      home: PlanerRahmen(
        status: const Text('Status'),
        konfiguration: k,
        zustand: zustand,
        ansicht: ansicht,
      ),
    ),
  );
  return (k: k, zustand: zustand, ansicht: ansicht);
}

Finder get _speichern => find.byKey(const ValueKey('speichern'));
Finder get _laden => find.byKey(const ValueKey('konfiguration-laden'));
Finder get _dialog => find.byKey(const ValueKey('laden-dialog'));
Finder get _meldung => find.byKey(const ValueKey('laden-meldung'));

void main() {
  testWidgets('Kopfzeile: SPEICHERN und LADEN mit Text und Symbol', (
    tester,
  ) async {
    await _zeige(tester, TestAblage());
    expect(find.text(de.speichern), findsOneWidget);
    expect(find.text(de.laden), findsOneWidget);
    expect(
      find.descendant(
        of: _speichern,
        matching: find.byIcon(Icons.save_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _laden,
        matching: find.byIcon(Icons.folder_open_outlined),
      ),
      findsOneWidget,
    );
    // Reihenfolge wie im alten Planer: Video-Beratung, SPEICHERN, LADEN,
    // ZURÜCKSETZEN
    final x = [
      for (final s in ['videoberatung', 'speichern', 'konfiguration-laden'])
        tester.getCenter(find.byKey(ValueKey(s))).dx,
      tester.getCenter(find.byKey(const ValueKey('zuruecksetzen'))).dx,
    ];
    expect([...x]..sort(), x);
  });

  testWidgets('schmal: nur Symbole mit Tooltip', (tester) async {
    await _zeige(tester, TestAblage());
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpAndSettle();
    expect(find.byTooltip(de.speichern), findsOneWidget);
    expect(find.byTooltip(de.laden), findsOneWidget);
    expect(find.text(de.speichern), findsNothing);
  });

  testWidgets('ohne Steuerung keine Knöpfe', (tester) async {
    await tester.pumpWidget(
      testApp(home: const PlanerRahmen(status: Text('x'))),
    );
    expect(_speichern, findsNothing);
    expect(_laden, findsNothing);
  });

  testWidgets('SPEICHERN ohne Rückfrage: Nummer und Version als Hinweis', (
    tester,
  ) async {
    final ablage = TestAblage();
    final s = await _zeige(tester, ablage);
    await tester.tap(_speichern);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.text(
        'Gespeichert: Konfigurationsnummer 2026-11-04-0001-K7QXM, Version 1. '
        'Bitte notieren Sie die Nummer samt Prüfcode (die letzten fünf '
        'Zeichen) – nur damit lässt sich die Konfiguration wieder laden.',
      ),
      findsOneWidget,
    );
    expect(s.k.stand, _v1);
    expect(ablage.versionen[_v1], Planung.start);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('SPEICHERN ohne Server: Hinweis, Planung bleibt', (tester) async {
    final ablage = TestAblage()..erreichbar = false;
    final s = await _zeige(tester, ablage);
    s.k.planung.setzePlanung(_planung(4000));
    await tester.tap(_speichern);
    await tester.pumpAndSettle();
    expect(find.text(de.speichernFehler), findsOneWidget);
    expect(s.k.planung.planung, _planung(4000));
    expect(s.k.stand, isNull);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('LADEN: vorbelegt, lädt identisch, Ansicht zurückgesetzt', (
    tester,
  ) async {
    final ablage = TestAblage();
    final v1 = await ablage.speichere(_planung(6000));
    final s = await _zeige(tester, ablage);
    await s.k.lade(v1);
    s.zustand.markiereGeaendert(PlanerSchritt.grundriss);
    s.ansicht.zoomeAuf(2);
    await tester.tap(_laden);
    await tester.pumpAndSettle();
    expect(_dialog, findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('nummer')))
          .controller!
          .text,
      '2026-11-04-0001-K7QXM',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('version'))).data,
      '1',
    );
    s.k.planung.setzePlanung(_planung(4000));
    await tester.tap(find.byKey(const ValueKey('laden-bestaetigen')));
    await tester.pumpAndSettle();
    expect(_dialog, findsNothing);
    expect(s.k.planung.planung, _planung(6000));
    expect(s.zustand.unveraendert, PlanerSchritt.values);
    expect(s.ansicht.zoom, 1);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('LADEN abbrechen ändert nichts', (tester) async {
    final s = await _zeige(tester, TestAblage());
    s.zustand.markiereGeaendert(PlanerSchritt.grundriss);
    s.ansicht.zoomeAuf(2);
    await tester.tap(_laden);
    await tester.pumpAndSettle();
    await tester.tap(find.text(de.zurueck));
    await tester.pumpAndSettle();
    expect(s.zustand.unveraendert, isNot(contains(PlanerSchritt.grundriss)));
    expect(s.ansicht.zoom, 2);
  });

  testWidgets('„Konfiguration Speichern“ im Ladedialog füllt Nummer/Version', (
    tester,
  ) async {
    final ablage = TestAblage();
    final s = await _zeige(tester, ablage);
    await tester.tap(_laden);
    await tester.pumpAndSettle();
    final knopf = find.byKey(const ValueKey('laden-speichern'));
    expect(find.text(de.konfigurationSpeichernKnopf), findsOneWidget);
    await tester.tap(knopf);
    await tester.pumpAndSettle();
    expect(s.k.stand, _v1);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('nummer')))
          .controller!
          .text,
      '2026-11-04-0001-K7QXM',
    );
    expect(
      tester.widget<Text>(_meldung).data,
      de.gespeichertMeldung('2026-11-04-0001-K7QXM', 1),
    );
    expect(tester.widget<Text>(_meldung).style, isNull);
    // zweites Speichern: Version 2
    s.k.planung.setzePlanung(_planung(4000));
    await tester.tap(knopf);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('version'))).data,
      '2',
    );
    // ohne Server: Meldung, Dialog bleibt
    ablage.erreichbar = false;
    await tester.tap(knopf);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(_meldung).data, de.speichernFehler);
    expect(
      tester.widget<Text>(_meldung).style!.color,
      Theme.of(tester.element(_dialog)).colorScheme.error,
    );
    expect(_dialog, findsOneWidget);
    expect(tester.widget<OutlinedButton>(knopf).onPressed, isNotNull);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('ZURÜCKSETZEN: neue Planung ohne Nummer', (tester) async {
    final ablage = TestAblage();
    final s = await _zeige(tester, ablage);
    s.k.planung.setzePlanung(_planung(4000));
    await s.k.speichere();
    await tester.tap(find.byKey(const ValueKey('zuruecksetzen')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('zuruecksetzen-bestaetigen')));
    await tester.pumpAndSettle();
    expect(s.k.stand, isNull);
    expect(s.k.planung.planung, Planung.start);
    await tester.pump(const Duration(seconds: 5));
  });

  test('Texte', () {
    expect(de.speichern, 'SPEICHERN');
    expect(de.laden, 'LADEN');
    expect(en.speichern, 'SAVE');
    expect(en.laden, 'LOAD');
    expect(
      de.speichernFehler,
      'Speichern nicht möglich – der Server ist nicht erreichbar. Ihre '
      'Planung bleibt erhalten, bitte später erneut speichern.',
    );
    expect(
      en.gespeichertMeldung('2026-11-04-0001-K7QXM', 2),
      'Saved: configuration number 2026-11-04-0001-K7QXM, version 2. Please '
      'note the number including the check code (the last five characters) '
      '– only with it can the configuration be loaded again.',
    );
    expect(Kopfzeile.textAb, 1680);
  });
}
