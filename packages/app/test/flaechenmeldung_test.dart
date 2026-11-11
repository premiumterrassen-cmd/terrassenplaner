import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/rahmen/berechnung_steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/flaechenmeldung.dart';
import 'package:terrassenplaner_app/src/rahmen/steuerung.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

void main() {
  Future<void> zeige(
    WidgetTester tester, {
    required double flaeche,
    Locale sprache = const Locale('de'),
  }) async {
    final planung = PlanungsSteuerung();
    final berechnung = BerechnungsSteuerung(
      planung: planung,
      berechne: (p) async =>
          Berechnung(umriss: p.aktuell.grundriss.ecken, flaeche: flaeche),
    );
    addTearDown(() {
      berechnung.dispose();
      planung.dispose();
    });
    await tester.pumpWidget(
      testApp(
        sprache: sprache,
        home: Scaffold(body: FlaechenMeldung(berechnung: berechnung)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder meldung(Flaechenmeldung m) =>
      find.byKey(ValueKey('flaechenmeldung-${m.name}'));

  testWidgets('übliche Fläche: keine Meldung', (tester) async {
    await zeige(tester, flaeche: 14.832e6);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('Fehler in Fehlerfarbe (Planungskern v6 Regel 1.7)', (
    tester,
  ) async {
    await zeige(tester, flaeche: 0.04e6);
    final m = meldung(Flaechenmeldung.masseFalsch);
    final farben = Theme.of(tester.element(m)).colorScheme;
    final icon = tester.widget<Icon>(
      find.descendant(of: m, matching: find.byType(Icon)),
    );
    expect(icon.icon, Icons.error_outline);
    expect(icon.color, farben.error);
    final text = tester.widget<Text>(
      find.descendant(of: m, matching: find.byType(Text)),
    );
    expect(text.data, startsWith('Maße fehlen oder sind falsch'));
    expect(text.style?.color, farben.error);
  });

  testWidgets('unplausibel groß: Fehler; außerhalb 1–300 m²: Hinweis', (
    tester,
  ) async {
    await zeige(tester, flaeche: 2000e6, sprache: const Locale('en'));
    expect(find.textContaining('implausibly large'), findsOneWidget);
    await zeige(tester, flaeche: 500e6);
    final m = meldung(Flaechenmeldung.ungewoehnlich);
    final icon = tester.widget<Icon>(
      find.descendant(of: m, matching: find.byType(Icon)),
    );
    expect(icon.icon, Icons.info_outline);
    expect(icon.color, Theme.of(tester.element(m)).colorScheme.primary);
    expect(
      tester
          .widget<Text>(find.descendant(of: m, matching: find.byType(Text)))
          .style,
      isNull,
    );
  });
}
