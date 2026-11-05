import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_schritt.dart';

import '../test/hilfe.dart';
import 'start.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('alle sieben Stationen sind erreichbar (M3-01)', (tester) async {
    await starteApp(tester);
    await tester.tap(find.byKey(const ValueKey('neu')));
    await tester.pumpAndSettle();
    for (final schritt in PlanerSchritt.values) {
      await tester.tap(find.byKey(ValueKey('station-${schritt.name}')));
      await tester.pumpAndSettle();
      expect(
        find.text(schritt.nummerierteUnterpunkte(de).first),
        findsOneWidget,
        reason: schritt.name,
      );
    }
    // M5-01: Belagauswahl vom Artikeldienst; der Smoke-Server läuft ohne
    // Artikeldatei, also ohne Beläge.
    await tester.tap(find.byKey(const ValueKey('station-terrassenbelag')));
    final keine = find.text(de.belagKeine);
    for (var i = 0; i < 100 && keine.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(keine, findsOneWidget);
    expect(find.text(de.dielenlaengeNichtWaehlbar), findsOneWidget);
    final fortschritt = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(fortschritt.value, 1);
    // M5-04: Verlegeart, M5-03 „kurze Stücke verbinden“ und M5-05
    // Verlegerichtung brauchen keine Beläge.
    final halb = find.byKey(const ValueKey('verlegeart-halbverband'));
    await tester.ensureVisible(halb);
    await tester.pumpAndSettle();
    await tester.tap(halb);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(halb).selected, isTrue);
    final ja = find.byKey(const ValueKey('kurze-stuecke-ja'));
    await tester.ensureVisible(ja);
    await tester.pumpAndSettle();
    await tester.tap(ja);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(ja).selected, isTrue);
    // M5-05: Verlegerichtung samt Feld „Winkel“
    final individuell = find.byKey(
      const ValueKey('verlegerichtung-individuell'),
    );
    await tester.ensureVisible(individuell);
    await tester.pumpAndSettle();
    await tester.tap(individuell);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(individuell).selected, isTrue);
    expect(find.byKey(const ValueKey('verlegewinkel')), findsOneWidget);
    // M5-07: Ausgangspunkt C wählen, Rückgängig zurück auf A; verschieben
    // lässt sich erst mit verlegten Dielen (der Smoke-Server hat keine)
    final c = find.byKey(const ValueKey('ausgangsecke-2'));
    await tester.ensureVisible(c);
    await tester.pumpAndSettle();
    await tester.tap(c);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(c).selected, isTrue);
    expect(find.text(de.verschiebungOhneDielen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rueckgaengig')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('ausgangsecke-0')))
          .selected,
      isTrue,
    );
    // M5-09: Befestigungsart unter 2.6; ohne verlegte Dielen nur der Hinweis
    final befestigung = find.byKey(const ValueKey('befestigung'));
    await tester.scrollUntilVisible(
      befestigung,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('bearbeitungsmenue')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('2.6 ${de.terrassenbelag6}'), findsOneWidget);
    expect(find.text(de.befestigungOhneDielen), findsOneWidget);
    // M6-01: Art der Terrasse unter 3.1; die Hochterrasse lässt 3.6 „Art
    // der Terrassennutzung“ entfallen, vorhandene UK fragt die Spannweite
    await tester.tap(find.byKey(const ValueKey('station-unterkonstruktion')));
    await tester.pumpAndSettle();
    expect(find.text('3.6 ${de.unterkonstruktion6}'), findsOneWidget);
    await _imMenue(
      tester,
      find.byKey(const ValueKey('terrassenart-hochterrasse')),
    );
    await tester.tap(find.byKey(const ValueKey('terrassenart-hochterrasse')));
    await tester.pumpAndSettle();
    expect(find.text('Vorgabehöhe: 54,2 cm'), findsOneWidget);
    expect(find.text('3.6 ${de.unterkonstruktion7}'), findsOneWidget);
    await _imMenue(
      tester,
      find.byKey(const ValueKey('terrassenart-vorhandeneUk')),
    );
    await tester.tap(find.byKey(const ValueKey('terrassenart-vorhandeneUk')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('spannweite')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rueckgaengig')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rueckgaengig')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('terrassenart-normal')))
          .selected,
      isTrue,
    );
    expect(find.text('3.6 ${de.unterkonstruktion6}'), findsOneWidget);
    // M6-02: Höhenpunkte mit Gefälle, Höhe an A eingeben; ohne Artikel
    // prüft der Smoke-Server nichts, also keine Aufbauhöhe
    final mit = find.byKey(const ValueKey('gefaelle-mit'));
    await _imMenue(tester, mit);
    await tester.tap(mit);
    await tester.pumpAndSettle();
    final a = find.descendant(
      of: find.byKey(const ValueKey('hoehe-0')),
      matching: find.byType(TextField),
    );
    await _imMenue(tester, a);
    await tester.enterText(a, '15');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(a).decoration!.hintText, '15');
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const ValueKey('hoehe-2')),
              matching: find.byType(TextField),
            ),
          )
          .decoration!
          .hintText,
      '8,6',
    );
    expect(find.textContaining('Aufbauhöhe'), findsNothing);
    // M6-03: UK-Auswahl und UK-Länge vom Artikeldienst; der Smoke-Server
    // hat keine Artikeldatei, also keine passende UK
    final keineUk = find.text(de.ukKeine);
    await _imMenue(tester, keineUk);
    expect(keineUk, findsOneWidget);
    expect(find.text(de.ukLaengeOhneUk), findsOneWidget);
    // M6-04: Untergrund unter 3.5, nur Information; Rückgängig wie bei den
    // anderen Eingaben
    await _waehle(tester, 'untergrund-beton');
    expect(await _gewaehlt(tester, 'untergrund-beton'), isTrue);
    expect(find.text(de.untergrundHinweis), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rueckgaengig')));
    await tester.pumpAndSettle();
    expect(await _gewaehlt(tester, 'untergrund-schotter'), isTrue);
    // M6-05: Art der Terrassennutzung unter 3.6; schwimmend mit Warnung
    // zur Verwindung, Rahmen ohne – Rückgängig stellt sie wieder her
    await _imMenue(tester, find.text(de.nutzungsartVerwindung));
    await _waehle(tester, 'nutzungsart-rahmen');
    expect(await _gewaehlt(tester, 'nutzungsart-rahmen'), isTrue);
    expect(find.text(de.nutzungsartVerwindung), findsNothing);
    await tester.tap(find.byKey(const ValueKey('rueckgaengig')));
    await tester.pumpAndSettle();
    expect(find.text(de.nutzungsartVerwindung), findsOneWidget);
    // M6-06: zusätzliche Querstreben unter 3.7 mit fester Anzahl der
    // Quertraversen; Rückgängig nimmt beides zurück
    await _waehle(tester, 'querstreben-ja');
    expect(find.text(de.querstrebenAbstand), findsOneWidget);
    final anzahl = find.descendant(
      of: find.byKey(const ValueKey('querstreben-anzahl')),
      matching: find.byType(TextField),
    );
    await _imMenue(tester, anzahl);
    await tester.enterText(anzahl, '4');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(anzahl).decoration!.hintText, '4');
    expect(await _gewaehlt(tester, 'querstreben-automatisch'), isFalse);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const ValueKey('rueckgaengig')));
      await tester.pumpAndSettle();
    }
    expect(await _gewaehlt(tester, 'querstreben-nein'), isTrue);
    // M6-07: private oder gewerbliche Nutzung unter 3.8; ohne Artikeldatei
    // kennt der Smoke-Server keine Stellfüße
    await _waehle(tester, 'nutzung-gewerblich');
    expect(await _gewaehlt(tester, 'nutzung-gewerblich'), isTrue);
    expect(find.text(de.stellfuesseKeine), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rueckgaengig')));
    await tester.pumpAndSettle();
    expect(await _gewaehlt(tester, 'nutzung-privat'), isTrue);
    // M6-08: Auflagen unter 3.9; ohne Artikeldatei keine Auflager mit
    // Höhenangaben, die Wahl ist ein Schritt für Rückgängig
    await _waehle(tester, 'auflagen-stelzfuesse');
    expect(await _gewaehlt(tester, 'auflagen-stelzfuesse'), isTrue);
    final ohneAuflager = find.text(de.auflagerKeine);
    await _imMenue(tester, ohneAuflager);
    expect(ohneAuflager, findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rueckgaengig')));
    await tester.pumpAndSettle();
    expect(await _gewaehlt(tester, 'auflagen-stelzfuesseUndPads'), isTrue);
    // M6-09: maximale Feldbreite unter 3.10; ohne Artikeldatei kein Belag
    // aus Holz, also nur der Hinweis
    final feldbreite = find.text(de.feldbreiteOhneBelag);
    await _imMenue(tester, feldbreite);
    expect(feldbreite, findsOneWidget);
    expect(find.text(de.feldbreiteHinweis), findsOneWidget);
    // M6-10: das Holzvolumen steht in den Kennzahlen; ohne Belag und UK
    // gibt es noch keins
    expect(find.text(de.volumen('– m³')), findsOneWidget);
  });
}

/// Zeigt [finder] im Bearbeitungsmenü: Die Liste baut nur die sichtbaren
/// Unterpunkte, deshalb erst nach oben und dann abwärts bis zum Ziel
/// scrollen – unabhängig von der Fenstergröße des Browsers.
Future<void> _imMenue(WidgetTester tester, Finder finder) async {
  final liste = find
      .descendant(
        of: find.descendant(
          of: find.byKey(const ValueKey('bearbeitungsmenue')),
          matching: find.byType(ListView),
        ),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.drag(liste, const Offset(0, 100000));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(finder, 200, scrollable: liste);
  await tester.pumpAndSettle();
}

/// Tippt den Auswahl-Chip [schluessel] im Bearbeitungsmenü an.
Future<void> _waehle(WidgetTester tester, String schluessel) async {
  final chip = find.byKey(ValueKey(schluessel));
  await _imMenue(tester, chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

/// Ob der Auswahl-Chip [schluessel] gewählt ist; scrollt vorher zu ihm,
/// weil das Menü nur die sichtbaren Unterpunkte baut (in kleinen Fenstern
/// der Build-Chain z. B. nach Rückgängig).
Future<bool> _gewaehlt(WidgetTester tester, String schluessel) async {
  final chip = find.byKey(ValueKey(schluessel));
  await _imMenue(tester, chip);
  return tester.widget<ChoiceChip>(chip).selected;
}
