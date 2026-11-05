import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/rahmen/anschluss.dart';
import 'package:terrassenplaner_app/src/rahmen/berechnung_steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_schritt.dart';
import 'package:terrassenplaner_app/src/rahmen/rahmen_zustand.dart';
import 'package:terrassenplaner_app/src/rahmen/steuerung.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

void main() {
  test('Seitenname wie in der Zeichnung', () {
    expect(seitenname(0, 4), 'A — B');
    expect(seitenname(3, 4), 'D — A');
  });

  group('Angrenzende Bauelemente (M7-01)', () {
    Future<({PlanungsSteuerung planung, List<int> aenderungen})> zeige(
      WidgetTester tester, {
      Locale sprache = const Locale('de'),
      Planungsstand stand = Planungsstand.start,
    }) async {
      final planung = PlanungsSteuerung()..setze(stand);
      addTearDown(planung.dispose);
      final aenderungen = <int>[];
      await tester.pumpWidget(
        testApp(
          sprache: sprache,
          home: Scaffold(
            body: AngrenzendWahl(
              planung: planung,
              onGeaendert: () => aenderungen.add(aenderungen.length),
            ),
          ),
        ),
      );
      return (planung: planung, aenderungen: aenderungen);
    }

    FilterChip chip(WidgetTester tester, int seite) =>
        tester.widget(find.byKey(ValueKey('angrenzend-$seite')));

    testWidgets('je Seite ein Schalter; Wahl ist ein Schritt im Verlauf', (
      tester,
    ) async {
      final s = await zeige(tester);
      expect(find.text(de.angrenzendFrage), findsOneWidget);
      for (final name in ['A — B', 'B — C', 'C — D', 'D — A']) {
        expect(find.text(name), findsOneWidget);
      }
      expect(chip(tester, 0).selected, isFalse);
      await tester.tap(find.byKey(const ValueKey('angrenzend-0')));
      await tester.pump();
      expect(s.planung.aktuell.anschluss.angrenzend, [0]);
      expect(chip(tester, 0).selected, isTrue);
      expect(s.aenderungen, [0]);
      await tester.tap(find.byKey(const ValueKey('angrenzend-0')));
      await tester.pump();
      expect(s.planung.aktuell.anschluss.angrenzend, isEmpty);
      s.planung.rueckgaengig();
      await tester.pump();
      expect(chip(tester, 0).selected, isTrue);
    });

    testWidgets('Kreis: keine Seiten, englische Texte', (tester) async {
      await zeige(
        tester,
        sprache: const Locale('en'),
        stand: Planungsstand.start.mitForm(Terrassenform.kreis),
      );
      expect(find.text(en.angrenzendFrage), findsOneWidget);
      expect(find.byKey(const ValueKey('angrenzend-leer')), findsOneWidget);
      expect(find.text(en.ohneSeiten), findsOneWidget);
    });

    testWidgets('im Bearbeitungsmenü unter 4.1', (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final planung = PlanungsSteuerung();
      addTearDown(planung.dispose);
      final zustand = RahmenZustand()..waehle(PlanerSchritt.terrassenanschluss);
      await tester.pumpWidget(
        testApp(
          home: PlanerRahmen(
            status: const SizedBox(),
            zustand: zustand,
            planung: planung,
          ),
        ),
      );
      expect(find.byType(AngrenzendWahl), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('angrenzend-1')));
      await tester.pump();
      expect(planung.aktuell.anschluss.angrenzend, [1]);
      expect(
        zustand.unveraendert,
        isNot(contains(PlanerSchritt.terrassenanschluss)),
      );
    });
  });

  group('Verblendung (M7-02)', () {
    Future<({PlanungsSteuerung planung, List<int> aenderungen})> zeige(
      WidgetTester tester, {
      Planungsstand stand = Planungsstand.start,
      List<Anschlussmeldung> meldungen = const [],
    }) async {
      final planung = PlanungsSteuerung()..setze(stand);
      final berechnung = BerechnungsSteuerung(
        planung: planung,
        berechne: (_) async => Berechnung(
          umriss: const [],
          flaeche: 0,
          anschluss: Anschlussergebnis(meldungen: meldungen),
        ),
      );
      addTearDown(() {
        berechnung.dispose();
        planung.dispose();
      });
      final aenderungen = <int>[];
      await tester.pumpWidget(
        testApp(
          home: Scaffold(
            body: VerblendungWahl(
              planung: planung,
              berechnung: berechnung,
              onGeaendert: () => aenderungen.add(aenderungen.length),
            ),
          ),
        ),
      );
      await tester.pump();
      return (planung: planung, aenderungen: aenderungen);
    }

    FilterChip chip(WidgetTester tester, String schluessel) =>
        tester.widget(find.byKey(ValueKey(schluessel)));

    testWidgets('Seiten an Bauelementen stehen nicht zur Wahl; Wahl ist ein '
        'Schritt im Verlauf', (tester) async {
      final s = await zeige(
        tester,
        stand: Planungsstand.start.mitAngrenzend(0, an: true),
      );
      expect(find.text(de.verblendungFrage), findsOneWidget);
      expect(find.text(de.verblendungHinweis), findsOneWidget);
      expect(find.byKey(const ValueKey('verblendet-0')), findsNothing);
      expect(chip(tester, 'verblendet-1').selected, isFalse);
      await tester.tap(find.byKey(const ValueKey('verblendet-1')));
      await tester.pump();
      expect(s.planung.aktuell.anschluss.verblendet, [1]);
      expect(chip(tester, 'verblendet-1').selected, isTrue);
      expect(s.aenderungen, [0]);
      s.planung.rueckgaengig();
      await tester.pump();
      expect(chip(tester, 'verblendet-1').selected, isFalse);
    });

    testWidgets('Kreis: Fläche verblenden', (tester) async {
      final s = await zeige(
        tester,
        stand: Planungsstand.start.mitForm(Terrassenform.kreis),
      );
      expect(find.text(de.flaecheVerblenden), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('verblendet-flaeche')));
      await tester.pump();
      expect(s.planung.aktuell.anschluss.verblendet, [0]);
      expect(chip(tester, 'verblendet-flaeche').selected, isTrue);
    });

    testWidgets('Hinweise vom Server als Warnung', (tester) async {
      await zeige(tester, meldungen: Anschlussmeldung.values);
      expect(
        find.byKey(const ValueKey('anschluss-ohneRinnenartikel')),
        findsNothing,
      );
      for (final m in Anschlussmeldung.values.where(
        (m) => m != Anschlussmeldung.ohneRinnenartikel,
      )) {
        expect(find.byKey(ValueKey('anschluss-${m.name}')), findsOneWidget);
        expect(find.text(anschlussmeldungText(de, m)), findsOneWidget);
      }
      expect(
        anschlussmeldungText(en, Anschlussmeldung.unterlueftung),
        en.meldungUnterlueftung,
      );
    });

    testWidgets('im Bearbeitungsmenü unter 4.2', (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final planung = PlanungsSteuerung();
      addTearDown(planung.dispose);
      final zustand = RahmenZustand()..waehle(PlanerSchritt.terrassenanschluss);
      await tester.pumpWidget(
        testApp(
          home: PlanerRahmen(
            status: const SizedBox(),
            zustand: zustand,
            planung: planung,
          ),
        ),
      );
      expect(find.byType(VerblendungWahl), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('verblendet-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('verblendet-2')));
      await tester.pump();
      expect(planung.aktuell.anschluss.verblendet, [2]);
      expect(
        zustand.unveraendert,
        isNot(contains(PlanerSchritt.terrassenanschluss)),
      );
    });
  });

  group('Entwässerungsrinnen (M7-03)', () {
    Future<PlanungsSteuerung> zeige(
      WidgetTester tester, {
      Planungsstand stand = Planungsstand.start,
      List<Anschlussmeldung> meldungen = const [],
      Locale sprache = const Locale('de'),
    }) async {
      final planung = PlanungsSteuerung()..setze(stand);
      final berechnung = BerechnungsSteuerung(
        planung: planung,
        berechne: (_) async => Berechnung(
          umriss: const [],
          flaeche: 0,
          anschluss: Anschlussergebnis(meldungen: meldungen),
        ),
      );
      addTearDown(() {
        berechnung.dispose();
        planung.dispose();
      });
      await tester.pumpWidget(
        testApp(
          sprache: sprache,
          home: Scaffold(
            body: SingleChildScrollView(
              child: RinnenWahl(
                planung: planung,
                berechnung: berechnung,
                onGeaendert: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return planung;
    }

    testWidgets('Seite wählen, Lage wählen, abwählen; verblendete Seiten '
        'nicht, Bauelement schon', (tester) async {
      final planung = await zeige(
        tester,
        stand: Planungsstand.start
            .mitAngrenzend(0, an: true)
            .mitVerblendet(1, an: true),
      );
      expect(find.text(de.rinnenFrage), findsOneWidget);
      expect(find.text(de.rinnenHinweis), findsOneWidget);
      expect(find.byKey(const ValueKey('rinne-1')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('rinne-0')));
      await tester.pump();
      expect(planung.aktuell.anschluss.rinneAn(0), Rinnenlage.gesamteSeite);
      expect(find.text(de.rinnenLage('A — B')), findsOneWidget);
      for (final l in Rinnenlage.values) {
        expect(find.text(rinnenlageText(de, l)), findsOneWidget);
      }
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('rinne-0-gesamteSeite')),
            )
            .selected,
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('rinne-0-vorElement')));
      await tester.pump();
      expect(planung.aktuell.anschluss.rinneAn(0), Rinnenlage.vorElement);
      // die gewählte Lage noch einmal: keine Änderung
      await tester.tap(find.byKey(const ValueKey('rinne-0-vorElement')));
      await tester.pump();
      expect(planung.aktuell.anschluss.rinneAn(0), Rinnenlage.vorElement);
      await tester.tap(find.byKey(const ValueKey('rinne-0')));
      await tester.pump();
      expect(planung.aktuell.anschluss.rinnen, isEmpty);
      expect(
        find.byKey(const ValueKey('anschluss-ohneRinnenartikel')),
        findsNothing,
      );
    });

    testWidgets('Hinweis ohne Rinnenartikel, englische Texte', (tester) async {
      await zeige(
        tester,
        sprache: const Locale('en'),
        meldungen: const [Anschlussmeldung.ohneRinnenartikel],
      );
      expect(find.text(en.meldungOhneRinnenartikel), findsOneWidget);
      expect(
        rinnenlageText(en, Rinnenlage.imElement),
        'In the floor-level element',
      );
      expect(
        anschlussmeldungText(de, Anschlussmeldung.ohneRinnenartikel),
        de.meldungOhneRinnenartikel,
      );
    });

    testWidgets('im Bearbeitungsmenü unter 4.3', (tester) async {
      tester.view.physicalSize = const Size(1440, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final planung = PlanungsSteuerung();
      addTearDown(planung.dispose);
      final zustand = RahmenZustand()..waehle(PlanerSchritt.terrassenanschluss);
      await tester.pumpWidget(
        testApp(
          home: PlanerRahmen(
            status: const SizedBox(),
            zustand: zustand,
            planung: planung,
          ),
        ),
      );
      final chip = find.byKey(const ValueKey('rinne-3'));
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pump();
      expect(planung.aktuell.anschluss.rinneAn(3), Rinnenlage.gesamteSeite);
    });
  });

  testWidgets('Seiten mit Rolle vom Server in der Zeichnung (M7)', (
    tester,
  ) async {
    final planung = PlanungsSteuerung();
    final berechnung = BerechnungsSteuerung(
      planung: planung,
      berechne: (_) async => Berechnung(
        umriss: const [],
        flaeche: 0,
        anschluss: Anschlussergebnis(
          seiten: const [
            (
              seite: 0,
              rolle: Seitenrolle.bauelement,
              von: Punkt(0, 0),
              bis: Punkt(4800, 0),
            ),
          ],
        ),
      ),
    );
    addTearDown(() {
      berechnung.dispose();
      planung.dispose();
    });
    await tester.pump();
    expect(berechnung.zeichnung.seiten, [
      (Offset.zero, const Offset(4800, 0), Seitenrolle.bauelement),
    ]);
  });
}
