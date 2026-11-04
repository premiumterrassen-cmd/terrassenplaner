import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/hilfe.dart';
import 'start.dart';

/// Ende-zu-Ende (M9-05): SPEICHERN → ZURÜCKSETZEN → LADEN über den Router
/// und den Konfigurationsdienst; die geladene Planung ist die gespeicherte.
/// Ein falscher Prüfcode gilt als unbekannt (M9-05b).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Speichern und Laden über den Server', (tester) async {
    await starteApp(tester);
    await tester.tap(find.byKey(const ValueKey('neu')));
    await tester.pumpAndSettle();
    await warteAuf(tester, find.text('Fläche: 14,832 m²'));
    await tester.tap(find.byKey(const ValueKey('form-lForm')));
    await warteAuf(tester, find.text('Fläche: 14,580 m²'));

    await tester.tap(find.byKey(const ValueKey('speichern')));
    final meldung = find.textContaining('Gespeichert: Konfigurationsnummer');
    await warteAuf(tester, meldung);
    final text = tester.widget<Text>(meldung).data!;
    final kennung = RegExp(r'\d{4}-\d{2}-\d{2}-\d{4}-[A-Z2-9]{5}')
        .firstMatch(text)![0]!;
    expect(text, contains('Version 1'));
    ScaffoldMessenger.of(
      tester.element(find.byKey(const ValueKey('speichern'))),
    ).removeCurrentSnackBar();

    await tester.tap(find.byKey(const ValueKey('zuruecksetzen')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('zuruecksetzen-bestaetigen')));
    await warteAuf(tester, find.text('Fläche: 14,832 m²'));

    await tester.tap(find.byKey(const ValueKey('konfiguration-laden')));
    await tester.pumpAndSettle();
    // falscher Prüfcode: dieselbe Meldung wie „unbekannt“
    final letztes = kennung[kennung.length - 1];
    final falsch =
        kennung.substring(0, kennung.length - 1) + (letztes == 'A' ? 'B' : 'A');
    final feld = find.byKey(const ValueKey('nummer'));
    await tester.enterText(feld, falsch);
    await tester.tap(find.byKey(const ValueKey('laden-bestaetigen')));
    await warteAuf(tester, find.text(de.konfigurationUnbekannt));
    expect(find.text('Fläche: 14,832 m²'), findsOneWidget);
    // unbekannte Version: eigene Meldung; Kleinschreibung ist erlaubt
    // Ein zweites enterText in dasselbe Feld kam im Browser nicht an;
    // deshalb direkt über den Controller.
    tester.widget<TextField>(feld).controller!.text = kennung.toLowerCase();
    await tester.tap(find.byKey(const ValueKey('version-plus')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('laden-bestaetigen')));
    // Der Knopf leert die alte Meldung, bevor die Antwort kommt.
    await tester.pump();
    await warteAuf(tester, find.text(de.konfigurationUnbekannt));
    await tester.tap(find.byKey(const ValueKey('version-minus')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('laden-bestaetigen')));
    await warteAuf(tester, find.text('Fläche: 14,580 m²'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('laden-dialog')), findsNothing);
  });
}
