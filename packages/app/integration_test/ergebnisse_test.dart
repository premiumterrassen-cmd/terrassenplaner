import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/hilfe.dart';
import 'start.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Material- und Stückliste vom Server (M9-03, M9-04)', (
    tester,
  ) async {
    await starteApp(tester);
    await tester.tap(find.byKey(const ValueKey('neu')));
    await tester.pumpAndSettle();
    // erst der Hinweis auf unveränderte Standardwerte (M3-05)
    await tester.tap(find.byKey(const ValueKey('materialliste-knopf')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('standardwert-fortfahren')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('materialliste-dialog')), findsOneWidget);
    // Der Smoke-Server läuft ohne Artikeldatei: nichts verlegt, Liste leer
    await warteAuf(tester, find.text(de.materiallisteLeer));
    // M9-04: umschalten auf die Stückliste, ebenfalls leer
    await tester.tap(find.byKey(const ValueKey('zur-stueckliste')));
    await tester.pumpAndSettle();
    expect(find.text(de.stuecklisteLeer), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('materialliste-schliessen')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('materialliste-dialog')), findsNothing);
  });
}
