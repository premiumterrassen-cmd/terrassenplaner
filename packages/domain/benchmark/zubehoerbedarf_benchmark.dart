import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

/// Automatische Zubehörmengen (M8-02): 12 × 8 m mit 6-cm-Dielen, waagrecht
/// und unter 45° – Befestigung, Gummiband über die Länge der Übergangs-UK,
/// Öl nach Belagfläche und die Zeilen „Tatsächlich“ mit einer Eingabe. Die
/// Verlegung selbst misst `domain.Belagverlegung.verlegeBelag`.
class ZubehoerbedarfBenchmark extends BenchmarkBase {
  ZubehoerbedarfBenchmark() : super('domain.Zubehoer.berechnetesZubehoer');

  static Artikel _artikel(
    String nummer,
    String titel,
    Artikelart art, {
    int inhalt = 1,
    int? laenge,
  }) => Artikel(
    nummer: Artikelnummer(nummer),
    titel: titel,
    art: art,
    einheit: Verkaufseinheit(Mengeneinheit.stueck, inhalt: inhalt),
    abmessungen: Abmessungen(
      laengen: [?(laenge == null ? null : Millimeter(laenge))],
    ),
  );

  static final _clips = [
    for (final vpe in [50, 100, 250])
      _artikel(
        '80-10-001-$vpe',
        'CLIP-FIXX - VPE $vpe',
        Artikelart.clip,
        inhalt: vpe,
      ),
  ];
  static final _zubehoer = [
    _artikel('568-250', 'Holzschutz-Öl ROBINIE, 2,5 Liter', Artikelart.pflege),
    _artikel('568-075', 'Holzschutz-Öl ROBINIE, 0,75 Liter', Artikelart.pflege),
    _artikel(
      '50-60-120',
      'Schutzband 75 mm, 10 Rollen à 10 m',
      Artikelart.gummiband,
      laenge: 10000,
    ),
  ];
  static final _belag = Artikel(
    nummer: const Artikelnummer('10-10-073-R'),
    titel: 'Terrassendiele',
    art: Artikelart.diele,
    einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
    abmessungen: Abmessungen(
      breite: const Millimeter(60),
      staerke: const Millimeter(23),
      laengen: const [Millimeter(4000), Millimeter(5000), Millimeter(6000)],
    ),
    holzart: robinie,
    serie: premiumSelect,
    profil: Profil.genutet,
  );
  static final _regelwerk = Regelwerk(
    Artikeldatei(
      quelle: 'benchmark',
      version: '1',
      eintraege: [
        Artikeleintrag(
          artikel: _belag,
          verweise: {
            Beziehung.befestigung.spalte: [for (final c in _clips) c.nummer],
            Beziehung.zubehoer.spalte: [for (final z in _zubehoer) z.nummer],
          },
          angaben: const {'Abstand_UK': 400},
        ),
        for (final a in [..._clips, ..._zubehoer]) Artikeleintrag(artikel: a),
      ],
    ),
  );
  static final _verlegungen = [
    for (final winkel in [0.0, 45.0])
      (
        winkel: winkel,
        stuecke: verlegeDielen(
          Kontur.rechteck(12000, 8000),
          winkel: winkel,
          ausgangspunkt: Punkt.ursprung,
          dielenbreite: const Millimeter(60),
          verlegeart: Verlegeart.halbverband,
          laengste: const Millimeter(6000),
        ),
      ),
  ];

  var _summe = 0;

  @override
  void run() {
    for (final (:winkel, :stuecke) in _verlegungen) {
      final befestigung = befestigungsbedarf(
        _regelwerk,
        _belag,
        Befestigungsart.clips,
        stuecke,
        winkel: winkel,
      );
      final zeilen = zubehoerpositionen(
        berechnetesZubehoer(
          _regelwerk,
          _belag,
          befestigung,
          stuecke,
          winkel: winkel,
          oelflaeche: oelflaeche(oelteile(belag: _belag, dielen: stuecke)),
        ),
        {const Artikelnummer('568-250'): 1},
      );
      _summe += zeilen.length;
    }
  }

  @override
  void teardown() {
    if (_summe == 0) throw StateError('Benchmark hat nichts berechnet');
  }
}

void main() => ZubehoerbedarfBenchmark().report();
