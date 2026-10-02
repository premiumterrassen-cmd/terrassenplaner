import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

/// Beispiel-Benchmark für den Rahmen (M0-05): Zusammensetzen des Projekttitels.
class ProjektTitelBenchmark extends BenchmarkBase {
  ProjektTitelBenchmark() : super('domain.ProjektInfo.titel');

  var _laenge = 0;

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      _laenge += ProjektInfo(
        name: 'Planer $i',
        firma: 'ALTO HOLZ',
      ).titel.length;
    }
  }

  @override
  void teardown() {
    if (_laenge == 0) throw StateError('Benchmark hat nichts berechnet');
  }
}

void main() => ProjektTitelBenchmark().report();
