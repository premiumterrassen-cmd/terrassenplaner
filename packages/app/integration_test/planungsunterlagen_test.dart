import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'start.dart';

/// Ende-zu-Ende (M9-06): PDF speichert die Planung, der Server erzeugt die
/// Planungsunterlagen dieser Version, der Browser bietet sie zum Download
/// an (`datei_angebot_web.dart`).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Planungsunterlagen als PDF über den Server', (tester) async {
    await starteApp(tester);
    await tester.tap(find.byKey(const ValueKey('neu')));
    await tester.pumpAndSettle();
    await warteAuf(tester, find.text('Fläche: 14,832 m²'));

    await tester.tap(find.byKey(const ValueKey('pdf')));
    await tester.pumpAndSettle();
    // nichts geändert: erst der Hinweis auf Standardwerte (M3-05)
    await tester.tap(find.byKey(const ValueKey('standardwert-fortfahren')));
    final meldung = find.textContaining(
      'Planungsunterlagen zu Konfigurationsnummer',
    );
    await warteAuf(tester, meldung);
    expect(tester.widget<Text>(meldung).data, contains('Version 1 erstellt.'));
  });
}
