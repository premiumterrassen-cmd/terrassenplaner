import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

/// Art der Terrassennutzung (M6-05): zusätzliches UK-Holz einer großen
/// Freiform (12 × 8 m mit schräger Ecke und Einbuchtung) für Versteifung mit
/// Rahmen und doppelte UK, waagrecht und unter 45° – Rahmen, zweite Lage,
/// Leiterverband und Lieferstücke.
class UkzusatzBenchmark extends BenchmarkBase {
  UkzusatzBenchmark() : super('domain.Ukzusatz.ukZusatz');

  static final _stand = Planungsstand(
    grundriss: FreiformGrundriss(const [
      Punkt(0, 0),
      Punkt(9000, 0),
      Punkt(12000, 2500),
      Punkt(12000, 8000),
      Punkt(7000, 8000),
      Punkt(7000, 6000),
      Punkt(4000, 6000),
      Punkt(4000, 8000),
      Punkt(0, 8000),
    ], geschlossen: true),
  );

  static final _uk = Artikel(
    nummer: const Artikelnummer('10-10-031'),
    titel: 'UK 40 x 60',
    art: Artikelart.unterkonstruktion,
    einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
    abmessungen: Abmessungen(
      breite: const Millimeter(40),
      staerke: const Millimeter(60),
      laengen: const [Millimeter(6000)],
    ),
    holzart: robinie,
    serie: basic,
  );

  var _summe = 0;

  @override
  void run() {
    for (final art in const [
      Nutzungsart.versteifungMitRahmen,
      Nutzungsart.doppelteUk,
    ]) {
      for (final richtung in const [
        Verlegerichtung.waagrecht,
        Verlegerichtung.diagonal45,
      ]) {
        final z = ukZusatz(
          _stand.mitNutzungsart(art).mitVerlegerichtung(richtung),
          _uk,
          ukAbstand: const Millimeter(400),
        );
        _summe += z.stuecke.length + z.bedarf.length;
      }
    }
  }

  @override
  void teardown() {
    if (_summe == 0) throw StateError('Benchmark hat nichts berechnet');
  }
}

void main() => UkzusatzBenchmark().report();
