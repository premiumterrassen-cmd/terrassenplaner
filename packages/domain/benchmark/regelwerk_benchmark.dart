import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

/// Regelwerk (M2-04): alle Auswahlmöglichkeiten für 50 Beläge in einer
/// Artikeldatei mit 250 Artikeln – Größenordnung der Upload-Datei v6.
class RegelwerkBenchmark extends BenchmarkBase {
  RegelwerkBenchmark() : super('domain.Regelwerk.auswahlJeBelag');

  late final Regelwerk _regelwerk;
  late final List<Artikel> _belaege;
  var _anzahl = 0;

  @override
  void setup() {
    Artikel artikel(String nummer, Artikelart art) => Artikel(
      nummer: Artikelnummer(nummer),
      titel: nummer,
      art: art,
      einheit: Verkaufseinheit(Mengeneinheit.stueck),
      holzart: art.istHolz ? robinie : null,
      serie: art.istHolz ? premiumSelect : null,
    );
    final zubehoer = [
      for (var i = 0; i < 200; i++)
        Artikeleintrag(artikel: artikel('Z-$i', Artikelart.sonstiges)),
    ];
    final belaege = [
      for (var i = 0; i < 50; i++)
        Artikeleintrag(
          artikel: artikel('B-$i', Artikelart.diele),
          verweise: {
            for (final (j, b) in Beziehung.values.indexed)
              b.spalte: [
                for (var k = 0; k < 5; k++)
                  zubehoer[(i + j * 5 + k) % zubehoer.length].artikel.nummer,
              ],
          },
          benoetigt: {zubehoer[i].artikel.nummer: 2},
        ),
    ];
    _regelwerk = Regelwerk(
      Artikeldatei(
        quelle: 'benchmark',
        version: '1',
        eintraege: [...zubehoer, ...belaege],
      ),
    );
    _belaege = _regelwerk.imBereich(Bereich.belag);
  }

  @override
  void run() {
    for (final belag in _belaege) {
      for (final b in Beziehung.values) {
        _anzahl += _regelwerk.moeglich(belag.nummer, b).length;
      }
      _anzahl += _regelwerk.pflichtzubehoer(belag.nummer).length;
      _anzahl += _regelwerk.befestigungWiderspruch(belag.nummer) == null
          ? 0
          : 1;
    }
  }

  @override
  void teardown() {
    if (_anzahl == 0) throw StateError('Benchmark hat nichts berechnet');
  }
}

void main() => RegelwerkBenchmark().report();
