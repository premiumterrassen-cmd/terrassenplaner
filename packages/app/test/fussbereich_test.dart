import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:terrassenplaner_app/src/design/planer_design.dart';
import 'package:terrassenplaner_app/src/rahmen/aktionen.dart';
import 'package:terrassenplaner_app/src/rahmen/ansichtsoptionen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_schritt.dart';
import 'package:terrassenplaner_app/src/rahmen/rahmen_zustand.dart';
import 'package:terrassenplaner_app/src/rahmen/standardwert_hinweis.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Zeichnet geöffnete Adressen auf, statt einen Browser zu starten.
class _Plattform extends UrlLauncherPlatform with MockPlatformInterfaceMixin {
  final geoeffnet = <(String, String?)>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    geoeffnet.add((url, options.webOnlyWindowName));
    return true;
  }
}

Future<({List<Uri> links, List<String> aufgerufen, RahmenZustand zustand})>
_zeige(
  WidgetTester tester, {
  Size groesse = const Size(1440, 900),
  bool mitAktionen = true,
  bool alleGeaendert = true,
}) async {
  tester.view
    ..physicalSize = groesse
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final links = <Uri>[];
  final aufgerufen = <String>[];
  final zustand = RahmenZustand();
  if (alleGeaendert) {
    for (final s in PlanerSchritt.values) {
      zustand.markiereGeaendert(s);
    }
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: planerThema(),
      home: PlanerRahmen(
        status: const Text('Status'),
        zustand: zustand,
        aktionen: RahmenAktionen(
          oeffne: (adresse) async => links.add(adresse),
          anfordern: mitAktionen
              ? () async => aufgerufen.add('anfordern')
              : null,
          pdf: mitAktionen ? () async => aufgerufen.add('pdf') : null,
        ),
      ),
    ),
  );
  return (links: links, aufgerufen: aufgerufen, zustand: zustand);
}

void main() {
  test('Ziele im Shop (Vorgabe Alexander)', () {
    expect(
      PlanerLinks.agb.toString(),
      'https://shop.robinienwelt.de/policies/terms-of-service',
    );
    expect(
      PlanerLinks.datenschutz.toString(),
      'https://shop.robinienwelt.de/policies/privacy-policy',
    );
    expect(
      PlanerLinks.impressum.toString(),
      'https://shop.robinienwelt.de/policies/legal-notice',
    );
    expect(
      PlanerLinks.videoberatung.toString(),
      'https://shop.robinienwelt.de/products/online-videoberatung-buchen',
    );
  });

  testWidgets('Fußbereich: AGB, Datenschutz, Impressum öffnen die Seiten', (
    tester,
  ) async {
    final s = await _zeige(tester);
    expect(find.text('Status'), findsOneWidget);
    for (final text in [
      Statuszeile.agb,
      Statuszeile.datenschutz,
      Statuszeile.impressum,
    ]) {
      await tester.tap(find.byKey(ValueKey('link-$text')));
    }
    expect(s.links, [
      PlanerLinks.agb,
      PlanerLinks.datenschutz,
      PlanerLinks.impressum,
    ]);
    expect(
      [Statuszeile.agb, Statuszeile.datenschutz, Statuszeile.impressum],
      ['AGB', 'Datenschutz', 'Impressum'],
    );
    final link = tester.widget<TextButton>(
      find.byKey(const ValueKey('link-AGB')),
    );
    expect(link.style!.textStyle!.resolve({})!.fontSize, 12);
  });

  testWidgets('Video-Beratung öffnet das Shop-Produkt', (tester) async {
    final s = await _zeige(tester);
    expect(find.text(Kopfzeile.videoberatung), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('videoberatung')));
    expect(s.links, [PlanerLinks.videoberatung]);
  });

  testWidgets('PDF und Anfordern: alles geändert – direkt ausgeführt', (
    tester,
  ) async {
    final s = await _zeige(tester);
    expect(find.text(Kopfzeile.pdf), findsOneWidget);
    expect(find.text(Kopfzeile.anfordern), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pdf')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('anfordern')));
    await tester.pumpAndSettle();
    expect(s.aufgerufen, ['pdf', 'anfordern']);
    final knopf = tester.widget<FilledButton>(
      find.byKey(const ValueKey('anfordern')),
    );
    expect(knopf.style!.backgroundColor!.resolve({}), PlanerFarben.gruen);
  });

  testWidgets('erst der Standardwert-Hinweis, Zurück bricht ab', (
    tester,
  ) async {
    final s = await _zeige(tester, alleGeaendert: false);
    await tester.tap(find.byKey(const ValueKey('anfordern')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('standardwert-hinweis')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('standardwert-zurueck')));
    await tester.pumpAndSettle();
    expect(s.aufgerufen, isEmpty);
    await tester.tap(find.byKey(const ValueKey('pdf')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('standardwert-fortfahren')));
    await tester.pumpAndSettle();
    expect(s.aufgerufen, ['pdf']);
  });

  testWidgets('ohne Angebot/PDF (bis M9): Meldung „folgt“', (tester) async {
    await _zeige(tester, mitAktionen: false);
    await tester.tap(find.byKey(const ValueKey('anfordern')));
    await tester.pumpAndSettle();
    expect(find.text(PlanerRahmen.folgt), findsOneWidget);
    expect(PlanerRahmen.folgt, 'Diese Funktion folgt in Kürze.');
  });

  testWidgets('Tablet: Knöpfe als Symbole mit Tooltip, ohne Überlauf', (
    tester,
  ) async {
    final s = await _zeige(tester, groesse: const Size(768, 1024));
    for (final t in [
      Kopfzeile.videoberatung,
      Kopfzeile.zuruecksetzen,
      Kopfzeile.pdf,
    ]) {
      expect(find.byTooltip(t), findsOneWidget);
      expect(find.text(t), findsNothing);
    }
    expect(find.text('ANFORDERN'), findsOneWidget);
    expect(find.text(PlanerRahmen.titel), findsNothing);
    await tester.tap(find.byKey(const ValueKey('videoberatung')));
    expect(s.links, [PlanerLinks.videoberatung]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'übergebene Ansichtsoptionen bleiben nach dem Schließen nutzbar',
    (tester) async {
      final optionen = AnsichtsOptionen();
      await tester.pumpWidget(
        MaterialApp(
          home: PlanerRahmen(status: const Text('x'), optionen: optionen),
        ),
      );
      await tester.pumpWidget(const SizedBox());
      // Freigegebene Notifier werfen bei addListener.
      expect(() => optionen.addListener(() {}), returnsNormally);
      optionen.dispose();
    },
  );

  testWidgets('Texte der Kopfzeile', (tester) async {
    expect(Kopfzeile.videoberatung, 'Video-Beratung buchen');
    expect(Kopfzeile.pdf, 'PDF');
    expect(Kopfzeile.anfordern, 'KONFIGURATION ANFORDERN');
    expect(StandardwertHinweis.fortfahren, 'Fortfahren');
  });

  test('Standard: öffnet im neuen Tab über url_launcher', () async {
    final plattform = _Plattform();
    final vorher = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = plattform;
    addTearDown(() => UrlLauncherPlatform.instance = vorher);
    expect(const RahmenAktionen().oeffne, oeffneImBrowser);
    expect(
      [const RahmenAktionen().anfordern, const RahmenAktionen().pdf],
      [null, null],
    );
    await oeffneImBrowser(PlanerLinks.agb);
    expect(plattform.geoeffnet, [(PlanerLinks.agb.toString(), '_blank')]);
  });
}
