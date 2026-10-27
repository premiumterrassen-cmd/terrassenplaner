import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/planer_app.dart';
import 'package:terrassenplaner_app/src/rahmen/ansichtsoptionen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_schritt.dart';
import 'package:terrassenplaner_app/src/sprache/sprache.dart';

import 'hilfe.dart';

Map<String, Object?> _arb(String sprache) =>
    jsonDecode(File('lib/l10n/planer_$sprache.arb').readAsStringSync())
        as Map<String, Object?>;

/// Texte einer ARB-Datei ohne Metadaten (`@…`).
Map<String, String> _texte(String sprache) => {
  for (final MapEntry(:key, :value) in _arb(sprache).entries)
    if (!key.startsWith('@')) key: value! as String,
};

/// Zeile ohne `$name` und `${…}` – eingesetzte Werte sind kein Text.
String _ohneEinsetzungen(String zeile) =>
    zeile.replaceAll(RegExp(r'\$(\{[^}]*\}|\w+)'), '');

Set<String> _platzhalter(String text) => {
  for (final m in RegExp(r'\{(\w+)\}').allMatches(text)) m[1]!,
};

Future<SprachSteuerung> _zeigeApp(WidgetTester tester, Size groesse) async {
  tester.view
    ..physicalSize = groesse
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final sprache = SprachSteuerung();
  addTearDown(sprache.dispose);
  await tester.pumpWidget(
    PlanerApp(
      hallo: () async => 'ok',
      laden: (_) async {},
      gespeichert: () async => null,
      sprache: sprache,
    ),
  );
  await tester.pumpAndSettle();
  // Eingangsdialog schließen.
  await tester.tap(find.byKey(const ValueKey('neu')));
  await tester.pumpAndSettle();
  return sprache;
}

void main() {
  group('Übersetzungsdateien', () {
    test('Deutsch ist Standard, Englisch die zweite Sprache', () {
      expect(SprachSteuerung().value, const Locale('de'));
      expect(SprachSteuerung.standard, const Locale('de'));
      expect(SprachSteuerung.sprachen, const [Locale('de'), Locale('en')]);
      expect([de.localeName, en.localeName], ['de', 'en']);
    });

    test('beide Sprachen haben dieselben Texte und Platzhalter', () {
      final deutsch = _texte('de');
      final englisch = _texte('en');
      expect(englisch.keys.toSet(), deutsch.keys.toSet());
      for (final MapEntry(:key, :value) in deutsch.entries) {
        expect(value.trim(), isNotEmpty, reason: key);
        expect(englisch[key]!.trim(), isNotEmpty, reason: key);
        expect(_platzhalter(englisch[key]!), _platzhalter(value), reason: key);
      }
    });

    test('Platzhalter sind in der Vorlage beschrieben', () {
      final vorlage = _arb('de');
      for (final MapEntry(:key, :value) in _texte('de').entries) {
        if (_platzhalter(value).isEmpty) continue;
        final meta = vorlage['@$key']! as Map<String, Object?>;
        expect(
          (meta['placeholders']! as Map<String, Object?>).keys.toSet(),
          _platzhalter(value),
          reason: key,
        );
      }
    });

    test('keine fest im Code stehenden Oberflächentexte', () {
      // Widget-Eigenschaften, die Text für den Kunden tragen, mit einem
      // Buchstaben-Literal – Ausnahmen gibt es keine.
      final verboten = RegExp(
        r'''(\bText\(|\b(tooltip|label|labelText|hintText|helperText|'''
        r'''errorText|semanticLabel|semanticsLabel|title|message|content)'''
        r''':\s*(const\s+)?(Text\()?)\s*['"][^'"]*[A-Za-zÄÖÜäöüß]''',
      );
      final funde = [
        for (final datei in Directory('lib').listSync(recursive: true))
          if (datei is File &&
              datei.path.endsWith('.dart') &&
              !datei.path.startsWith('lib/l10n/'))
            for (final (i, zeile) in datei.readAsLinesSync().indexed)
              if (verboten.hasMatch(_ohneEinsetzungen(zeile)))
                '${datei.path}:${i + 1}: $zeile',
      ];
      expect(funde, isEmpty);
      // Die Prüfung erkennt feste Texte wirklich.
      for (final probe in [
        "Text('Hallo')",
        "tooltip: 'Hilfe'",
        'label: const Text("Zoom")',
        "semanticLabel: 'Logo'",
      ]) {
        expect(verboten.hasMatch(probe), isTrue, reason: probe);
      }
      expect(verboten.hasMatch("Text('42')"), isFalse);
      expect(
        verboten.hasMatch(_ohneEinsetzungen(r"Text('$_version')")),
        isFalse,
      );
      expect(
        verboten.hasMatch(_ohneEinsetzungen(r"Text('${s.nummer} Schritt')")),
        isTrue,
      );
      expect(verboten.hasMatch('Text(t.zoom)'), isFalse);
    });
  });

  group('Zahlen und Aufzählungen', () {
    test('Zahlen im Format der Sprache', () {
      expect(zahlText(de, 12.5, '0.00'), '12,50');
      expect(zahlText(en, 12.5, '0.00'), '12.50');
      expect(zahlText(de, 1234.5, '0.#'), '1234,5');
      expect(Kennzahlen.zahl(en, 0.25, 'm³'), '0.25 m³');
    });

    test('Schritte, Ebenen und Beschriftungen auf Englisch', () {
      expect(
        [for (final s in PlanerSchritt.values) s.titel(en)],
        [
          'FLOOR PLAN',
          'DECKING',
          'SUBSTRUCTURE',
          'CONNECTIONS',
          'STAIRS',
          'ACCESSORIES',
          'CUTTING OPTIMISATION',
        ],
      );
      expect(PlanerSchritt.grundriss.getrennterTitel(en), 'FLOOR PLAN');
      expect(
        PlanerSchritt.unterkonstruktion.getrennterTitel(en),
        'SUB-\nSTRUCTURE',
      );
      expect(
        PlanerSchritt.zubehoer.nummerierteUnterpunkte(en).last,
        '6.8 RIBOL decking oil',
      );
      expect(
        [for (final e in Ebene.values) e.titel(en)],
        ['Deck', 'Sub', 'Dims'],
      );
      expect(
        [for (final e in Ebene.values) e.langerTitel(en)],
        ['Decking', 'Substructure', 'Dimensions'],
      );
      expect(
        [for (final e in Ebene.values) e.langerTitel(de)],
        ['Belag', 'Unterkonstruktion', 'Maße'],
      );
      expect(
        [for (final b in Beschriftung.values) b.titel(en)],
        ['Side lengths', 'Angles', 'Points', 'Drains'],
      );
      // Gleich viele Unterpunkte in beiden Sprachen.
      for (final s in PlanerSchritt.values) {
        expect(s.unterpunkte(en).length, s.unterpunkte(de).length);
      }
    });
  });

  group('Sprachauswahl', () {
    testWidgets('wechselt die Oberfläche sofort ins Englische und zurück', (
      tester,
    ) async {
      final sprache = await _zeigeApp(tester, const Size(1440, 900));
      expect(find.text(de.planerTitel), findsOneWidget);
      expect(find.text('DE'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sprachauswahl')));
      await tester.pumpAndSettle();
      expect(find.text('Deutsch'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sprache-en')));
      await tester.pumpAndSettle();
      expect(sprache.value, const Locale('en'));
      expect(find.text('EN'), findsOneWidget);
      expect(find.text(en.planerTitel), findsOneWidget);
      expect(find.text(en.anfordern), findsOneWidget);
      expect(find.text(en.impressum), findsOneWidget);
      expect(find.text('1. FLOOR PLAN'), findsOneWidget);
      expect(find.text('Area: – m²'), findsOneWidget);
      expect(find.byTooltip(en.sprache), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('sprachauswahl')));
      await tester.pumpAndSettle();
      final eintrag = tester.widget<PopupMenuButton<Locale>>(
        find.byKey(const ValueKey('sprachauswahl')),
      );
      expect(eintrag.initialValue, const Locale('en'));
      await tester.tap(find.byKey(const ValueKey('sprache-de')));
      await tester.pumpAndSettle();
      expect(find.text(de.planerTitel), findsOneWidget);
    });

    for (final breite in [768.0, 1024.0, 1280.0, 1365.0, 1366.0, 1440.0]) {
      testWidgets('beide Sprachen ohne Überlauf bei $breite px', (
        tester,
      ) async {
        final sprache = await _zeigeApp(tester, Size(breite, 900));
        for (final t in [de, en]) {
          sprache.value = Locale(t.localeName);
          await tester.pumpAndSettle();
          // Unter 1366 px nur Symbole mit Tooltip (Kopfzeile.textAb).
          final mitText = breite >= Kopfzeile.textAb;
          expect(
            find.text(t.videoberatung),
            mitText ? findsOneWidget : findsNothing,
          );
          expect(
            find.byTooltip(t.videoberatung),
            mitText ? findsNothing : findsOneWidget,
          );
          expect(
            find.text(mitText ? t.anfordern : t.anfordernKurz),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull, reason: t.localeName);
        }
      });
    }

    testWidgets('ohne Sprachsteuerung keine Auswahl im Rahmen', (tester) async {
      await tester.pumpWidget(
        testApp(home: const PlanerRahmen(status: Text('x'))),
      );
      expect(find.byKey(const ValueKey('sprachauswahl')), findsNothing);
    });

    testWidgets('eigene Sprachsteuerung der App wird freigegeben', (
      tester,
    ) async {
      await tester.pumpWidget(
        PlanerApp(
          hallo: () async => 'ok',
          laden: (_) async {},
          gespeichert: () async => null,
        ),
      );
      await tester.pumpAndSettle();
      final rahmen = tester.widget<PlanerRahmen>(find.byType(PlanerRahmen));
      final sprache = rahmen.sprache!;
      await tester.pumpWidget(const SizedBox());
      // Freigegebene Notifier werfen bei addListener.
      expect(() => sprache.addListener(() {}), throwsFlutterError);
    });

    testWidgets(
      'übergebene Sprachsteuerung bleibt nach dem Schließen nutzbar',
      (tester) async {
        final sprache = SprachSteuerung();
        await tester.pumpWidget(
          PlanerApp(
            hallo: () async => 'ok',
            laden: (_) async {},
            gespeichert: () async => null,
            sprache: sprache,
          ),
        );
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        expect(() => sprache.addListener(() {}), returnsNormally);
        sprache.dispose();
      },
    );
  });
}
