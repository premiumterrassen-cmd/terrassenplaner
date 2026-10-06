import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:terrassenplaner_app/main.dart' as app;
import 'package:web/web.dart' as web;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Ladebildschirm verschwindet, sobald die App zeichnet', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle();
    // fertig() entfernt das Ladebild nach zwei Bildern (+ Ausblenden).
    for (
      var i = 0;
      i < 50 && web.document.getElementById('ladebild') != null;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(web.document.getElementById('ladebild'), isNull);
    expect(find.text('Terrassenplaner – ALTO HOLZ'), findsOneWidget);
  });
}
