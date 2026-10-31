import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

/// Dielenlängen (M5-02): 3000 Dielenreihen von 1 mm bis 30 m, der größten
/// Seitenlänge, automatisch und mit erzwungener Länge.
class DielenlaengeBenchmark extends BenchmarkBase {
  DielenlaengeBenchmark() : super('domain.Dielenlaenge.lieferlaengenFuer');

  static const _laengen = [
    Millimeter(4000),
    Millimeter(5000),
    Millimeter(6000),
    Millimeter(7000),
  ];

  var _summe = 0;

  @override
  void run() {
    for (var reihe = 1; reihe <= 30000; reihe += 10) {
      _summe += lieferlaengenFuer(Millimeter(reihe), _laengen).length;
      _summe += lieferlaengenFuer(
        Millimeter(reihe),
        _laengen,
        fest: _laengen.first,
      ).length;
    }
  }

  @override
  void teardown() {
    if (_summe == 0) throw StateError('Benchmark hat nichts berechnet');
  }
}

void main() => DielenlaengeBenchmark().report();
