import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

/// Berechnung der Stelzfüße und Pads mit Höhenzuordnung (M6-11): große
/// Freiform (12 × 8 m mit schräger Ecke und Einbuchtung) mit Gefälle über
/// neun Eckpunkte – Lage jedes Auflagers längs der UK-Hölzer, Höhe aus den
/// Dreiecken der Ecken, Wahl je Spalt aus Pads und Stelzfüßen und die
/// Tabelle der Höhenzuordnung, waagrecht und unter 45°.
class AuflagerBenchmark extends BenchmarkBase {
  AuflagerBenchmark() : super('domain.Auflager.auflagerbedarf');

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
    gefaelle: true,
    eckhoehen: const [
      Millimeter(250),
      Millimeter(240),
      Millimeter(200),
      Millimeter(120),
      Millimeter(100),
      Millimeter(100),
      Millimeter(90),
      Millimeter(86),
      Millimeter(150),
    ],
  );

  static Artikel _artikel(String nummer, Artikelart art, int inhalt) => Artikel(
    nummer: Artikelnummer(nummer),
    titel: nummer,
    art: art,
    einheit: Verkaufseinheit(Mengeneinheit.karton, inhalt: inhalt),
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

  /// Pads 2/5/8 mm, Keile 14–22 und 18–32 mm, Füße 35–55, 55–95, 80–200 mm.
  static final _bereiche = [
    for (final (nummer, art, inhalt, von, bis) in [
      ('50-60-004', Artikelart.pad, 150, 2, 2),
      ('50-60-005', Artikelart.pad, 70, 5, 5),
      ('50-60-006', Artikelart.pad, 50, 8, 8),
      ('50-40-001', Artikelart.stellfuss, 100, 14, 22),
      ('50-40-003', Artikelart.stellfuss, 75, 18, 32),
      ('60-55-110', Artikelart.stellfuss, 10, 35, 55),
      ('60-55-136', Artikelart.stellfuss, 20, 55, 95),
      ('60-57-009', Artikelart.stellfuss, 5, 80, 200),
    ])
      Auflagerbereich(
        einheiten: [_artikel(nummer, art, inhalt)],
        von: Millimeter(von),
        bis: Millimeter(bis),
        pad: art == Artikelart.pad,
      ),
  ];

  late final List<(Planungsstand, UkVerlegung)> _faelle;
  var _summe = 0;

  @override
  void setup() {
    _faelle = [
      for (final richtung in const [
        Verlegerichtung.waagrecht,
        Verlegerichtung.diagonal45,
      ])
        if (_stand.mitVerlegerichtung(richtung) case final s)
          (s, ukVerlegung(s, _uk, abstand: const Millimeter(400))),
    ];
  }

  @override
  void run() {
    for (final (stand, verlegung) in _faelle) {
      final b = auflagerbedarf(
        stand,
        verlegung,
        uk: _uk,
        abstand: const Millimeter(600),
        flaeche: Hoehenflaeche(stand.grundriss.ecken, stand.hoehen),
        aufbauhoehe: const Millimeter(81),
        bereiche: _bereiche,
      );
      _summe += b.punkte.length + b.zeilen.length;
    }
  }

  @override
  void teardown() {
    if (_summe == 0) throw StateError('Benchmark hat nichts berechnet');
  }
}

void main() => AuflagerBenchmark().report();
