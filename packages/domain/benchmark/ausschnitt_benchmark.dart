import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

/// Prüfungen der Ausschnitte (M4-12): L-Form 10 × 8 m mit gerundeter Ecke
/// und sechs Ausschnitten aller Formen – außerhalb, Kollision, Teilung. Läuft
/// bei jeder Eingabe in einem Ausschnitt.
class AusschnittBenchmark extends BenchmarkBase {
  AusschnittBenchmark() : super('domain.Ausschnitte.pruefen6');

  final _stand = Planungsstand(
    grundriss: LGrundriss(
      const Millimeter(5000),
      const Millimeter(3000),
      const Millimeter(5000),
      const Millimeter(5000),
    ),
    rundungen: Rundungen.keine.mitEcke(0, const Millimeter(1000)),
    ausschnitte: [
      for (final (i, (x, y, form)) in [
        (1500, 500, Ausschnittform.rechteck),
        (500, 3500, Ausschnittform.kreis),
        (3000, 3500, Ausschnittform.sechseck),
        (5500, 3500, Ausschnittform.dreieck),
        (8000, 3500, Ausschnittform.rechteck),
        (1500, 6000, Ausschnittform.kreis),
      ].indexed)
        Ausschnitt(
          bezeichnung: 'A${i + 1}',
          x: Millimeter(x),
          y: Millimeter(y),
          laenge: const Millimeter(1500),
          breite: const Millimeter(1000),
          form: form,
        ),
    ],
  );

  var _meldungen = -1;

  @override
  void run() => _meldungen = pruefeAusschnitte(_stand).length;

  @override
  void teardown() {
    if (_meldungen != 0) throw StateError('Ausschnitte sollten passen');
  }
}

void main() => AusschnittBenchmark().report();
