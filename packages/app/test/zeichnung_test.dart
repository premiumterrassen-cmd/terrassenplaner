import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/design/planer_design.dart';
import 'package:terrassenplaner_app/src/rahmen/ansichtsoptionen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/rahmen/steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/zeichenflaeche.dart';
import 'package:terrassenplaner_app/src/rahmen/zeichnung.dart';
import 'package:terrassenplaner_app/src/sprache/sprache.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

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
  PlanerTexte? sprache,
]) => ZeichnungsMaler(
  zeichnung: z,
  optionen: o,
  ansicht: a ?? AnsichtSteuerung(),
  sprache: sprache ?? de,
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
      expect(
        [for (final e in Ebene.values) e.titel(de)],
        ['Belag', 'UK', 'Maße'],
      );
      expect(
        [for (final b in Beschriftung.values) b.titel(de)],
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
      final maler = _maler(Zeichnung.leer, AnsichtsOptionen());
      expect(maler.zentimeter(4800), '480 cm');
      expect(maler.zentimeter(125), '12,5 cm');
      expect(maler.zentimeter(1234.4), '123,4 cm');
      expect(maler.zentimeter(1239.6), '124 cm');
      final englisch = _maler(Zeichnung.leer, AnsichtsOptionen(), null, en);
      expect(englisch.zentimeter(125), '12.5 cm');
      expect(
        [
          for (final i in [0, 1, 25, 26]) ZeichnungsMaler.punktname(i),
        ],
        ['A', 'B', 'Z', 'A'],
      );
      expect(de.ablauf, 'Ablauf');
    });

    test('Dielenstücke (M5-05): auf der Ebene Belag, im Zoom', () {
      final z = Zeichnung(
        dielen: const [
          [Offset(0, 0), Offset(1000, 0), Offset(1000, 65), Offset(0, 65)],
          [Offset(1000, 0), Offset(2000, 0), Offset(2000, 65)],
        ],
      );
      final o = AnsichtsOptionen();
      final a = AnsichtSteuerung();
      final m = _maler(z, o, a);
      expect(z.dielen, hasLength(2));
      expect(() => z.dielen.add(const []), throwsUnsupportedError);
      final [erste, zweite] = m.dielenpfade();
      expect(erste.getBounds(), const Rect.fromLTRB(0, 0, 100, 6.5));
      expect(zweite.getBounds(), const Rect.fromLTRB(100, 0, 200, 6.5));
      o.setzeEbenen({Ebene.unterkonstruktion});
      expect(m.dielenpfade(), isEmpty);
      o.setzeEbenen({Ebene.belag});
      final aufnahme = PictureRecorder();
      final leinwand = _ZaehlendeLeinwand(Canvas(aufnahme));
      m.paint(leinwand, const Size(800, 600));
      aufnahme.endRecording();
      expect(leinwand.aufrufe, {'drawPath': 4});
      final [fuellung, fuge, ...] = leinwand.pfadStifte;
      expect(fuellung.color.toARGB32(), ZeichnungsMaler.belagFarbe.toARGB32());
      expect(fuge.style, PaintingStyle.stroke);
      expect(fuge.color.a, closeTo(0.3, 0.01));
    });

    test('Dielenstücke mit Rand in der Farbe der Stückliste (M9-04)', () {
      const rot = Color(0xFFD32F2F);
      final z = Zeichnung(
        dielen: const [
          [Offset(0, 0), Offset(1000, 0), Offset(1000, 65)],
          [Offset(1000, 0), Offset(2000, 0), Offset(2000, 65)],
        ],
        dielenfarben: const [rot],
      );
      expect(() => z.dielenfarben.add(rot), throwsUnsupportedError);
      final m = _maler(z, AnsichtsOptionen());
      expect(m.dielenrand(0), rot);
      expect(m.dielenrand(1), isNull);
      final aufnahme = PictureRecorder();
      final leinwand = _ZaehlendeLeinwand(Canvas(aufnahme));
      m.paint(leinwand, const Size(800, 600));
      aufnahme.endRecording();
      final [_, rand, _, fuge, ...] = leinwand.pfadStifte;
      expect(rand.color.toARGB32(), rot.toARGB32());
      expect(rand.style, PaintingStyle.stroke);
      expect(rand.strokeWidth, 1.5);
      expect(fuge.color.a, closeTo(0.3, 0.01));
    });

    test('Querstreben (M6-06): grün über dem Belag, nur mit der Ebene UK', () {
      final z = Zeichnung(
        dielen: const [
          [Offset(0, 0), Offset(1000, 0), Offset(1000, 65)],
        ],
        querstreben: const [(Offset(20, 500), Offset(380, 500))],
      );
      expect(
        () => z.querstreben.add((Offset.zero, Offset.zero)),
        throwsUnsupportedError,
      );
      final o = AnsichtsOptionen();
      final a = AnsichtSteuerung();
      final m = _maler(z, o, a);
      expect(m.strebenlinien(), [
        (
          a.verschiebung + const Offset(2, 50),
          a.verschiebung + const Offset(38, 50),
        ),
      ]);
      final aufnahme = PictureRecorder();
      final leinwand = _ZaehlendeLeinwand(Canvas(aufnahme));
      m.paint(leinwand, const Size(800, 600));
      aufnahme.endRecording();
      final strebe = leinwand.linienStifte.singleWhere(
        (p) => p.strokeWidth == 3,
      );
      expect(strebe.color.toARGB32(), ZeichnungsMaler.strebenFarbe.toARGB32());
      expect(ZeichnungsMaler.strebenFarbe.toARGB32(), Stueckfarbe.gruen.argb);
      o.setzeEbenen({Ebene.belag});
      expect(m.strebenlinien(), isEmpty);
    });

    test('UK-Hölzer (M6-10): in der Farbe der Stückliste, so breit wie die '
        'UK, halb durchsichtig über dem Belag, nur mit der Ebene UK', () {
      final rot = Color(Stueckfarbe.rot.argb);
      final z = Zeichnung(
        ukHoelzer: [(const Offset(20, 0), const Offset(20, 3090), rot)],
        ukBreite: 40,
      );
      expect(
        () => z.ukHoelzer.add((Offset.zero, Offset.zero, rot)),
        throwsUnsupportedError,
      );
      final o = AnsichtsOptionen();
      final a = AnsichtSteuerung();
      final m = _maler(z, o, a);
      final [(von, bis, farbe, breite)] = m.holzlinien();
      expect(von, a.verschiebung + const Offset(2, 0));
      expect(bis, a.verschiebung + const Offset(2, 309));
      expect(farbe.toARGB32(), rot.withValues(alpha: 0.6).toARGB32());
      expect(ZeichnungsMaler.holzDeckkraft, 0.6);
      expect(breite, 4);
      final aufnahme = PictureRecorder();
      final leinwand = _ZaehlendeLeinwand(Canvas(aufnahme));
      m.paint(leinwand, const Size(800, 600));
      aufnahme.endRecording();
      expect(
        leinwand.linienStifte.where((p) => p.strokeWidth == 4),
        hasLength(1),
      );
      // weit herausgezoomt mindestens 1 Pixel
      a.zoomeAuf(AnsichtSteuerung.kleinsterZoom);
      final schmal = _maler(
        Zeichnung(
          ukHoelzer: [(const Offset(20, 0), const Offset(20, 3090), rot)],
          ukBreite: 20,
        ),
        o,
        a,
      );
      expect(schmal.holzlinien().single.$4, 1);
      expect(m.holzlinien().single.$4, 1);
      expect(Zeichnung.leer.ukBreite, 0);
      o.setzeEbenen({Ebene.belag});
      expect(m.holzlinien(), isEmpty);
    });

    test('Auflager (M6-11): Quadrate, rot ohne passendes Auflager, Spalt ab '
        '150 % Zoom, nur mit der Ebene UK', () {
      final z = Zeichnung(
        auflager: const [
          (Offset(20, 0), Millimeter(45), true),
          (Offset(20, 515), Millimeter(300), false),
        ],
      );
      expect(
        () => z.auflager.add((Offset.zero, const Millimeter(0), true)),
        throwsUnsupportedError,
      );
      final o = AnsichtsOptionen();
      final a = AnsichtSteuerung();
      final m = _maler(z, o, a);
      final [(ort, farbe, text), (_, rot, _)] = m.auflagerpunkte();
      expect(ort, a.verschiebung + const Offset(2, 0));
      expect(farbe, ZeichnungsMaler.auflagerFarbe);
      expect(rot.toARGB32(), Stueckfarbe.rot.argb);
      expect(ZeichnungsMaler.ohneFarbe.toARGB32(), Stueckfarbe.rot.argb);
      expect(text, isNull);
      expect(ZeichnungsMaler.hoeheAbZoom, 1.5);
      expect(ZeichnungsMaler.auflagerGroesse, 6);
      a.zoomeAuf(1.5);
      expect(m.auflagerpunkte().first.$3, '4,5');
      expect(m.auflagerpunkte().last.$3, '30');
      final aufnahme = PictureRecorder();
      final leinwand = _ZaehlendeLeinwand(Canvas(aufnahme));
      m.paint(leinwand, const Size(800, 600));
      aufnahme.endRecording();
      a.zoomeAuf(1);
      final ohneText = PictureRecorder();
      m.paint(_ZaehlendeLeinwand(Canvas(ohneText)), const Size(800, 600));
      ohneText.endRecording();
      o.setzeEbenen({Ebene.belag});
      expect(m.auflagerpunkte(), isEmpty);
    });

    test('Seiten mit Rolle (M7): dick in ihrer Farbe, unabhängig von den '
        'Ebenen', () {
      final z = Zeichnung(
        seiten: const [(Offset(0, 0), Offset(4800, 0), Seitenrolle.bauelement)],
      );
      expect(
        () => z.seiten.add((Offset.zero, Offset.zero, Seitenrolle.bauelement)),
        throwsUnsupportedError,
      );
      final o = AnsichtsOptionen();
      final a = AnsichtSteuerung();
      final m = _maler(z, o, a);
      final [(von, bis, farbe)] = m.seitenlinien();
      expect(von, a.verschiebung);
      expect(bis, a.verschiebung + const Offset(480, 0));
      expect(farbe, ZeichnungsMaler.bauelementFarbe);
      expect(ZeichnungsMaler.bauelementFarbe, const Color(0xFF9E9E9E));
      expect(
        ZeichnungsMaler.seitenfarbe(Seitenrolle.verblendung),
        const Color(0xFFF2C200),
      );
      expect(ZeichnungsMaler.verblendungFarbe, const Color(0xFFF2C200));
      expect(
        ZeichnungsMaler.seitenfarbe(Seitenrolle.bauelement),
        ZeichnungsMaler.bauelementFarbe,
      );
      final aufnahme = PictureRecorder();
      final leinwand = _ZaehlendeLeinwand(Canvas(aufnahme));
      m.paint(leinwand, const Size(800, 600));
      aufnahme.endRecording();
      expect(
        leinwand.linienStifte.where(
          (p) => p.strokeWidth == ZeichnungsMaler.seitenBreite,
        ),
        hasLength(1),
      );
      expect(ZeichnungsMaler.seitenBreite, 8);
      o.setzeEbenen({});
      expect(m.seitenlinien(), hasLength(1));
      expect(Zeichnung.leer.seiten, isEmpty);
    });

    test('Dielennummern (M5-08): nur wo sie ins Stück passen, längs '
        'gedreht, nie auf dem Kopf', () {
      final z = Zeichnung(
        dielen: const [
          // 100 × 65 px, längste Kante nach rechts
          [Offset(0, 0), Offset(1000, 0), Offset(1000, 650), Offset(0, 650)],
          // längste Kante nach links: wird umgedreht
          [
            Offset(2000, 650),
            Offset(1000, 650),
            Offset(1000, 0),
            Offset(2000, 0),
          ],
          // senkrecht, längste Kante nach oben
          [
            Offset(3000, 1000),
            Offset(3000, 0),
            Offset(3650, 0),
            Offset(3650, 1000),
          ],
          // 6,5 px schmal
          [
            Offset(0, 700),
            Offset(1000, 700),
            Offset(1000, 765),
            Offset(0, 765),
          ],
          // zu kurz für zwölf Ziffern
          [
            Offset(0, 800),
            Offset(300, 800),
            Offset(300, 1450),
            Offset(0, 1450),
          ],
          // ohne Fläche
          [Offset(5000, 0), Offset(5000, 0)],
          // ohne Nummer
          [Offset(0, 2000), Offset(1000, 2000), Offset(1000, 2650)],
        ],
        nummern: const [1, 2, 3, 4, 123456789012, 6],
      );
      expect(() => z.nummern.add(1), throwsUnsupportedError);
      final o = AnsichtsOptionen();
      final m = _maler(z, o);
      final nummern = m.dielennummern();
      expect([for (final n in nummern) n.text], ['1', '2', '3']);
      expect(nummern[0].ort, const Offset(50, 32.5));
      expect(nummern[0].winkel, 0);
      expect(nummern[1].winkel, closeTo(0, 1e-12));
      expect(nummern[2].winkel, closeTo(math.pi / 2, 1e-12));
      // zehn Ziffern passen gerade noch
      expect(
        _maler(
          Zeichnung(dielen: [z.dielen[4]], nummern: const [1234567890]),
          o,
        ).dielennummern(),
        hasLength(1),
      );
      final aufnahme = PictureRecorder();
      final leinwand = _ZaehlendeLeinwand(Canvas(aufnahme));
      m.paint(leinwand, const Size(800, 600));
      aufnahme.endRecording();
      expect(leinwand.aufrufe['drawParagraph'], 3);
      expect(leinwand.aufrufe['rotate'], 3);
      expect(leinwand.aufrufe['save'], leinwand.aufrufe['restore']);
      o.setzeEbenen({Ebene.unterkonstruktion});
      expect(m.dielennummern(), isEmpty);
    });

    test('Ausschnitte: Füllung unter dem Belag, Rand und Name darüber', () {
      final z = Zeichnung(
        ausschnitte: const [
          [Offset(0, 0), Offset(100, 0), Offset(100, 100)],
        ],
        ausschnittDarstellung: const [(name: 'A1', farbe: Color(0xFF123456))],
        dielen: const [
          [Offset(0, 0), Offset(100, 0), Offset(100, 65)],
        ],
      );
      final aufnahme = PictureRecorder();
      final leinwand = _ZaehlendeLeinwand(Canvas(aufnahme));
      _maler(z, AnsichtsOptionen()).paint(leinwand, const Size(800, 600));
      aufnahme.endRecording();
      final [fuellung, diele, fuge, rand] = leinwand.pfadStifte;
      expect(fuellung.color.toARGB32(), 0xFF123456);
      expect(diele.color.toARGB32(), ZeichnungsMaler.belagFarbe.toARGB32());
      expect(fuge.style, PaintingStyle.stroke);
      expect(rand.strokeWidth, 2);
      expect(leinwand.aufrufe['drawParagraph'], 1);
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
      expect(m.strich, PlanerFarben.text);
      final dunkel = ZeichnungsMaler(
        zeichnung: z,
        optionen: o,
        ansicht: a,
        sprache: de,
        strich: PlanerFarbenDunkel.text,
      );
      expect(m.shouldRepaint(dunkel), isTrue);
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
        testApp(
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
      expect(find.byTooltip(de.beschriftungen), findsOneWidget);
    });

    testWidgets('genau 1000 px Leiste: mit Regler und Hinweis', (tester) async {
      // 1340 − 320 (Menü) − 20 (Griff) = 1000 px für die Werkzeugleiste.
      tester.view
        ..physicalSize = const Size(1340, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testApp(home: const PlanerRahmen(status: Text('x'))),
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
        testApp(home: const PlanerRahmen(status: Text('x'))),
      );
      expect(find.byKey(const ValueKey('zoom-regler')), findsNothing);
      expect(find.text(de.bedienHinweis), findsNothing);
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
  final pfadStifte = <Paint>[];
  final linienStifte = <Paint>[];
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
    pfadStifte.add(paint);
    _ziel.drawPath(path, paint);
  }

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    _zaehle('drawLine');
    linienStifte.add(paint);
    _ziel.drawLine(p1, p2, paint);
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
  void save() {
    _zaehle('save');
    _ziel.save();
  }

  @override
  void restore() {
    _zaehle('restore');
    _ziel.restore();
  }

  @override
  void translate(double dx, double dy) => _ziel.translate(dx, dy);

  @override
  void rotate(double radians) {
    _zaehle('rotate');
    _ziel.rotate(radians);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
