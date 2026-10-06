import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/planer_app.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

void main() {
  testWidgets('zeigt den Projekttitel', (tester) async {
    await tester.pumpWidget(PlanerApp(hallo: () async => 'x'));
    expect(find.text('Terrassenplaner – ALTO HOLZ'), findsOneWidget);
  });

  testWidgets('zeigt übergebene Projektdaten', (tester) async {
    const info = ProjektInfo(name: 'Test', firma: 'X');
    await tester.pumpWidget(PlanerApp(hallo: () async => 'x', info: info));
    expect(find.text('Test – X'), findsOneWidget);
  });

  testWidgets('Status: erst „Verbinde …“, dann die Antwort des Servers', (
    tester,
  ) async {
    final antwort = Completer<String>();
    await tester.pumpWidget(PlanerApp(hallo: () => antwort.future));
    expect(find.text(ServerStatus.verbinde), findsOneWidget);
    antwort.complete('Verbunden mit Test');
    await tester.pump();
    expect(find.text('Verbunden mit Test'), findsOneWidget);
  });

  testWidgets('Status bei Fehler: keine Verbindung', (tester) async {
    await tester.pumpWidget(
      PlanerApp(hallo: () => Future<String>.error(StateError('weg'))),
    );
    await tester.pump();
    expect(find.text(ServerStatus.keineVerbindung), findsOneWidget);
  });

  test('Texte des Status', () {
    expect(ServerStatus.verbinde, 'Verbinde mit dem Server …');
    expect(ServerStatus.keineVerbindung, 'Keine Verbindung zum Server');
  });
}
