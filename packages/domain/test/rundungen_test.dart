import 'dart:math' as math;

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

import 'argument_fehler.dart';

final _r540 = RechteckGrundriss(const Millimeter(5400), const Millimeter(3600));

void main() {
  test('Beispiel des alten Planers: Ecke A gerundet → 19,099 m²', () {
    // Radius aus der Fläche zurückgerechnet: 19,44 − r²(1 − π/4) = 19,099
    const r = Millimeter(1261);
    final k = Rundungen.keine.mitEcke(0, r).kontur(_r540);
    expect(k.flaeche / 1e6, closeTo(19.099, 0.001));
    expect(
      k.flaeche,
      closeTo(19440000 - 1261 * 1261 * (1 - math.pi / 4), 1e-3),
    );
    // Ecke A wird zu zwei Tangentenpunkten mit einem Viertelkreis dazwischen
    expect(k.punkte.first.gleich(const Punkt(0, 1261)), isTrue);
    expect(k.punkte[1].gleich(const Punkt(1261, 0)), isTrue);
    expect(k.woelbungen.first, closeTo(math.tan(math.pi / 8), 1e-12));
    for (final w in k.innenwinkel.take(2)) {
      expect(w, closeTo(180, 1e-9));
    }
  });

  test('Seite nach außen und nach innen gewölbt', () {
    final aussen = Rundungen.keine
        .mitSeite(0, const Millimeter(500))
        .kontur(_r540);
    final innen = Rundungen.keine
        .mitSeite(0, const Millimeter(-500))
        .kontur(_r540);
    // Kreisabschnitt über 540 cm mit Stich 50 cm
    const c = 5400.0, s = 500.0;
    final r = (c * c / 4 + s * s) / (2 * s);
    final theta = 2 * math.asin(c / 2 / r);
    final abschnitt = r * r / 2 * (theta - math.sin(theta));
    expect(aussen.flaeche, closeTo(19440000 + abschnitt, 1e-3));
    expect(innen.flaeche, closeTo(19440000 - abschnitt, 1e-3));
    // gleiche Bedeutung auch bei umgekehrtem Umlauf
    final umgekehrt = FreiformGrundriss(
      _r540.ecken.reversed.toList(),
      geschlossen: true,
    );
    expect(
      Rundungen.keine
          // dort ist B—A die Seite 2
          .mitSeite(2, const Millimeter(500))
          .kontur(umgekehrt)
          .flaeche,
      closeTo(19440000 + abschnitt, 1e-3),
    );
  });

  test('spitzer und stumpfer Winkel: Tangentenlänge r · tan(φ/2)', () {
    // Dreieck mit 60°-Ecke bei A: Richtungswechsel 120°, tan(60°) = √3
    final dreieck = FreiformGrundriss(const [
      Punkt(0, 0),
      Punkt(4000, 0),
      Punkt(2000, 3464.1016151377544),
    ], geschlossen: true);
    final k = Rundungen.keine.mitEcke(1, const Millimeter(500)).kontur(dreieck);
    final t = 500 * math.sqrt(3);
    expect(k.punkte[1].gleich(Punkt(4000 - t, 0), 1e-6), isTrue);
    // stumpfe Ecke der L-Form (270° innen): Richtungswechsel −90°
    final l = Rundungen.keine
        .mitEcke(2, const Millimeter(300))
        .kontur(LGrundriss.vorgabe);
    expect(l.punkte[2].gleich(const Punkt(2700, 1500), 1e-6), isTrue);
    expect(l.punkte[3].gleich(const Punkt(3000, 1800), 1e-6), isTrue);
    expect(l.flaeche, closeTo(14580000 + 300 * 300 * (1 - math.pi / 4), 1e-3));
  });

  test('Ecke und angrenzende Seite zugleich', () {
    final k = Rundungen.keine
        .mitEcke(1, const Millimeter(1000))
        .mitSeite(0, const Millimeter(200))
        .kontur(_r540);
    expect(k.punkte, hasLength(5));
    expect(k.flaeche, greaterThan(19440000 - 1000 * 1000 * (1 - math.pi / 4)));
  });

  test('unzulässige Rundungen werden abgewiesen (Abnahme M4-11)', () {
    expect(
      () => Rundungen.keine
          .mitEcke(0, const Millimeter(3000))
          .mitEcke(1, const Millimeter(2500))
          .kontur(_r540),
      wirftArgumentFehler('ecke', 3000, 'Rundung zu groß für die Kante A—B'),
    );
    expect(
      () => Rundungen.keine.mitEcke(1, const Millimeter(3600)).kontur(_r540),
      wirftArgumentFehler('ecke', 3600, 'Rundung zu groß für die Kante B—C'),
    );
    expect(
      () => Rundungen.keine.mitSeite(1, const Millimeter(-2000)).kontur(_r540),
      wirftArgumentFehler(
        'seite',
        -2000,
        'Stich höchstens bis zum Halbkreis der Seite B',
      ),
    );
    expect(
      Rundungen.keine.mitSeite(1, const Millimeter(1799)).kontur(_r540).flaeche,
      greaterThan(19440000),
    );
    expect(
      () => Rundungen.keine.mitSeite(1, const Millimeter(1800)).kontur(_r540),
      wirftArgumentFehler(
        'seite',
        1800,
        'Stich höchstens bis zum Halbkreis der Seite B',
      ),
    );
    // zwei Seiten an Ecke A weit nach innen: die Bögen kreuzen sich
    expect(
      () => Rundungen.keine
          .mitSeite(0, const Millimeter(-1700))
          .mitSeite(3, const Millimeter(-1700))
          .kontur(_r540),
      wirftArgumentFehler('rundungen', 2, 'Rundungen überschneiden sich'),
    );
  });

  test('setzen, entfernen, gleich, Transport', () {
    final r = Rundungen.keine
        .mitEcke(0, const Millimeter(1000))
        .mitSeite(2, const Millimeter(-300));
    expect(r.leer, isFalse);
    expect(Rundungen.keine.leer, isTrue);
    expect(r.ecken, {0: const Millimeter(1000)});
    expect(r.seiten, {2: const Millimeter(-300)});
    expect(r.mitEcke(0, const Millimeter(0)).ecken, isEmpty);
    expect(r.mitSeite(2, const Millimeter(0)).seiten, isEmpty);
    expect(r.masse, [0, 0, 1000, 1, 2, -300]);
    expect(Rundungen.aus(r.masse), r);
    expect(Rundungen.aus(r.masse).hashCode, r.hashCode);
    expect(r == Rundungen.keine, isFalse);
    expect(r == r.mitEcke(0, const Millimeter(999)), isFalse);
    expect(r == r.mitSeite(1, const Millimeter(5)), isFalse);
    expect(r == Object(), isFalse);
    expect(
      () => Rundungen.aus(const [0, 1]),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          'Rundungen brauchen Dreiergruppen: 2',
        ),
      ),
    );
  });

  group('Bogen mit Radius je Seite (Planungskern v12, Regel 14.1)', () {
    test('Radius → Bogen mit diesem Radius, nach außen oder innen', () {
      final r = Rundungen.keine.mitRadius(0, const Millimeter(3750));
      final bogen = r.seitenboegen(_r540)[0]!;
      expect(bogen.radius, closeTo(3750, 1e-6));
      expect(bogen.start.gleich(Punkt.ursprung), isTrue);
      expect(bogen.ende.gleich(const Punkt(5400, 0)), isTrue);
      // Stich r − √(r² − (c/2)²)
      const h = 3750 - 2602.4026;
      final abschnitt = bogen.segmentflaeche.abs();
      expect(r.kontur(_r540).flaeche, closeTo(19440000 + abschnitt, 1e-3));
      expect(
        Rundungen.keine
            .mitRadius(0, const Millimeter(3750), innen: true)
            .kontur(_r540)
            .flaeche,
        closeTo(19440000 - abschnitt, 1e-3),
      );
      // gleich wie der Stich
      expect(
        abschnitt,
        closeTo(
          Rundungen.keine
              .mitSeite(0, const Millimeter(1148))
              .seitenboegen(_r540)[0]!
              .segmentflaeche
              .abs(),
          abschnitt * 0.001,
        ),
      );
      // _r540 läuft gegen den Uhrzeigersinn: außen ist positiv
      expect(bogen.woelbung, closeTo(2 * h / 5400, 1e-6));
      // Richtung aus dem Umlaufsinn: umgekehrt bleibt der Bogen außen
      final umgekehrt = FreiformGrundriss(
        _r540.ecken.reversed.toList(),
        geschlossen: true,
      );
      expect(
        Rundungen.keine
            .mitRadius(2, const Millimeter(3750))
            .kontur(umgekehrt)
            .flaeche,
        closeTo(19440000 + abschnitt, 1e-3),
      );
      expect(r.zuKleineRadien(_r540), isEmpty);
    });

    test('Halbkreis erlaubt; Radius unter der halben Sehne als Halbkreis '
        'mit Hinweis', () {
      final genau = Rundungen.keine.mitRadius(1, const Millimeter(1800));
      expect(genau.seitenboegen(_r540)[1]!.woelbung.abs(), closeTo(1, 1e-12));
      expect(
        genau.kontur(_r540).flaeche,
        closeTo(19440000 + math.pi * 1800 * 1800 / 2, 1e-3),
      );
      expect(genau.zuKleineRadien(_r540), isEmpty);
      final klein = Rundungen.keine.mitRadius(1, const Millimeter(1799));
      expect(klein.kontur(_r540).flaeche, genau.kontur(_r540).flaeche);
      expect(klein.zuKleineRadien(_r540), [1]);
      expect(
        Rundungen.keine
            .mitRadius(1, const Millimeter(1000), innen: true)
            .zuKleineRadien(_r540),
        [1],
      );
      // ohne Radien oder ohne Ecken nichts
      expect(
        Rundungen.keine.mitSeite(1, const Millimeter(5)).zuKleineRadien(_r540),
        isEmpty,
      );
      expect(klein.zuKleineRadien(KreisGrundriss.vorgabe), isEmpty);
    });

    test('Radius und Stich ersetzen sich; nur Bögen der Seiten, zwischen den '
        'Rundungen der Ecken', () {
      final r = Rundungen.keine
          .mitSeite(0, const Millimeter(300))
          .mitRadius(0, const Millimeter(4000));
      expect(r.seiten, isEmpty);
      expect(r.radien, {0: const Millimeter(4000)});
      expect(r.mitSeite(0, const Millimeter(300)).radien, isEmpty);
      expect(r.mitRadius(0, const Millimeter(0)).leer, isTrue);
      expect(
        r.mitRadius(0, const Millimeter(-4000)).radien[0],
        const Millimeter(4000),
      );
      final mitEcke = r.mitEcke(1, const Millimeter(1000));
      final boegen = mitEcke.seitenboegen(_r540);
      expect(boegen.keys, [0]);
      expect(boegen[0]!.ende.gleich(const Punkt(4400, 0)), isTrue);
      expect(Rundungen.keine.seitenboegen(_r540), isEmpty);
      expect(r.seitenboegen(KreisGrundriss.vorgabe), isEmpty);
      expect(
        Rundungen.keine.mitEcke(1, const Millimeter(500)).seitenboegen(_r540),
        isEmpty,
      );
    });

    test('Stich je Seite für den Griff: eingegeben oder aus dem Radius', () {
      final r = Rundungen.keine
          .mitSeite(0, const Millimeter(-300))
          .mitRadius(1, const Millimeter(1800))
          .mitRadius(3, const Millimeter(2000), innen: true);
      expect(r.stichAn(_r540, 0), const Millimeter(-300));
      expect(r.stichAn(_r540, 1), const Millimeter(1800));
      expect(r.stichAn(_r540, 2), const Millimeter(0));
      final h = (2000 - math.sqrt(2000 * 2000 - 1800 * 1800)).round();
      expect(r.stichAn(_r540, 3), Millimeter(-h));
      // umgekehrter Umlauf: gleiche Bedeutung
      final umgekehrt = FreiformGrundriss(
        _r540.ecken.reversed.toList(),
        geschlossen: true,
      );
      final vorwaerts = Rundungen.keine
          .mitRadius(0, const Millimeter(3000))
          .stichAn(_r540, 0);
      expect(vorwaerts.mm, (3000 - math.sqrt(9e6 - 2700 * 2700)).round());
      expect(
        Rundungen.keine
            .mitRadius(2, const Millimeter(3000))
            .stichAn(umgekehrt, 2),
        vorwaerts,
      );
    });

    test('Transport (Art 2), Gleichheit, unbekannte Art', () {
      final r = Rundungen.keine
          .mitEcke(0, const Millimeter(1000))
          .mitRadius(2, const Millimeter(2500), innen: true);
      expect(r.masse, [0, 0, 1000, 2, 2, -2500]);
      expect(Rundungen.aus(r.masse), r);
      expect(r == r.mitRadius(2, const Millimeter(2500)), isFalse);
      expect(r.leer, isFalse);
      expect(Rundungen.keine.mitRadius(1, const Millimeter(1)).leer, isFalse);
      for (final art in [3, -1]) {
        expect(
          () => Rundungen.aus([art, 0, 5]),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              'unbekannte Rundungsart $art',
            ),
          ),
        );
      }
      final stand = Planungsstand(grundriss: _r540, rundungen: r);
      expect(Planungsstand.ausBytes(stand.zuBytes()).rundungen, r);
    });
  });

  test('ohne Rundungen oder ohne Ecken: die Kontur des Grundrisses', () {
    expect(Rundungen.keine.kontur(_r540).punkte, _r540.kontur.punkte);
    final kreis = Rundungen.keine
        .mitEcke(0, const Millimeter(10))
        .kontur(KreisGrundriss.vorgabe);
    expect(kreis.flaeche, KreisGrundriss.vorgabe.kontur.flaeche);
  });

  group('Planungsstand mit Rundungen', () {
    final rund = Rundungen.keine.mitEcke(0, const Millimeter(1000));
    final stand = Planungsstand(grundriss: _r540, rundungen: rund);

    test('Kontur, Transport, Gleichheit', () {
      expect(stand.kontur.flaeche, lessThan(19440000));
      expect(Planungsstand.ausBytes(stand.zuBytes()), stand);
      expect(stand == Planungsstand(grundriss: _r540), isFalse);
      expect(Planungsstand.start.mitRundungen(rund).rundungen, rund);
    });

    test('bleiben bei passendem Grundriss, sonst weg', () {
      final groesser = stand.mitGrundriss(
        _r540.mitMass(0, const Millimeter(6000)),
      );
      expect(groesser.rundungen, rund);
      final zuKlein = stand.mitGrundriss(
        _r540.mitMass(1, const Millimeter(900)),
      );
      expect(zuKlein.rundungen, Rundungen.keine);
      final andereEcken = stand.mitGrundriss(LGrundriss.vorgabe);
      expect(andereEcken.rundungen, Rundungen.keine);
      expect(stand.mitForm(Terrassenform.lForm).rundungen, Rundungen.keine);
      expect(stand.gedreht(90).rundungen, Rundungen.keine);
      // ohne Rundungen bleibt auch eine offene Freiform unberührt
      final offen = FreiformGrundriss(const [Punkt(0, 0), Punkt(1000, 0)]);
      expect(Planungsstand.start.mitGrundriss(offen).grundriss, offen);
      final mitAusschnitt = Planungsstand(
        grundriss: _r540,
        ausschnitte: [Ausschnitt.oForm],
        rundungen: rund,
      );
      expect(
        mitAusschnitt
            .mitAusschnitt(
              0,
              Ausschnitt.oForm.mitMass(0, const Millimeter(1000)),
            )
            .rundungen,
        rund,
      );
    });
  });
}
