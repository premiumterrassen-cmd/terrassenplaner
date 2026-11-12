import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/rahmen/ansichtsoptionen.dart';
import 'package:terrassenplaner_app/src/rahmen/berechnung_steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_schritt.dart';
import 'package:terrassenplaner_app/src/rahmen/rahmen_zustand.dart';
import 'package:terrassenplaner_app/src/rahmen/steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/treppen.dart';
import 'package:terrassenplaner_app/src/rahmen/zeichnung.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

const _mm = Millimeter.new;

void main() {
  Future<({PlanungsSteuerung planung, List<int> aenderungen})> zeige(
    WidgetTester tester, {
    Planungsstand stand = Planungsstand.start,
    List<Anschlussmeldung> meldungen = const [],
    Locale sprache = const Locale('de'),
  }) async {
    tester.view
      ..physicalSize = const Size(800, 4000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final planung = PlanungsSteuerung()..setze(stand);
    final berechnung = BerechnungsSteuerung(
      planung: planung,
      berechne: (p) async => Berechnung(
        umriss: const [],
        flaeche: 0,
        anschluss: Anschlussergebnis(
          meldungen: meldungen,
          treppen: treppenbilder(p.aktuell),
        ),
      ),
    );
    addTearDown(() {
      berechnung.dispose();
      planung.dispose();
    });
    final aenderungen = <int>[];
    await tester.pumpWidget(
      testApp(
        sprache: sprache,
        home: Scaffold(
          body: SingleChildScrollView(
            child: TreppenWahl(
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

  Future<void> tippe(WidgetTester tester, String schluessel) async {
    await tester.tap(find.byKey(ValueKey(schluessel)));
    await tester.pumpAndSettle();
  }

  Future<void> gib(WidgetTester tester, String schluessel, String text) async {
    final feld = find.descendant(
      of: find.byKey(ValueKey(schluessel)),
      matching: find.byType(TextField),
    );
    await tester.enterText(feld, text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  Treppe treppe(PlanungsSteuerung p) => p.aktuell.treppen.single;

  testWidgets('Treppe hinzufügen: Vorgaben, Maße vom Server, Start nur an '
      'freien Seiten', (tester) async {
    final s = await zeige(
      tester,
      stand: Planungsstand.start
          .mitAngrenzend(0, an: true)
          .mitRinne(1, Rinnenlage.gesamteSeite),
    );
    expect(find.text(de.treppenFrage), findsOneWidget);
    await tippe(tester, 'treppe-hinzufuegen');
    expect(treppe(s.planung).seite, 2);
    expect(find.text(de.treppeName(1)), findsOneWidget);
    expect(find.text(de.treppeMasse('100', '54', '31,2')), findsOneWidget);
    // Prüfliste (Planungskern v7 Regel 9.5.5): Schrittmaß 58,2 cm
    expect(find.text(de.treppeMeldungSchrittmass), findsOneWidget);
    expect(find.byKey(const ValueKey('treppe-0-seite-0')), findsNothing);
    expect(find.byKey(const ValueKey('treppe-0-seite-1')), findsNothing);
    await tippe(tester, 'treppe-0-seite-3');
    expect(treppe(s.planung).seite, 3);
    // die gewählte Seite noch einmal: bleibt
    await tippe(tester, 'treppe-0-seite-3');
    expect(treppe(s.planung).seite, 3);
    await gib(tester, 'treppe-0-abstand', '20');
    expect(treppe(s.planung).abstand, _mm(200));
    await gib(tester, 'treppe-0-breite', '120');
    expect(treppe(s.planung).breite, _mm(1200));
    await gib(tester, 'treppe-0-breite', '5');
    expect(find.text(de.treppeUngueltig), findsOneWidget);
    await tippe(tester, 'treppe-0-bau-${Treppenbau.fundament}');
    expect(treppe(s.planung).bau, Treppenbau.fundament);
    await tippe(tester, 'treppe-0-bau-${Treppenbau.fundament}');
    expect(s.aenderungen, hasLength(5));
  });

  testWidgets('Stufen: Anzahl, gemeinsame und individuelle Maße', (
    tester,
  ) async {
    final s = await zeige(tester, stand: Planungsstand.start.mitNeuerTreppe());
    await tippe(tester, 'treppe-0-mehr');
    expect(treppe(s.planung).anzahl, 3);
    expect(find.text('3'), findsOneWidget);
    await tippe(tester, 'treppe-0-weniger');
    await tippe(tester, 'treppe-0-weniger');
    expect(treppe(s.planung).anzahl, 1);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('treppe-0-weniger')))
          .onPressed,
      isNull,
    );
    await gib(tester, 'treppe-0-stufe-tiefe', '30');
    await gib(tester, 'treppe-0-stufe-hoehe', '17');
    expect(treppe(s.planung).stufe, (tiefe: _mm(300), hoehe: _mm(170)));
    await tippe(tester, 'treppe-0-individuell-true');
    expect(treppe(s.planung).individuell, isTrue);
    expect(find.text(de.treppeStufe(1)), findsOneWidget);
    await gib(tester, 'treppe-0-stufe-0-hoehe', '20');
    await gib(tester, 'treppe-0-stufe-0-tiefe', '25');
    expect(treppe(s.planung).stufenmasse.single, (
      tiefe: _mm(250),
      hoehe: _mm(200),
    ));
    s.planung.setze(
      s.planung.aktuell.mitTreppe(0, treppe(s.planung).mit(anzahl: 20)),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('treppe-0-mehr')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('Fächertreppe: Podest statt Breite; entfernen; Hinweis', (
    tester,
  ) async {
    final s = await zeige(
      tester,
      stand: Planungsstand.start.mitNeuerTreppe(),
      meldungen: const [Anschlussmeldung.treppeNichtFrei],
      sprache: const Locale('en'),
    );
    expect(find.text(en.meldungTreppeNichtFrei), findsOneWidget);
    expect(find.byKey(const ValueKey('treppe-0-podest-tiefe')), findsNothing);
    await tippe(tester, 'treppe-0-art-${Treppenart.zweiteilig}');
    expect(treppe(s.planung).art, Treppenart.zweiteilig);
    expect(find.byKey(const ValueKey('treppe-0-breite')), findsNothing);
    expect(find.text(en.treppeMasse('104', '108', '46.8')), findsOneWidget);
    await gib(tester, 'treppe-0-podest-tiefe', '60');
    await gib(tester, 'treppe-0-podest-breite', '70');
    await gib(tester, 'treppe-0-podest-hoehe', '18');
    expect(treppe(s.planung).podest, (
      tiefe: _mm(600),
      breite: _mm(700),
      hoehe: _mm(180),
    ));
    await tippe(tester, 'treppe-0-entfernen');
    expect(s.planung.aktuell.treppen, isEmpty);
  });

  testWidgets('Prüfliste der Treppe: alle Hinweise in beiden Sprachen', (
    tester,
  ) async {
    final stand = Planungsstand.start.mitNeuerTreppe().mitTreppe(
      0,
      const Treppe(
        seite: 2,
        abstand: Millimeter(4500),
        breite: Millimeter(400),
        stufe: (tiefe: Millimeter(400), hoehe: Millimeter(200)),
      ),
    );
    await zeige(tester, stand: stand);
    for (final text in [
      de.treppeMeldungSteigung,
      de.treppeMeldungSchrittmass,
      de.treppeMeldungZuSchmal,
      de.treppeMeldungUeberSeite,
    ]) {
      expect(find.text(text), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('treppe-0-ueberSeite')), findsOneWidget);
    await zeige(tester, stand: stand, sprache: const Locale('en'));
    expect(find.textContaining('Checklist'), findsNWidgets(4));
  });

  testWidgets('Kreis: keine Seiten', (tester) async {
    await zeige(
      tester,
      stand: Planungsstand.start.mitForm(Terrassenform.kreis),
    );
    expect(find.byKey(const ValueKey('treppen-leer')), findsOneWidget);
    expect(find.byKey(const ValueKey('treppe-hinzufuegen')), findsNothing);
  });

  testWidgets('ohne Berechnung keine Maße; im Bearbeitungsmenü unter 5.1', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1440, 2000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final planung = PlanungsSteuerung()
      ..setze(Planungsstand.start.mitNeuerTreppe());
    addTearDown(planung.dispose);
    final zustand = RahmenZustand()..waehle(PlanerSchritt.treppen);
    await tester.pumpWidget(
      testApp(
        home: PlanerRahmen(
          status: const SizedBox(),
          zustand: zustand,
          planung: planung,
        ),
      ),
    );
    expect(find.byType(TreppenWahl), findsOneWidget);
    expect(find.byKey(const ValueKey('treppe-0-masse')), findsNothing);
    await tester.ensureVisible(
      find.byKey(const ValueKey('treppe-hinzufuegen')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('treppe-hinzufuegen')));
    await tester.pump();
    expect(planung.aktuell.treppen, hasLength(2));
    expect(zustand.unveraendert, isNot(contains(PlanerSchritt.treppen)));
  });

  testWidgets('Treppen vom Server in der Zeichnung', (tester) async {
    final planung = PlanungsSteuerung();
    final b = BerechnungsSteuerung(
      planung: planung,
      berechne: (_) async => Berechnung(
        umriss: const [],
        flaeche: 0,
        anschluss: Anschlussergebnis(
          treppen: treppenbilder(Planungsstand.start.mitNeuerTreppe()),
        ),
      ),
    );
    addTearDown(() {
      b.dispose();
      planung.dispose();
    });
    await tester.pump();
    expect(b.zeichnung.treppen, hasLength(2));
    expect(b.zeichnung.treppen.first.first, Offset.zero);
    final o = AnsichtsOptionen();
    final maler = ZeichnungsMaler(
      zeichnung: b.zeichnung,
      optionen: o,
      ansicht: AnsichtSteuerung(),
      sprache: de,
    );
    expect(maler.treppenpfade(), hasLength(2));
    final aufnahme = PictureRecorder();
    maler.paint(Canvas(aufnahme), const Size(800, 600));
    aufnahme.endRecording();
    o.setzeEbenen({Ebene.unterkonstruktion});
    expect(maler.treppenpfade(), isEmpty);
    expect(() => b.zeichnung.treppen.add(const []), throwsUnsupportedError);
  });
}
