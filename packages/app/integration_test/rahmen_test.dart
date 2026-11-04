import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:terrassenplaner_app/main.dart' as app;
import 'package:terrassenplaner_app/src/rahmen/planer_schritt.dart';

import '../test/hilfe.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('alle sieben Stationen sind erreichbar (M3-01)', (tester) async {
    app.main();
    await tester.pumpAndSettle();
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
    await tester.ensureVisible(
      find.byKey(const ValueKey('terrassenart-hochterrasse')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('terrassenart-hochterrasse')));
    await tester.pumpAndSettle();
    expect(find.text('Vorgabehöhe: 54,2 cm'), findsOneWidget);
    expect(find.text('3.6 ${de.unterkonstruktion7}'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('terrassenart-vorhandeneUk')),
    );
    await tester.pumpAndSettle();
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
  });
}
