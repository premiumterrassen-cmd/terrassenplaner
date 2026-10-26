import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:terrassenplaner_app/main.dart' as app;
import 'package:terrassenplaner_app/src/start/eingangsdialog.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Eingangsdialog: laden (noch ohne Server) und neu (M3-02)', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle();
    expect(find.text(Eingangsdialog.titel), findsOneWidget);
    expect(find.text(Eingangsdialog.weiterKnopf), findsNothing);

    await tester.tap(find.byKey(const ValueKey('laden')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('nummer')),
      '2026-10-08-1511',
    );
    await tester.tap(find.byKey(const ValueKey('laden-bestaetigen')));
    await tester.pumpAndSettle();
    // Laden über den Server folgt mit M9-05.
    expect(find.text(LadenDialog.ladeFehler), findsOneWidget);
    await tester.tap(find.text(LadenDialog.zurueckKnopf));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('neu')));
    await tester.pumpAndSettle();
    expect(find.text(Eingangsdialog.titel), findsNothing);
    expect(find.text('TERRASSENKONFIGURATOR'), findsOneWidget);
  });
}
