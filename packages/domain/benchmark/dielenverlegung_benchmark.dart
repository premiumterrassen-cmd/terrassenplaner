import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

/// Verlegerichtungen (M5-05): Dielenstücke einer 12 × 8 m großen Fläche
/// mit gerundeter Ecke in allen fünf Richtungen (Halbverband, 6-m-Dielen).
class DielenverlegungBenchmark extends BenchmarkBase {
  DielenverlegungBenchmark() : super('domain.Dielenverlegung.verlegeDielen');

  static final _kontur = Planungsstand(
    grundriss: RechteckGrundriss(
      const Millimeter(12000),
      const Millimeter(8000),
    ),
    rundungen: Rundungen.keine.mitEcke(2, const Millimeter(1500)),
  ).kontur;

  var _summe = 0;

  @override
  void run() {
    for (final winkel in const [0, 90, 45, 135, 30]) {
      _summe += verlegeDielen(
        _kontur,
        winkel: winkel.toDouble(),
        ausgangspunkt: _kontur.punkte.first,
        dielenbreite: const Millimeter(60),
        verlegeart: Verlegeart.halbverband,
        laengste: const Millimeter(6000),
      ).length;
    }
  }

  @override
  void teardown() {
    if (_summe == 0) throw StateError('Benchmark hat nichts berechnet');
  }
}

void main() => DielenverlegungBenchmark().report();
