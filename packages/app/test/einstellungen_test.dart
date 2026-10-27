import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/planer_app.dart';
import 'package:terrassenplaner_app/src/design/darstellung.dart';
import 'package:terrassenplaner_app/src/design/planer_design.dart';
import 'package:terrassenplaner_app/src/einstellungen/einstellungs_speicher.dart';
import 'package:terrassenplaner_app/src/einstellungen/lokale_einstellungen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/sprache/sprache.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

/// Wie ein gesperrter Browser-Speicher: jeder Zugriff wirft.
final class _GesperrterSpeicher implements EinstellungsSpeicher {
  @override
  String? lies(String schluessel) => throw StateError('gesperrt');

  @override
  void schreibe(String schluessel, String wert) => throw StateError('gesperrt');
}

final _stand = KonfigurationsStand(
  Konfigurationsnummer.pruefe('2026-10-08-1511'),
  3,
);

void main() {
  group('Speicher', () {
    test('flüchtig: liest, was geschrieben wurde', () {
      final speicher = FluechtigerSpeicher();
      expect(speicher.lies('a'), isNull);
      speicher.schreibe('a', '1');
      expect(speicher.lies('a'), '1');
      speicher.schreibe('a', '2');
      expect(speicher.lies('a'), '2');
    });

    test('sicher: reicht durch und fängt Fehler ab', () {
      final innen = FluechtigerSpeicher();
      final sicher = SichererSpeicher(innen)..schreibe('a', '1');
      expect(innen.lies('a'), '1');
      expect(sicher.lies('a'), '1');
      final gesperrt = SichererSpeicher(_GesperrterSpeicher());
      expect(gesperrt.lies('a'), isNull);
      expect(() => gesperrt.schreibe('a', '1'), returnsNormally);
    });

    test('außerhalb des Browsers: abgesichert und nur für die Sitzung', () {
      final speicher = browserSpeicher();
      expect(speicher, isA<SichererSpeicher>());
      expect(
        (speicher as SichererSpeicher).inneren,
        isA<FluechtigerSpeicher>(),
      );
      speicher.schreibe('a', '1');
      expect(speicher.lies('a'), '1');
    });
  });

  group('LokaleEinstellungen', () {
    late FluechtigerSpeicher speicher;
    late LokaleEinstellungen einstellungen;

    setUp(() {
      speicher = FluechtigerSpeicher();
      einstellungen = LokaleEinstellungen(speicher);
    });

    test('Schlüssel wie im Ladebildschirm (web/ladebild/fortschritt.js)', () {
      expect(LokaleEinstellungen.sprachSchluessel, 'terrassenplaner.sprache');
      expect(
        LokaleEinstellungen.darstellungSchluessel,
        'terrassenplaner.darstellung',
      );
      expect(
        LokaleEinstellungen.konfigurationSchluessel,
        'terrassenplaner.weiterplanen',
      );
    });

    test('Sprache: Standard Deutsch, Änderung wird gespeichert', () {
      final sprache = einstellungen.sprache();
      addTearDown(sprache.dispose);
      expect(sprache.value, const Locale('de'));
      expect(speicher.lies(LokaleEinstellungen.sprachSchluessel), isNull);
      sprache.value = const Locale('en');
      expect(speicher.lies(LokaleEinstellungen.sprachSchluessel), 'en');
      final wieder = LokaleEinstellungen(speicher).sprache();
      addTearDown(wieder.dispose);
      expect(wieder.value, const Locale('en'));
    });

    test('Sprache: unbekannter Wert → Deutsch', () {
      speicher.schreibe(LokaleEinstellungen.sprachSchluessel, 'fr');
      final sprache = einstellungen.sprache();
      addTearDown(sprache.dispose);
      expect(sprache.value, const Locale('de'));
    });

    test('Darstellung: Standard wie System, Änderung wird gespeichert', () {
      final darstellung = einstellungen.darstellung();
      addTearDown(darstellung.dispose);
      expect(darstellung.value, ThemeMode.system);
      darstellung.value = ThemeMode.dark;
      expect(speicher.lies(LokaleEinstellungen.darstellungSchluessel), 'dark');
      final wieder = LokaleEinstellungen(speicher).darstellung();
      addTearDown(wieder.dispose);
      expect(wieder.value, ThemeMode.dark);
      darstellung.value = ThemeMode.light;
      expect(speicher.lies(LokaleEinstellungen.darstellungSchluessel), 'light');
    });

    test('Darstellung: unbekannter Wert → wie System', () {
      speicher.schreibe(LokaleEinstellungen.darstellungSchluessel, 'grell');
      final darstellung = einstellungen.darstellung();
      addTearDown(darstellung.dispose);
      expect(darstellung.value, ThemeMode.system);
    });

    test('Weiterplanen: gemerkte Konfiguration wird wiedergefunden', () {
      expect(einstellungen.letzteKonfiguration(), isNull);
      einstellungen.merke(_stand);
      expect(
        speicher.lies(LokaleEinstellungen.konfigurationSchluessel),
        '2026-10-08-1511/3',
      );
      expect(LokaleEinstellungen(speicher).letzteKonfiguration(), _stand);
    });

    test('Weiterplanen: ungültige Einträge werden ignoriert', () {
      for (final falsch in [
        '',
        '2026-10-08-1511',
        '2026-10-08-1511/',
        '2026-10-08-1511/x',
        '2026-10-08-1511/0',
        '2026-10-08-1511/3/1',
        '2026-02-30-1511/3',
        'abc/3',
      ]) {
        speicher.schreibe(LokaleEinstellungen.konfigurationSchluessel, falsch);
        expect(einstellungen.letzteKonfiguration(), isNull, reason: falsch);
      }
    });

    test('merkend: nur erfolgreich geladene Konfigurationen', () async {
      final geladen = <KonfigurationsStand>[];
      await einstellungen.merkend((stand) async => geladen.add(stand))(_stand);
      expect(geladen, [_stand]);
      expect(einstellungen.letzteKonfiguration(), _stand);

      final anderer = KonfigurationsStand(_stand.nummer, 4);
      await expectLater(
        einstellungen.merkend((_) => Future.error(StateError('weg')))(anderer),
        throwsStateError,
      );
      expect(einstellungen.letzteKonfiguration(), _stand);
    });

    test('gesperrter Speicher: Standardwerte, Änderungen ohne Fehler', () {
      final gesperrt = LokaleEinstellungen(
        SichererSpeicher(_GesperrterSpeicher()),
      );
      final sprache = gesperrt.sprache();
      final darstellung = gesperrt.darstellung();
      addTearDown(sprache.dispose);
      addTearDown(darstellung.dispose);
      expect(sprache.value, SprachSteuerung.standard);
      expect(darstellung.value, DarstellungSteuerung.standard);
      expect(gesperrt.letzteKonfiguration(), isNull);
      expect(() => sprache.value = const Locale('en'), returnsNormally);
      expect(() => darstellung.value = ThemeMode.dark, returnsNormally);
      expect(() => gesperrt.merke(_stand), returnsNormally);
    });
  });

  group('Darstellung', () {
    Future<DarstellungSteuerung> zeigeApp(
      WidgetTester tester, {
      Locale sprache = SprachSteuerung.standard,
    }) async {
      tester.view
        ..physicalSize = const Size(1440, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final darstellung = DarstellungSteuerung();
      final steuerung = SprachSteuerung(sprache);
      addTearDown(darstellung.dispose);
      addTearDown(steuerung.dispose);
      await tester.pumpWidget(
        PlanerApp(
          hallo: () async => 'ok',
          laden: (_) async {},
          gespeichert: () async => null,
          sprache: steuerung,
          darstellung: darstellung,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('neu')));
      await tester.pumpAndSettle();
      return darstellung;
    }

    Brightness helligkeit(WidgetTester tester) =>
        Theme.of(tester.element(find.byKey(const ValueKey('zeichenflaeche'))))
            .brightness;

    test('Standard wie System', () {
      expect(DarstellungSteuerung.standard, ThemeMode.system);
      expect(DarstellungSteuerung().value, ThemeMode.system);
    });

    test('Symbole und Namen je Darstellung', () {
      expect(
        [for (final m in ThemeMode.values) Darstellungsauswahl.symbol(m)],
        [
          Icons.brightness_auto_outlined,
          Icons.light_mode_outlined,
          Icons.dark_mode_outlined,
        ],
      );
      expect(
        [for (final m in ThemeMode.values) Darstellungsauswahl.name(de, m)],
        ['Wie System', 'Hell', 'Dunkel'],
      );
      expect(
        [for (final m in ThemeMode.values) Darstellungsauswahl.name(en, m)],
        ['System', 'Light', 'Dark'],
      );
    });

    testWidgets('folgt dem System, bis hell oder dunkel gewählt ist', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final darstellung = await zeigeApp(tester);
      expect(helligkeit(tester), Brightness.dark);
      expect(find.byIcon(Icons.brightness_auto_outlined), findsOneWidget);
      expect(find.bySemanticsLabel('Darstellung: Wie System'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('darstellungsauswahl')));
      await tester.pumpAndSettle();
      expect(find.text('Hell'), findsOneWidget);
      expect(find.text('Dunkel'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('darstellung-light')));
      await tester.pumpAndSettle();
      expect(darstellung.value, ThemeMode.light);
      expect(helligkeit(tester), Brightness.light);
      expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);

      darstellung.value = ThemeMode.dark;
      await tester.pumpAndSettle();
      expect(helligkeit(tester), Brightness.dark);
      expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
      // Flächen aus dem dunklen Thema.
      final flaeche = tester.widget<ColoredBox>(
        find.byKey(const ValueKey('zeichenflaeche')),
      );
      expect(flaeche.color, PlanerFarbenDunkel.grund);
    });

    testWidgets('Auswahl in der aktuellen Sprache', (tester) async {
      await zeigeApp(tester, sprache: const Locale('en'));
      expect(find.byTooltip('Appearance'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('darstellungsauswahl')));
      await tester.pumpAndSettle();
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
    });

    testWidgets('ohne Steuerung keine Auswahl im Rahmen', (tester) async {
      await tester.pumpWidget(
        testApp(home: const PlanerRahmen(status: Text('ok'))),
      );
      expect(find.byKey(const ValueKey('darstellungsauswahl')), findsNothing);
    });
  });
}
