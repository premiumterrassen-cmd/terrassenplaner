import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/rahmen/anschluss.dart';
import 'package:terrassenplaner_app/src/rahmen/berechnung_steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_schritt.dart';
import 'package:terrassenplaner_app/src/rahmen/rahmen_zustand.dart';
import 'package:terrassenplaner_app/src/rahmen/steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/unterkonstruktion.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

void main() {
  test('Seitenname wie in der Zeichnung (Eckbuchstaben R-E03)', () {
    expect(seitenname(Planungsstand.start, 0), 'A — B');
    expect(seitenname(Planungsstand.start, 3), 'D — A');
    // um 90° gedreht: der erste Punkt liegt oben rechts und heißt B
    final gedreht = Planungsstand.start.mitGrundriss(
      Planungsstand.start.grundriss.gedreht(90),
    );
    expect(seitenname(gedreht, 0), 'B — C');
    expect(seitenname(gedreht, 3), 'A — B');
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

  group('Blende am Bogen einer Ecke und an Aussparungen (Planungskern '
      'v14/v15)', () {
    Future<PlanungsSteuerung> zeige(
      WidgetTester tester,
      Planungsstand stand, {
      bool mitPlanbild = true,
    }) async {
      final planung = PlanungsSteuerung()..setze(stand);
      final umriss = umrisspunkte(stand);
      final berechnung = BerechnungsSteuerung(
        planung: planung,
        berechne: (_) async => Berechnung(
          umriss: const [],
          flaeche: 0,
          planbild: mitPlanbild
              ? Planbild(
                  umrisspunkte: umriss,
                  aussparungsecken: aussparungsecken(stand, umriss),
                )
              : null,
        ),
      );
      addTearDown(() {
        berechnung.dispose();
        planung.dispose();
      });
      await tester.pumpWidget(
        testApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VerblendungWahl(
                planung: planung,
                berechnung: berechnung,
                onGeaendert: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return planung;
    }

    final stand = Planungsstand(
      grundriss: RechteckGrundriss(
        const Millimeter(5400),
        const Millimeter(3600),
      ),
      rundungen: Rundungen.keine.mitEcke(2, const Millimeter(1000)),
    ).mitNeuemAusschnitt();

    testWidgets('nur, wenn gewählt; Namen vom Server', (tester) async {
      final planung = await zeige(tester, stand);
      expect(find.text(de.verblendungZusatzFrage), findsOneWidget);
      expect(find.text('Bogen C–E'), findsOneWidget);
      expect(find.text('A1: F–G'), findsOneWidget);
      expect(find.text('A1: I–F'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('eckblende-2')));
      await tester.pump();
      expect(planung.aktuell.anschluss.eckblenden, [2]);
      await tester.tap(find.byKey(const ValueKey('aussparungsblende-0-1')));
      await tester.pump();
      expect(planung.aktuell.anschluss.aussparungsblenden, [
        (ausschnitt: 0, kante: 1),
      ]);
      await tester.tap(find.byKey(const ValueKey('aussparungsblende-0-1')));
      await tester.pump();
      expect(planung.aktuell.anschluss.aussparungsblenden, isEmpty);
    });

    testWidgets('ohne Berechnung: Ecke und Nummer der Kante; ohne Bogen und '
        'Aussparung nichts', (tester) async {
      await zeige(tester, stand, mitPlanbild: false);
      expect(find.text('Bogen C'), findsOneWidget);
      expect(find.text('A1: 2'), findsOneWidget);
      await zeige(tester, Planungsstand.start);
      expect(find.byKey(const ValueKey('zusatzblenden')), findsNothing);
      await zeige(
        tester,
        Planungsstand.start.mitNeuemAusschnitt().mitAusschnitt(
          0,
          Planungsstand.start.mitNeuemAusschnitt().ausschnitte[0].mitForm(
            Ausschnittform.kreis,
          ),
        ),
      );
      expect(find.byKey(const ValueKey('zusatzblenden')), findsNothing);
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
            body: SingleChildScrollView(
              child: VerblendungWahl(
                planung: planung,
                berechnung: berechnung,
                onGeaendert: () => aenderungen.add(aenderungen.length),
              ),
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

    testWidgets('Seitenblende je Seite (Planungskern v7, Regel 9.4): Höhe, '
        'automatisch, Teilstücke', (tester) async {
      final s = await zeige(
        tester,
        stand: Planungsstand.start.mitVerblendet(1, an: true),
      );
      expect(find.text(de.blendeSeite('B — C')), findsOneWidget);
      expect(find.text(de.blendeJeSeiteHilfe), findsOneWidget);
      expect(find.text(de.blendenhoeheAutomatisch), findsOneWidget);
      expect(find.byKey(const ValueKey('blende-1-automatisch')), findsNothing);
      Finder feld(String schluessel) => find.descendant(
        of: find.byKey(ValueKey(schluessel)),
        matching: find.byType(TextField),
      );
      await tester.enterText(feld('blende-1-hoehe'), '14');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(
        s.planung.aktuell.anschluss.blendenhoeheAn(1),
        const Millimeter(140),
      );
      await tester.tap(find.byKey(const ValueKey('blende-1-automatisch')));
      await tester.pump();
      expect(s.planung.aktuell.anschluss.blendenhoeheAn(1), isNull);
      // Teilstück: ganze Seite vorbelegt, dann ändern und entfernen
      await tester.tap(find.byKey(const ValueKey('blende-1-teil-hinzufuegen')));
      await tester.pump();
      expect(s.planung.aktuell.anschluss.teileAn(1), const [
        (von: Millimeter(0), bis: Millimeter(3090)),
      ]);
      expect(find.text(de.blendenteil(1)), findsOneWidget);
      expect(find.text(de.blendenteilVon('B')), findsOneWidget);
      await tester.enterText(feld('blende-1-teil-0-von'), '100');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.enterText(feld('blende-1-teil-0-bis'), '250');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(s.planung.aktuell.anschluss.teileAn(1), const [
        (von: Millimeter(1000), bis: Millimeter(2500)),
      ]);
      // Anfang hinter dem Ende: Fehler, nichts übernommen
      await tester.enterText(feld('blende-1-teil-0-von'), '300');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text(de.blendenteilUngueltig), findsOneWidget);
      await tester.enterText(feld('blende-1-teil-0-bis'), '50');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text(de.blendenteilUngueltig), findsNWidgets(2));
      expect(s.planung.aktuell.anschluss.teileAn(1).single.von.mm, 1000);
      await tester.tap(find.byKey(const ValueKey('blende-1-teil-0-entfernen')));
      await tester.pump();
      expect(s.planung.aktuell.anschluss.teileAn(1), isEmpty);
      expect(s.aenderungen, hasLength(6));
    });

    testWidgets('Kreis: nur die Höhe, keine Teilstücke', (tester) async {
      final s = await zeige(
        tester,
        stand: Planungsstand.start
            .mitForm(Terrassenform.kreis)
            .mitVerblendet(0, an: true),
      );
      expect(find.byKey(const ValueKey('blende-0-hoehe')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('blende-0-teil-hinzufuegen')),
        findsNothing,
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('blende-0-hoehe')),
          matching: find.byType(TextField),
        ),
        '20',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(
        s.planung.aktuell.anschluss.blendenhoeheAn(0),
        const Millimeter(200),
      );
      expect(en.blendeSeite('A — B'), 'Cladding A — B');
    });

    testWidgets('Hinweise vom Server als Warnung', (tester) async {
      await zeige(tester, meldungen: Anschlussmeldung.values);
      expect(
        find.byKey(const ValueKey('anschluss-ohneRinnenartikel')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('anschluss-treppeNichtFrei')),
        findsNothing,
      );
      for (final m in zurVerblendung) {
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

    testWidgets('nur gerade, waagerechte oder senkrechte Seiten ab 30 cm; '
        'Farbe eloxiert/anthrazit (Planungskern v11, Regel 13.1)', (
      tester,
    ) async {
      final bogen = Planungsstand.start
          .mitRinne(0, Rinnenlage.gesamteSeite)
          .mitRundungen(
            Rundungen.keine
                .mitSeite(0, const Millimeter(100))
                .mitSeite(2, const Millimeter(100)),
          );
      final planung = await zeige(tester, stand: bogen);
      // Seite C — D am Bogen nicht wählbar, die gewählte A — B bleibt
      // abwählbar
      expect(find.byKey(const ValueKey('rinne-2')), findsNothing);
      expect(find.byKey(const ValueKey('rinne-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('rinne-1')), findsOneWidget);
      expect(find.text(de.rinnenFarbe), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('rinnenfarbe-eloxiert')),
            )
            .selected,
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('rinnenfarbe-anthrazit')));
      await tester.pump();
      expect(planung.aktuell.anschluss.rinnenfarbe, Rinnenfarbe.anthrazit);
      // die gewählte Farbe noch einmal: keine Änderung
      await tester.tap(find.byKey(const ValueKey('rinnenfarbe-anthrazit')));
      await tester.pump();
      expect(planung.aktuell.anschluss.rinnenfarbe, Rinnenfarbe.anthrazit);
      await tester.tap(find.byKey(const ValueKey('rinne-0')));
      await tester.pump();
      expect(find.text(de.rinnenFarbe), findsNothing);
      expect(rinnenfarbeText(de, Rinnenfarbe.eloxiert), 'eloxiert');
      expect(rinnenfarbeText(en, Rinnenfarbe.anthrazit), 'anthracite');
    });

    testWidgets('Hinweise zur Rinne: Warnungen, die Annahme zur Montage als '
        'Hinweis', (tester) async {
      await zeige(tester, meldungen: Anschlussmeldung.values);
      for (final m in zurRinne) {
        expect(find.byKey(ValueKey('anschluss-${m.name}')), findsOneWidget);
        expect(find.text(anschlussmeldungText(de, m)), findsOneWidget);
        expect(
          tester
              .widget<Hinweis>(find.byKey(ValueKey('anschluss-${m.name}')))
              .warnung,
          m != Anschlussmeldung.rinnenmontage,
        );
      }
      expect(
        find.byKey(const ValueKey('anschluss-unterlueftung')),
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
        find.byKey(const ValueKey('anschluss-ohneRinnenartikel')),
        findsOneWidget,
      );
      expect(
        rinnenlageText(en, Rinnenlage.imElement),
        'In the floor-level element',
      );
      expect(
        anschlussmeldungText(de, Anschlussmeldung.ohneRinnenartikel),
        de.meldungOhneRinnenartikel,
      );
      expect(
        anschlussmeldungText(de, Anschlussmeldung.treppeNichtFrei),
        de.meldungTreppeNichtFrei,
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
