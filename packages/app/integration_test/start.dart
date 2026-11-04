import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/main.dart' as app;

/// Wartet, bis [finder] etwas findet (Antworten des Servers kommen
/// asynchron, `pumpAndSettle` wartet nicht auf das Netz).
Future<void> warteAuf(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  expect(finder, findsOneWidget);
}

/// Startet die App und wartet auf den Eingangsdialog – er erscheint erst,
/// wenn der Server nach einem Entwurf gefragt wurde (M9-05).
Future<void> starteApp(WidgetTester tester) async {
  app.main();
  await tester.pumpAndSettle();
  await warteAuf(tester, find.byKey(const ValueKey('neu')));
  await tester.pumpAndSettle();
}
