import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/rahmen/belagmeldungen.dart';
import 'package:terrassenplaner_app/src/rahmen/berechnung_steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/steuerung.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

/// Antwort wie vom Server mit allen Meldungen (M5-10).
Future<Berechnung> _alle(Planung planung) async => Berechnung(
  umriss: planung.aktuell.grundriss.ecken,
  flaeche: 1,
  belagmeldungen: Belagmeldung.values,
);

void main() {
  Future<PlanungsSteuerung> zeige(
    WidgetTester tester, {
    required int unterpunkt,
    PlanungBerechnen berechne = _alle,
    Locale sprache = const Locale('de'),
  }) async {
    final planung = PlanungsSteuerung();
    final berechnung = BerechnungsSteuerung(
      planung: planung,
      berechne: berechne,
    );
    addTearDown(() {
      berechnung.dispose();
      planung.dispose();
    });
    await tester.pumpWidget(
      testApp(
        sprache: sprache,
        home: Scaffold(
          body: BelagMeldungen(
            berechnung: berechnung,
            planung: planung,
            unterpunkt: unterpunkt,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return planung;
  }

  Finder meldung(Belagmeldung m) =>
      find.byKey(ValueKey('belagmeldung-${m.name}'));

  testWidgets('je Unterpunkt nur seine Meldungen', (tester) async {
    for (final unterpunkt in [0, 1, 2, 5]) {
      await zeige(tester, unterpunkt: unterpunkt);
      for (final m in Belagmeldung.values) {
        expect(
          meldung(m),
          m.unterpunkt == unterpunkt ? findsOneWidget : findsNothing,
        );
      }
    }
  });

  testWidgets('Warnung in Fehlerfarbe, Hinweis mit Info-Zeichen', (
    tester,
  ) async {
    await zeige(tester, unterpunkt: 0);
    final farben = Theme.of(tester.element(meldung(Belagmeldung.belagErsetzt)))
        .colorScheme;
    Icon icon(Belagmeldung m) => tester.widget<Icon>(
      find.descendant(of: meldung(m), matching: find.byType(Icon)),
    );
    Text text(Belagmeldung m) => tester.widget<Text>(
      find.descendant(of: meldung(m), matching: find.byType(Text)),
    );
    final warnung = Belagmeldung.flaecheKleinerAlsBelag;
    expect(icon(warnung).icon, Icons.warning_amber);
    expect(icon(warnung).color, farben.error);
    expect(text(warnung).style?.color, farben.error);
    final hinweis = Belagmeldung.belagErsetzt;
    expect(icon(hinweis).icon, Icons.info_outline);
    expect(icon(hinweis).color, farben.primary);
    expect(text(hinweis).style, isNull);
    expect(find.text(de.belagmeldungFlaecheKleiner), findsOneWidget);
  });

  testWidgets('Länge aus dem Planungsstand, auch auf Englisch', (tester) async {
    final planung = await zeige(
      tester,
      unterpunkt: 1,
      sprache: const Locale('en'),
    );
    expect(
      find.text(
        'The selected length of 0 cm is not available for this decking. '
        'The board length is determined automatically.',
      ),
      findsOneWidget,
    );
    planung.setze(planung.aktuell.mitDielenlaenge(const Millimeter(7000)));
    await tester.pumpAndSettle();
    expect(find.text(en.belagmeldungLaengeNichtLieferbar(700)), findsOneWidget);
  });

  testWidgets('ohne Berechnung oder ohne Meldung nichts', (tester) async {
    await zeige(
      tester,
      unterpunkt: 0,
      berechne: (_) async => throw StateError('offline'),
    );
    expect(find.byType(Icon), findsNothing);
  });

  test('Texte aller Meldungen (Deutsch)', () {
    const stand = Planungsstand(dielenlaenge: Millimeter(7000));
    expect(
      [for (final m in Belagmeldung.values) belagmeldungText(de, m, stand)],
      [
        de.belagmeldungBelagErsetzt,
        de.belagmeldungOhneMasse,
        de.belagmeldungSystemdiele,
        de.belagmeldungFlaecheKleiner,
        de.belagmeldungFliesenSpitzeWinkel,
        de.belagmeldungBombierung,
        'Die gewählte Länge von 700 cm gibt es für diesen Belag nicht. Die '
            'Dielenlänge wird automatisch ermittelt.',
        'Keine Lieferlänge dieses Belags erfüllt die Vorgabe Dielenlänge. '
            'Geplant wird mit allen Lagerlängen.',
        de.belagmeldungStosslinieZusatz(0),
        de.belagmeldungStosslinieMuster,
        de.belagmeldungStosslinieOhneWirkung,
        de.belagmeldungBefestigungsart,
        de.belagmeldungOhneBefestigung,
        de.belagmeldungSchraubeZuKurz,
      ],
    );
    expect(
      belagmeldungText(
        de,
        Belagmeldung.stosslinieZusatzstoesse,
        stand,
        zusatzstoesse: 1,
      ),
      contains('1 zusätzlichen, gleichmäßig verteilten Stoß'),
    );
    expect(
      en.belagmeldungStosslinieZusatz(2),
      contains('2 evenly spaced joints'),
    );
    expect(
      de.belagmeldungFliesenSpitzeWinkel,
      'Die Fläche hat Ecken unter 90°. Holzfliesen müssen dort schräg '
      'zugeschnitten werden – für solche Formen eignen sich Dielen besser.',
    );
  });
}
