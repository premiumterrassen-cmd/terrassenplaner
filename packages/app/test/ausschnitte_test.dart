import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/design/planer_design.dart';
import 'package:terrassenplaner_app/src/rahmen/ansichtsoptionen.dart';
import 'package:terrassenplaner_app/src/rahmen/ausschnitte.dart';
import 'package:terrassenplaner_app/src/rahmen/berechnung_steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/freiform.dart';
import 'package:terrassenplaner_app/src/rahmen/steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/zeichenflaeche.dart';
import 'package:terrassenplaner_app/src/rahmen/zeichnung.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

final _terrasse = Planungsstand(
  grundriss: RechteckGrundriss(const Millimeter(5400), const Millimeter(3600)),
);

({
  PlanungsSteuerung planung,
  ZeichenModus modus,
  AusschnittBedienung b,
  List<int> geaendert,
})
_bedienung([Planungsstand? stand]) {
  final planung = PlanungsSteuerung(stand ?? _terrasse);
  final modus = ZeichenModus();
  final geaendert = <int>[];
  return (
    planung: planung,
    modus: modus,
    geaendert: geaendert,
    b: AusschnittBedienung(
      planung: planung,
      modus: modus,
      onGeaendert: () => geaendert.add(geaendert.length),
    ),
  );
}

void main() {
  group('AusschnittBedienung', () {
    test('hinzufügen, ändern, entfernen', () {
      final s = _bedienung();
      expect(s.b.fuegeHinzu(), isNull);
      expect(s.planung.aktuell.ausschnitte.single.bezeichnung, 'A1');
      expect(
        s.b.aendereAusschnitt(0, (a) => a.mitMass(0, const Millimeter(0))),
        isNull,
      );
      expect(s.planung.aktuell.ausschnitte.single.x, const Millimeter(0));
      // A2 entstünde mitten auf A1? Nein – A1 liegt jetzt links; trotzdem
      // überschneiden sich 180 × 120 bei X 0 und X 180 nicht
      expect(s.b.fuegeHinzu(), isNull);
      s.b.entferne(0);
      expect(s.planung.aktuell.ausschnitte.single.bezeichnung, 'A2');
      expect(s.geaendert, [0, 1, 2, 3]);
    });

    test('Prüfungen weisen ab und melden', () {
      final s = _bedienung(Planungsstand.start.mitForm(Terrassenform.oForm));
      final kollision = s.b.fuegeHinzu();
      expect(kollision!.meldung.problem, AusschnittProblem.kollision);
      expect(s.planung.aktuell.ausschnitte, hasLength(1));
      final aussen = s.b.aendereAusschnitt(
        0,
        (a) => a.mitMass(0, const Millimeter(4000)),
      );
      expect(aussen!.meldung.problem, AusschnittProblem.ausserhalb);
      expect(s.geaendert, isEmpty);
    });

    test('Meldungstexte wie im alten Planer', () {
      final a = [Ausschnitt.oForm, Ausschnitt.oForm.mitBezeichnung('Pool')];
      String text(AusschnittProblem p, [int? anderer]) =>
          AusschnittBedienung.text(de, (
            meldung: (problem: p, ausschnitt: 1, anderer: anderer),
            ausschnitte: a,
          ));
      expect(
        text(AusschnittProblem.ausserhalb),
        'Der Ausschnitt darf nicht außerhalb der Terrasse sein!',
      );
      expect(
        text(AusschnittProblem.kollision, 0),
        'Pool und A1 dürfen sich nicht überschneiden.',
      );
      expect(
        text(AusschnittProblem.teilung),
        'Pool darf die Terrasse nicht teilen.',
      );
      expect(
        AusschnittBedienung.text(en, (
          meldung: (
            problem: AusschnittProblem.teilung,
            ausschnitt: 0,
            anderer: null,
          ),
          ausschnitte: a,
        )),
        'A1 must not split the terrace.',
      );
    });

    test('Ziehen: ein Schritt, Einrasten, ungültige Lagen bleiben aus', () {
      final s = _bedienung(Planungsstand.start.mitForm(Terrassenform.oForm));
      s.b
        ..ziehe(0, const Punkt(130, 40), beginn: true)
        ..ziehe(0, const Punkt(249, -51), beginn: false);
      final a = s.planung.aktuell.ausschnitte.single;
      expect([a.x.mm, a.y.mm], [1700, 800]);
      // weit nach rechts: ragte hinaus – bleibt, wo es war
      s.b.ziehe(0, const Punkt(5000, 0), beginn: false);
      expect(s.planung.aktuell.ausschnitte.single.x.mm, 1700);
      s.planung.rueckgaengig();
      expect(s.planung.aktuell.ausschnitte.single, Ausschnitt.oForm);
      // ohne Einrasten genau
      s.modus.einrasten = false;
      s.b.ziehe(0, const Punkt(13, 7), beginn: true);
      expect(s.planung.aktuell.ausschnitte.single.x.mm, 1513);
      // ungültiger Beginn: kein Schritt
      final t = _bedienung(Planungsstand.start.mitForm(Terrassenform.oForm));
      t.b.ziehe(0, const Punkt(5000, 0), beginn: true);
      expect(t.planung.kannRueckgaengig, isFalse);
    });
  });

  group('AusschnittMasse', () {
    Future<PlanungsSteuerung> zeige(
      WidgetTester tester,
      Planungsstand stand,
    ) async {
      final s = _bedienung(stand);
      addTearDown(s.planung.dispose);
      await tester.pumpWidget(
        testApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: s.planung,
              builder: (context, _) =>
                  SingleChildScrollView(child: AusschnittMasse(bedienung: s.b)),
            ),
          ),
        ),
      );
      return s.planung;
    }

    testWidgets('Form, Funktion, Inhalt, Bezeichnung, entfernen', (
      tester,
    ) async {
      final planung = await zeige(
        tester,
        Planungsstand.start.mitForm(Terrassenform.oForm),
      );
      Ausschnitt a() => planung.aktuell.ausschnitte.single;
      await tester.tap(find.text('Kreis'));
      await tester.pump();
      expect(a().form, Ausschnittform.kreis);
      expect(find.text('Breite: cm'), findsNothing);
      await tester.tap(find.text('Sechseck'));
      await tester.pump();
      expect(a().form, Ausschnittform.sechseck);
      expect(find.text('Breite: cm'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ausschnitt-0-inhalt')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pool').last);
      await tester.pumpAndSettle();
      expect(a().inhalt, Ausschnittinhalt.pool);
      await tester.tap(find.text('anderer Terrassenbelag'));
      await tester.pump();
      expect(a().funktion, Ausschnittfunktion.andererBelag);
      expect(find.byKey(const ValueKey('ausschnitt-0-inhalt')), findsNothing);
      final name = find.byKey(const ValueKey('ausschnitt-0-bezeichnung'));
      await tester.enterText(name, '  ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(a().bezeichnung, 'A1');
      await tester.enterText(name, ' Beet ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(a().bezeichnung, 'Beet');
      expect(find.text('Ausschnitt Beet'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ausschnitt-0-entfernen')));
      await tester.pump();
      expect(planung.aktuell.ausschnitte, isEmpty);
      await tester.tap(find.byKey(const ValueKey('weitere-flaeche')));
      await tester.pump();
      expect(planung.aktuell.ausschnitte.single.bezeichnung, 'A1');
    });

    testWidgets('Meldung als Dialog mit SCHLIESSEN', (tester) async {
      final planung = await zeige(
        tester,
        Planungsstand.start.mitForm(Terrassenform.oForm),
      );
      await tester.ensureVisible(find.byKey(const ValueKey('weitere-flaeche')));
      await tester.tap(find.byKey(const ValueKey('weitere-flaeche')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ausschnitt-meldung')), findsOneWidget);
      expect(
        find.text('A2 und A1 dürfen sich nicht überschneiden.'),
        findsOneWidget,
      );
      await tester.tap(find.text('SCHLIESSEN'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ausschnitt-meldung')), findsNothing);
      expect(planung.aktuell.ausschnitte, hasLength(1));
      // auch die Formwahl wird geprüft: flach unten liegend passt das
      // Rechteck, ein Kreis Ø 240 ragte unten heraus
      planung.setze(
        planung.aktuell.mitAusschnitt(
          0,
          Ausschnitt.oForm
              .mitMass(3, const Millimeter(600))
              .mitMass(1, const Millimeter(2800)),
        ),
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Kreis'));
      await tester.tap(find.text('Kreis'));
      await tester.pumpAndSettle();
      expect(
        find.text('Der Ausschnitt darf nicht außerhalb der Terrasse sein!'),
        findsOneWidget,
      );
      expect(planung.aktuell.ausschnitte.single.form, Ausschnittform.rechteck);
    });

    test('Namen der Formen und Inhalte', () {
      expect(
        [
          for (final f in Ausschnittform.values)
            AusschnittMasse.formName(en, f),
        ],
        ['Rectangle', 'Triangle', 'Hexagon', 'Circle'],
      );
      expect(
        [
          for (final i in Ausschnittinhalt.values)
            AusschnittMasse.inhaltName(de, i),
        ],
        ['leer/weiß', 'Kies hell', 'Stein dunkel', 'Pool', 'Rasen', 'Erde'],
      );
      expect(
        [
          for (final i in Ausschnittinhalt.values)
            AusschnittMasse.inhaltName(en, i),
        ],
        ['empty/white', 'Light gravel', 'Dark stone', 'Pool', 'Lawn', 'Soil'],
      );
      expect(
        [en.weitereFlaeche, en.ausschnittEntfernen, en.feldBezeichnung],
        ['Add further area', 'Remove area', 'Area name'],
      );
      expect(
        [en.funktionLeer, en.funktionBelag, en.schliessen],
        ['empty area', 'other decking', 'CLOSE'],
      );
      expect(
        en.meldungAusserhalb,
        'The cut-out must not lie outside the terrace!',
      );
      expect(en.meldungKollision('A', 'B'), 'A and B must not overlap.');
    });
  });

  group('Darstellung und Ziehen in der Zeichnung', () {
    test('Füllung je Inhalt, Teilfläche in Belagfarbe', () {
      final a = Ausschnitt.oForm;
      expect(BerechnungsSteuerung.farbe(a), PlanerFarben.weiss);
      expect({
        for (final i in Ausschnittinhalt.values)
          BerechnungsSteuerung.farbe(a.mitInhalt(i)),
      }, hasLength(6));
      expect(
        BerechnungsSteuerung.farbe(
          a
              .mitInhalt(Ausschnittinhalt.pool)
              .mitFunktion(Ausschnittfunktion.andererBelag),
        ),
        PlanerFarben.belagAnders,
      );
    });

    test('Zeichnung trägt Namen und Füllung', () async {
      final planung = PlanungsSteuerung(
        Planungsstand.start.mitForm(Terrassenform.oForm),
      );
      final b = BerechnungsSteuerung(
        planung: planung,
        berechne: (p) async => Berechnung(
          umriss: p.aktuell.grundriss.ecken,
          flaeche: 1,
          ausschnitte: [for (final a in p.aktuell.ausschnitte) a.kontur.punkte],
        ),
      );
      await pumpEventQueue();
      expect(b.zeichnung.ausschnittDarstellung.single.name, 'A1');
      b.dispose();
      planung.dispose();
    });

    testWidgets('Griff in der Mitte verschiebt den Ausschnitt', (tester) async {
      tester.view
        ..physicalSize = const Size(1440, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = _bedienung(Planungsstand.start.mitForm(Terrassenform.oForm));
      final ansicht = AnsichtSteuerung();
      addTearDown(s.planung.dispose);
      addTearDown(ansicht.dispose);
      await tester.pumpWidget(
        testApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: s.planung,
              builder: (context, _) => Zeichenflaeche(
                planung: s.planung,
                ansicht: ansicht,
                optionen: AnsichtsOptionen(),
                ausschnitte: s.b,
                zeichnung: Zeichnung(
                  umriss: [
                    for (final p in s.planung.aktuell.grundriss.ecken)
                      Offset(p.x, p.y),
                  ],
                  ausschnitte: [
                    for (final a in s.planung.aktuell.ausschnitte)
                      [for (final p in a.kontur.punkte) Offset(p.x, p.y)],
                  ],
                  ausschnittDarstellung: const [
                    (name: 'A1', farbe: Color(0xFF7FC4E8)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final ursprung = tester.getTopLeft(
        find.byKey(const ValueKey('zeichenflaeche')),
      );
      // Mitte von A1 (2700|1800) mm = (270|180) px
      expect(
        tester.getCenter(find.byKey(const ValueKey('ausschnitt-griff-0'))),
        ursprung + const Offset(270, 180),
      );
      await tester.drag(
        find.byKey(const ValueKey('ausschnitt-griff-0')),
        const Offset(-50, 30),
      );
      await tester.pump();
      final a = s.planung.aktuell.ausschnitte.single;
      expect([a.x.mm, a.y.mm], [1000, 1200]);
    });
  });
}
