import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/design/planer_design.dart';
import 'package:terrassenplaner_app/src/rahmen/ansichtsoptionen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/rahmen/steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/zeichenflaeche.dart';
import 'package:terrassenplaner_app/src/rahmen/zeichnung.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

/// Rechteck 4 × 3 m aus dem Prototyp-Modell (M3-10) mit einem Ablauf.
Zeichnung _rechteck() => Zeichnung(
  umriss: const [
    Offset(0, 0),
    Offset(4000, 0),
    Offset(4000, 3000),
    Offset(0, 3000),
  ],
  bauteile: rechteckTerrasse(
    laenge: const Millimeter(4000),
    breite: const Millimeter(3000),
    dielenbreite: const Millimeter(120),
    dielenstaerke: const Millimeter(23),
    ukBreite: const Millimeter(70),
    ukHoehe: const Millimeter(45),
    ukAchsabstand: const Millimeter(400),
  ),
  ablaeufe: const [Offset(2000, 2900)],
);

/// L-Form (Uhrzeigersinn auf dem Bildschirm) mit einspringender Ecke bei D.
const _l = [
  Offset(0, 0),
  Offset(4000, 0),
  Offset(4000, 2000),
  Offset(2000, 2000),
  Offset(2000, 3000),
  Offset(0, 3000),
];

ZeichnungsMaler _maler(
  Zeichnung z,
  AnsichtsOptionen o, [
  AnsichtSteuerung? a,
]) => ZeichnungsMaler(
  zeichnung: z,
  optionen: o,
  ansicht: a ?? AnsichtSteuerung(),
);

List<String> _texte(ZeichnungsMaler m) => [for (final t in m.texte()) t.text];

void main() {
  group('AnsichtsOptionen', () {
    test('anfangs alles an; Ebenen setzen, Beschriftungen schalten', () {
      final o = AnsichtsOptionen();
      var meldungen = 0;
      o.addListener(() => meldungen++);
      expect(o.ebenen, Ebene.values.toSet());
      expect(o.beschriftungen, Beschriftung.values.toSet());
      o.setzeEbenen({Ebene.masse});
      expect([for (final e in Ebene.values) o.zeigt(e)], [false, false, true]);
      o.schalte(Beschriftung.winkel);
      expect(o.beschriftet(Beschriftung.winkel), isFalse);
      expect(o.beschriftet(Beschriftung.punkte), isTrue);
      o.schalte(Beschriftung.winkel);
      expect(o.beschriftet(Beschriftung.winkel), isTrue);
      expect(meldungen, 3);
      expect(o.ebenen.clear, throwsUnsupportedError);
      expect(o.beschriftungen.clear, throwsUnsupportedError);
    });

    test('Titel', () {
      expect([for (final e in Ebene.values) e.titel], ['Belag', 'UK', 'Maße']);
      expect(
        [for (final b in Beschriftung.values) b.titel],
        ['Seitenlängen', 'Winkel', 'Punkte', 'Abläufe'],
      );
    });
  });

  group('ZeichnungsMaler', () {
    test('Ebenen: UK unter dem Belag, jede einzeln abschaltbar', () {
      final z = _rechteck();
      final o = AnsichtsOptionen();
      final m = _maler(z, o);
      final alle = m.rechtecke();
      final uk = z.bauteile.where((b) => b.art == Bauteilart.unterkonstruktion);
      final dielen = z.bauteile.where((b) => b.art == Bauteilart.diele);
      expect(alle.length, uk.length + dielen.length);
      expect(alle.first.$2, ZeichnungsMaler.ukFarbe);
      expect(alle.last.$2, ZeichnungsMaler.belagFarbe);
      o.setzeEbenen({Ebene.belag});
      expect(m.rechtecke().length, dielen.length);
      o.setzeEbenen({Ebene.unterkonstruktion});
      expect(m.rechtecke().length, uk.length);
      expect({for (final r in m.rechtecke()) r.$2}, {ZeichnungsMaler.ukFarbe});
      o.setzeEbenen({});
      expect(m.rechtecke(), isEmpty);
    });

    test('Draufsicht: 1 m = 100 px bei 100 %, folgt Zoom und Verschiebung', () {
      final z = Zeichnung(
        bauteile: [
          Bauteil(
            Bauteilart.diele,
            Quader(
              x: const Millimeter(1000),
              y: const Millimeter(45),
              z: const Millimeter(500),
              laenge: const Millimeter(2000),
              hoehe: const Millimeter(23),
              breite: const Millimeter(120),
            ),
          ),
        ],
      );
      final a = AnsichtSteuerung();
      final m = _maler(z, AnsichtsOptionen(), a);
      expect(m.rechtecke().single.$1, const Rect.fromLTRB(100, 50, 300, 62));
      a.value = Matrix4.identity()
        ..translateByDouble(10, 20, 0, 1)
        ..scaleByDouble(2, 2, 2, 1);
      expect(m.rechtecke().single.$1, const Rect.fromLTRB(210, 120, 610, 144));
      expect(m.bildschirm(const Offset(1000, 0)), const Offset(210, 20));
      expect(pixelJeMm, 0.1);
    });

    test('Beschriftungen: Punkte, Seitenlängen, Winkel, Abläufe, Maße', () {
      final o = AnsichtsOptionen();
      final m = _maler(_rechteck(), o);
      expect(_texte(m), [
        'A', 'B', 'C', 'D', //
        '400 cm', '300 cm', '400 cm', '300 cm',
        '90°', '90°', '90°', '90°',
        'Ablauf',
        '400 cm', '300 cm',
      ]);
      o.schalte(Beschriftung.punkte);
      expect(_texte(m).contains('A'), isFalse);
      o.schalte(Beschriftung.seitenlaengen);
      o.schalte(Beschriftung.winkel);
      o.schalte(Beschriftung.ablaeufe);
      expect(_texte(m), ['400 cm', '300 cm']);
      o.setzeEbenen({});
      expect(_texte(m), isEmpty);
    });

    test('Lage der Texte: Seiten außen, Winkel innen, Punkte außen', () {
      final o = AnsichtsOptionen();
      final texte = _maler(_rechteck(), o).texte();
      Offset ort(String text, [int n = 0]) =>
          texte.where((t) => t.text == text).elementAt(n).ort;
      const d = 6 / 1.4142135623730951;
      expect(ort('A').dx, closeTo(-d, 1e-9));
      expect(ort('A').dy, closeTo(-d, 1e-9));
      expect(ort('C').dx, closeTo(400 + d, 1e-9));
      expect(ort('90°').dx, closeTo(d, 1e-9));
      expect(ort('90°').dy, closeTo(d, 1e-9));
      // Seitenlängen 16 px außen neben der Kantenmitte.
      expect(ort('400 cm'), const Offset(200, -6));
      expect(ort('300 cm'), const Offset(406, 150));
      expect(ort('400 cm', 1), const Offset(200, 306));
      expect(ort('300 cm', 1), const Offset(-6, 150));
      expect(ort('Ablauf'), const Offset(200, 284));
      // Gesamtmaße 44 px unter bzw. rechts neben dem Umriss.
      expect(ort('400 cm', 2), const Offset(200, 344));
      expect(ort('300 cm', 2), const Offset(444, 150));
      expect(ZeichnungsMaler.masslinienAbstand, 44);
      Offset richtung(String text, [int n = 0]) =>
          texte.where((t) => t.text == text).elementAt(n).richtung;
      expect(richtung('400 cm'), const Offset(0, -1));
      expect(richtung('300 cm'), const Offset(1, 0));
      expect(richtung('Ablauf'), const Offset(0, -1));
      expect(richtung('400 cm', 2), const Offset(0, 1));
      expect(richtung('300 cm', 2), const Offset(1, 0));
      expect(richtung('A').dx, closeTo(-1 / 1.4142135623730951, 1e-9));
      expect(richtung('90°').dy, closeTo(1 / 1.4142135623730951, 1e-9));
      expect(ZeichnungsMaler.beschriftungsAbstand, 6);
    });

    test(
      'Richtungen auch bei Gegenrichtung, einspringender und gestreckter Ecke',
      () {
        // L-Form: an der einspringenden Ecke D (2000, 2000) fehlt das Stück
        // rechts unten – die Fläche liegt links oben.
        final innenD = ZeichnungsMaler.innen(_l, 3);
        expect(innenD.dx, closeTo(-1 / 1.4142135623730951, 1e-9));
        expect(innenD.dy, closeTo(-1 / 1.4142135623730951, 1e-9));
        final rueckwaerts = _l.reversed.toList();
        // Kante F→E (Gegenrichtung, unten entlang) zeigt nach außen: unten.
        expect(ZeichnungsMaler.aussen(rueckwaerts, 0), const Offset(0, 1));
        expect(ZeichnungsMaler.aussen(_l, 0), const Offset(0, -1));
        const gestreckt = [
          Offset(0, 0),
          Offset(1000, 0),
          Offset(2000, 0),
          Offset(2000, 1000),
          Offset(0, 1000),
        ];
        expect(ZeichnungsMaler.innenwinkel(gestreckt, 1), closeTo(180, 1e-9));
        expect(ZeichnungsMaler.innen(gestreckt, 1), const Offset(0, 1));
      },
    );

    test('Innenwinkel auch an einspringenden Ecken, beide Richtungen', () {
      expect(
        [
          for (var i = 0; i < _l.length; i++)
            ZeichnungsMaler.innenwinkel(_l, i).round(),
        ],
        [90, 90, 90, 270, 90, 90],
      );
      final rueckwaerts = _l.reversed.toList();
      expect(
        [
          for (var i = 0; i < rueckwaerts.length; i++)
            ZeichnungsMaler.innenwinkel(rueckwaerts, i).round(),
        ],
        [90, 90, 270, 90, 90, 90],
      );
      const dreieck = [Offset(0, 0), Offset(3000, 0), Offset(0, 4000)];
      expect(
        [for (var i = 0; i < 3; i++) ZeichnungsMaler.innenwinkel(dreieck, i)],
        [closeTo(90, 1e-9), closeTo(53.13, 0.01), closeTo(36.87, 0.01)],
      );
    });

    test('Text liegt vom Anker aus in seiner Richtung', () {
      const groesse = Size(40, 10);
      const anker = Offset(100, 100);
      expect(
        ZeichnungsMaler.textLage(anker, Offset.zero, groesse),
        const Offset(80, 95),
      );
      expect(
        ZeichnungsMaler.textLage(anker, const Offset(1, 0), groesse),
        const Offset(100, 95),
      );
      expect(
        ZeichnungsMaler.textLage(anker, const Offset(0, -1), groesse),
        const Offset(80, 90),
      );
      expect(
        ZeichnungsMaler.textLage(anker, const Offset(-1, 1), groesse),
        const Offset(60, 100),
      );
    });

    test('Zentimeter und Punktnamen', () {
      expect(ZeichnungsMaler.zentimeter(4800), '480 cm');
      expect(ZeichnungsMaler.zentimeter(125), '12,5 cm');
      expect(ZeichnungsMaler.zentimeter(1234.4), '123,4 cm');
      expect(ZeichnungsMaler.zentimeter(1239.6), '124 cm');
      expect(
        [
          for (final i in [0, 1, 25, 26]) ZeichnungsMaler.punktname(i),
        ],
        ['A', 'B', 'Z', 'A'],
      );
      expect(ZeichnungsMaler.ablaufText, 'Ablauf');
    });

    test('leere Zeichnung: nichts zu zeichnen, keine Maße', () {
      final m = _maler(Zeichnung.leer, AnsichtsOptionen());
      expect([m.rechtecke(), m.texte()], [isEmpty, isEmpty]);
      final aufnahme = PictureRecorder();
      final leinwand = _ZaehlendeLeinwand(Canvas(aufnahme));
      m.paint(leinwand, const Size(100, 100));
      aufnahme.endRecording();
      expect(leinwand.aufrufe, isEmpty);
    });

    test('paint: Rechtecke, Umriss, Abläufe und Texte', () {
      final o = AnsichtsOptionen();
      final z = _rechteck();
      final m = _maler(z, o);
      Map<String, int> zeichne() {
        final aufnahme = PictureRecorder();
        final leinwand = _ZaehlendeLeinwand(Canvas(aufnahme));
        m.paint(leinwand, const Size(800, 600));
        aufnahme.endRecording();
        return leinwand.aufrufe;
      }

      expect(zeichne(), {
        'drawRect': z.bauteile.length * 2,
        'drawPath': 1,
        'drawCircle': 1,
        'drawParagraph': 15,
      });
      o
        ..schalte(Beschriftung.ablaeufe)
        ..setzeEbenen({Ebene.belag});
      final ohne = zeichne();
      expect(ohne['drawCircle'], isNull);
      expect(ohne['drawParagraph'], 12);
    });

    test('paint: Füllung, Rand und Textlage', () {
      final z = Zeichnung(
        umriss: const [Offset(0, 0), Offset(1000, 0), Offset(1000, 1000)],
        bauteile: [_rechteck().bauteile.last],
      );
      final m = _maler(z, AnsichtsOptionen());
      final aufnahme = PictureRecorder();
      final leinwand = _ZaehlendeLeinwand(Canvas(aufnahme));
      m.paint(leinwand, const Size(800, 600));
      aufnahme.endRecording();
      final [fuellung, rand] = leinwand.stifte;
      expect(fuellung.color.toARGB32(), ZeichnungsMaler.belagFarbe.toARGB32());
      expect(fuellung.style, PaintingStyle.fill);
      expect(rand.style, PaintingStyle.stroke);
      expect(rand.color.a, closeTo(0.3, 0.01));
      final erster = m.texte().first;
      final maler = TextPainter(
        text: TextSpan(
          text: erster.text,
          style: const TextStyle(fontSize: 12, color: PlanerFarben.text),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      expect(
        leinwand.textOrte.first,
        ZeichnungsMaler.textLage(erster.ort, erster.richtung, maler.size),
      );
    });

    test('Zeichnung ist unveränderlich', () {
      final z = _rechteck();
      expect(z.umriss.clear, throwsUnsupportedError);
      expect(z.bauteile.clear, throwsUnsupportedError);
      expect(z.ablaeufe.clear, throwsUnsupportedError);
    });

    test('neu zeichnen bei anderer Zeichnung, Optionen oder Ansicht', () {
      final z = _rechteck();
      final o = AnsichtsOptionen();
      final a = AnsichtSteuerung();
      final m = _maler(z, o, a);
      expect(m.shouldRepaint(_maler(z, o, a)), isFalse);
      expect(m.shouldRepaint(_maler(_rechteck(), o, a)), isTrue);
      expect(m.shouldRepaint(_maler(z, AnsichtsOptionen(), a)), isTrue);
      expect(m.shouldRepaint(_maler(z, o, AnsichtSteuerung())), isTrue);
    });
  });

  group('Bedienung', () {
    Future<AnsichtsOptionen> zeige(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(1440, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final o = AnsichtsOptionen();
      addTearDown(o.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: planerThema(),
          home: PlanerRahmen(
            status: const Text('x'),
            optionen: o,
            zeichnung: _rechteck(),
          ),
        ),
      );
      return o;
    }

    ZeichnungsMaler maler(WidgetTester tester) =>
        tester
                .widget<CustomPaint>(find.byKey(const ValueKey('zeichnung')))
                .painter!
            as ZeichnungsMaler;

    testWidgets('Ebenen-Schalter wirkt sofort auf die Zeichnung', (
      tester,
    ) async {
      final o = await zeige(tester);
      final vorher = maler(tester).rechtecke().length;
      await tester.tap(find.text('Belag'));
      await tester.pump();
      expect(o.zeigt(Ebene.belag), isFalse);
      expect(maler(tester).rechtecke().length, lessThan(vorher));
      await tester.tap(find.text('Maße'));
      await tester.pump();
      expect(o.zeigt(Ebene.masse), isFalse);
      await tester.tap(find.text('Belag'));
      await tester.pump();
      expect(o.ebenen, {Ebene.belag, Ebene.unterkonstruktion});
      final schalter = tester.widget<SegmentedButton<Ebene>>(
        find.byKey(const ValueKey('ebenen')),
      );
      expect(
        [
          schalter.multiSelectionEnabled,
          schalter.emptySelectionAllowed,
          schalter.showSelectedIcon,
        ],
        [true, true, false],
      );
    });

    testWidgets('Beschriftungen per Menü ein- und ausschalten', (tester) async {
      final o = await zeige(tester);
      await tester.tap(find.byKey(const ValueKey('beschriftungen')));
      await tester.pumpAndSettle();
      for (final b in Beschriftung.values) {
        final eintrag = tester.widget<CheckedPopupMenuItem<Beschriftung>>(
          find.byKey(ValueKey('beschriftung-${b.name}')),
        );
        expect([eintrag.checked, eintrag.value], [true, b]);
      }
      await tester.tap(find.text('Winkel'));
      await tester.pumpAndSettle();
      expect(o.beschriftet(Beschriftung.winkel), isFalse);
      expect(maler(tester).texte().any((t) => t.text == '90°'), isFalse);
      await tester.tap(find.byKey(const ValueKey('beschriftungen')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckedPopupMenuItem<Beschriftung>>(
              find.byKey(const ValueKey('beschriftung-winkel')),
            )
            .checked,
        isFalse,
      );
      expect(find.byTooltip(Werkzeugleiste.beschriftungen), findsOneWidget);
    });

    testWidgets('genau 1000 px Leiste: mit Regler und Hinweis', (tester) async {
      // 1340 − 320 (Menü) − 20 (Griff) = 1000 px für die Werkzeugleiste.
      tester.view
        ..physicalSize = const Size(1340, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(home: PlanerRahmen(status: Text('x'))),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('werkzeugleiste'))).width,
        1000,
      );
      expect(find.byKey(const ValueKey('zoom-regler')), findsOneWidget);
    });

    testWidgets('schmal: ohne Regler und Hinweis', (tester) async {
      tester.view
        ..physicalSize = const Size(900, 700)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(home: PlanerRahmen(status: Text('x'))),
      );
      expect(find.byKey(const ValueKey('zoom-regler')), findsNothing);
      expect(find.text(Werkzeugleiste.hinweis), findsNothing);
      expect(find.byKey(const ValueKey('ebenen')), findsOneWidget);
      expect(Werkzeugleiste.breitAb, 1000);
      expect(tester.takeException(), isNull);
    });
  });
}

class _ZaehlendeLeinwand implements Canvas {
  _ZaehlendeLeinwand(this._ziel);

  final Canvas _ziel;
  final aufrufe = <String, int>{};
  final stifte = <Paint>[];
  final textOrte = <Offset>[];

  void _zaehle(String name) => aufrufe[name] = (aufrufe[name] ?? 0) + 1;

  @override
  void drawRect(Rect rect, Paint paint) {
    _zaehle('drawRect');
    stifte.add(paint);
    _ziel.drawRect(rect, paint);
  }

  @override
  void drawPath(Path path, Paint paint) {
    _zaehle('drawPath');
    _ziel.drawPath(path, paint);
  }

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    _zaehle('drawCircle');
    _ziel.drawCircle(c, radius, paint);
  }

  @override
  void drawParagraph(Paragraph paragraph, Offset offset) {
    _zaehle('drawParagraph');
    textOrte.add(offset);
    _ziel.drawParagraph(paragraph, offset);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
