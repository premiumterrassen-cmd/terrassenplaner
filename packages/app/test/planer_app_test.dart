import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/planer_app.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

void main() {
  testWidgets('zeigt den Projekttitel', (tester) async {
    await tester.pumpWidget(const PlanerApp());
    expect(find.text('Terrassenplaner – ALTO HOLZ'), findsOneWidget);
  });

  testWidgets('zeigt übergebene Projektdaten', (tester) async {
    const info = ProjektInfo(name: 'Test', firma: 'X');
    await tester.pumpWidget(const PlanerApp(info: info));
    expect(find.text('Test – X'), findsOneWidget);
  });
}
