import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/design/planer_design.dart';
import 'package:terrassenplaner_app/src/rahmen/befestigung.dart';
import 'package:terrassenplaner_app/src/rahmen/berechnung_steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_schritt.dart';
import 'package:terrassenplaner_app/src/rahmen/rahmen_zustand.dart';
import 'package:terrassenplaner_app/src/rahmen/steuerung.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

/// Antwort wie vom Server für einen glattkanten Belag: wählbar sind beide
/// Arten der Verschraubung, Clips gelten nicht (B-090).
Future<Berechnung> _glattkant(Planung planung) async {
  final art = planung.aktuell.befestigungsart.wirksam(Profil.glattkant)!;
  return Berechnung(
    umriss: planung.aktuell.grundriss.ecken,
    flaeche: 1,
    befestigung: Befestigungsbedarf(
      arten: Befestigungsart.fuer(Profil.glattkant),
      art: art,
      punkte: 390,
      mittel: [
        const Befestigungsposition(
          Artikelnummer('50-50-102'),
          'Terrassenschrauben 5,0 x 50 mm, 200 Stück',
          4,
        ),
        if (art == Befestigungsart.verschraubtMitAbstandshaltern)
          const Befestigungsposition(
            Artikelnummer('50-80-009'),
            'ALTO Montagehilfe Abstandshalter, VPE zu 4 Stück',
            1,
          ),
      ],
    ),
  );
}

Future<Berechnung> _ohneDielen(Planung planung) async =>
    Berechnung(umriss: planung.aktuell.grundriss.ecken, flaeche: 1);

void main() {
  Future<({PlanungsSteuerung planung, List<int> aenderungen})> zeige(
    WidgetTester tester, {
    PlanungBerechnen? berechne,
    Locale sprache = const Locale('de'),
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
        sprache: sprache,
        home: Scaffold(
          body: BefestigungsartWahl(
            planung: planung,
            berechnung: berechnung,
            onGeaendert: () => aenderungen.add(aenderungen.length),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (planung: planung, aenderungen: aenderungen);
  }

  testWidgets('glattkant: verschraubt, mit Abstandshaltern wählbar, '
      'Artikel mit Anzahl', (tester) async {
    final s = await zeige(tester, berechne: _glattkant);
    final clips = find.byKey(const ValueKey('befestigungsart-clips'));
    final direkt = find.byKey(const ValueKey('befestigungsart-verschraubt'));
    final abstand = find.byKey(
      const ValueKey('befestigungsart-verschraubtMitAbstandshaltern'),
    );
    expect(clips, findsNothing);
    expect(tester.widget<ChoiceChip>(direkt).selected, isTrue);
    expect(tester.widget<ChoiceChip>(abstand).selected, isFalse);
    expect(find.text(de.befestigungsartVerschraubt), findsOneWidget);
    expect(find.text(de.befestigungspunkte(390)), findsOneWidget);
    expect(find.text('Befestigungspunkte: 390'), findsOneWidget);
    expect(
      find.text('4 × Terrassenschrauben 5,0 x 50 mm, 200 Stück'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('befestigungsmittel-50-80-009')),
      findsNothing,
    );
    await tester.tap(abstand);
    await tester.pumpAndSettle();
    expect(
      s.planung.aktuell.befestigungsart,
      Befestigungsart.verschraubtMitAbstandshaltern,
    );
    expect(s.aenderungen, [0]);
    expect(tester.widget<ChoiceChip>(abstand).selected, isTrue);
    expect(find.text('1 × ALTO Montagehilfe Abstandshalter, VPE zu 4 Stück'), findsOneWidget);
    // erneutes Tippen auf die gewählte Art ändert nichts
    await tester.tap(abstand);
    await tester.pumpAndSettle();
    expect(s.aenderungen, [0]);
    await tester.tap(direkt);
    await tester.pumpAndSettle();
    expect(s.planung.aktuell.befestigungsart, Befestigungsart.verschraubt);
    expect(s.aenderungen, [0, 1]);
  });

  testWidgets('ohne Dielen oder ohne Berechnung ein Hinweis', (tester) async {
    await zeige(tester, berechne: _ohneDielen);
    expect(find.text(de.befestigungOhneDielen), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    await zeige(tester);
    expect(find.text(de.befestigungOhneDielen), findsOneWidget);
  });

  testWidgets('Texte auf Englisch', (tester) async {
    await zeige(tester, berechne: _glattkant, sprache: const Locale('en'));
    expect(find.text('Screwed directly'), findsOneWidget);
    expect(find.text('Screwed with spacers'), findsOneWidget);
    expect(find.text('Fastening points: 390'), findsOneWidget);
    expect(en.befestigungsartClips, 'With clips');
    expect(de.befestigungsartClips, 'Mit Clips');
    expect(de.befestigungsartAbstandshalter, 'Verschraubt mit Abstandshaltern');
  });

  test('Text je Art', () {
    expect(befestigungsartText(de, Befestigungsart.clips), 'Mit Clips');
    expect(
      befestigungsartText(de, Befestigungsart.verschraubt),
      'Direkt verschraubt',
    );
    expect(
      befestigungsartText(de, Befestigungsart.verschraubtMitAbstandshaltern),
      'Verschraubt mit Abstandshaltern',
    );
  });

  testWidgets('im Rahmen: Unterpunkt 2.6 im Schritt Terrassenbelag', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1440, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final zustand = RahmenZustand();
    await tester.pumpWidget(
      testApp(
        theme: planerThema(),
        home: PlanerRahmen(
          status: const Text('Status'),
          zustand: zustand,
          berechne: _glattkant,
        ),
      ),
    );
    await tester.pumpAndSettle();
    zustand.waehle(PlanerSchritt.terrassenbelag);
    await tester.pumpAndSettle();
    final abstand = find.byKey(
      const ValueKey('befestigungsart-verschraubtMitAbstandshaltern'),
    );
    await tester.scrollUntilVisible(
      abstand,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('bearbeitungsmenue')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('2.6 Befestigungsart'), findsOneWidget);
    await tester.tap(abstand);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(abstand).selected, isTrue);
    expect(zustand.unveraendert, isNot(contains(PlanerSchritt.terrassenbelag)));
  });
}
