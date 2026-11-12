import 'dart:math';

import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

const _ohne = Millimeter(0);
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

/// Stücke von F04 (diagonal 135°, 480 × 309 cm, Fuge 6 mm, Überlänge).
const _f04 = [
  70,
  202,
  334,
  466,
  598,
  730,
  862,
  994,
  1126,
  1258,
  1390,
  1522,
  1654,
  1786,
  1918,
  2050,
  2182,
  2314,
  2432,
  14,
  2498,
  80,
  2564,
  146,
  2630,
  212,
  2696,
  278,
  2762,
  344,
  2828,
  410,
  2894,
  476,
  2960,
  542,
  3026,
  608,
  3092,
  674,
  3158,
  740,
  3224,
  806,
  3290,
  872,
  3356,
  938,
  3394,
  1004,
  3366,
  1070,
  3300,
  1136,
  3234,
  1202,
  3168,
  1268,
  3102,
  1334,
  3036,
  1400,
  2970,
  1466,
  2904,
  1532,
  2838,
  1598,
  2772,
  1664,
  2706,
  1730,
  2640,
  1796,
  2574,
  1862,
  2508,
  1928,
  2442,
  1994,
  2376,
  2060,
  2310,
  2126,
  2244,
  2185,
  2178,
  2178,
  2112,
  2112,
  2046,
  2046,
  1980,
  1980,
  1914,
  1914,
  1848,
  1848,
  1782,
  1782,
  1716,
  1716,
  1650,
  1650,
  1584,
  1584,
  1518,
  1518,
  1452,
  1452,
  1386,
  1386,
  1320,
  1320,
  1254,
  1254,
  1188,
  1188,
  1122,
  1122,
  1056,
  1056,
  990,
  990,
  924,
  924,
  858,
  858,
  792,
  792,
  726,
  726,
  660,
  660,
  594,
  594,
  528,
  528,
  462,
  462,
  396,
  396,
  330,
  330,
  264,
  264,
  198,
  198,
  132,
  132,
  66,
  66,
];

/// Musterverfahren eingehalten (R-B17): höchstens 3 Stücke, Sägeschnitt
/// zwischen zwei Stücken, Stücke absteigend, jedes weitere aus einem Rest
/// ab 30 cm; Lieferlänge samt Überlänge reicht, keine kürzere reichte.
void _musterGueltig(
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
    expect(d.schnitte.length, inInclusiveRange(1, stueckeJeDiele));
    var rest = d.laenge.mm + dielenUeberlaenge.mm;
    for (final (i, s) in d.schnitte.indexed) {
      if (i > 0) {
        expect(s.mm, lessThanOrEqualTo(d.schnitte[i - 1].mm));
        expect(rest, greaterThanOrEqualTo(mindestrest.mm));
      }
      expect(s.mm, lessThanOrEqualTo(rest));
      rest -= s.mm + saegeschnitt.mm;
    }
    final schnitte = [for (final s in d.schnitte) s.mm];
    for (final l in laengen) {
      if (l < d.laenge) {
        expect(
          Musterregel.dielen.passt(l.mm + dielenUeberlaenge.mm, schnitte),
          isFalse,
        );
      }
    }
  }
}

void main() {
  group('optimiereZuschnitt', () {
    test('F01: 48 Stücke à 4800 mm in 48 × 5000 mm wie die Regel', () {
      final stuecke = List.filled(48, const Millimeter(4800));
      final d = optimiereZuschnitt(stuecke, _laengen);
      expect(_text(d), List.filled(48, '5000: 4800'));
    });

    test('3 cm Überlänge (Planungskern v6 / Entscheidung 11.11.2026): '
        'eine Lieferlänge nimmt bis zu ihrer Länge plus 3 cm auf', () {
      const u = dielenUeberlaenge;
      expect(
        _text(
          optimiereZuschnitt(
            _mm([6030, 6030, 3015, 3015]),
            _laengen,
            ueberlaenge: u,
            muster: Musterregel.frei,
          ),
        ),
        ['6000: 6030', '6000: 6030', '6000: 3015 + 3015'],
      );
      // ohne Überlänge passen 2 × 301,5 cm nicht in 6 m
      expect(_text(optimiereZuschnitt(_mm([3015, 3015]), const [_m6])), [
        '6000: 3015',
        '6000: 3015',
      ]);
      // je Lieferlänge eine Variante, wenn das längste Stück samt Überlänge
      // hineinpasst
      final v = verschnittvarianten([
        (
          belag: _diele,
          laengen: _laengen,
          stuecke: _mm([6030, 2000]),
          ueberlaenge: u,
          muster: Musterregel.frei,
        ),
      ]);
      expect(v, hasLength(2));
      expect(v[1].dielenlisten[_diele]!.anzahl, {_m6: 2});
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
          ueberlaenge: _ohne,
          muster: Musterregel.frei,
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
        (
          ueberlaenge: _ohne,
          muster: Musterregel.frei,
          belag: _diele,
          laengen: const [_m6, _m4, _m5],
          stuecke: stuecke,
        ),
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
          (
            ueberlaenge: _ohne,
            muster: Musterregel.frei,
            belag: _diele,
            laengen: _laengen,
            stuecke: stuecke,
          ),
        ], hoechstens: 2),
        hasLength(2),
      );
      // eine Länge: nur eine Variante
      expect(
        verschnittvarianten([
          (
            ueberlaenge: _ohne,
            muster: Musterregel.frei,
            belag: _diele,
            laengen: const [_m5],
            stuecke: stuecke,
          ),
        ]),
        hasLength(1),
      );
    });

    test('gleiche Länge geliefert: weniger Dielen zuerst', () {
      final v = verschnittvarianten([
        (
          ueberlaenge: _ohne,
          muster: Musterregel.frei,
          belag: _diele,
          laengen: _laengen,
          stuecke: _mm([2000, 2000, 2000]),
        ),
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

    test('zuerst weniger geliefert, auch mit mehr Dielen', () {
      final v = verschnittvarianten([
        (
          ueberlaenge: _ohne,
          muster: Musterregel.frei,
          belag: _diele,
          laengen: const [_m4, _m6],
          stuecke: List.filled(7, const Millimeter(1900)),
        ),
      ]);
      expect([for (final x in v) x.summe.geliefert.mm], [14000, 16000, 18000]);
      expect(v[1].dielenlisten[_diele]!.anzahl, {_m4: 4});
      expect(v[2].dielenlisten[_diele]!.anzahl, {_m6: 3});
    });

    test('mehrere Beläge: Variante k nimmt je Belag die k-te oder letzte; '
        'Gruppen desselben Belags zusammen', () {
      final v = verschnittvarianten([
        (
          ueberlaenge: _ohne,
          muster: Musterregel.frei,
          belag: _diele,
          laengen: _laengen,
          stuecke: List.filled(2, const Millimeter(4800)),
        ),
        (
          ueberlaenge: _ohne,
          muster: Musterregel.frei,
          belag: _andere,
          laengen: const [_m4],
          stuecke: _mm([3000]),
        ),
        (
          ueberlaenge: _ohne,
          muster: Musterregel.frei,
          belag: _diele,
          laengen: const [_m4],
          stuecke: _mm([3900]),
        ),
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
          (
            ueberlaenge: _ohne,
            muster: Musterregel.frei,
            belag: _diele,
            laengen: _laengen,
            stuecke: const <Millimeter>[],
          ),
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
        (
          ueberlaenge: _ohne,
          muster: Musterregel.frei,
          belag: _diele,
          laengen: _laengen,
          stuecke: stuecke,
        ),
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
  group('Musterverfahren (R-B17, Planungskern v6 Regeln 1.3, 1.4)', () {
    const u = dielenUeberlaenge;
    const muster = Musterregel.dielen;
    List<String> lauf(List<int> stuecke, int nr, [List<Millimeter>? l]) =>
        _text(
          musterZuschnitte(
            _mm(stuecke),
            l ?? const [_m6],
            ueberlaenge: u,
            muster: muster,
          )[nr],
        );

    test('größte Füllung: bis zu zwei weitere Stücke, gleiche Länge nur, '
        'wenn zwei offen sind', () {
      expect(lauf([3000, 1500, 1500], 0), ['6000: 3000 + 1500 + 1500']);
      expect(lauf([3000, 1500, 1400], 0), ['6000: 3000 + 1500 + 1400']);
      expect(lauf([3000, 1500], 0), ['6000: 3000 + 1500']);
      // ein Stück, wenn es mehr füllt als jedes Paar
      expect(lauf([3000, 2600, 100], 0), ['6000: 3000 + 2600 + 100']);
      // nach 2900 bleiben 12 cm: zu kurz für das dritte Stück
      expect(lauf([3000, 2900, 100], 0), ['6000: 3000 + 2900', '6000: 100']);
      expect(lauf([3000, 2800, 1500, 1200], 0), [
        '6000: 3000 + 2800',
        '6000: 1500 + 1200',
      ]);
      // das zweite Stück muss einen Rest ab 30 cm lassen: 2720 ja, 2730 nein
      expect(lauf([3000, 2700, 20], 0), ['6000: 3000 + 2700 + 20']);
      expect(lauf([3000, 2730, 20], 0), ['6000: 3000 + 2730', '6000: 20']);
      // Rest nach dem ersten Stück unter 30 cm: kein weiteres
      expect(lauf([5800, 200], 0), ['6000: 5800', '6000: 200']);
      // das Paar mit der größten Summe, auch wenn das zweite Stück kürzer
      // wird: 2000 + 1000 statt 2500 + 300
      expect(lauf([3000, 2500, 2000, 1000, 300], 0), [
        '6000: 3000 + 2000 + 1000',
        '6000: 2500 + 300',
      ]);
    });

    test('kürzestes Stück dazu: das kürzeste offene und das längste, das '
        'davor noch passt', () {
      expect(lauf([3000, 2000, 1000, 100], 0), [
        '6000: 3000 + 2000 + 1000',
        '6000: 100',
      ]);
      expect(lauf([3000, 2000, 1000, 100], 1), [
        '6000: 3000 + 2000 + 100',
        '6000: 1000',
      ]);
      // kein Stück passt mehr davor: nur das kürzeste
      expect(lauf([3000, 2900, 100], 1), ['6000: 3000 + 100', '6000: 2900']);
      // das kürzeste zweimal, wenn zwei offen sind
      expect(lauf([3000, 100, 100], 1), ['6000: 3000 + 100 + 100']);
      // passt das kürzeste nicht oder ist der Rest zu kurz: größte Füllung
      expect(lauf([5000, 1200, 1100], 1), ['6000: 5000', '6000: 1200 + 1100']);
      expect(lauf([5800, 200, 200], 1), ['6000: 5800', '6000: 200 + 200']);
    });

    test('F04: 152 Stücke brauchen mindestens 51 Dielen – das kürzeste Stück '
        'dazu schafft es mit 237 m, die größte Füllung braucht 57', () {
      final stuecke = _mm(_f04);
      final laeufe = musterZuschnitte(
        stuecke,
        _laengen,
        ueberlaenge: u,
        muster: muster,
      );
      expect([for (final l in laeufe) l.length], [57, 51]);
      expect(_geliefert(laeufe[1]), 237000);
      final d = zuschneiden(stuecke, _laengen, ueberlaenge: u, muster: muster);
      expect(_text(d), _text(laeufe[1]));
      _musterGueltig(stuecke, _laengen, d);
      // ohne Musterverfahren 46 × 5000 mm (1-%-Regel nur mit Muster: hier
      // die kürzeste, 230 m)
      expect(
        Dielenliste.aus(zuschneiden(stuecke, _laengen, ueberlaenge: u))
            .geliefert,
        const Millimeter(231000),
      );
      // mit Optimierung dasselbe
      expect(
        _text(
          optimiereZuschnitt(stuecke, _laengen, ueberlaenge: u, muster: muster),
        ),
        _text(d),
      );
    });

    test('Zufallsfälle: Musterverfahren immer eingehalten', () {
      final zufall = Random(17);
      for (var fall = 0; fall < 200; fall++) {
        final stuecke = [
          for (var k = 0; k < zufall.nextInt(90); k++)
            Millimeter(1 + zufall.nextInt(6030)),
        ];
        for (final d in [
          zuschneiden(stuecke, _laengen, ueberlaenge: u, muster: muster),
          verteile(stuecke, _laengen, ueberlaenge: u, muster: muster),
          ...musterZuschnitte(
            stuecke,
            _laengen,
            ueberlaenge: u,
            muster: muster,
          ),
        ]) {
          _musterGueltig(stuecke, _laengen, d);
        }
      }
    });

    test('Varianten: die nach der 1-%-Regel beste zuerst', () {
      // 6 × 1900 mm: 3 × 4000 (12 m) oder 2 × 6000 (12 m, weniger Dielen)
      final v = verschnittvarianten([
        (
          belag: _diele,
          laengen: const [_m4, _m6],
          stuecke: List.filled(6, const Millimeter(1900)),
          ueberlaenge: u,
          muster: muster,
        ),
      ]);
      expect(
        [for (final x in v) x.dielenlisten[_diele]!.anzahl],
        [
          {_m6: 2},
          {_m4: 3},
        ],
      );
      // bis 1 % mehr, aber weniger Dielen, gewinnt vor der kürzesten: 108 m
      // in 18 Dielen statt 107 m
      final w = verschnittvarianten([
        (
          belag: _diele,
          laengen: _laengen,
          stuecke: _mm([
            2500, 5500, 6000, 3000, 6000, 3000, 4500, 500, 3000, 3500, //
            1500, 3500, 1000, 3500, 6000, 6000, 5500, 2500, 4500, 1500,
            1000, 6000, 5500, 2500, 5500, 4500, 2000, 1500, 1000, 2500,
          ]),
          ueberlaenge: u,
          muster: muster,
        ),
      ]);
      expect([for (final x in w) x.summe.geliefert.mm], [108000, 107000]);
      expect(w.first.zuschnitt[_diele], hasLength(18));
    });
  });
}
