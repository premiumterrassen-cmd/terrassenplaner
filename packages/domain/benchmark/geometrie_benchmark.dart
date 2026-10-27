import 'dart:math' as math;

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

/// Geometrie-Kern (M4-01): U-Form 13,5 x 8,1 m mit zwei gerundeten Ecken,
/// davon nacheinander sechs Ausschnitte abziehen (Rechtecke, Kreise, Dreieck),
/// dann Fläche, Prüfungen und Abstand berechnen.
class GeometrieBenchmark extends BenchmarkBase {
  GeometrieBenchmark() : super('domain.Geometrie.uFormMitAusschnitten');

  final _woelbung = math.tan(math.pi / 8);
  late final Flaeche _uForm = Flaeche(
    Kontur(
      const [
        Punkt(0, 0),
        Punkt(12500, 0),
        Punkt(13500, 1000),
        Punkt(13500, 8100),
        Punkt(9000, 8100),
        Punkt(9000, 2700),
        Punkt(4500, 2700),
        Punkt(4500, 8100),
        Punkt(1000, 8100),
        Punkt(0, 7100),
      ],
      woelbungen: [0, _woelbung, 0, 0, 0, 0, 0, 0, _woelbung, 0],
    ),
  );

  final _ausschnitte = [
    Flaeche(Kontur.rechteck(1800, 1200, const Punkt(500, 500))),
    Flaeche(Kontur.kreis(const Punkt(6750, 1350), 600)),
    Flaeche(Kontur.rechteck(1000, 1000, const Punkt(11000, 6000))),
    Flaeche(Kontur.kreis(const Punkt(2250, 5000), 900)),
    Flaeche(
      Kontur(const [
        Punkt(10000, 3000),
        Punkt(12500, 3000),
        Punkt(11250, 4800),
      ]),
    ),
    // reicht über den Rand: kerbt die Außenkante ein
    Flaeche(Kontur.rechteck(1500, 800, const Punkt(-500, 3500))),
  ];

  var _summe = 0.0;

  @override
  void run() {
    var teile = [_uForm];
    for (final a in _ausschnitte) {
      teile = verknuepfe(teile, [a], Verknuepfung.differenz);
    }
    _summe += gesamtflaeche(teile);
    for (final a in _ausschnitte) {
      if (_uForm.ueberschneidet(a)) _summe += 1;
      if (_uForm.umschliesst(a)) _summe += 1;
    }
    _summe += _uForm.abstand(_ausschnitte.first);
  }

  @override
  void teardown() {
    if (_summe == 0) throw StateError('Benchmark hat nichts berechnet');
  }
}

void main() => GeometrieBenchmark().report();
