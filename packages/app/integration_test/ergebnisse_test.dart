import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/hilfe.dart';
import 'start.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Material-, Stückliste und Zuschnitt vom Server (M9-02 bis M9-04)',
    (tester) async {
      await starteApp(tester);
      await tester.tap(find.byKey(const ValueKey('neu')));
      await tester.pumpAndSettle();
      // erst der Hinweis auf unveränderte Standardwerte (M3-05)
      await tester.tap(find.byKey(const ValueKey('materialliste-knopf')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('standardwert-fortfahren')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('materialliste-dialog')),
        findsOneWidget,
      );
      // Der Smoke-Server läuft ohne Artikeldatei: nichts verlegt, Liste leer
      await warteAuf(tester, find.text(de.materiallisteLeer));
      // M9-04: umschalten auf die Stückliste, ebenfalls leer
      await tester.tap(find.byKey(const ValueKey('zur-stueckliste')));
      await tester.pumpAndSettle();
      expect(find.text(de.stuecklisteLeer), findsOneWidget);
      // M9-02: Zuschnittpläne, ohne Artikeldatei ebenfalls leer
      await tester.tap(find.byKey(const ValueKey('zum-zuschnitt')));
      await tester.pumpAndSettle();
      final leer = find.byKey(const ValueKey('zuschnittplan-leer'));
      await tester.ensureVisible(leer);
      expect(tester.widget<Text>(leer).data, de.zuschnittLeer);
      await tester.tap(find.byKey(const ValueKey('materialliste-schliessen')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('materialliste-dialog')), findsNothing);
    },
  );

  testWidgets('Verschnittoptimierung erstellen und zurücksetzen (M9-01)', (
    tester,
  ) async {
    await starteApp(tester);
    await tester.tap(find.byKey(const ValueKey('neu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('station-verschnittoptimierung')),
    );
    await tester.pumpAndSettle();
    final erstellen = find.byKey(const ValueKey('optimierung-erstellen'));
    await _zeige(tester, erstellen);
    // Der Smoke-Server läuft ohne Artikeldatei: keine Dielen
    expect(find.text(de.keineDielen), findsOneWidget);
    await tester.tap(erstellen);
    await tester.pumpAndSettle();
    final zuruecksetzen = find.byKey(
      const ValueKey('optimierung-zuruecksetzen'),
    );
    await _zeige(tester, zuruecksetzen);
    expect(erstellen, findsNothing);
    await tester.tap(zuruecksetzen);
    await tester.pumpAndSettle();
    await _zeige(tester, erstellen);
  });
}

/// Scrollt das Bearbeitungsmenü bis [finder] (es baut nur sichtbare
/// Unterpunkte) und wartet auf ihn.
Future<void> _zeige(WidgetTester tester, Finder finder) async {
  final liste = find
      .descendant(
        of: find.descendant(
          of: find.byKey(const ValueKey('bearbeitungsmenue')),
          matching: find.byType(ListView),
        ),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(finder, 200, scrollable: liste);
  await tester.pumpAndSettle();
  await warteAuf(tester, finder);
}
