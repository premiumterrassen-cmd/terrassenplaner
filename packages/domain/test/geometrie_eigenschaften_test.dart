import 'dart:math' as math;

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

/// Eigenschaftsbasierte Tests des Geometrie-Kerns (M4-01): zufällige, aber
/// reproduzierbare Formen (fester Startwert) müssen Gesetzmäßigkeiten
/// erfüllen, die für jede Form gelten.
const _durchlaeufe = 150;

/// Sternförmiges, einfaches Vieleck um [mitte] mit 3–12 Ecken gegen den
/// Uhrzeigersinn: je Ecke ein Winkelsektor, Lücken stets unter 180°.
Kontur _zufallsform(math.Random z, Punkt mitte) {
  final ecken = 3 + z.nextInt(10);
  return Kontur([
    for (var i = 0; i < ecken; i++)
      mitte +
          const Punkt(1, 0).gedreht(
                2 * math.pi * (i + 0.3 + 0.4 * z.nextDouble()) / ecken,
              ) *
              (500 + z.nextDouble() * 2500),
  ]);
}

Punkt _zufallspunkt(math.Random z, double groesse) =>
    Punkt((z.nextDouble() - 0.5) * groesse, (z.nextDouble() - 0.5) * groesse);

void main() {
  test('Fläche, Umfang und Winkel unabhängig von Lage und Umlaufsinn', () {
    final z = math.Random(31);
    for (var i = 0; i < _durchlaeufe; i++) {
      final k = _zufallsform(z, _zufallspunkt(z, 4000));
      final winkel = z.nextDouble() * 360;
      final bewegt = k
          .gedreht(winkel, _zufallspunkt(z, 4000))
          .verschoben(_zufallspunkt(z, 4000));
      expect(bewegt.flaeche, closeTo(k.flaeche, k.flaeche * 1e-9));
      expect(bewegt.umfang, closeTo(k.umfang, k.umfang * 1e-9));
      expect(bewegt.gegenUhrzeigersinn, isTrue);
      expect(k.umgekehrt.flaeche, closeTo(k.flaeche, k.flaeche * 1e-9));
      expect(k.umgekehrt.gegenUhrzeigersinn, isFalse);
      final summe = k.innenwinkel.reduce((a, b) => a + b);
      expect(summe, closeTo((k.punkte.length - 2) * 180, 1e-6));
      final summeUmgekehrt = k.umgekehrt.innenwinkel.reduce((a, b) => a + b);
      expect(summeUmgekehrt, closeTo(summe, 1e-6));
      expect(k.istEinfach, isTrue);
    }
  });

  test('Einschluss-Ausschluss: A ∪ B + A ∩ B = A + B, A ∖ B + A ∩ B = A', () {
    final z = math.Random(47);
    for (var i = 0; i < _durchlaeufe; i++) {
      final a = Flaeche(_zufallsform(z, _zufallspunkt(z, 3000)));
      final b = Flaeche(_zufallsform(z, _zufallspunkt(z, 3000)));
      final vereinigt = gesamtflaeche(a.vereinigt(b));
      final schnitt = gesamtflaeche(a.geschnitten(b));
      final ohne = gesamtflaeche(a.ohne(b));
      expect(vereinigt + schnitt, closeTo(a.flaeche + b.flaeche, 1e-3));
      expect(ohne + schnitt, closeTo(a.flaeche, 1e-3));
      expect(gesamtflaeche(b.geschnitten(a)), closeTo(schnitt, 1e-3));
      expect(schnitt, lessThanOrEqualTo(math.min(a.flaeche, b.flaeche) + 1e-3));
    }
  });

  test('Punkte liegen genau dann im Ergebnis, wenn die Verknüpfung gilt', () {
    final z = math.Random(53);
    for (var i = 0; i < _durchlaeufe; i++) {
      final a = Flaeche(_zufallsform(z, _zufallspunkt(z, 2000)));
      final b = Flaeche(_zufallsform(z, _zufallspunkt(z, 2000)));
      final ergebnisse = {
        for (final v in Verknuepfung.values) v: verknuepfe([a], [b], v),
      };
      for (var j = 0; j < 20; j++) {
        final p = _zufallspunkt(z, 8000);
        if (a.abstandZumRand(p) < 0.01 || b.abstandZumRand(p) < 0.01) continue;
        final inA = a.enthaelt(p), inB = b.enthaelt(p);
        bool drin(Verknuepfung v) => ergebnisse[v]!.any((f) => f.enthaelt(p));
        expect(drin(Verknuepfung.vereinigung), inA || inB);
        expect(drin(Verknuepfung.schnitt), inA && inB);
        expect(drin(Verknuepfung.differenz), inA && !inB);
      }
    }
  });

  test('Rasterrechtecke mit deckungsgleichen Kanten, auch gedreht', () {
    final z = math.Random(71);
    Flaeche rasterrechteck() => Flaeche(
      Kontur.rechteck(
        100.0 * (1 + z.nextInt(6)),
        100.0 * (1 + z.nextInt(6)),
        Punkt(100.0 * z.nextInt(6), 100.0 * z.nextInt(6)),
      ),
    );
    for (var i = 0; i < _durchlaeufe; i++) {
      final winkel = i.isEven ? 0.0 : z.nextDouble() * 360;
      final a = rasterrechteck().gedreht(winkel);
      final b = rasterrechteck().gedreht(winkel);
      final c = rasterrechteck().gedreht(winkel);
      final ab = verknuepfe([a], [b], Verknuepfung.vereinigung);
      final schnitt = gesamtflaeche(a.geschnitten(b));
      expect(gesamtflaeche(ab) + schnitt, closeTo(a.flaeche + b.flaeche, 1e-3));
      expect(gesamtflaeche(a.ohne(b)) + schnitt, closeTo(a.flaeche, 1e-3));
      // drei Flächen: (A ∪ B) ∖ C + (A ∪ B) ∩ C = A ∪ B
      final ohneC = verknuepfe(ab, [c], Verknuepfung.differenz);
      final mitC = verknuepfe(ab, [c], Verknuepfung.schnitt);
      expect(
        gesamtflaeche(ohneC) + gesamtflaeche(mitC),
        closeTo(gesamtflaeche(ab), 1e-3),
      );
      for (final f in [...ab, ...ohneC, ...mitC]) {
        expect(f.kontur.gegenUhrzeigersinn, isTrue);
        for (final loch in f.loecher) {
          expect(loch.gegenUhrzeigersinn, isFalse);
        }
      }
    }
  });

  test('Kreis: Fläche exakt, Sehnenzug innerhalb der Toleranz', () {
    final z = math.Random(61);
    for (var i = 0; i < _durchlaeufe; i++) {
      final r = 100 + z.nextDouble() * 5000;
      final k = Kontur.kreis(_zufallspunkt(z, 4000), r);
      expect(k.flaeche, closeTo(math.pi * r * r, r * r * 1e-12));
      final vieleck = Kontur(k.vieleck());
      expect(vieleck.flaeche, lessThan(k.flaeche));
      expect(
        vieleck.flaeche,
        greaterThan(k.flaeche - k.umfang * bogenToleranz),
      );
    }
  });
}
