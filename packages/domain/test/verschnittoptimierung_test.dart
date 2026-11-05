import 'dart:math';

import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

const _m4 = Millimeter(4000);
const _m5 = Millimeter(5000);
const _m6 = Millimeter(6000);
const _laengen = [_m4, _m5, _m6];
const _diele = Artikelnummer('10-10-001');
const _andere = Artikelnummer('10-10-002');

List<Millimeter> _mm(List<int> werte) => [for (final w in werte) Millimeter(w)];

/// Zuschnitt als Texte „Länge: Schnitte“ in mm, in der Reihenfolge.
List<String> _text(List<Lieferdiele> dielen) => [
  for (final d in dielen)
    '${d.laenge.mm}: ${[for (final s in d.schnitte) s.mm].join(' + ')}',
];

int _geliefert(List<Lieferdiele> dielen) =>
    dielen.fold(0, (s, d) => s + d.laenge.mm);

/// Jedes Stück genau einmal geschnitten, keine Diele überfüllt, nur
/// erlaubte Längen.
void _gueltig(
  List<Millimeter> stuecke,
  List<Millimeter> laengen,
  List<Lieferdiele> dielen,
) {
  final geschnitten = [
    for (final d in dielen) ...[for (final s in d.schnitte) s.mm],
  ]..sort();
  expect(geschnitten, [for (final s in stuecke) s.mm]..sort());
  for (final d in dielen) {
    expect(laengen, contains(d.laenge));
    expect(d.genutzt.mm, lessThanOrEqualTo(d.laenge.mm));
    expect(d.schnitte, isNotEmpty);
  }
}

void main() {
  group('optimiereZuschnitt', () {
    test('F01: 48 Stücke à 4800 mm in 48 × 5000 mm wie die Regel', () {
      final stuecke = List.filled(48, const Millimeter(4800));
      final d = optimiereZuschnitt(stuecke, _laengen);
      expect(_text(d), List.filled(48, '5000: 4800'));
    });

    test('Teilsummen auf den Millimeter: 3000 + 1700 + 1300 füllen 6000 mm '
        'genau, nicht 3000 + 1700 + 1000', () {
      final d = optimiereZuschnitt(_mm([3000, 1700, 1300, 1000]), const [_m6]);
      expect(_text(d), ['6000: 3000 + 1700 + 1300', '6000: 1000']);
    });

    test('über Reihen und Flächen gemischt: weniger als die Regel', () {
      final stuecke = _mm([5500, 4500, 4500, 1000]);
      expect(_text(zuschneiden(stuecke, _laengen)), [
        '6000: 5500',
        '5000: 4500',
        '5000: 4500',
        '4000: 1000',
      ]);
      expect(_text(optimiereZuschnitt(stuecke, _laengen)), [
        '6000: 5500',
        '6000: 4500 + 1000',
        '5000: 4500',
      ]);
    });

    test('liefert die Regel weniger, gilt sie', () {
      final stuecke = _mm([2000, 3000, 1500, 3000, 3000]);
      final d = optimiereZuschnitt(stuecke, _laengen);
      expect(_text(d), _text(zuschneiden(stuecke, _laengen)));
      expect(_text(d), [
        '5000: 3000 + 2000',
        '5000: 3000 + 1500',
        '4000: 3000',
      ]);
    });

    test('gleich viel geliefert: die mit weniger Dielen', () {
      final stuecke = _mm([3500, 3000, 3000, 1000, 1000]);
      expect(_geliefert(zuschneiden(stuecke, _laengen)), 12000);
      expect(zuschneiden(stuecke, _laengen), hasLength(3));
      expect(_text(optimiereZuschnitt(stuecke, _laengen)), [
        '6000: 3500 + 1000 + 1000',
        '6000: 3000 + 3000',
      ]);
    });

    test('Vorschau gegen Ende: kein kurzes Stück für eine ganze Diele', () {
      // 4800 + 1000 in 6000 nutzt mehr, ließe aber 700 für 4000 mm übrig
      expect(_text(optimiereZuschnitt(_mm([4800, 1000, 700]), _laengen)), [
        '5000: 4800',
        '4000: 1000 + 700',
      ]);
      // viele offene Stücke: erst der größte genutzte Anteil
      final viele = List.filled(vorschau, const Millimeter(4800));
      final d = optimiereZuschnitt([
        ...viele,
        ..._mm([1000, 700]),
      ], _laengen);
      expect(_text(d).first, '6000: 4800 + 1000');
      expect(_geliefert(d), 6000 + (vorschau - 2) * 5000 + 6000);
    });

    test('Muster wiederholt, die letzte Wiederholung neu entschieden', () {
      // 2 × (4600) und 1100 + 1000: die zweite 4600 nimmt die 1100 mit
      final d = optimiereZuschnitt(
        _mm([4600, 4600, 1500, 1100, 1000, 3200]),
        _laengen,
      );
      _gueltig(_mm([4600, 4600, 1500, 1100, 1000, 3200]), _laengen, d);
      expect(_geliefert(d), lessThanOrEqualTo(17000));
      // gleiche Stücke in Menge: ein Muster für alle
      final paare = optimiereZuschnitt(
        List.filled(1000, const Millimeter(2000)),
        _laengen,
      );
      // 2 × 2000 füllen 4000 mm genau so gut wie 3 × 2000 die 6000 mm –
      // die kürzere gewinnt
      expect(_text(paare).toSet(), {'4000: 2000 + 2000'});
      expect(paare, hasLength(500));
    });

    test('Bitfeld über Wortgrenzen und Vielfache von 32 mm', () {
      // 3200 = 100 × 32 (Schritt ohne Rest), 33 und 31 mm über die Grenze
      expect(
        _text(optimiereZuschnitt(_mm([3200, 2768, 33, 31]), const [_m6])),
        ['6000: 3200 + 2768 + 31', '6000: 33'],
      );
      expect(_text(optimiereZuschnitt(_mm([5936, 32, 32]), const [_m6])), [
        '6000: 5936 + 32 + 32',
      ]);
      expect(_text(optimiereZuschnitt(_mm([5967, 33]), const [_m6])), [
        '6000: 5967 + 33',
      ]);
    });

    test('Lieferlängen in beliebiger Reihenfolge, leer, Stück zu lang', () {
      expect(optimiereZuschnitt(const [], _laengen), isEmpty);
      expect(_text(optimiereZuschnitt(_mm([3900]), const [_m6, _m4, _m5])), [
        '4000: 3900',
      ]);
      expect(
        () => optimiereZuschnitt(_mm([6001]), _laengen),
        throwsArgumentError,
      );
    });

    test('Zufall: immer gültig und nie mehr als die Regel', () {
      final zufall = Random(74);
      for (var i = 0; i < 400; i++) {
        final stuecke = [
          for (var k = 0; k < 1 + zufall.nextInt(30); k++)
            Millimeter(50 + zufall.nextInt(5951)),
        ];
        final d = optimiereZuschnitt(stuecke, _laengen);
        _gueltig(stuecke, _laengen, d);
        final regel = zuschneiden(stuecke, _laengen);
        expect(_geliefert(d), lessThanOrEqualTo(_geliefert(regel)));
      }
    });
  });

  group('verschnittvarianten', () {
    test('F01: 4 % in 5000 mm, 20 % in 6000 mm (alter Planer F43 ohne die '
        '550 cm, die es nicht mehr gibt)', () {
      final v = verschnittvarianten([
        (
          belag: _diele,
          laengen: _laengen,
          stuecke: List.filled(48, const Millimeter(4800)),
        ),
      ]);
      expect(v, hasLength(2));
      expect(v[0].dielenlisten[_diele]!.anzahl, {_m5: 48});
      expect(v[0].summe.verschnitt, closeTo(0.04, 1e-9));
      expect(v[1].dielenlisten[_diele]!.anzahl, {_m6: 48});
      expect(v[1].summe.verschnitt, closeTo(0.2, 1e-9));
    });

    test('Längenmischung zuerst, dann je Länge; gleiche Listen einmal, '
        'höchstens drei', () {
      final stuecke = _mm([3500, 3000, 3000, 1000, 1000]);
      final v = verschnittvarianten([
        (belag: _diele, laengen: const [_m6, _m4, _m5], stuecke: stuecke),
      ]);
      expect(
        [for (final x in v) x.dielenlisten[_diele]!.anzahl],
        [
          {_m6: 2},
          {_m4: 3},
          {_m5: 3},
        ],
      );
      expect(
        verschnittvarianten([
          (belag: _diele, laengen: _laengen, stuecke: stuecke),
        ], hoechstens: 2),
        hasLength(2),
      );
      // eine Länge: nur eine Variante
      expect(
        verschnittvarianten([
          (belag: _diele, laengen: const [_m5], stuecke: stuecke),
        ]),
        hasLength(1),
      );
    });

    test('gleiche Länge geliefert: weniger Dielen zuerst', () {
      final v = verschnittvarianten([
        (belag: _diele, laengen: _laengen, stuecke: _mm([2000, 2000, 2000])),
      ]);
      expect(
        [for (final x in v) x.dielenlisten[_diele]!.anzahl],
        [
          {_m6: 1},
          {_m4: 2},
          {_m5: 2},
        ],
      );
    });

    test('mehrere Beläge: Variante k nimmt je Belag die k-te oder letzte; '
        'Gruppen desselben Belags zusammen', () {
      final v = verschnittvarianten([
        (
          belag: _diele,
          laengen: _laengen,
          stuecke: List.filled(2, const Millimeter(4800)),
        ),
        (belag: _andere, laengen: const [_m4], stuecke: _mm([3000])),
        (belag: _diele, laengen: const [_m4], stuecke: _mm([3900])),
      ]);
      expect(v, hasLength(2));
      expect(v[0].zuschnitt.keys, [_diele, _andere]);
      expect(v[0].dielenlisten[_diele]!.anzahl, {_m4: 1, _m5: 2});
      expect(v[1].dielenlisten[_diele]!.anzahl, {_m4: 1, _m6: 2});
      expect(v[1].dielenlisten[_andere]!.anzahl, {_m4: 1});
      expect(v[1].summe.geliefert, const Millimeter(20000));
      expect(v[1].summe.geplant, const Millimeter(16500));
      expect(verschnittvarianten(const []), isEmpty);
      expect(
        verschnittvarianten([
          (belag: _diele, laengen: _laengen, stuecke: const []),
        ]).single.summe.geliefert,
        const Millimeter(0),
      );
    });

    test('Variante unveränderlich', () {
      final v = Verschnittvariante({
        _diele: [
          Lieferdiele(_m5, const [Millimeter(4800)]),
        ],
      });
      expect(() => v.zuschnitt[_andere] = const [], throwsUnsupportedError);
      expect(v.zuschnitt[_diele]!.clear, throwsUnsupportedError);
    });

    test('Laufzeit: 10 000 Stücke in 300 Sorten unter einer Sekunde', () {
      final zufall = Random(9);
      final sorten = [for (var i = 0; i < 300; i++) 300 + zufall.nextInt(5700)];
      final stuecke = [
        for (var i = 0; i < 10000; i++) Millimeter(sorten[i % 300]),
      ];
      final uhr = Stopwatch()..start();
      final v = verschnittvarianten([
        (belag: _diele, laengen: _laengen, stuecke: stuecke),
      ]);
      expect(uhr.elapsed, lessThan(const Duration(seconds: 1)));
      expect(v.first.summe.verschnitt, lessThan(0.02));
    });
  });

  group('Berechnung: Varianten im Transport (Plätze 165, 166)', () {
    const liste = [(belag: _diele, laenge: _m5, anzahl: 48)];
    test('hin und zurück, unveränderlich, in der Kopie mit Planung', () {
      final b = Berechnung(umriss: const [], flaeche: 1).mitPlanung(
        2,
        verschnittvarianten: const [
          (verschnitt: 0.04, dielen: liste),
          (verschnitt: 0.2, dielen: [(belag: _diele, laenge: _m6, anzahl: 48)]),
        ],
        verschnittvariante: 2,
      );
      for (final k in [b, Berechnung.ausBytes(b.zuBytes())]) {
        expect(k.verschnittvarianten, hasLength(2));
        expect(k.verschnittvarianten.first.verschnitt, 0.04);
        expect(k.verschnittvarianten.first.dielen, liste);
        expect(k.verschnittvarianten.last.dielen.single.laenge, _m6);
      }
      expect(Berechnung.ausBytes(b.zuBytes()).verschnittvariante, 2);
      expect(b.mitPlanung(2).verschnittvariante, isNull);
      expect(b.mitPlanung(2).verschnittvarianten, isEmpty);
      expect(b.verschnittvarianten.clear, throwsUnsupportedError);
      expect(b.verschnittvarianten.first.dielen.clear, throwsUnsupportedError);
      final ohne = Berechnung.ausBytes(
        Berechnung(umriss: const [], flaeche: 0).zuBytes(),
      );
      expect(ohne.verschnittvarianten, isEmpty);
      expect(ohne.verschnittvariante, isNull);
    });

    test('fehlende Felder einer Variante: 0 und leer', () {
      final fbb = fb.Builder()..startTable(0);
      final leer = fbb.endTable();
      final varianten = fbb.writeList([leer]);
      fbb
        ..startTable(167)
        ..addOffset(165, varianten);
      fbb.finish(fbb.endTable());
      final v = Berechnung.ausBytes(fbb.buffer).verschnittvarianten.single;
      expect(v.verschnitt, 0);
      expect(v.dielen, isEmpty);
    });
  });
}
