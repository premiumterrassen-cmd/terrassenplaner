import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/planer_app.dart';
import 'package:terrassenplaner_app/src/design/planer_design.dart';
import 'package:terrassenplaner_app/src/einstellungen/lokale_einstellungen.dart';
import 'package:terrassenplaner_app/src/konfiguration/konfigurations_steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/start/eingangsdialog.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

final _gefunden = stand('2026-10-08-1511-K7QXM', 3);

/// App mit Eingangsdialog über [ablage] und [gedaechtnis].
Future<void> _starte(
  WidgetTester tester, {
  KonfigurationsAblage? ablage,
  LokaleEinstellungen? gedaechtnis,
}) async {
  tester.view
    ..physicalSize = const Size(1440, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    PlanerApp(
      hallo: () async => 'ok',
      ablage: ablage ?? TestAblage(),
      gedaechtnis: gedaechtnis ?? testGedaechtnis(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Planung der App (über die Steuerung des Rahmens).
Planung _planung(WidgetTester tester) => tester
    .widget<PlanerRahmen>(find.byType(PlanerRahmen))
    .konfiguration!
    .planung
    .planung;

/// Gespeicherte Planung mit einer Fläche von [laenge] mm.
Planung _gespeichert(int laenge) => Planung([
  Terrassenflaeche(
    Planungsstand(
      grundriss: RechteckGrundriss(Millimeter(laenge), const Millimeter(3000)),
    ),
  ),
]);

/// Ablage, deren Laden erst mit [antwort] endet.
class _WartendeAblage extends TestAblage {
  final antwort = Completer<Planung>();

  @override
  Future<Planung> lade(KonfigurationsStand stand) => antwort.future;
}

/// Ablage, die ihre Ladeaufrufe zählt.
class _ZaehlendeAblage extends TestAblage {
  var ladeAufrufe = 0;

  @override
  Future<Planung> lade(KonfigurationsStand stand) {
    ladeAufrufe++;
    return super.lade(stand);
  }
}

/// Ablage, deren Suche nach dem Entwurf erst mit [sucheFertig] endet.
class _WartendeSuche extends TestAblage {
  final sucheFertig = Completer<void>();

  @override
  Future<PlanungsEntwurf?> entwurf(String schluessel) async {
    await sucheFertig.future;
    return null;
  }
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
    final ablage = TestAblage();
    ablage.versionen[_gefunden] = _gespeichert(6000);
    final gedaechtnis = testGedaechtnis();
    await _starte(tester, ablage: ablage, gedaechtnis: gedaechtnis);
    await tester.tap(find.byKey(const ValueKey('laden')));
    await tester.pumpAndSettle();
    expect(_ladenDialog, findsOneWidget);
    // Titel und Knopf heißen gleich (wie im alten Planer).
    expect(find.text(de.ladenTitel), findsNWidgets(2));
    // beim Start ohne „Konfiguration Speichern“ und ohne Vorbelegung
    expect(find.byKey(const ValueKey('laden-speichern')), findsNothing);
    expect(find.text(de.konfigurationSpeichernKnopf), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('nummer')))
          .controller!
          .text,
      isEmpty,
    );
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

    // Kleinbuchstaben und Leerzeichen sind erlaubt (M9-05b)
    await tester.enterText(
      find.byKey(const ValueKey('nummer')),
      ' 2026 10 08 1511 k7qxm ',
    );
    await tester.tap(find.byKey(const ValueKey('laden-bestaetigen')));
    await tester.pumpAndSettle();
    expect(_ladenDialog, findsNothing);
    expect(_dialog, findsNothing);
    // geladen ist identisch zur gespeicherten Planung und wird gemerkt
    expect(_planung(tester), _gespeichert(6000));
    expect(gedaechtnis.letzteKonfiguration(), _gefunden);
  });

  testWidgets('Laden prüft das Format', (tester) async {
    final ablage = TestAblage();
    ablage.versionen[stand('2026-10-08-1511-K7QXM', 1)] = _gespeichert(7000);
    await _starte(tester, ablage: ablage);
    await tester.tap(find.byKey(const ValueKey('laden')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('nummer')), '2026-10-08');
    await tester.tap(find.byKey(const ValueKey('laden-bestaetigen')));
    await tester.pump();
    expect(find.text(de.nummerFehler), findsOneWidget);
    expect(_planung(tester), Planung.start);

    // Enter im Feld lädt ebenfalls; der Fehlertext verschwindet.
    await tester.enterText(
      find.byKey(const ValueKey('nummer')),
      '2026-10-08-1511-K7QXM',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text(de.nummerFehler), findsNothing);
    expect(_planung(tester), _gespeichert(7000));
  });

  testWidgets('unbekannte Nummer oder Version: eigene Meldung', (tester) async {
    await _starte(tester);
    await tester.tap(find.byKey(const ValueKey('laden')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('nummer')),
      '2026-10-08-1511-K7QXM',
    );
    await tester.tap(find.byKey(const ValueKey('laden-bestaetigen')));
    await tester.pumpAndSettle();
    expect(find.text(de.konfigurationUnbekannt), findsOneWidget);
    expect(find.text(de.ladeFehler), findsNothing);
    expect(_ladenDialog, findsOneWidget);
  });

  testWidgets('falscher oder fehlender Prüfcode: wie unbekannt (M9-05b)', (
    tester,
  ) async {
    final ablage = _ZaehlendeAblage();
    ablage.versionen[_gefunden] = _gespeichert(5000);
    await _starte(tester, ablage: ablage);
    await tester.tap(find.byKey(const ValueKey('laden')));
    await tester.pumpAndSettle();
    final feld = find.byKey(const ValueKey('nummer'));
    // falscher Code: der Server antwortet „unbekannt“
    await tester.enterText(feld, '2026-10-08-1511-K7QXN');
    await tester.tap(find.byKey(const ValueKey('laden-bestaetigen')));
    await tester.pumpAndSettle();
    expect(find.text(de.konfigurationUnbekannt), findsOneWidget);
    expect(ablage.ladeAufrufe, 1);
    // fehlender oder falsch geschriebener Code: dieselbe Meldung, ohne Server
    for (final text in ['2026-10-08-1511', '2026-10-08-1511-K7Q0M']) {
      await tester.enterText(feld, '2026-10-08');
      await tester.tap(find.byKey(const ValueKey('laden-bestaetigen')));
      await tester.pump();
      expect(find.text(de.nummerFehler), findsOneWidget);
      final aufrufe = ablage.ladeAufrufe;
      await tester.enterText(feld, text);
      await tester.tap(find.byKey(const ValueKey('laden-bestaetigen')));
      await tester.pump();
      expect(
        find.text(de.konfigurationUnbekannt),
        findsOneWidget,
        reason: text,
      );
      expect(find.text(de.nummerFehler), findsNothing, reason: text);
      expect(ablage.ladeAufrufe, aufrufe, reason: text);
    }
    expect(_planung(tester), Planung.start);
    expect(_ladenDialog, findsOneWidget);
  });

  testWidgets('Ladefehler: Meldung, Dialog bleibt offen', (tester) async {
    final ablage = _WartendeAblage();
    await _starte(tester, ablage: ablage);
    await tester.tap(find.byKey(const ValueKey('laden')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('nummer')),
      '2026-10-08-1511-K7QXM',
    );
    await tester.tap(find.byKey(const ValueKey('laden-bestaetigen')));
    await tester.pump();
    final knopf = find.byKey(const ValueKey('laden-bestaetigen'));
    expect(tester.widget<FilledButton>(knopf).onPressed, isNull);
    ablage.antwort.completeError(StateError('keine Verbindung'));
    await tester.pumpAndSettle();
    expect(find.text(de.ladeFehler), findsOneWidget);
    expect(tester.widget<FilledButton>(knopf).onPressed, isNotNull);
    expect(_ladenDialog, findsOneWidget);
    final fehler = tester.widget<Text>(find.text(de.ladeFehler));
    expect(
      fehler.style!.color,
      Theme.of(tester.element(_ladenDialog)).colorScheme.error,
    );
    expect(_planung(tester), Planung.start);
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

  testWidgets('Weg 3: gemerkte Konfiguration – weiterplanen lädt sie', (
    tester,
  ) async {
    final ablage = TestAblage();
    ablage.versionen[_gefunden] = _gespeichert(5000);
    final gedaechtnis = testGedaechtnis()..merke(_gefunden);
    await _starte(tester, ablage: ablage, gedaechtnis: gedaechtnis);
    expect(
      find.text(
        'Wir haben eine Konfiguration gefunden. Möchten Sie mit dieser '
        'weiterplanen? (2026-10-08-1511-K7QXM, Version 3)',
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
    expect(_planung(tester), _gespeichert(5000));
  });

  testWidgets('Weg 3: ungespeicherter Entwurf – weiterplanen', (tester) async {
    final ablage = TestAblage();
    final gedaechtnis = testGedaechtnis();
    ablage.entwuerfe[gedaechtnis.sitzungsschluessel()] = (
      planung: _gespeichert(4400),
      bezug: null,
    );
    await _starte(tester, ablage: ablage, gedaechtnis: gedaechtnis);
    expect(find.text(de.gefundenEntwurf), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('weiterplanen')));
    await tester.pumpAndSettle();
    expect(_planung(tester), _gespeichert(4400));
  });

  testWidgets('Weiterplanen ohne Server: Hinweis, leere Planung', (
    tester,
  ) async {
    final ablage = TestAblage()..erreichbar = false;
    await _starte(
      tester,
      ablage: ablage,
      gedaechtnis: testGedaechtnis()..merke(_gefunden),
    );
    await tester.tap(find.byKey(const ValueKey('weiterplanen')));
    await tester.pumpAndSettle();
    expect(_dialog, findsNothing);
    expect(find.text(de.ladeFehler), findsOneWidget);
    expect(_planung(tester), Planung.start);
  });

  testWidgets('kein Dialog, wenn die App vorher geschlossen wurde', (
    tester,
  ) async {
    final ablage = _WartendeSuche();
    await tester.pumpWidget(
      PlanerApp(
        hallo: () async => 'ok',
        ablage: ablage,
        gedaechtnis: testGedaechtnis(),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    ablage.sucheFertig.complete();
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
      en.gefunden('2026-10-08-1511-K7QXM', 3),
      'We found a configuration. Would you like to continue planning with '
      'it? (2026-10-08-1511-K7QXM, version 3)',
    );
    expect(
      de.willkommenText,
      'Planen Sie Ihre Wunschterrasse aus Robinie mit wenigen Klicks: '
      'Dielen, Verlegung und Unterkonstruktion wählen Sie selbst. Danach '
      'bestellen Sie direkt oder fordern ein Angebot an. Persönliche Hilfe '
      'bekommen Sie in der Video-Beratung.',
    );
    expect(de.nummerFehler, 'Bitte im Format JJJJ-MM-TT-NNNN-XXXXX eingeben');
    expect(en.nummerFehler, 'Please enter in the format YYYY-MM-DD-NNNN-XXXXX');
    expect(
      de.ladeFehler,
      'Die Konfiguration konnte nicht geladen werden – der Server ist nicht '
      'erreichbar.',
    );
    expect(
      de.konfigurationUnbekannt,
      'Diese Konfiguration gibt es nicht. Bitte prüfen Sie '
      'Konfigurationsnummer, Prüfcode und Version.',
    );
    expect(de.konfigurationSpeichernKnopf, 'Konfiguration Speichern');
    expect(
      de.gefundenEntwurf,
      'Wir haben eine ungespeicherte Konfiguration gefunden. Möchten Sie mit '
      'dieser weiterplanen?',
    );
    expect(
      en.konfigurationUnbekannt,
      'This configuration does not exist. Please check the configuration '
      'number, check code and version.',
    );
    expect(de.zurueck, 'Zurück');
    expect(de.ladenTitel, 'Konfiguration laden');
    expect(de.nummerFeld, 'Konfigurationsnummer mit Prüfcode');
    expect(de.nummerHinweis, 'z. B. 2026-10-08-1511-K7QXM');
    expect(en.nummerFeld, 'Configuration number with check code');
    expect(en.nummerHinweis, 'e.g. 2026-10-08-1511-K7QXM');
    expect(de.version, 'Version');
    expect(de.ladenTitel, 'Konfiguration laden');
    expect(Startweg.values, [
      Startweg.neu,
      Startweg.geladen,
      Startweg.weiterplanen,
    ]);
  });
}
