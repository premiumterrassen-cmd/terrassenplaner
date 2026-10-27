import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:terrassenplaner_app/main.dart' as app;

/// Ende-zu-Ende (M4-02): Maße in der App → Planungsstand als FlatBuffer über
/// den Router → Planungsdienst rechnet → Fläche zurück in der App.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> warteAuf(WidgetTester tester, String text) async {
    for (var i = 0; i < 100 && find.text(text).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(find.text(text), findsOneWidget);
  }

  testWidgets('Rechteckmaße und L-Form: Fläche vom Server', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('neu')));
    await tester.pumpAndSettle();
    await warteAuf(tester, 'Fläche: 14,83 m²');
    await tester.enterText(find.byKey(const ValueKey('mass-0')), '540');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await warteAuf(tester, 'Fläche: 16,69 m²');
    // M4-03: L-Form mit Vorgabemaßen, Form 1 im Transportformat
    await tester.tap(find.byKey(const ValueKey('form-lForm')));
    await warteAuf(tester, 'Fläche: 14,58 m²');
    // M4-06: O-Form mit Ausschnitt A1 (Ausschnitte im Transportformat)
    await tester.tap(find.byKey(const ValueKey('form-oForm')));
    await warteAuf(tester, 'Fläche: 19,44 m²');
    // M4-07: Kreis Ø 360 cm, exakt π·r²
    await tester.tap(find.byKey(const ValueKey('form-kreis')));
    await warteAuf(tester, 'Fläche: 10,18 m²');
  });
}
