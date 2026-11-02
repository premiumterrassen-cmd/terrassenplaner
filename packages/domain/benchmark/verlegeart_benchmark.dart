import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

/// Verlegearten (M5-04): Stoßlinien und Dielenstücke für 500 Reihen einer
/// 30 m langen Fläche je Verlegeart, mit und ohne „kurze Stücke verbinden“.
class VerlegeartBenchmark extends BenchmarkBase {
  VerlegeartBenchmark() : super('domain.Verlegeart.reihenstuecke');

  static const _von = Millimeter(0);
  static const _bis = Millimeter(30000);
  static const _raster = Millimeter(6000);

  var _summe = 0;

  @override
  void run() {
    for (final art in Verlegeart.values) {
      for (var reihe = 0; reihe < 500; reihe++) {
        final stoesse = art.stoesse(reihe, _von, _bis, _raster);
        // Reihen unterschiedlich lang wie bei schrägen Seiten
        final anfang = Millimeter(reihe * 7 % 3000);
        _summe += reihenstuecke(
          anfang,
          _bis,
          stoesse,
          laengste: _raster,
        ).length;
        _summe += reihenstuecke(
          anfang,
          _bis,
          stoesse,
          laengste: _raster,
          verbinden: true,
        ).length;
      }
    }
  }

  @override
  void teardown() {
    if (_summe == 0) throw StateError('Benchmark hat nichts berechnet');
  }
}

void main() => VerlegeartBenchmark().report();
