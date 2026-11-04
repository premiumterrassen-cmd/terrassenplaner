import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/hilfe.dart';
import 'start.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Eingangsdialog: unbekannte Nummer laden und neu (M3-02, M9-05)',
    (tester) async {
      await starteApp(tester);
      expect(find.text(de.willkommenTitel), findsOneWidget);
      expect(find.text(de.weiterplanen), findsNothing);

      await tester.tap(find.byKey(const ValueKey('laden')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('nummer')),
        '2026-10-08-1511',
      );
      await tester.tap(find.byKey(const ValueKey('laden-bestaetigen')));
      // Der Konfigurationsdienst kennt die Nummer nicht (M9-05).
      for (
        var i = 0;
        i < 100 && find.text(de.konfigurationUnbekannt).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(find.text(de.konfigurationUnbekannt), findsOneWidget);
      await tester.tap(find.text(de.zurueck));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('neu')));
      await tester.pumpAndSettle();
      expect(find.text(de.willkommenTitel), findsNothing);
      expect(find.text('TERRASSENKONFIGURATOR'), findsOneWidget);
    },
  );
}
