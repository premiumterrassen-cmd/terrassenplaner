import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/design/planer_design.dart';
import 'package:terrassenplaner_app/src/konfiguration/datei_stub.dart';
import 'package:terrassenplaner_app/src/konfiguration/konfigurations_steuerung.dart';
import 'package:terrassenplaner_app/src/konfiguration/planungsunterlagen.dart';
import 'package:terrassenplaner_app/src/rahmen/aktionen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_schritt.dart';
import 'package:terrassenplaner_app/src/rahmen/rahmen_zustand.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

final _v1 = stand('2026-11-04-0001-K7QXM', 1);
final _pdf = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);

/// Aufrufe der Unterlagen und angebotene Dateien.
final class _Aufrufe {
  final geladen = <(KonfigurationsStand, String)>[];
  final angeboten = <(Uint8List, String)>[];

  Unterlagenabruf abruf() => Unterlagenabruf((stand, sprache) async {
    geladen.add((stand, sprache));
    return _pdf;
  }, anbieten: (inhalt, name) => angeboten.add((inhalt, name)));
}

Future<KonfigurationsSteuerung> _zeige(
  WidgetTester tester, {
  TestAblage? ablage,
  Unterlagenabruf? unterlagen,
  RahmenAktionen aktionen = const RahmenAktionen(),
  Locale sprache = const Locale('de'),
}) async {
  tester.view
    ..physicalSize = const Size(1920, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final k = KonfigurationsSteuerung(
    ablage: ablage ?? TestAblage(),
    gedaechtnis: testGedaechtnis(),
  );
  addTearDown(k.dispose);
  final zustand = RahmenZustand();
  for (final s in PlanerSchritt.values) {
    zustand.markiereGeaendert(s);
  }
  await tester.pumpWidget(
    testApp(
      theme: planerThema(),
      sprache: sprache,
      home: PlanerRahmen(
        status: const Text('Status'),
        konfiguration: k,
        zustand: zustand,
        unterlagen: unterlagen,
        aktionen: aktionen,
      ),
    ),
  );
  return k;
}

Future<void> _tippePdf(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('pdf')));
  await tester.pumpAndSettle();
}

void main() {
  test('Dateiname mit Nummer und Version, ohne Prüfcode', () {
    expect(
      Unterlagenabruf.dateiname(_v1),
      'Planungsunterlagen_2026-11-04-0001_V1.pdf',
    );
  });

  test('holen: Stand und Sprache an den Server, PDF anbieten', () async {
    final aufrufe = _Aufrufe();
    await aufrufe.abruf().hole(_v1, 'en');
    expect(aufrufe.geladen, [(_v1, 'en')]);
    expect(aufrufe.angeboten, [
      (_pdf, 'Planungsunterlagen_2026-11-04-0001_V1.pdf'),
    ]);
  });

  test('außerhalb des Browsers kein Download', () {
    expect(() => dateiAnbieten(_pdf, 'x.pdf'), throwsUnsupportedError);
    expect(Unterlagenabruf((_, _) async => _pdf).anbieten, dateiAnbieten);
  });

  testWidgets('PDF: erst speichern, dann die Unterlagen dieser Version', (
    tester,
  ) async {
    final ablage = TestAblage();
    final aufrufe = _Aufrufe();
    final k = await _zeige(tester, ablage: ablage, unterlagen: aufrufe.abruf());
    await _tippePdf(tester);
    expect(k.stand, _v1);
    expect(ablage.versionen.keys, [_v1]);
    expect(aufrufe.geladen, [(_v1, 'de')]);
    expect(aufrufe.angeboten.single.$2, Unterlagenabruf.dateiname(_v1));
    expect(find.text(de.pdfErstellt(_v1.kennung.wert, 1)), findsOneWidget);
    expect(
      de.pdfErstellt(_v1.kennung.wert, 1),
      'Planungsunterlagen zu Konfigurationsnummer 2026-11-04-0001-K7QXM, '
      'Version 1 erstellt.',
    );
    // erneut: wieder mit Speichern (unveränderte Planung gibt auf dem
    // Server keine neue Version, M9-05)
    await _tippePdf(tester);
    expect(aufrufe.geladen.last.$1, k.stand);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('PDF auf Englisch', (tester) async {
    final aufrufe = _Aufrufe();
    await _zeige(
      tester,
      unterlagen: aufrufe.abruf(),
      sprache: const Locale('en'),
    );
    await _tippePdf(tester);
    expect(aufrufe.geladen.single.$2, 'en');
    expect(find.text(en.pdfErstellt(_v1.kennung.wert, 1)), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('PDF ohne Server: Hinweis, nichts angeboten', (tester) async {
    final aufrufe = _Aufrufe();
    await _zeige(
      tester,
      ablage: TestAblage()..erreichbar = false,
      unterlagen: aufrufe.abruf(),
    );
    await _tippePdf(tester);
    expect(find.text(de.pdfFehler), findsOneWidget);
    expect(aufrufe.angeboten, isEmpty);
    expect(en.pdfFehler, startsWith('PDF not possible'));
  });

  testWidgets('eigene PDF-Aktion geht vor, ohne Unterlagen „folgt“', (
    tester,
  ) async {
    final aufrufe = _Aufrufe();
    var eigene = 0;
    await _zeige(
      tester,
      unterlagen: aufrufe.abruf(),
      aktionen: RahmenAktionen(pdf: () async => eigene++),
    );
    await _tippePdf(tester);
    expect(eigene, 1);
    expect(aufrufe.geladen, isEmpty);
    await _zeige(tester);
    await _tippePdf(tester);
    expect(find.text(de.folgt), findsOneWidget);
  });
}
