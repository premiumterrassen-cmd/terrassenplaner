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
