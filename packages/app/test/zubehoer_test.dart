import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/design/planer_design.dart';
import 'package:terrassenplaner_app/src/rahmen/berechnung_steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_schritt.dart';
import 'package:terrassenplaner_app/src/rahmen/rahmen_zustand.dart';
import 'package:terrassenplaner_app/src/rahmen/steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/zubehoer.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

Artikel _artikel(String nummer, String titel, Zubehoergruppe gruppe) => Artikel(
  nummer: Artikelnummer(nummer),
  titel: titel,
  art: Artikelart.sonstiges,
  einheit: Verkaufseinheit(Mengeneinheit.stueck),
  zubehoergruppe: gruppe,
);

final _vlies = _artikel(
  '50-80-006',
  'Schutz-Vlies, 1,1m Breite',
  Zubehoergruppe.allgemein,
);
final _bit = _artikel(
  '50-80-002',
  'Bit TX20 für Clipschrauben',
  Zubehoergruppe.allgemein,
);
final _oel = _artikel(
  '568-250',
  'Holzschutz-Öl ROBINIE, 2,5 Liter',
  Zubehoergruppe.terrassenoel,
);

final _auswahl = Zubehoerauswahl.aus('v1', [_vlies, _bit, _oel]);

void main() {
  Future<PlanungsSteuerung> zeige(
    WidgetTester tester, {
    ZubehoerQuelle? quelle,
    List<int>? aenderungen,
  }) async {
    final planung = PlanungsSteuerung();
    addTearDown(() {
      quelle?.dispose();
      planung.dispose();
    });
    await tester.pumpWidget(
      testApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ZubehoerBereich(
              quelle: quelle,
              planung: planung,
              onGeaendert: () => aenderungen?.add(aenderungen.length),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return planung;
  }

  testWidgets('acht Gruppen, die erste offen, immer nur eine', (tester) async {
    await zeige(tester, quelle: ZubehoerQuelle(() async => _auswahl));
    for (final punkt in PlanerSchritt.zubehoer.nummerierteUnterpunkte(de)) {
      expect(find.text(punkt), findsOneWidget);
    }
    expect(find.text('6.1 Allgemein'), findsOneWidget);
    expect(find.text('6.8 Terrassenöl RIBOL'), findsOneWidget);
    expect(find.byKey(const ValueKey('zubehoertabelle-allgemein')), findsOne);
    expect(find.text(de.zubehoerBezeichnung), findsOneWidget);
    expect(find.text(de.zubehoerTatsaechlich), findsOneWidget);
    expect(find.text('Schutz-Vlies, 1,1m Breite'), findsOneWidget);
    expect(find.text('Bit TX20 für Clipschrauben'), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
    expect(find.byIcon(Icons.expand_more), findsNWidgets(7));
    // andere Gruppe öffnen: die erste schließt
    await tester.tap(find.byKey(const ValueKey('zubehoergruppe-terrassenoel')));
    await tester.pumpAndSettle();
    expect(find.text('Schutz-Vlies, 1,1m Breite'), findsNothing);
    expect(find.text('Holzschutz-Öl ROBINIE, 2,5 Liter'), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
    // offene Gruppe noch einmal: alle zu
    await tester.tap(find.byKey(const ValueKey('zubehoergruppe-terrassenoel')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.expand_less), findsNothing);
    expect(find.text(de.zubehoerTatsaechlich), findsNothing);
    // leere Gruppe (Rhombusleisten)
    await tester.tap(
      find.byKey(const ValueKey('zubehoergruppe-rhombusleisten')),
    );
    await tester.pumpAndSettle();
    expect(find.text(de.zubehoerKeine), findsOneWidget);
  });

  testWidgets('Tatsächlich eingeben, zurücknehmen, ungültig', (tester) async {
    final aenderungen = <int>[];
    final planung = await zeige(
      tester,
      quelle: ZubehoerQuelle(() async => _auswahl),
      aenderungen: aenderungen,
    );
    final feld = find.byKey(const ValueKey('zubehoermenge-50-80-006'));
    TextField textfeld() => tester.widget<TextField>(feld);
    expect(textfeld().decoration!.hintText, '0');
    await tester.enterText(feld, ' 3 ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(planung.aktuell.zubehoer, {const Artikelnummer('50-80-006'): 3});
    expect(textfeld().decoration!.hintText, '3');
    expect(textfeld().controller!.text, isEmpty);
    expect(aenderungen, [0]);
    // ungültig: Hinweis, nichts übernommen
    for (final falsch in ['-1', 'x', '100000', '1,5']) {
      await tester.enterText(feld, falsch);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text(de.zubehoerMengeUngueltig(99999)), findsOneWidget);
      expect(planung.aktuell.zubehoer.values, [3]);
    }
    expect(aenderungen, [0]);
    // Grenzen gültig, Hinweis verschwindet
    await tester.enterText(feld, '99999');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text(de.zubehoerMengeUngueltig(99999)), findsNothing);
    expect(planung.aktuell.zubehoer.values, [99999]);
    await tester.enterText(feld, '0');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(planung.aktuell.zubehoer.values, [0]);
    // leer: Eingabe zurücknehmen
    await tester.enterText(feld, '  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(planung.aktuell.zubehoer, isEmpty);
    expect(aenderungen, [0, 1, 2, 3]);
    // Rückgängig zeigt den alten Wert
    planung.rueckgaengig();
    await tester.pumpAndSettle();
    expect(textfeld().decoration!.hintText, '0');
  });

  testWidgets('laden, Fehler mit erneutem Versuch, ohne Quelle', (
    tester,
  ) async {
    final antwort = Completer<Zubehoerauswahl>();
    var versuche = 0;
    await zeige(
      tester,
      quelle: ZubehoerQuelle(() {
        versuche++;
        return versuche == 1 ? Future.error(StateError('weg')) : antwort.future;
      }),
    );
    expect(find.text(de.zubehoerFehler), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('zubehoer-neu-laden')));
    await tester.pump();
    expect(find.text(de.zubehoerLaedt), findsOneWidget);
    antwort.complete(_auswahl);
    await tester.pumpAndSettle();
    expect(find.text('Schutz-Vlies, 1,1m Breite'), findsOneWidget);
    expect(versuche, 2);
  });

  testWidgets('ohne Quelle: Gruppen ohne Artikel', (tester) async {
    await zeige(tester);
    expect(find.text('6.1 Allgemein'), findsOneWidget);
    expect(find.text(de.zubehoerKeine), findsOneWidget);
  });

  testWidgets('englisch', (tester) async {
    final planung = PlanungsSteuerung();
    final quelle = ZubehoerQuelle(() async => _auswahl);
    addTearDown(() {
      quelle.dispose();
      planung.dispose();
    });
    await tester.pumpWidget(
      testApp(
        sprache: const Locale('en'),
        home: Scaffold(
          body: ZubehoerBereich(
            quelle: quelle,
            planung: planung,
            onGeaendert: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('6.1 General'), findsOneWidget);
    expect(find.text('Actual'), findsOneWidget);
  });

  testWidgets('im Rahmen: Schritt 6 zeigt das Zubehör vom Server', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1440, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final zustand = RahmenZustand();
    final planung = PlanungsSteuerung();
    addTearDown(planung.dispose);
    await tester.pumpWidget(
      testApp(
        theme: planerThema(),
        home: PlanerRahmen(
          status: const Text('Status'),
          zustand: zustand,
          planung: planung,
          zubehoer: () async => _auswahl,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('zubehoer')), findsNothing);
    zustand.waehle(PlanerSchritt.zubehoer);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('zubehoer')), findsOneWidget);
    expect(find.text('Schutz-Vlies, 1,1m Breite'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('zubehoermenge-50-80-002')),
      '2',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(planung.aktuell.zubehoer, {const Artikelnummer('50-80-002'): 2});
    expect(zustand.unveraendert, isNot(contains(PlanerSchritt.zubehoer)));
    // anderer Schritt: die Unterpunkte als Text wie bisher
    zustand.waehle(PlanerSchritt.treppen);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('zubehoer')), findsNothing);
  });

  testWidgets('berechnete Mengen (M8-02): Start mit dem Wert des Servers, '
      'eine abweichende Eingabe zeigt ihn darunter', (tester) async {
    final planung = PlanungsSteuerung();
    final quelle = ZubehoerQuelle(() async => _auswahl);
    // wie der Server: berechnet 4 × Öl, „Tatsächlich“ aus den Eingaben
    final berechnung = BerechnungsSteuerung(
      planung: planung,
      berechne: (p) async => Berechnung(
        umriss: const [],
        flaeche: 1,
        zubehoer: zubehoerpositionen({
          const Artikelnummer('568-250'): 4,
        }, p.aktuell.zubehoer),
      ),
    );
    addTearDown(() {
      berechnung.dispose();
      quelle.dispose();
      planung.dispose();
    });
    await tester.pumpWidget(
      testApp(
        home: Scaffold(
          body: ZubehoerBereich(
            quelle: quelle,
            berechnung: berechnung,
            planung: planung,
            onGeaendert: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('zubehoergruppe-terrassenoel')));
    await tester.pumpAndSettle();
    final feld = find.byKey(const ValueKey('zubehoermenge-568-250'));
    expect(tester.widget<TextField>(feld).decoration!.hintText, '4');
    final hinweis = find.byKey(const ValueKey('zubehoerberechnet-568-250'));
    expect(hinweis, findsNothing);
    await tester.enterText(feld, '1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(feld).decoration!.hintText, '1');
    expect(find.text(de.zubehoerBerechnet(4)), findsOneWidget);
    await tester.enterText(feld, '4');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(hinweis, findsNothing);
    await tester.enterText(feld, '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(planung.aktuell.zubehoer, isEmpty);
    expect(tester.widget<TextField>(feld).decoration!.hintText, '4');
  });
}
