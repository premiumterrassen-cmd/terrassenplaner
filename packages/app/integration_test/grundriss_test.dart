import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('Formen und Freiform: Fläche vom Server', (tester) async {
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
    // M4-08: Freiform – drei Punkte antippen, x schließt
    await tester.tap(find.byKey(const ValueKey('form-freiform')));
    await warteAuf(tester, 'Fläche: – m²');
    final ursprung = tester.getTopLeft(
      find.byKey(const ValueKey('freiform-zeichnen')),
    );
    for (final p in const [
      Offset(100, 100),
      Offset(400, 100),
      Offset(400, 300),
    ]) {
      await tester.tapAt(ursprung + p);
      await tester.pumpAndSettle();
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
    await warteAuf(tester, 'Fläche: 3,00 m²');
    // M4-09: Ecke B um 1 m nach rechts ziehen → Dreieck 4 × 2 m / 2
    await tester.drag(
      find.byKey(const ValueKey('ecke-1')),
      const Offset(100, 0),
    );
    await warteAuf(tester, 'Fläche: 4,00 m²');
    // M4-11: Rechteck, Ecke A um 70,7 cm abrunden (Rundungen im Transport)
    await tester.tap(find.byKey(const ValueKey('form-rechteck')));
    await warteAuf(tester, 'Fläche: 14,83 m²');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('rundungen-hinzufuegen')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('bearbeitungsmenue')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const ValueKey('rundungen-hinzufuegen')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('rundung-ecke-0')),
      const Offset(50, 50),
    );
    await warteAuf(tester, 'Fläche: 14,72 m²');
    // M4-12: weitere Fläche A1 – Ausschnitte mit Form im Transport, die
    // Fläche bleibt wie im alten Planer die Außenfläche
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('weitere-flaeche')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('bearbeitungsmenue')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const ValueKey('weitere-flaeche')));
    await tester.pumpAndSettle();
    expect(find.text('Ausschnitt A1'), findsOneWidget);
    await warteAuf(tester, 'Fläche: 14,72 m²');
  });
}
