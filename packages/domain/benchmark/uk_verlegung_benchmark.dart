import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

/// Berechnung der UK-Verlegung (M6-10): große Freiform (12 × 8 m mit
/// schräger Ecke und Einbuchtung) mit Gefälle, Drittelverband (viele Stöße,
/// doppelte UK), waagrecht und unter 45° – Lage der Hölzer, Abschnitte,
/// Stöße, Stückliste, Lieferstücke und die Befestigungspunkte darauf.
class UkVerlegungBenchmark extends BenchmarkBase {
  UkVerlegungBenchmark() : super('domain.UkVerlegung.ukVerlegung');

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
    verlegeart: Verlegeart.drittelverband,
    gefaelle: true,
    eckhoehen: const [
      Millimeter(150),
      Millimeter(150),
      Millimeter(120),
      Millimeter(86),
      Millimeter(86),
      Millimeter(86),
      Millimeter(86),
      Millimeter(86),
      Millimeter(120),
    ],
  );

  static final _belag = Artikel(
    nummer: const Artikelnummer('10-10-073'),
    titel: 'Diele 60 x 21',
    art: Artikelart.diele,
    einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
    abmessungen: Abmessungen(
      breite: const Millimeter(60),
      staerke: const Millimeter(21),
      laengen: const [Millimeter(4000), Millimeter(5000), Millimeter(6000)],
    ),
    holzart: robinie,
    serie: basic,
    profil: Profil.genutet,
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

  late final List<(Planungsstand, List<Dielenstueck>)> _faelle;
  var _summe = 0;

  @override
  void setup() {
    _faelle = [
      for (final richtung in const [
        Verlegerichtung.waagrecht,
        Verlegerichtung.diagonal45,
      ])
        if (_stand.mitVerlegerichtung(richtung) case final s)
          (s, [for (final t in verlegeBelag(s, _belag)!.teile) ...t.stuecke]),
    ];
  }

  @override
  void run() {
    for (final (stand, dielen) in _faelle) {
      final v = ukVerlegung(
        stand,
        _uk,
        abstand: const Millimeter(400),
        dielen: dielen,
      );
      _summe += v.stuecke.length + befestigungspunkteAufUk(dielen, v).punkte;
    }
  }

  @override
  void teardown() {
    if (_summe == 0) throw StateError('Benchmark hat nichts berechnet');
  }
}

void main() => UkVerlegungBenchmark().report();
