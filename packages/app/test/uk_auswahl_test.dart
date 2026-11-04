import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_schritt.dart';
import 'package:terrassenplaner_app/src/rahmen/rahmen_zustand.dart';
import 'package:terrassenplaner_app/src/rahmen/steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/uk_auswahl.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

Artikel _uk(String nummer, int breite, int staerke, Serie serie) => Artikel(
  nummer: Artikelnummer(nummer),
  titel: 'Unterkonstruktionsholz Robinie $breite x $staerke mm',
  art: Artikelart.unterkonstruktion,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  abmessungen: Abmessungen(
    breite: Millimeter(breite),
    staerke: Millimeter(staerke),
    laengen: const [Millimeter(6000)],
  ),
  preisBrutto: const Cent(990),
  holzart: robinie,
  serie: serie,
);

final _premium = Ukauswahl('v1', [
  Belagangebot.jeLfm(_uk('10-10-031-R', 45, 60, premiumSelect)),
  Belagangebot.jeLfm(_uk('10-10-039-R', 45, 70, premiumSelect)),
]);

final _eco = Ukauswahl('v1', [
  Belagangebot.jeLfm(_uk('10-10-031-S', 40, 60, ecoSelect)),
]);

/// Wie der Server: zum PREMIUM-Belag (Vorgabe) die PREMIUM-UK, zum Belag
/// 10-10-143-S die ECO-UK.
Future<Ukauswahl> _server(Artikelnummer? belag) async =>
    belag == const Artikelnummer('10-10-143-S') ? _eco : _premium;

void main() {
  group('UkQuelle', () {
    test('lädt zum Belag und bei jedem Belagwechsel neu', () async {
      final planung = PlanungsSteuerung();
      final gefragt = <Artikelnummer?>[];
      final quelle = UkQuelle(
        lade: (belag) {
          gefragt.add(belag);
          return _server(belag);
        },
        planung: planung,
      );
      await pumpEventQueue();
      expect(quelle.auswahl, _premium);
      expect(quelle.fehler, isNull);
      planung.setze(planung.aktuell.mitVerlegeart(Verlegeart.halbverband));
      await pumpEventQueue();
      expect(gefragt, [null]);
      planung.setze(
        planung.aktuell.mitBelag(const Artikelnummer('10-10-143-S')),
      );
      await pumpEventQueue();
      expect(gefragt, [null, const Artikelnummer('10-10-143-S')]);
      expect(quelle.auswahl, _eco);
      quelle.dispose();
      planung
        ..setze(planung.aktuell.mitBelag(const Artikelnummer('x')))
        ..dispose();
      expect(gefragt, hasLength(2));
    });

    test('ältere Antworten und Antworten nach dispose werden verworfen; '
        'Fehler', () async {
      final planung = PlanungsSteuerung();
      addTearDown(planung.dispose);
      final antworten = <Completer<Ukauswahl>>[];
      final quelle = UkQuelle(
        lade: (_) {
          final c = Completer<Ukauswahl>();
          antworten.add(c);
          return c.future;
        },
        planung: planung,
      );
      planung.setze(
        planung.aktuell.mitBelag(const Artikelnummer('10-10-143-S')),
      );
      antworten[1].complete(_eco);
      await pumpEventQueue();
      antworten[0].complete(_premium);
      await pumpEventQueue();
      expect(quelle.auswahl, _eco);
      // ein späterer Fehler einer veralteten Anfrage zählt nicht
      planung.setze(planung.aktuell.mitBelag(const Artikelnummer('a')));
      planung.setze(planung.aktuell.mitBelag(const Artikelnummer('b')));
      antworten[2].completeError(StateError('alt'));
      await pumpEventQueue();
      expect(quelle.fehler, isNull);
      antworten[3].completeError(StateError('weg'));
      await pumpEventQueue();
      expect(quelle.fehler, isA<StateError>());
      var meldungen = 0;
      quelle.addListener(() => meldungen++);
      unawaited(quelle.ladeNeu());
      expect(quelle.fehler, isNull);
      expect(meldungen, 1);
      quelle.dispose();
      antworten[4].complete(_premium);
      await pumpEventQueue();
      expect(meldungen, 1);
    });
  });

  group('Unterkonstruktion auswählen (M6-03)', () {
    Future<
      ({PlanungsSteuerung planung, UkQuelle quelle, List<int> aenderungen})
    >
    zeige(
      WidgetTester tester, {
      UnterkonstruktionenLaden lade = _server,
      Locale sprache = const Locale('de'),
    }) async {
      final planung = PlanungsSteuerung();
      final quelle = UkQuelle(lade: lade, planung: planung);
      addTearDown(() {
        quelle.dispose();
        planung.dispose();
      });
      final aenderungen = <int>[];
      void geaendert() => aenderungen.add(aenderungen.length);
      await tester.pumpWidget(
        testApp(
          sprache: sprache,
          home: Scaffold(
            body: Column(
              children: [
                UkAnzeige(
                  quelle: quelle,
                  planung: planung,
                  onGeaendert: geaendert,
                ),
                UkLaengeWahl(
                  quelle: quelle,
                  planung: planung,
                  onGeaendert: geaendert,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (planung: planung, quelle: quelle, aenderungen: aenderungen);
    }

    testWidgets('Vorgabe ist die erste passende UK; Dialog wählt eine andere', (
      tester,
    ) async {
      final s = await zeige(tester);
      expect(
        find.text('Unterkonstruktionsholz Robinie 45 x 60 mm'),
        findsOneWidget,
      );
      expect(find.text('Maße: 6000 × 45 × 60 mm'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('uk-produktauswahl')));
      await tester.pumpAndSettle();
      expect(find.text(de.ukDialogTitel), findsOneWidget);
      expect(find.byKey(const ValueKey('belag-10-10-031-R')), findsOneWidget);
      expect(find.text(de.gewaehlt), findsOneWidget);
      expect(find.text(de.preisJeLfm('9,90 €')), findsNWidgets(2));
      // zurück ohne Wahl ändert nichts
      await tester.tap(find.byKey(const ValueKey('uk-zurueck')));
      await tester.pumpAndSettle();
      expect(s.aenderungen, isEmpty);
      await tester.tap(find.byKey(const ValueKey('uk-produktauswahl')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('belag-10-10-039-R')));
      await tester.pumpAndSettle();
      expect(
        s.planung.aktuell.unterkonstruktion,
        const Artikelnummer('10-10-039-R'),
      );
      expect(s.aenderungen, [0]);
      expect(
        find.text('Unterkonstruktionsholz Robinie 45 x 70 mm'),
        findsOneWidget,
      );
      s.planung.rueckgaengig();
      await tester.pumpAndSettle();
      expect(
        find.text('Unterkonstruktionsholz Robinie 45 x 60 mm'),
        findsOneWidget,
      );
      // anderer Belag: nur seine UK, die Wahl fällt auf dessen Vorgabe
      s.planung.setze(
        s.planung.aktuell
            .mitUnterkonstruktion(const Artikelnummer('10-10-039-R'))
            .mitBelag(const Artikelnummer('10-10-143-S')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Unterkonstruktionsholz Robinie 40 x 60 mm'),
        findsOneWidget,
      );
    });

    testWidgets('Länge: automatisch (Vorgabe) oder eine Lieferlänge der '
        'Serie', (tester) async {
      final s = await zeige(tester);
      ChoiceChip chip(String name) =>
          tester.widget(find.byKey(ValueKey('uk-laenge-$name')));
      expect(chip('automatisch').selected, isTrue);
      expect(find.text(de.automatisch), findsOneWidget);
      for (final mm in [4000, 5000, 6000]) {
        expect(chip('$mm').selected, isFalse);
      }
      expect(find.text('500 cm'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('uk-laenge-5000')));
      await tester.pumpAndSettle();
      expect(s.planung.aktuell.ukLaenge, const Millimeter(5000));
      expect(chip('5000').selected, isTrue);
      expect(chip('automatisch').selected, isFalse);
      // erneutes Tippen ändert nichts
      await tester.tap(find.byKey(const ValueKey('uk-laenge-5000')));
      await tester.pumpAndSettle();
      expect(s.aenderungen, [0]);
      await tester.tap(find.byKey(const ValueKey('uk-laenge-automatisch')));
      await tester.pumpAndSettle();
      expect(s.planung.aktuell.ukLaenge, isNull);
      await tester.tap(find.byKey(const ValueKey('uk-laenge-automatisch')));
      await tester.pumpAndSettle();
      expect(s.aenderungen, [0, 1]);
      // eine Länge, die die UK nicht liefert, gilt als automatisch
      s.planung.setze(s.planung.aktuell.mitUkLaenge(const Millimeter(7000)));
      await tester.pumpAndSettle();
      expect(chip('automatisch').selected, isTrue);
    });

    testWidgets('lädt, Fehler mit erneutem Versuch, keine passende UK', (
      tester,
    ) async {
      final antworten = <Completer<Ukauswahl>>[];
      await zeige(
        tester,
        lade: (_) {
          final c = Completer<Ukauswahl>();
          antworten.add(c);
          return c.future;
        },
      );
      expect(find.text(de.ukLaedt), findsOneWidget);
      expect(find.text(de.ukLaengeOhneUk), findsOneWidget);
      antworten.single.completeError(StateError('weg'));
      await tester.pumpAndSettle();
      expect(find.text(de.ukFehler), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('uk-neu-laden')));
      await tester.pump();
      expect(find.text(de.ukLaedt), findsOneWidget);
      antworten.last.complete(Ukauswahl('v1', const []));
      await tester.pumpAndSettle();
      expect(find.text(de.ukKeine), findsOneWidget);
      expect(find.text(de.ukLaengeOhneUk), findsOneWidget);
    });

    testWidgets('englische Texte', (tester) async {
      await zeige(tester, sprache: const Locale('en'));
      expect(find.text(en.automatisch), findsOneWidget);
      expect(find.text(en.produktauswahl), findsOneWidget);
    });
  });

  testWidgets('Menü: 3.3 und 3.4 mit der Quelle des Rahmens', (tester) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final zustand = RahmenZustand()..waehle(PlanerSchritt.unterkonstruktion);
    await tester.pumpWidget(
      testApp(
        home: PlanerRahmen(
          status: const SizedBox(),
          zustand: zustand,
          unterkonstruktionen: _server,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('uk-anzeige')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('uk-laenge-4000')));
    await tester.pumpAndSettle();
    expect(
      zustand.unveraendert,
      isNot(contains(PlanerSchritt.unterkonstruktion)),
    );
    zustand.vergissAenderungen();
    await tester.tap(find.byKey(const ValueKey('uk-produktauswahl')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('belag-10-10-039-R')));
    await tester.pumpAndSettle();
    expect(
      zustand.unveraendert,
      isNot(contains(PlanerSchritt.unterkonstruktion)),
    );
    // ohne Quelle keine Eingaben unter 3.3 und 3.4
    await tester.pumpWidget(
      testApp(
        home: PlanerRahmen(
          key: UniqueKey(),
          status: const SizedBox(),
          zustand: zustand,
        ),
      ),
    );
    expect(find.byKey(const ValueKey('uk-anzeige')), findsNothing);
  });
}
