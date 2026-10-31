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
  });
}
