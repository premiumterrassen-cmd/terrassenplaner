import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_schritt.dart';
import 'package:terrassenplaner_app/src/rahmen/rahmen_zustand.dart';
import 'package:terrassenplaner_app/src/rahmen/steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/unterkonstruktion.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

void main() {
  test('cm-Texte und Eingaben in cm', () {
    expect(cmText(de, const Millimeter(86)), '8,6');
    expect(cmText(de, const Millimeter(540)), '54');
    expect(cmText(en, const Millimeter(86)), '8.6');
    expect(cmAusText(' 8,6 '), const Millimeter(86));
    expect(cmAusText('54.2'), const Millimeter(542));
    expect(cmAusText('abc'), isNull);
    expect(cmAusText('Infinity'), isNull);
  });

  group('Art der Terrasse (M6-01)', () {
    Future<({PlanungsSteuerung planung, List<int> aenderungen})> zeige(
      WidgetTester tester, {
      Locale sprache = const Locale('de'),
    }) async {
      final planung = PlanungsSteuerung();
      addTearDown(planung.dispose);
      final aenderungen = <int>[];
      await tester.pumpWidget(
        testApp(
          sprache: sprache,
          home: Scaffold(
            body: TerrassenartWahl(
              planung: planung,
              onGeaendert: () => aenderungen.add(aenderungen.length),
            ),
          ),
        ),
      );
      return (planung: planung, aenderungen: aenderungen);
    }

    ChoiceChip chip(WidgetTester tester, Terrassenart art) =>
        tester.widget(find.byKey(ValueKey('terrassenart-${art.name}')));

    testWidgets('drei Arten, Vorgabe normal mit 8,6 cm; Wahl ist ein '
        'Schritt im Verlauf', (tester) async {
      final s = await zeige(tester);
      expect(find.text(de.terrassenartNormal), findsOneWidget);
      expect(find.text(de.terrassenartHochterrasse), findsOneWidget);
      expect(find.text(de.terrassenartVorhandeneUk), findsOneWidget);
      expect(chip(tester, Terrassenart.normal).selected, isTrue);
      expect(find.text('Vorgabehöhe: 8,6 cm'), findsOneWidget);
      expect(find.byKey(const ValueKey('spannweite')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('terrassenart-hochterrasse')));
      await tester.pump();
      expect(s.planung.aktuell.terrassenart, Terrassenart.hochterrasse);
      expect(chip(tester, Terrassenart.hochterrasse).selected, isTrue);
      expect(find.text('Vorgabehöhe: 54,2 cm'), findsOneWidget);
      expect(s.aenderungen, [0]);
      // erneutes Tippen auf die gewählte Art ändert nichts
      await tester.tap(find.byKey(const ValueKey('terrassenart-hochterrasse')));
      await tester.pump();
      expect(s.aenderungen, [0]);
      s.planung.rueckgaengig();
      await tester.pump();
      expect(chip(tester, Terrassenart.normal).selected, isTrue);
      s.planung.wiederherstellen();
      await tester.pump();
      expect(chip(tester, Terrassenart.hochterrasse).selected, isTrue);
    });

    testWidgets('vorhandene UK: Feld Spannweite (Vorgabe 80 cm), Enter '
        'übernimmt, ungültig mit Meldung', (tester) async {
      final s = await zeige(tester);
      await tester.tap(find.byKey(const ValueKey('terrassenart-vorhandeneUk')));
      await tester.pump();
      expect(find.text('Vorgabehöhe: 14,2 cm'), findsOneWidget);
      expect(find.text(de.spannweiteFrage), findsOneWidget);
      final feld = find.descendant(
        of: find.byKey(const ValueKey('spannweite')),
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(feld).decoration!.hintText, '80');
      await tester.enterText(feld, '5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text(de.spannweiteUngueltig), findsOneWidget);
      expect(s.planung.aktuell.spannweite, const Millimeter(800));
      await tester.enterText(feld, 'x');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text(de.spannweiteUngueltig), findsOneWidget);
      await tester.enterText(feld, '62,5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(s.planung.aktuell.spannweite, const Millimeter(625));
      expect(find.text(de.spannweiteUngueltig), findsNothing);
      expect(tester.widget<TextField>(feld).controller!.text, isEmpty);
      expect(tester.widget<TextField>(feld).decoration!.hintText, '62,5');
      expect(s.aenderungen, [0, 1]);
      s.planung.rueckgaengig();
      await tester.pump();
      expect(tester.widget<TextField>(feld).decoration!.hintText, '80');
    });

    testWidgets('englische Texte', (tester) async {
      await zeige(tester, sprache: const Locale('en'));
      expect(find.text(en.terrassenartNormal), findsOneWidget);
      expect(find.text('Default height: 8.6 cm'), findsOneWidget);
    });
  });

  testWidgets('Menü: 3.1 Art der Terrasse; bei Hochterrasse entfällt '
      '„Art der Terrassennutzung“ (F28)', (tester) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final zustand = RahmenZustand()..waehle(PlanerSchritt.unterkonstruktion);
    final planung = PlanungsSteuerung();
    addTearDown(planung.dispose);
    await tester.pumpWidget(
      testApp(
        home: PlanerRahmen(
          status: const SizedBox(),
          zustand: zustand,
          planung: planung,
        ),
      ),
    );
    expect(find.byKey(const ValueKey('terrassenart')), findsOneWidget);
    expect(find.text('3.6 ${de.unterkonstruktion6}'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('terrassenart-hochterrasse')));
    await tester.pump();
    expect(find.textContaining(de.unterkonstruktion6), findsNothing);
    expect(find.text('3.6 ${de.unterkonstruktion7}'), findsOneWidget);
    expect(find.text('3.7 ${de.unterkonstruktion8}'), findsOneWidget);
    expect(
      zustand.unveraendert,
      isNot(contains(PlanerSchritt.unterkonstruktion)),
    );
  });
}
