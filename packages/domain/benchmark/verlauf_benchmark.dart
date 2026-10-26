import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

/// Verlauf (M3-03): 500 Änderungen über die Grenze von 200 Schritten, dann
/// alles rückgängig und wieder hergestellt.
class VerlaufBenchmark extends BenchmarkBase {
  VerlaufBenchmark() : super('domain.Verlauf.aendernRueckgaengig');

  var _summe = 0;

  @override
  void run() {
    final verlauf = Verlauf(0);
    for (var i = 1; i <= 500; i++) {
      verlauf.setze(i);
    }
    while (verlauf.kannRueckgaengig) {
      _summe += verlauf.rueckgaengig();
    }
    while (verlauf.kannWiederherstellen) {
      _summe += verlauf.wiederherstellen();
    }
  }

  @override
  void teardown() {
    if (_summe == 0) throw StateError('Benchmark hat nichts berechnet');
  }
}

void main() => VerlaufBenchmark().report();
