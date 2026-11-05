import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';

Artikel _artikel(String nummer, Artikelart art, {int inhalt = 1}) => Artikel(
  nummer: Artikelnummer(nummer),
  titel: 'Artikel $nummer',
  art: art,
  einheit: Verkaufseinheit(Mengeneinheit.karton, inhalt: inhalt),
  preisBrutto: const Cent(2500),
);

final _diele = Artikel(
  nummer: const Artikelnummer('10-10-073'),
  titel: 'Terrassendiele Robinie 60 x 21 mm, genutet',
  art: Artikelart.diele,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  preisBrutto: const Cent(449),
  abmessungen: Abmessungen(
    breite: const Millimeter(60),
    staerke: const Millimeter(21),
    laengen: const [Millimeter(4000), Millimeter(5000), Millimeter(6000)],
  ),
  holzart: robinie,
  serie: basic,
  profil: Profil.genutet,
);

final _uk = Artikel(
  nummer: const Artikelnummer('10-10-031'),
  titel: 'Unterkonstruktionsholz Robinie 40 x 60 mm',
  art: Artikelart.unterkonstruktion,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  preisBrutto: const Cent(979),
  abmessungen: Abmessungen(
    breite: const Millimeter(40),
    staerke: const Millimeter(60),
  ),
  holzart: robinie,
  serie: basic,
);

final _pad = _artikel('50-60-005', Artikelart.pad, inhalt: 70);
final _fuss = _artikel('60-55-136', Artikelart.stellfuss, inhalt: 20);

final _regelwerk = Regelwerk(
  Artikeldatei(
    quelle: 'benchmark',
    version: '1',
    eintraege: [
      Artikeleintrag(artikel: _diele, angaben: const {'Abstand_UK': 400}),
      Artikeleintrag(
        artikel: _uk,
        verweise: {
          Beziehung.stellfussPrivat.spalte: [_fuss.nummer],
          Beziehung.unterlegpads.spalte: [_pad.nummer],
        },
        angaben: const {'Abstand_Stelzfuesse': 600},
      ),
      Artikeleintrag(
        artikel: _pad,
        angaben: const {'MinHoehe': 5, 'MaxHoehe': 5},
      ),
      Artikeleintrag(
        artikel: _fuss,
        angaben: const {'MinHoehe': 55, 'MaxHoehe': 95},
      ),
    ],
  ),
);

/// M9-06: Planungsunterlagen einer typischen Planung – zwei Flächen (F01
/// mit Gefälle und eine L-Form, zweimal gebaut) mit Belag, UK, Auflagern
/// und Materialliste – zusammenstellen und als PDF setzen.
class PlanungsunterlagenBenchmark extends AsyncBenchmarkBase {
  PlanungsunterlagenBenchmark() : super('server.Planungsunterlagen.pdf');

  final _planung = Planung([
    Terrassenflaeche(
      Planungsstand.start
          .mitGefaelle(true)
          .mitEckhoehe(0, const Millimeter(150))
          .mitEckhoehe(1, const Millimeter(150)),
    ),
    Terrassenflaeche(
      Planungsstand.start.mitForm(Terrassenform.lForm),
      haeufigkeit: 2,
    ),
  ]);
  var _bytes = 0;

  @override
  Future<void> run() async {
    final unterlagen = UnterlagenDienst.unterlagen(
      _planung,
      datum: DateTime(2026, 11, 5),
      belag: (_) => _diele,
      regelwerk: _regelwerk,
      unterkonstruktion: (_) => _uk,
    );
    _bytes += (await planungsunterlagenPdf(unterlagen)).length;
  }

  @override
  Future<void> teardown() async {
    if (_bytes == 0) throw StateError('Benchmark hat nichts erzeugt');
  }
}

Future<void> main() => PlanungsunterlagenBenchmark().report();
