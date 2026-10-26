import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/design/planer_design.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/rahmen/steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/zeichenflaeche.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

/// Unterscheidbarer Planungsstand für Tests (der echte wächst ab M4).
final class _Stand extends Planungsstand {
  const _Stand(this.n) : super.leer();

  final int n;

  @override
  bool operator ==(Object other) => other is _Stand && other.n == n;

  @override
  int get hashCode => n;
}

Future<({PlanungsSteuerung planung, AnsichtSteuerung ansicht})> _zeige(
  WidgetTester tester, {
  Size groesse = const Size(1440, 900),
}) async {
  tester.view
    ..physicalSize = groesse
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final planung = PlanungsSteuerung();
  final ansicht = AnsichtSteuerung();
  addTearDown(planung.dispose);
  addTearDown(ansicht.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: planerThema(),
      home: PlanerRahmen(
        status: const Text('Status'),
        planung: planung,
        ansicht: ansicht,
      ),
    ),
  );
  return (planung: planung, ansicht: ansicht);
}

IconButton _knopf(WidgetTester tester, String schluessel) =>
    tester.widget<IconButton>(find.byKey(ValueKey(schluessel)));

void main() {
  group('PlanungsSteuerung', () {
    test('Rückgängig und Wiederherstellen mit Meldung', () {
      final p = PlanungsSteuerung();
      var meldungen = 0;
      p.addListener(() => meldungen++);
      expect(p.aktuell, const Planungsstand.leer());
      expect([p.kannRueckgaengig, p.kannWiederherstellen], [false, false]);
      p
        ..setze(const _Stand(1))
        ..setze(const _Stand(2));
      expect(p.aktuell, const _Stand(2));
      p.rueckgaengig();
      expect(p.aktuell, const _Stand(1));
      expect([p.kannRueckgaengig, p.kannWiederherstellen], [true, true]);
      p.wiederherstellen();
      expect(p.aktuell, const _Stand(2));
      p.zuruecksetzen();
      expect(p.aktuell, const Planungsstand.leer());
      expect([p.kannRueckgaengig, p.kannWiederherstellen], [false, false]);
      expect(meldungen, 5);
    });

    test('Anfangsstand übergeben', () {
      expect(PlanungsSteuerung(const _Stand(7)).aktuell, const _Stand(7));
    });
  });

  group('AnsichtSteuerung', () {
    test('Grenzen und Schritt', () {
      expect(AnsichtSteuerung.kleinsterZoom, 0.25);
      expect(AnsichtSteuerung.groessterZoom, 4);
      expect(AnsichtSteuerung.schritt, 1.25);
    });

    test('Zoom um die Mitte der Fläche, begrenzt', () {
      final a = AnsichtSteuerung()..flaeche = const Size(800, 600);
      expect([a.zoom, a.verschiebung, a.prozent], [1, Offset.zero, '100 %']);
      a.vergroessern();
      expect(a.zoom, closeTo(1.25, 1e-9));
      // Die Mitte (400, 300) bleibt an ihrer Stelle.
      expect(a.verschiebung.dx, closeTo(400 - 400 * 1.25, 1e-9));
      expect(a.verschiebung.dy, closeTo(300 - 300 * 1.25, 1e-9));
      expect(a.prozent, '125 %');
      a.verkleinern();
      expect(a.zoom, closeTo(1, 1e-9));
      expect(a.verschiebung.dx, closeTo(0, 1e-9));
      a.zoomeAuf(100);
      expect(a.zoom, 4);
      a.zoomeAuf(0.01);
      expect(a.zoom, 0.25);
      expect(a.prozent, '25 %');
      a.zentriere();
      expect([a.zoom, a.verschiebung], [1, Offset.zero]);
    });

    test('Regler logarithmisch zwischen 25 % und 400 %', () {
      final a = AnsichtSteuerung()..flaeche = const Size(800, 600);
      expect(a.reglerWert, closeTo(0.5, 1e-9));
      a.setzeReglerWert(0);
      expect(a.zoom, closeTo(0.25, 1e-9));
      expect(a.reglerWert, closeTo(0, 1e-9));
      a.setzeReglerWert(1);
      expect(a.zoom, closeTo(4, 1e-9));
      a.setzeReglerWert(0.75);
      expect(a.zoom, closeTo(2, 1e-9));
    });

    test('Zoom ohne Fläche um den Ursprung', () {
      final a = AnsichtSteuerung()..vergroessern();
      expect(a.flaeche, Size.zero);
      expect(a.verschiebung, Offset.zero);
    });
  });

  group('RasterMaler', () {
    test('folgt Zoom und Verschiebung', () {
      final a = AnsichtSteuerung()
        ..value = (Matrix4.identity()
          ..translateByDouble(30, -10, 0, 1)
          ..scaleByDouble(2, 2, 1, 1));
      final aufnahme = PictureRecorder();
      final leinwand = _ZaehlendeLeinwand(Canvas(aufnahme));
      RasterMaler(
        ansicht: a,
        abstand: 25,
      ).paint(leinwand, const Size(120, 100));
      aufnahme.endRecording();
      // Schritt 50 px; x ab 30 % 50 = 30, y ab -10 % 50 = 40.
      expect(leinwand.linien, [
        (const Offset(30, 0), const Offset(30, 100)),
        (const Offset(80, 0), const Offset(80, 100)),
        (const Offset(0, 40), const Offset(120, 40)),
        (const Offset(0, 90), const Offset(120, 90)),
      ]);
      expect(
        {for (final f in leinwand.farben) f.toARGB32()},
        {PlanerFarben.linie.toARGB32()},
      );
    });

    test('Ränder: Linien genau auf Breite und Höhe', () {
      final aufnahme = PictureRecorder();
      final leinwand = _ZaehlendeLeinwand(Canvas(aufnahme));
      RasterMaler(
        ansicht: AnsichtSteuerung(),
        abstand: 50,
      ).paint(leinwand, const Size(100, 50));
      aufnahme.endRecording();
      expect(leinwand.linien.length, 3 + 2);
    });

    test('neu zeichnen nur bei anderem Abstand oder anderer Ansicht', () {
      final a = AnsichtSteuerung();
      final maler = RasterMaler(ansicht: a);
      expect(maler.abstand, 40);
      for (final falsch in [0.0, -40.0]) {
        expect(
          () => RasterMaler(ansicht: a, abstand: falsch),
          throwsA(
            isA<ArgumentError>()
                .having((e) => e.name, 'name', 'abstand')
                .having((e) => e.message, 'message', 'muss größer als 0 sein'),
          ),
        );
      }
      expect(maler.shouldRepaint(RasterMaler(ansicht: a)), isFalse);
      expect(maler.shouldRepaint(RasterMaler(ansicht: a, abstand: 20)), isTrue);
      expect(
        maler.shouldRepaint(RasterMaler(ansicht: AnsichtSteuerung())),
        isTrue,
      );
    });
  });

  group('Werkzeugleiste', () {
    testWidgets('Rückgängig/Wiederherstellen nur, wenn möglich', (
      tester,
    ) async {
      final s = await _zeige(tester);
      expect(_knopf(tester, 'rueckgaengig').onPressed, isNull);
      expect(_knopf(tester, 'wiederherstellen').onPressed, isNull);
      s.planung
        ..setze(const _Stand(1))
        ..setze(const _Stand(2));
      await tester.pump();
      expect(_knopf(tester, 'wiederherstellen').onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('rueckgaengig')));
      await tester.pump();
      expect(s.planung.aktuell, const _Stand(1));
      await tester.tap(find.byKey(const ValueKey('wiederherstellen')));
      await tester.pump();
      expect(s.planung.aktuell, const _Stand(2));
      expect(find.byTooltip(Werkzeugleiste.rueckgaengig), findsOneWidget);
      expect(find.byTooltip(Werkzeugleiste.wiederherstellen), findsOneWidget);
    });

    testWidgets('Zoom per Knopf, Regler und Zentrieren', (tester) async {
      final s = await _zeige(tester);
      String prozent() =>
          tester.widget<Text>(find.byKey(const ValueKey('zoom-prozent'))).data!;
      expect(prozent(), '100 %');
      expect(s.ansicht.flaeche.width, greaterThan(0));
      await tester.tap(find.byKey(const ValueKey('vergroessern')));
      await tester.pump();
      expect(prozent(), '125 %');
      await tester.tap(find.byKey(const ValueKey('verkleinern')));
      await tester.tap(find.byKey(const ValueKey('verkleinern')));
      await tester.pump();
      expect(prozent(), '80 %');
      final regler = tester.widget<Slider>(
        find.byKey(const ValueKey('zoom-regler')),
      );
      expect(regler.value, closeTo(s.ansicht.reglerWert, 1e-9));
      expect(regler.label, Werkzeugleiste.zoom);
      regler.onChanged!(1);
      await tester.pump();
      expect(prozent(), '400 %');
      await tester.tap(find.byKey(const ValueKey('zentrieren')));
      await tester.pump();
      expect(prozent(), '100 %');
      expect(s.ansicht.verschiebung, Offset.zero);
      for (final t in [
        Werkzeugleiste.zentrieren,
        Werkzeugleiste.verkleinern,
        Werkzeugleiste.vergroessern,
      ]) {
        expect(find.byTooltip(t), findsOneWidget);
      }
      final hinweis = tester.widget<Text>(find.text(Werkzeugleiste.hinweis));
      expect(
        [hinweis.style!.fontSize, hinweis.style!.color],
        [12, PlanerFarben.text],
      );
    });

    testWidgets('Mausrad zoomt, Ziehen verschiebt', (tester) async {
      final s = await _zeige(tester);
      final mitte = tester.getCenter(
        find.byKey(const ValueKey('zeichenflaeche')),
      );
      await tester.drag(
        find.byKey(const ValueKey('zeichenflaeche')),
        const Offset(120, 80),
      );
      await tester.pumpAndSettle();
      expect(s.ansicht.verschiebung.dx, greaterThan(0));
      expect(s.ansicht.verschiebung.dy, greaterThan(0));
      final maus = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(maus.hover(mitte));
      await tester.sendEventToBinding(maus.scroll(const Offset(0, -200)));
      await tester.pumpAndSettle();
      expect(s.ansicht.zoom, greaterThan(1));
    });

    testWidgets('Tablet: Werkzeugleiste ohne Überlauf', (tester) async {
      await _zeige(tester, groesse: const Size(768, 1024));
      expect(find.byKey(const ValueKey('werkzeugleiste')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Zurücksetzen', () {
    testWidgets('fragt nach; Abbrechen lässt alles, wie es ist', (
      tester,
    ) async {
      final s = await _zeige(tester);
      s.planung.setze(const _Stand(1));
      s.ansicht.vergroessern();
      await tester.tap(find.byKey(const ValueKey('zuruecksetzen')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('zuruecksetzen-dialog')),
        findsOneWidget,
      );
      expect(find.text(ZuruecksetzenDialog.titel), findsOneWidget);
      expect(find.text(ZuruecksetzenDialog.text), findsOneWidget);
      expect(find.text(ZuruecksetzenDialog.zurueck), findsOneWidget);
      expect(find.text(ZuruecksetzenDialog.bestaetigen), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('zuruecksetzen-abbrechen')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('zuruecksetzen-dialog')), findsNothing);
      expect(s.planung.aktuell, const _Stand(1));
      expect(s.ansicht.zoom, closeTo(1.25, 1e-9));
    });

    testWidgets('nur nach Bestätigung: leere Planung, Ansicht zentriert', (
      tester,
    ) async {
      final s = await _zeige(tester);
      s.planung.setze(const _Stand(1));
      s.ansicht.vergroessern();
      await tester.tap(find.byKey(const ValueKey('zuruecksetzen')));
      await tester.pumpAndSettle();
      final knopf = tester.widget<FilledButton>(
        find.byKey(const ValueKey('zuruecksetzen-bestaetigen')),
      );
      expect(
        knopf.style!.backgroundColor!.resolve({}),
        Theme.of(tester.element(find.byType(AlertDialog))).colorScheme.error,
      );
      await tester.tap(find.byKey(const ValueKey('zuruecksetzen-bestaetigen')));
      await tester.pumpAndSettle();
      expect(s.planung.aktuell, const Planungsstand.leer());
      expect(s.planung.kannRueckgaengig, isFalse);
      expect(s.ansicht.zoom, 1);
    });

    testWidgets('Tippen neben den Dialog setzt nicht zurück', (tester) async {
      final s = await _zeige(tester);
      s.planung.setze(const _Stand(1));
      await tester.tap(find.byKey(const ValueKey('zuruecksetzen')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(s.planung.aktuell, const _Stand(1));
    });

    test('Texte', () {
      expect(Kopfzeile.zuruecksetzen, 'ZURÜCKSETZEN');
      expect(ZuruecksetzenDialog.titel, 'Planung zurücksetzen?');
      expect(
        ZuruecksetzenDialog.text,
        'Sind Sie sicher, dass Sie die Planung zurücksetzen möchten? Dadurch '
        'geht Ihr Fortschritt verloren. Stellen Sie sicher, dass Sie die '
        'Konfiguration gespeichert und die Konfigurationsnummer notiert haben.',
      );
      expect(ZuruecksetzenDialog.zurueck, 'Zurück zur Konfiguration');
      expect(ZuruecksetzenDialog.bestaetigen, 'Konfiguration zurücksetzen');
    });
  });

  testWidgets('eigene Steuerungen werden beim Schließen freigegeben', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PlanerRahmen(status: Text('x'))),
    );
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}

class _ZaehlendeLeinwand implements Canvas {
  _ZaehlendeLeinwand(this._ziel);

  final Canvas _ziel;
  final linien = <(Offset, Offset)>[];
  final farben = <Color>[];

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    linien.add((p1, p2));
    farben.add(paint.color);
    _ziel.drawLine(p1, p2, paint);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
