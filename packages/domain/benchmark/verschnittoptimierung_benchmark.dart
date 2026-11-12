import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

/// Verschnittoptimierung (M9-01): Varianten für die große Freiform aus dem
/// Benchmark der Dielenverlegung (12 × 8 m mit schräger Ecke, Einbuchtung
/// und drei Ausschnitten, 6-cm-Dielen in 4/5/6 m, Halbverband), waagrecht
/// und unter 45°, je einmal und zehnmal gebaut (Häufigkeit, alle Stücke
/// gemeinsam: bis 5460 Stücke in 454 Längen). Zeitbudget: 250 ms je
/// Durchlauf (alle vier Planungen) – Fachkonzept 7.1.
class VerschnittoptimierungBenchmark extends BenchmarkBase {
  VerschnittoptimierungBenchmark()
    : super('domain.Verschnittoptimierung.verschnittvarianten');

  static const _laengen = [
    Millimeter(4000),
    Millimeter(5000),
    Millimeter(6000),
  ];

  static Ausschnitt _ausschnitt(
    String name,
    int x,
    int y,
    int l,
    int b, {
    Ausschnittform form = Ausschnittform.rechteck,
    Ausschnittfunktion funktion = Ausschnittfunktion.leer,
  }) => Ausschnitt(
    bezeichnung: name,
    x: Millimeter(x),
    y: Millimeter(y),
    laenge: Millimeter(l),
    breite: Millimeter(b),
    form: form,
    funktion: funktion,
  );

  static final _stand = () {
    var stand = Planungsstand(
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
    ).mitVerlegeart(Verlegeart.halbverband);
    for (final a in [
      _ausschnitt('A1', 1500, 1500, 2000, 1200),
      _ausschnitt('A2', 6000, 2000, 1500, 1500, form: Ausschnittform.kreis),
      _ausschnitt(
        'A3',
        9000,
        5000,
        1800,
        1200,
        funktion: Ausschnittfunktion.andererBelag,
      ),
    ]) {
      stand = stand.mitNeuemAusschnitt().mitAusschnitt(
        stand.ausschnitte.length,
        a,
      );
    }
    return stand;
  }();

  static final _belag = Artikel(
    nummer: const Artikelnummer('10-10-001'),
    titel: 'Terrassendiele',
    art: Artikelart.diele,
    einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
    abmessungen: Abmessungen(breite: const Millimeter(60), laengen: _laengen),
    holzart: robinie,
    serie: basic,
  );

  late final List<List<Belagstuecke>> _planungen;
  var _summe = 0;

  @override
  void setup() {
    _planungen = [
      for (final richtung in const [
        Verlegerichtung.waagrecht,
        Verlegerichtung.diagonal45,
      ])
        for (final haeufigkeit in const [1, 10])
          [
            (
              belag: _belag.nummer,
              laengen: _laengen,
              ueberlaenge: dielenUeberlaenge,
              stuecke: [
                for (var k = 0; k < haeufigkeit; k++)
                  for (final t in verlegeBelag(
                    _stand.mitVerlegerichtung(richtung),
                    _belag,
                  )!.teile)
                    for (final s in t.stuecke) s.laenge,
              ],
            ),
          ],
    ];
  }

  @override
  void run() {
    for (final p in _planungen) {
      _summe += verschnittvarianten(p).length;
    }
  }

  @override
  void teardown() {
    if (_summe == 0) throw StateError('Benchmark hat nichts berechnet');
  }
}

void main() => VerschnittoptimierungBenchmark().report();
