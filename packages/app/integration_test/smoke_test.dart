import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:terrassenplaner_app/main.dart' as app;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App startet, verbindet sich per WAMP und zeigt die Antwort', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle();
    expect(find.text('Terrassenplaner – ALTO HOLZ'), findsOneWidget);
    // Ende-zu-Ende (M0-12): Web-App → Router → Hallo-Dienst
    for (
      var i = 0;
      i < 100 && find.text(begruessung()).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(
      find.text('Verbunden mit Terrassenplaner – ALTO HOLZ'),
      findsOneWidget,
    );
  });
}
