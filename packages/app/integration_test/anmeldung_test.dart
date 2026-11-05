import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/hilfe.dart';
import 'start.dart';

/// Testkonto, das `tool/smoke.sh` nur für diesen Lauf im Auth-Server anlegt
/// (Konten nur im Arbeitsspeicher, Passwort zufällig).
const _email = String.fromEnvironment('SMOKE_MITARBEITER_EMAIL');
const _passwort = String.fromEnvironment('SMOKE_MITARBEITER_PASSWORT');

/// Ende-zu-Ende (M9-10): SPEICHERN als Kunde → ANMELDEN (SCRAM mit Argon2id
/// im Browser) → LADEN mit der Nummer allein → ABMELDEN; danach verlangt
/// LADEN wieder den Prüfcode.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Anmelden, ohne Prüfcode laden, abmelden', (tester) async {
    expect(_email, isNotEmpty, reason: 'Testkonto fehlt (tool/smoke.sh)');
    await starteApp(tester);
    await tester.tap(find.byKey(const ValueKey('neu')));
    await tester.pumpAndSettle();
    await warteAuf(tester, find.text('Fläche: 14,832 m²'));
    await tester.tap(find.byKey(const ValueKey('form-lForm')));
    await warteAuf(tester, find.text('Fläche: 14,580 m²'));
    await tester.tap(find.byKey(const ValueKey('speichern')));
    final meldung = find.textContaining('Gespeichert: Konfigurationsnummer');
    await warteAuf(tester, meldung);
    final nummer = RegExp(r'\d{4}-\d{2}-\d{2}-\d{4}')
        .firstMatch(tester.widget<Text>(meldung).data!)![0]!;
    ScaffoldMessenger.of(
      tester.element(find.byKey(const ValueKey('speichern'))),
    ).removeCurrentSnackBar();
    await tester.tap(find.byKey(const ValueKey('zuruecksetzen')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('zuruecksetzen-bestaetigen')));
    await warteAuf(tester, find.text('Fläche: 14,832 m²'));

    // ANMELDEN: falsches Passwort, dann richtig
    await tester.tap(find.byKey(const ValueKey('anmelden')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('anmelden-email')),
      _email,
    );
    await tester.enterText(
      find.byKey(const ValueKey('anmelden-passwort')),
      '${_passwort}x',
    );
    await tester.tap(find.byKey(const ValueKey('anmelden-bestaetigen')));
    await warteAuf(tester, find.text(de.anmeldungAbgelehnt));
    final passwort = find.byKey(const ValueKey('anmelden-passwort'));
    tester.widget<TextField>(passwort).controller!.text = _passwort;
    await tester.tap(find.byKey(const ValueKey('anmelden-bestaetigen')));
    await warteAuf(tester, find.text(de.angemeldetAls(_email)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('anmelde-dialog')), findsNothing);

    // LADEN mit der Nummer allein
    await tester.tap(find.byKey(const ValueKey('konfiguration-laden')));
    await tester.pumpAndSettle();
    expect(find.text(de.nummerHinweisMitarbeiter), findsOneWidget);
    final feld = find.byKey(const ValueKey('nummer'));
    tester.widget<TextField>(feld).controller!.text = nummer;
    await tester.tap(find.byKey(const ValueKey('laden-bestaetigen')));
    await warteAuf(tester, find.text('Fläche: 14,580 m²'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('laden-dialog')), findsNothing);

    // ABMELDEN: wieder Kunde, die Nummer allein reicht nicht mehr
    await tester.tap(find.byKey(const ValueKey('abmelden')));
    await warteAuf(tester, find.byKey(const ValueKey('anmelden')));
    expect(find.text(de.angemeldetAls(_email)), findsNothing);
    await tester.tap(find.byKey(const ValueKey('konfiguration-laden')));
    await tester.pumpAndSettle();
    tester.widget<TextField>(feld).controller!.text = nummer;
    await tester.tap(find.byKey(const ValueKey('laden-bestaetigen')));
    await warteAuf(tester, find.text(de.konfigurationUnbekannt));
  });
}
