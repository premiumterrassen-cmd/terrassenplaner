import 'dart:math' as math;

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

import 'argument_fehler.dart';

Matcher _punkt(double x, double y) => isA<Punkt>()
    .having((p) => p.x, 'x', closeTo(x, 1e-6))
    .having((p) => p.y, 'y', closeTo(y, 1e-6));

const _r = 1000.0;

List<Matcher> _grad(List<num> winkel) => [
  for (final w in winkel) closeTo(w, 1e-9),
];

/// Halbkreis oben, gegen den Uhrzeigersinn.
const _oben = Kante(Punkt(_r, 0), Punkt(-_r, 0), 1);

/// Halbkreis unten, im Uhrzeigersinn.
const _unten = Kante(Punkt(_r, 0), Punkt(-_r, 0), -1);

/// L-Form aus dem alten Planer (Fachkonzept 1.1) in mm.
final _lForm = Kontur(const [
  Punkt(0, 0),
  Punkt(5400, 0),
  Punkt(5400, 3600),
  Punkt(2700, 3600),
  Punkt(2700, 1800),
  Punkt(0, 1800),
]);

void main() {
  group('Kante als Strecke', () {
    const k = Kante(Punkt(0, 0), Punkt(300, 400));

    test('Maße', () {
      expect(k.istBogen, isFalse);
      expect(k.woelbung, 0);
      expect(k.winkel, 0);
      expect(k.laenge, 500);
      expect(k.segmentflaeche, 0);
      expect(k.richtungAmStart, _punkt(300, 400));
      expect(k.richtungAmEnde, _punkt(300, 400));
      expect(k.zwischenpunkte(0.1), [k.start]);
      expect(k.segmentEnthaelt(const Punkt(100, 100)), isFalse);
    });

    test('Abstand: senkrecht, vor dem Anfang, hinter dem Ende', () {
      expect(k.abstand(const Punkt(400, -300)), closeTo(500, 1e-9));
      expect(k.abstand(const Punkt(-30, -40)), closeTo(50, 1e-9));
      expect(k.abstand(const Punkt(600, 800)), closeTo(500, 1e-9));
      expect(k.abstand(const Punkt(150, 200)), closeTo(0, 1e-9));
    });

    test('umgekehrt', () {
      final u = const Kante(Punkt(0, 0), Punkt(1, 0), 0.5).umgekehrt;
      expect(
        [u.start, u.ende, u.woelbung],
        [const Punkt(1, 0), const Punkt(0, 0), -0.5],
      );
    });
  });

  group('Kante als Bogen', () {
    test('Halbkreis gegen den Uhrzeigersinn', () {
      expect(_oben.istBogen, isTrue);
      expect(_oben.winkel, closeTo(math.pi, 1e-12));
      expect(_oben.radius, closeTo(_r, 1e-9));
      expect(_oben.mittelpunkt, _punkt(0, 0));
      expect(_oben.laenge, closeTo(math.pi * _r, 1e-9));
      expect(_oben.segmentflaeche, closeTo(math.pi * _r * _r / 2, 1e-6));
      expect(_oben.richtungAmStart, _punkt(0, 2 * _r));
      expect(_oben.richtungAmEnde, _punkt(0, -2 * _r));
    });

    test('Viertelkreis im Uhrzeigersinn: Mittelpunkt rechts der Sehne', () {
      final k = Kante(
        const Punkt(0, 0),
        const Punkt(100, 100),
        -math.tan(math.pi / 8),
      );
      expect(k.winkel, closeTo(-math.pi / 2, 1e-12));
      expect(k.radius, closeTo(100, 1e-9));
      expect(k.mittelpunkt, _punkt(100, 0));
      expect(k.segmentflaeche, closeTo(-(math.pi / 4 - 0.5) * 100 * 100, 1e-6));
      expect(k.richtungAmStart, _punkt(0, 100 * math.sqrt2));
    });

    test('Dreiviertelkreis: Mittelpunkt auf der Seite des Bogens', () {
      final k = Kante(
        const Punkt(100, 0),
        const Punkt(0, -100),
        math.tan(3 * math.pi / 8),
      );
      expect(k.mittelpunkt, _punkt(0, 0));
      expect(k.laenge, closeTo(150 * math.pi, 1e-9));
    });

    test('Sehnenzug weicht höchstens um die Toleranz ab', () {
      final p = _oben.zwischenpunkte(0.1);
      // 2·acos(1 − 0,1/1000) ≈ 0,02828 → π / 0,02828 → 112 Stücke
      expect(p.length, 112);
      expect(p.first, _oben.start);
      for (final x in p) {
        expect(x.laenge, closeTo(_r, 1e-6));
      }
      final sehne = p[0].abstand(p[1]);
      final pfeilhoehe = _r - math.sqrt(_r * _r - sehne * sehne / 4);
      expect(pfeilhoehe, lessThanOrEqualTo(0.1));
      expect(pfeilhoehe, greaterThan(0.09));
      expect(
        p[1],
        _punkt(_r * math.cos(math.pi / 112), _r * math.sin(math.pi / 112)),
      );
    });

    test('Toleranz größer als der Radius: ein Stück je Halbkreis', () {
      expect(_oben.zwischenpunkte(2 * _r), [_oben.start]);
    });

    test('Abstand innerhalb und außerhalb des Bogenwinkels', () {
      expect(_oben.abstand(Punkt.ursprung), closeTo(_r, 1e-9));
      expect(_oben.abstand(const Punkt(0, 1500)), closeTo(500, 1e-9));
      expect(_oben.abstand(const Punkt(0, 600)), closeTo(400, 1e-9));
      final unten = const Punkt(0, -2 * _r);
      expect(_oben.abstand(unten), closeTo(_r * math.sqrt(5), 1e-9));
      expect(_unten.abstand(unten), closeTo(_r, 1e-9));
      expect(
        _unten.abstand(const Punkt(0, 2 * _r)),
        closeTo(_r * math.sqrt(5), 1e-9),
      );
    });

    test('Abstand zu Bögen abseits des Ursprungs', () {
      // Viertelkreis um (500|500), Radius 100, von 90° bis 180°
      final ccw = Kante(
        const Punkt(500, 600),
        const Punkt(400, 500),
        math.tan(math.pi / 8),
      );
      final w = 3 * math.pi / 4;
      final aussen =
          const Punkt(500, 500) + Punkt(math.cos(w), math.sin(w)) * 150;
      expect(ccw.abstand(aussen), closeTo(50, 1e-9));
      expect(
        ccw.abstand(const Punkt(650, 500)),
        closeTo(math.sqrt(150 * 150 + 100 * 100), 1e-9),
      );
      // derselbe Bogen im Uhrzeigersinn
      final cw = ccw.umgekehrt;
      expect(cw.abstand(aussen), closeTo(50, 1e-9));
      expect(
        cw.abstand(const Punkt(650, 500)),
        closeTo(math.sqrt(150 * 150 + 100 * 100), 1e-9),
      );
      expect(cw.abstand(const Punkt(400, 400)), closeTo(100, 1e-9));
    });

    test('Kreisabschnitt zwischen Sehne und Bogen', () {
      expect(_oben.segmentEnthaelt(const Punkt(0, 500)), isTrue);
      expect(_oben.segmentEnthaelt(const Punkt(0, -500)), isFalse);
      expect(_oben.segmentEnthaelt(const Punkt(0, 1001)), isFalse);
      expect(_unten.segmentEnthaelt(const Punkt(0, -500)), isTrue);
      expect(_unten.segmentEnthaelt(const Punkt(0, 500)), isFalse);
    });
  });

  group('Kontur', () {
    test('braucht je Punkt eine Wölbung', () {
      expect(
        () => Kontur(
          const [Punkt(0, 0), Punkt(1, 0), Punkt(0, 1)],
          woelbungen: const [0, 0],
        ),
        wirftArgumentFehler(
          'woelbungen',
          2,
          'braucht genau eine Wölbung je Punkt',
        ),
      );
    });

    test('muss eine Fläche umschließen', () {
      expect(
        () => Kontur(const [Punkt(0, 0), Punkt(1, 0)]),
        wirftArgumentFehler('punkte', 2, 'umschließen keine Fläche'),
      );
      expect(
        () => Kontur(const [Punkt(0, 0), Punkt(1, 1), Punkt(2, 2)]),
        wirftArgumentFehler('punkte', 3, 'umschließen keine Fläche'),
      );
    });

    test('Rechteck 540 x 360 cm', () {
      final r = Kontur.rechteck(5400, 3600, const Punkt(10, 20));
      expect(r.punkte, [
        const Punkt(10, 20),
        const Punkt(5410, 20),
        const Punkt(5410, 3620),
        const Punkt(10, 3620),
      ]);
      expect(r.woelbungen, [0, 0, 0, 0]);
      expect(r.flaeche, 19440000);
      expect(r.umfang, 18000);
      expect(r.gegenUhrzeigersinn, isTrue);
      expect(r.innenwinkel, _grad([90, 90, 90, 90]));
      expect(r.kanten.last.ende, r.punkte.first);
      expect(Kontur.rechteck(1, 2).punkte.first, Punkt.ursprung);
    });

    test('L-Form: Fläche 14,58 m², ein überstumpfer Winkel', () {
      expect(_lForm.flaeche, 14580000);
      expect(_lForm.umfang, 18000);
      expect(_lForm.innenwinkel, _grad([90, 90, 90, 90, 270, 90]));
      final umgekehrt = _lForm.umgekehrt;
      expect(umgekehrt.gegenUhrzeigersinn, isFalse);
      expect(umgekehrt.flaeche, 14580000);
      expect(umgekehrt.innenwinkel, _grad([90, 270, 90, 90, 90, 90]));
    });

    test('Kreis: exakte Fläche und Umfang', () {
      final k = Kontur.kreis(const Punkt(5, 5), 1800);
      expect(k.punkte, [const Punkt(1805, 5), const Punkt(-1795, 5)]);
      expect(k.flaeche, closeTo(math.pi * 1800 * 1800, 1e-6));
      expect(k.umfang, closeTo(2 * math.pi * 1800, 1e-9));
      expect(k.innenwinkel, _grad([180, 180]));
      expect(k.enthaelt(const Punkt(5, 1800)), isTrue);
      expect(k.enthaelt(const Punkt(5, -1790)), isTrue);
      expect(k.enthaelt(const Punkt(5, 1806)), isFalse);
      final u = k.huellrechteck;
      expect(u.min, _punkt(-1795, -1795));
      expect(u.max.x, closeTo(1805, 1e-6));
      expect(u.max.y, closeTo(1805, 0.1));
    });

    test('Ecke mit Rundung: Tangente stetig, Fläche kleiner', () {
      // 540 x 360, Ecke rechts oben mit Radius 1000 nach außen gewölbt
      final w = math.tan(math.pi / 8);
      final k = Kontur(
        const [
          Punkt(0, 0),
          Punkt(5400, 0),
          Punkt(5400, 2600),
          Punkt(4400, 3600),
          Punkt(0, 3600),
        ],
        woelbungen: [0, 0, w, 0, 0],
      );
      expect(
        k.flaeche,
        closeTo(19440000 - 1000 * 1000 * (1 - math.pi / 4), 1e-6),
      );
      expect(k.innenwinkel, _grad([90, 90, 180, 180, 90]));
      expect(k.umfang, closeTo(18000 - 2000 + 500 * math.pi, 1e-9));
    });

    test('nach innen gewölbte Kante nimmt Fläche weg', () {
      final k = Kontur(
        const [Punkt(0, 0), Punkt(2000, 0), Punkt(2000, 2000), Punkt(0, 2000)],
        woelbungen: const [0, 0, -1, 0],
      );
      expect(k.flaeche, closeTo(4000000 - math.pi * 1000 * 1000 / 2, 1e-6));
      expect(k.enthaelt(const Punkt(1000, 1900)), isFalse);
      expect(k.enthaelt(const Punkt(1000, 900)), isTrue);
      expect(k.enthaelt(const Punkt(100, 1500)), isTrue);
    });

    test('Punkt im Inneren und Abstand zum Rand', () {
      expect(_lForm.enthaelt(const Punkt(100, 100)), isTrue);
      expect(_lForm.enthaelt(const Punkt(1000, 2000)), isFalse);
      expect(_lForm.enthaelt(const Punkt(-1, 100)), isFalse);
      expect(_lForm.enthaelt(const Punkt(3000, 3000)), isTrue);
      expect(_lForm.abstandZumRand(const Punkt(1000, 2000)), 200);
      expect(_lForm.abstandZumRand(const Punkt(3000, 3000)), 300);
    });

    test('Sehnenzug, Huellrechteck, Verschieben, Drehen', () {
      expect(_lForm.vieleck(), _lForm.punkte);
      expect(Kontur.kreis(Punkt.ursprung, _r).vieleck().length, 224);
      expect(Kontur.kreis(Punkt.ursprung, _r).vieleck(10).length, 24);
      final u = _lForm.huellrechteck;
      expect([u.min, u.max], [Punkt.ursprung, const Punkt(5400, 3600)]);
      final v = _lForm.verschoben(const Punkt(-100, 50));
      expect(v.punkte[1], const Punkt(5300, 50));
      final kreis = Kontur.kreis(
        Punkt.ursprung,
        10,
      ).verschoben(const Punkt(1, 0));
      expect(kreis.woelbungen, [1, 1]);
      final d = _lForm.gedreht(90, const Punkt(100, 0));
      expect(d.punkte[1], _punkt(100, 5300));
      expect(d.flaeche, closeTo(14580000, 1e-6));
      expect(Kontur.kreis(Punkt.ursprung, 10).gedreht(90).woelbungen, [1, 1]);
      expect(_lForm.gedreht(90).punkte[1], _punkt(0, 5400));
    });

    test('umgekehrt: Wölbungen wandern mit ihrer Kante', () {
      final k = Kontur(
        const [Punkt(0, 0), Punkt(10, 0), Punkt(10, 10), Punkt(0, 10)],
        woelbungen: const [0.1, 0.2, 0.3, 0.4],
      );
      final u = k.umgekehrt;
      expect(u.punkte, [
        const Punkt(0, 10),
        const Punkt(10, 10),
        const Punkt(10, 0),
        const Punkt(0, 0),
      ]);
      expect(u.woelbungen, [-0.3, -0.2, -0.1, -0.4]);
      expect(u.flaeche, closeTo(k.flaeche, 1e-9));
    });

    test('einfach: keine Selbstüberschneidung', () {
      expect(_lForm.istEinfach, isTrue);
      expect(Kontur.rechteck(1, 1).istEinfach, isTrue);
      expect(Kontur.kreis(Punkt.ursprung, 100).istEinfach, isTrue);
      expect(
        Kontur(const [Punkt(0, 0), Punkt(30, 10), Punkt(20, 0), Punkt(0, 20)])
            .istEinfach,
        isFalse,
      );
      // berührt sich nur in einem Punkt
      expect(
        Kontur(const [
          Punkt(0, 0),
          Punkt(20, 0),
          Punkt(10, 10),
          Punkt(20, 20),
          Punkt(0, 20),
          Punkt(10, 10),
        ]).istEinfach,
        isFalse,
      );
    });
  });

  group('Strecken', () {
    test('Abstand: Kreuzung, Berührung, parallel, windschief', () {
      const a = Punkt(0, 0), b = Punkt(10, 0);
      expect(streckenAbstand(a, b, const Punkt(5, -5), const Punkt(5, 5)), 0);
      expect(streckenAbstand(a, b, const Punkt(5, 0), const Punkt(5, 5)), 0);
      expect(streckenAbstand(a, b, const Punkt(0, 3), const Punkt(10, 3)), 3);
      expect(streckenAbstand(a, b, const Punkt(13, 4), const Punkt(20, 9)), 5);
      expect(streckenAbstand(const Punkt(13, 4), const Punkt(20, 9), a, b), 5);
      expect(streckenAbstand(a, b, const Punkt(5, 2), const Punkt(15, 8)), 2);
      expect(streckenAbstand(const Punkt(5, 2), const Punkt(15, 8), a, b), 2);
      expect(
        streckenBeruehren(a, b, const Punkt(10, 0), const Punkt(12, 1)),
        isTrue,
      );
      expect(
        streckenBeruehren(a, b, const Punkt(11, 0), const Punkt(12, 1)),
        isFalse,
      );
    });
  });
}
