import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/anmeldung/anmelde_dialog.dart';
import 'package:terrassenplaner_app/src/anmeldung/mitarbeiter_anmeldung.dart';
import 'package:terrassenplaner_app/src/design/planer_design.dart';
import 'package:terrassenplaner_app/src/konfiguration/konfigurations_steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

Planung _planung(int laenge) => Planung([
  Terrassenflaeche(
    Planungsstand(
      grundriss: RechteckGrundriss(Millimeter(laenge), const Millimeter(3000)),
    ),
  ),
]);

/// Rahmen mit Konfiguration und Anmeldung (M9-10); [breite] ab
/// [Kopfzeile.textAb] mit Beschriftungen.
Future<({KonfigurationsSteuerung k, TestAblage ablage})> _zeige(
  WidgetTester tester,
  MitarbeiterAnmeldung? anmeldung, {
  double breite = 1920,
}) async {
  tester.view
    ..physicalSize = Size(breite, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final ablage = TestAblage();
  final k = KonfigurationsSteuerung(
    ablage: ablage,
    gedaechtnis: testGedaechtnis(),
  );
  addTearDown(k.dispose);
  await tester.pumpWidget(
    testApp(
      theme: planerThema(),
      home: PlanerRahmen(
        status: const Text('Status'),
        konfiguration: k,
        anmeldung: anmeldung,
      ),
    ),
  );
  return (k: k, ablage: ablage);
}

Finder get _anmelden => find.byKey(const ValueKey('anmelden'));
Finder get _abmelden => find.byKey(const ValueKey('abmelden'));
Finder get _dialog => find.byKey(const ValueKey('anmelde-dialog'));
Finder get _email => find.byKey(const ValueKey('anmelden-email'));
Finder get _passwort => find.byKey(const ValueKey('anmelden-passwort'));
Finder get _bestaetigen => find.byKey(const ValueKey('anmelden-bestaetigen'));
Finder get _meldung => find.byKey(const ValueKey('anmelden-meldung'));

String _feld(WidgetTester tester, Finder feld) =>
    tester.widget<TextField>(feld).controller!.text;

Future<void> _oeffneDialog(WidgetTester tester) async {
  await tester.tap(_anmelden);
  await tester.pumpAndSettle();
  expect(_dialog, findsOneWidget);
}

Future<void> _melde(
  WidgetTester tester, {
  String email = 'anna@example.test',
  String passwort = 'richtig',
}) async {
  await tester.enterText(_email, email);
  await tester.enterText(_passwort, passwort);
  await tester.tap(_bestaetigen);
  await tester.pumpAndSettle();
}

void main() {
  test('Anmeldename und Ablehnung', () {
    expect(anmeldename('  Anna@Example.TEST '), 'anna@example.test');
    expect('${const AnmeldungAbgelehnt()}', 'Anmeldung abgelehnt');
  });

  testWidgets('Kopfzeile: ANMELDEN nach ZURÜCKSETZEN, ohne Anmeldung keiner', (
    tester,
  ) async {
    await _zeige(tester, TestAnmeldung());
    expect(find.text(de.anmelden), findsOneWidget);
    expect(
      find.descendant(of: _anmelden, matching: find.byIcon(Icons.login)),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(_anmelden).dx,
      greaterThan(
        tester.getTopLeft(find.byKey(const ValueKey('zuruecksetzen'))).dx,
      ),
    );
    expect(_abmelden, findsNothing);
    expect(find.byKey(const ValueKey('angemeldet-als')), findsNothing);
    await _zeige(tester, null);
    expect(_anmelden, findsNothing);
    expect(_abmelden, findsNothing);
  });

  testWidgets('falsches Passwort: Meldung, Passwortfeld leer', (tester) async {
    final anmeldung = TestAnmeldung();
    await _zeige(tester, anmeldung);
    await _oeffneDialog(tester);
    expect(find.text(de.anmeldenTitel), findsOneWidget);
    expect(find.text(de.anmeldenHinweis), findsOneWidget);
    expect(find.text(de.emailFeld), findsOneWidget);
    expect(find.text(de.passwortFeld), findsOneWidget);
    expect(tester.widget<TextField>(_passwort).obscureText, isTrue);
    expect(tester.widget<TextField>(_email).obscureText, isFalse);
    expect(_meldung, findsNothing);
    await _melde(tester, passwort: 'falsch');
    expect(find.text(de.anmeldungAbgelehnt), findsOneWidget);
    expect(_feld(tester, _passwort), isEmpty);
    expect(_feld(tester, _email), 'anna@example.test');
    expect(anmeldung.versuche, [('anna@example.test', 'falsch')]);
    expect(_dialog, findsOneWidget);
    expect(anmeldung.angemeldetAls.value, isNull);
  });

  testWidgets('Server nicht erreichbar: eigene Meldung', (tester) async {
    final anmeldung = TestAnmeldung()..erreichbar = false;
    await _zeige(tester, anmeldung);
    await _oeffneDialog(tester);
    await _melde(tester);
    expect(find.text(de.anmeldungFehler), findsOneWidget);
    expect(find.text(de.anmeldungAbgelehnt), findsNothing);
    // neuer Versuch leert die alte Meldung
    anmeldung
      ..erreichbar = true
      ..sperre = Completer<void>();
    await tester.enterText(_passwort, 'richtig');
    await tester.tap(_bestaetigen);
    await tester.pump();
    expect(_meldung, findsNothing);
    anmeldung.sperre!.complete();
    await tester.pumpAndSettle();
    expect(_dialog, findsNothing);
  });

  testWidgets('richtig: Dialog zu, ABMELDEN und „Angemeldet als …“', (
    tester,
  ) async {
    final anmeldung = TestAnmeldung();
    await _zeige(tester, anmeldung);
    await _oeffneDialog(tester);
    await _melde(tester, email: ' Anna@Example.test');
    expect(_dialog, findsNothing);
    expect(anmeldung.angemeldetAls.value, 'anna@example.test');
    expect(_anmelden, findsNothing);
    expect(find.text(de.abmelden), findsOneWidget);
    expect(
      find.descendant(of: _abmelden, matching: find.byIcon(Icons.logout)),
      findsOneWidget,
    );
    final angemeldet = find.byKey(const ValueKey('angemeldet-als'));
    expect(
      tester.widget<Text>(angemeldet).data,
      'Angemeldet als anna@example.test',
    );
    // in der Statuszeile
    expect(
      find.descendant(of: find.byType(Statuszeile), matching: angemeldet),
      findsOneWidget,
    );

    await tester.tap(_abmelden);
    await tester.pumpAndSettle();
    expect(anmeldung.angemeldetAls.value, isNull);
    expect(find.text(de.abgemeldetMeldung), findsOneWidget);
    expect(_anmelden, findsOneWidget);
    expect(angemeldet, findsNothing);
  });

  testWidgets('Enter im Passwortfeld meldet an, doppelt nur einmal', (
    tester,
  ) async {
    final anmeldung = TestAnmeldung()..sperre = Completer<void>();
    await _zeige(tester, anmeldung);
    await _oeffneDialog(tester);
    await tester.enterText(_email, 'anna@example.test');
    await tester.enterText(_passwort, 'richtig');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(tester.widget<FilledButton>(_bestaetigen).onPressed, isNull);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(anmeldung.versuche, hasLength(1));
    anmeldung.sperre!.complete();
    await tester.pumpAndSettle();
    expect(_dialog, findsNothing);
    expect(anmeldung.angemeldetAls.value, 'anna@example.test');
  });

  testWidgets('Abbrechen schließt ohne Anmeldung', (tester) async {
    final anmeldung = TestAnmeldung();
    await _zeige(tester, anmeldung);
    await _oeffneDialog(tester);
    await tester.tap(find.text(de.abbrechen));
    await tester.pumpAndSettle();
    expect(_dialog, findsNothing);
    expect(anmeldung.versuche, isEmpty);
  });

  testWidgets('Dialog geschlossen, bevor die Antwort kommt', (tester) async {
    final anmeldung = TestAnmeldung(passwort: 'anders')
      ..sperre = Completer<void>();
    await tester.pumpWidget(testApp(home: AnmeldeDialog(anmeldung: anmeldung)));
    await tester.enterText(_email, 'anna@example.test');
    await tester.enterText(_passwort, 'richtig');
    await tester.tap(_bestaetigen);
    await tester.pump();
    await tester.pumpWidget(testApp(home: const SizedBox()));
    anmeldung.sperre!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('schmal: Symbole, Tooltip mit „Angemeldet als …“', (
    tester,
  ) async {
    final anmeldung = TestAnmeldung();
    await _zeige(tester, anmeldung, breite: 1280);
    expect(find.byTooltip(de.anmelden), findsOneWidget);
    expect(find.text(de.anmelden), findsNothing);
    anmeldung.angemeldetAls.value = 'anna@example.test';
    await tester.pump();
    expect(
      find.byTooltip('Angemeldet als anna@example.test – ${de.abmelden}'),
      findsOneWidget,
    );
    expect(find.text(de.abmelden), findsNothing);
  });

  group('LADEN als Mitarbeiter (M9-10)', () {
    Future<({KonfigurationsSteuerung k, TestAblage ablage})> ladeDialog(
      WidgetTester tester, {
      required bool angemeldet,
    }) async {
      final anmeldung = TestAnmeldung();
      if (angemeldet) anmeldung.angemeldetAls.value = 'anna@example.test';
      final gezeigt = await _zeige(tester, anmeldung);
      await gezeigt.ablage.speichere(_planung(6000));
      await tester.tap(find.byKey(const ValueKey('konfiguration-laden')));
      await tester.pumpAndSettle();
      return gezeigt;
    }

    Future<void> lade(WidgetTester tester, String text) async {
      await tester.enterText(find.byKey(const ValueKey('nummer')), text);
      await tester.tap(find.byKey(const ValueKey('laden-bestaetigen')));
      await tester.pumpAndSettle();
      // Zwischenspeichern nach dem Laden abwarten.
      await tester.pump(const Duration(seconds: 5));
    }

    testWidgets('Nummer ohne Prüfcode genügt', (tester) async {
      final (:k, ablage: _) = await ladeDialog(tester, angemeldet: true);
      expect(find.text(de.nummerHinweisMitarbeiter), findsOneWidget);
      await lade(tester, '2026-11-04-0001');
      expect(find.byKey(const ValueKey('laden-dialog')), findsNothing);
      // vollständige Kennung vom Server gemerkt
      expect(k.stand, stand('2026-11-04-0001-K7QXM', 1));
      expect(k.planung.planung, _planung(6000));
    });

    testWidgets('falscher Prüfcode stört nicht', (tester) async {
      final (:k, ablage: _) = await ladeDialog(tester, angemeldet: true);
      await lade(tester, '2026-11-04-0001-AAAAA');
      expect(find.byKey(const ValueKey('laden-dialog')), findsNothing);
      expect(k.stand, stand('2026-11-04-0001-K7QXM', 1));
    });

    testWidgets('unbekannte Nummer: Meldung', (tester) async {
      await ladeDialog(tester, angemeldet: true);
      await lade(tester, '2026-11-04-0002');
      expect(find.text(de.konfigurationUnbekannt), findsOneWidget);
    });

    testWidgets('Server nicht erreichbar: Ladefehler', (tester) async {
      final (k: _, :ablage) = await ladeDialog(tester, angemeldet: true);
      ablage.erreichbar = false;
      await lade(tester, '2026-11-04-0001');
      expect(find.text(de.ladeFehler), findsOneWidget);
    });

    testWidgets('abgemeldet: ohne Prüfcode unbekannt, kein Hinweis', (
      tester,
    ) async {
      await ladeDialog(tester, angemeldet: false);
      expect(find.text(de.nummerHinweisMitarbeiter), findsNothing);
      await lade(tester, '2026-11-04-0001');
      expect(find.text(de.konfigurationUnbekannt), findsOneWidget);
      await lade(tester, '2026-11-04-0001-K7QXM');
      expect(find.byKey(const ValueKey('laden-dialog')), findsNothing);
    });

    testWidgets('unlesbare Nummer: Feldfehler, auch angemeldet', (
      tester,
    ) async {
      await ladeDialog(tester, angemeldet: true);
      await lade(tester, '2026-13-01-0001');
      expect(find.text(de.nummerFehler), findsOneWidget);
    });
  });
}
