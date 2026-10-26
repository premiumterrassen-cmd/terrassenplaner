import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/planer_app.dart';
import 'package:terrassenplaner_app/src/design/planer_design.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/start/eingangsdialog.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

final _gefunden = KonfigurationsStand(
  const Konfigurationsnummer('2026-10-08-1511'),
  3,
);

/// App mit Eingangsdialog; [geladen] sammelt die Ladeaufträge.
Future<void> _starte(
  WidgetTester tester, {
  KonfigurationsStand? gefunden,
  List<KonfigurationsStand>? geladen,
  KonfigurationLaden? laden,
}) async {
  tester.view
    ..physicalSize = const Size(1440, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    PlanerApp(
      hallo: () async => 'ok',
      laden: laden ?? (stand) async => geladen?.add(stand),
      gespeichert: () async => gefunden,
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _dialog => find.byKey(const ValueKey('eingangsdialog'));
Finder get _ladenDialog => find.byKey(const ValueKey('laden-dialog'));

void main() {
  testWidgets('erscheint beim Start über dem Rahmen', (tester) async {
    await _starte(tester);
    expect(_dialog, findsOneWidget);
    expect(find.byType(PlanerRahmen), findsOneWidget);
    expect(find.text(de.willkommenTitel), findsOneWidget);
    expect(find.text(de.willkommenText), findsOneWidget);
    expect(find.text(de.konfigurationLadenKnopf), findsOneWidget);
    expect(find.text(de.neuKnopf), findsOneWidget);
    expect(find.text(de.weiterplanen), findsNothing);
    expect(
      tester.widget<Image>(
        find.descendant(of: _dialog, matching: find.byType(Image)),
      ),
      isA<Image>()
          .having((b) => b.image, 'Logo', const AssetImage(Kopfzeile.logo))
          .having((b) => b.height, 'Höhe', 72),
    );
  });

  testWidgets('lässt sich nicht durch Tippen daneben schließen', (
    tester,
  ) async {
    await _starte(tester);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(_dialog, findsOneWidget);
  });

  testWidgets('Weg 1: neu konfigurieren schließt den Dialog', (tester) async {
    await _starte(tester);
    await tester.tap(find.byKey(const ValueKey('neu')));
    await tester.pumpAndSettle();
    expect(_dialog, findsNothing);
  });

  testWidgets('Weg 2: Konfiguration laden mit Nummer und Version', (
    tester,
  ) async {
    final geladen = <KonfigurationsStand>[];
    await _starte(tester, geladen: geladen);
    await tester.tap(find.byKey(const ValueKey('laden')));
    await tester.pumpAndSettle();
    expect(_ladenDialog, findsOneWidget);
    // Titel und Knopf heißen gleich (wie im alten Planer).
    expect(find.text(de.ladenTitel), findsNWidgets(2));
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('version'))).data,
      '1',
    );
    final minus = find.byKey(const ValueKey('version-minus'));
    expect(tester.widget<IconButton>(minus).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('version-plus')));
    await tester.tap(find.byKey(const ValueKey('version-plus')));
    await tester.tap(find.byKey(const ValueKey('version-plus')));
    await tester.pump();
    await tester.tap(minus);
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('version'))).data,
      '3',
    );

    await tester.enterText(
      find.byKey(const ValueKey('nummer')),
      ' 2026-10-08-1511 ',
    );
    await tester.tap(find.byKey(const ValueKey('laden-bestaetigen')));
    await tester.pumpAndSettle();
    expect(geladen, [_gefunden]);
    expect(_ladenDialog, findsNothing);
    expect(_dialog, findsNothing);
  });

  testWidgets('Laden prüft das Format', (tester) async {
    final geladen = <KonfigurationsStand>[];
    await _starte(tester, geladen: geladen);
    await tester.tap(find.byKey(const ValueKey('laden')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('nummer')), '2026-10-08');
    await tester.tap(find.byKey(const ValueKey('laden-bestaetigen')));
    await tester.pump();
    expect(find.text(de.nummerFehler), findsOneWidget);
    expect(geladen, isEmpty);

    // Enter im Feld lädt ebenfalls; der Fehlertext verschwindet.
    await tester.enterText(
      find.byKey(const ValueKey('nummer')),
      '2026-10-08-1511',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text(de.nummerFehler), findsNothing);
    expect(geladen, [
      KonfigurationsStand(const Konfigurationsnummer('2026-10-08-1511'), 1),
    ]);
  });

  testWidgets('Ladefehler: Meldung, Dialog bleibt offen', (tester) async {
    final antwort = Completer<void>();
    await _starte(tester, laden: (_) => antwort.future);
    await tester.tap(find.byKey(const ValueKey('laden')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('nummer')),
      '2026-10-08-1511',
    );
    await tester.tap(find.byKey(const ValueKey('laden-bestaetigen')));
    await tester.pump();
    final knopf = find.byKey(const ValueKey('laden-bestaetigen'));
    expect(tester.widget<FilledButton>(knopf).onPressed, isNull);
    antwort.completeError(StateError('nicht gefunden'));
    await tester.pumpAndSettle();
    expect(find.text(de.ladeFehler), findsOneWidget);
    expect(tester.widget<FilledButton>(knopf).onPressed, isNotNull);
    expect(_ladenDialog, findsOneWidget);
    final fehler = tester.widget<Text>(find.text(de.ladeFehler));
    expect(
      fehler.style!.color,
      Theme.of(tester.element(_ladenDialog)).colorScheme.error,
    );
  });

  testWidgets('Zurück schließt nur den Ladedialog', (tester) async {
    await _starte(tester);
    await tester.tap(find.byKey(const ValueKey('laden')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(de.zurueck));
    await tester.pumpAndSettle();
    expect(_ladenDialog, findsNothing);
    expect(_dialog, findsOneWidget);
  });

  testWidgets('Weg 3: gefundene Konfiguration – weiterplanen', (tester) async {
    await _starte(tester, gefunden: _gefunden);
    expect(
      find.text(
        'Wir haben eine Konfiguration gefunden. Möchten Sie mit dieser '
        'weiterplanen? (2026-10-08-1511, Version 3)',
      ),
      findsOneWidget,
    );
    final knopf = find.byKey(const ValueKey('weiterplanen'));
    expect(
      tester.widget<FilledButton>(knopf).style!.backgroundColor!.resolve({}),
      PlanerFarben.gruen,
    );
    await tester.tap(knopf);
    await tester.pumpAndSettle();
    expect(_dialog, findsNothing);
  });

  testWidgets('kein Dialog, wenn die App vorher geschlossen wurde', (
    tester,
  ) async {
    final suche = Completer<KonfigurationsStand?>();
    await tester.pumpWidget(
      PlanerApp(
        hallo: () async => 'ok',
        laden: (_) async {},
        gespeichert: () => suche.future,
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    suche.complete(null);
    await tester.pumpAndSettle();
    expect(_dialog, findsNothing);
  });

  test('Texte', () {
    expect(
      de.willkommenTitel,
      'Willkommen beim RobinienWelt Terrassenkonfigurator!',
    );
    expect(de.konfigurationLadenKnopf, 'KONFIGURATION LADEN');
    expect(de.neuKnopf, 'WUNSCHTERRASSE KONFIGURIEREN');
    expect(de.weiterplanen, 'WEITERPLANEN');
    expect(
      en.gefunden('2026-10-08-1511', 3),
      'We found a configuration. Would you like to continue planning with '
      'it? (2026-10-08-1511, version 3)',
    );
    expect(
      de.willkommenText,
      'Planen Sie Ihre Wunschterrasse aus Robinie mit wenigen Klicks: '
      'Dielen, Verlegung und Unterkonstruktion wählen Sie selbst. Danach '
      'bestellen Sie direkt oder fordern ein Angebot an. Persönliche Hilfe '
      'bekommen Sie in der Video-Beratung.',
    );
    expect(de.nummerFehler, 'Bitte im Format JJJJ-MM-TT-NNNN eingeben');
    expect(de.ladeFehler, 'Die Konfiguration konnte nicht geladen werden.');
    expect(de.zurueck, 'Zurück');
    expect(de.ladenTitel, 'Konfiguration laden');
    expect(de.nummerFeld, 'Konfigurationsnummer');
    expect(de.nummerHinweis, 'z. B. 2026-10-08-1511');
    expect(de.version, 'Version');
    expect(de.ladenTitel, 'Konfiguration laden');
    expect(Startweg.values, [
      Startweg.neu,
      Startweg.geladen,
      Startweg.weiterplanen,
    ]);
  });
}
