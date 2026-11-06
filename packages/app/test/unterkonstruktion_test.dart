import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/rahmen/berechnung_steuerung.dart';
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

  group('Höhenpunkte (M6-02)', () {
    /// Antwort wie vom Server mit Belag 23 mm und UK 40 x 60 mm.
    Future<Berechnung> server(Planung planung) async {
      final stand = planung.aktuell;
      return Berechnung(
        umriss: stand.grundriss.ecken,
        flaeche: 1,
        hoehenpunkte: pruefeHoehen(
          stand.hoehen,
          art: stand.terrassenart,
          dielenstaerke: const Millimeter(23),
          uk: (a: const Millimeter(40), b: const Millimeter(60)),
        ),
      );
    }

    Future<({PlanungsSteuerung planung, List<int> aenderungen})> zeige(
      WidgetTester tester, {
      PlanungBerechnen? berechne,
    }) async {
      final planung = PlanungsSteuerung();
      final berechnung = berechne == null
          ? null
          : BerechnungsSteuerung(planung: planung, berechne: berechne);
      addTearDown(() {
        berechnung?.dispose();
        planung.dispose();
      });
      final aenderungen = <int>[];
      await tester.pumpWidget(
        testApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HoehenpunkteWahl(
                planung: planung,
                berechnung: berechnung,
                onGeaendert: () => aenderungen.add(aenderungen.length),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (planung: planung, aenderungen: aenderungen);
    }

    Finder feld(String name) => find.descendant(
      of: find.byKey(ValueKey('hoehe-$name')),
      matching: find.byType(TextField),
    );

    Future<void> gib(WidgetTester tester, String name, String text) async {
      await tester.enterText(feld(name), text);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }

    testWidgets('ohne Gefälle eine Höhe für alle, Vorgabe der Art; mit '
        'Gefälle je Eckpunkt', (tester) async {
      final s = await zeige(tester, berechne: server);
      expect(find.text(de.hoehenpunkteHilfe), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('gefaelle-ohne')))
            .selected,
        isTrue,
      );
      expect(
        tester.widget<TextField>(feld('alle')).decoration!.hintText,
        '8,6',
      );
      expect(
        find.text('Aufbauhöhe (Belag und Unterkonstruktion): 8,3 cm'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('uk-gedreht')), findsNothing);
      expect(find.byKey(const ValueKey('hoehe-korrigiert')), findsNothing);
      await gib(tester, 'alle', '12');
      expect(s.planung.aktuell.hoehen, List.filled(4, const Millimeter(120)));
      expect(s.aenderungen, [0]);
      await gib(tester, 'alle', '0');
      expect(find.text(de.hoeheUngueltig), findsOneWidget);
      expect(s.aenderungen, [0]);
      // erneutes Tippen auf „ohne Gefälle“ ändert nichts
      await tester.tap(find.byKey(const ValueKey('gefaelle-ohne')));
      await tester.pumpAndSettle();
      expect(s.aenderungen, [0]);
      await tester.tap(find.byKey(const ValueKey('gefaelle-mit')));
      await tester.pumpAndSettle();
      expect(s.planung.aktuell.gefaelle, isTrue);
      expect(s.aenderungen, [0, 1]);
      expect(feld('alle'), findsNothing);
      for (final (i, name) in ['A', 'B', 'C', 'D'].indexed) {
        expect(
          tester.widget<TextField>(feld('$i')).decoration!.labelText,
          name,
        );
        expect(tester.widget<TextField>(feld('$i')).decoration!.hintText, '12');
      }
      await gib(tester, '2', '8,6');
      expect(s.planung.aktuell.hoehen, [
        const Millimeter(120),
        const Millimeter(120),
        const Millimeter(86),
        const Millimeter(120),
      ]);
      expect(s.aenderungen, [0, 1, 2]);
      s.planung.rueckgaengig();
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(feld('2')).decoration!.hintText, '12');
      await tester.tap(find.byKey(const ValueKey('gefaelle-ohne')));
      await tester.pumpAndSettle();
      expect(s.planung.aktuell.gefaelle, isFalse);
    });

    testWidgets('Hinweis bei gedrehter UK, Meldung bei Korrektur', (
      tester,
    ) async {
      await zeige(tester, berechne: server);
      await gib(tester, 'alle', '7');
      expect(find.text(de.ukGedreht), findsOneWidget);
      expect(
        find.text('Aufbauhöhe (Belag und Unterkonstruktion): 6,3 cm'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('hoehe-korrigiert')), findsNothing);
      await gib(tester, 'alle', '5');
      expect(
        find.text(
          'Der Höhenreferenzpunkt unterschreitet die minimale Höhe von '
          '6,3 cm. Er wurde korrigiert.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('ohne Berechnung nur die Eingaben', (tester) async {
      await zeige(tester);
      expect(feld('alle'), findsOneWidget);
      expect(find.textContaining('Aufbauhöhe'), findsNothing);
      expect(find.byKey(const ValueKey('uk-gedreht')), findsNothing);
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
    expect(find.byKey(const ValueKey('hoehenpunkte')), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('hoehe-alle')),
        matching: find.byType(TextField),
      ),
      '20',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(planung.aktuell.alleHoehe, const Millimeter(200));
    expect(
      zustand.unveraendert,
      isNot(contains(PlanerSchritt.unterkonstruktion)),
    );
    zustand.vergissAenderungen();
    expect(find.text('3.6 ${de.unterkonstruktion6}'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('terrassenart-hochterrasse')));
    await tester.pump();
    expect(find.textContaining(de.unterkonstruktion6), findsNothing);
    expect(find.text('3.6 ${de.unterkonstruktion7}'), findsOneWidget);
    expect(find.text('3.7 ${de.unterkonstruktion8}'), findsOneWidget);
    expect(find.text('3.8 ${de.unterkonstruktion9}'), findsOneWidget);
    expect(find.text('3.9 ${de.unterkonstruktion10}'), findsOneWidget);
    expect(
      zustand.unveraendert,
      isNot(contains(PlanerSchritt.unterkonstruktion)),
    );
  });
}
