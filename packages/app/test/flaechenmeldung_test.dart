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
    List<Punkt>? ecken,
  }) async {
    final planung = PlanungsSteuerung();
    final berechnung = BerechnungsSteuerung(
      planung: planung,
      berechne: (p) async => Berechnung(
        umriss: p.aktuell.grundriss.ecken,
        ecken: ecken ?? const [],
        flaeche: flaeche,
      ),
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

  testWidgets('Kanten unter 10 cm und über 30 m: Hinweise (Planungskern v7 '
      'Regel 9.6)', (tester) async {
    await zeige(
      tester,
      flaeche: 14.832e6,
      ecken: const [
        Punkt(0, 0),
        Punkt(31000, 0),
        Punkt(31000, 55),
        Punkt(0, 3000),
      ],
    );
    final kurz = find.byKey(const ValueKey('kantenwarnung-B–C'));
    expect(
      tester
          .widget<Text>(find.descendant(of: kurz, matching: find.byType(Text)))
          .data,
      'Hinweis: Kante B–C ist nur 5,5 cm lang (unter 10 cm) – bitte prüfen '
      'Sie die Maße.',
    );
    expect(find.byKey(const ValueKey('kantenwarnung-A–B')), findsOneWidget);
    expect(find.textContaining('über 30 m'), findsNWidgets(2));
    expect(find.byIcon(Icons.info_outline), findsNWidgets(3));
    await zeige(
      tester,
      flaeche: 14.832e6,
      sprache: const Locale('en'),
      ecken: const [Punkt(0, 0), Punkt(31000, 0), Punkt(0, 3000)],
    );
    expect(find.textContaining('over 30 m'), findsNWidgets(2));
  });
}
