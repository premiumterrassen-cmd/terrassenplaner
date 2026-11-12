import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

import 'altplaner.dart';

const _m4 = Millimeter(4000);
const _m5 = Millimeter(5000);
const _m6 = Millimeter(6000);
const _m7 = Millimeter(7000);

Artikel _diele(
  int breite, [
  List<Millimeter> laengen = const [_m4, _m5, _m6],
  Artikelart art = Artikelart.diele,
]) => Artikel(
  nummer: const Artikelnummer('10-10-001'),
  titel: 'Diele',
  art: art,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  abmessungen: Abmessungen(breite: Millimeter(breite), laengen: laengen),
  holzart: art.istHolz ? robinie : null,
  serie: art.istHolz ? basic : null,
);

/// Holzfliese 606 × 606 mm (ROBI-FIXX, F25).
final _fliese = Artikel(
  nummer: const Artikelnummer('40-10-001'),
  titel: 'Fliese',
  art: Artikelart.holzfliese,
  einheit: Verkaufseinheit(Mengeneinheit.stueck),
  abmessungen: Abmessungen(
    breite: const Millimeter(606),
    laengen: const [Millimeter(606)],
  ),
);

List<int> _mm(Iterable<Millimeter> werte) => [for (final w in werte) w.mm];

Map<int, int> _anzahl(Dielenliste liste) => {
  for (final MapEntry(:key, :value) in liste.anzahl.entries) key.mm: value,
};

Planungsstand _rechteck(int ab, int bc) =>
    Planungsstand(grundriss: RechteckGrundriss(Millimeter(ab), Millimeter(bc)));

/// Rechteck als geschlossene Freiform – auch schmaler als 50 cm.
Planungsstand _streifen(double ab, double bc) => Planungsstand(
  grundriss: FreiformGrundriss([
    Punkt.ursprung,
    Punkt(ab, 0),
    Punkt(ab, bc),
    Punkt(0, bc),
  ], geschlossen: true),
);

Belagverlegung _verlegt(Planungsstand stand, [Artikel? belag]) => verlegeBelag(
  stand,
  belag ?? _diele(60),
  fuge: altplanerFuge,
  dielenmuster: altplanerMuster,
)!;

/// Dielen nach Nummer als sortierbare Texte „Länge × Breite: Stück“ (cm).
List<String> _sorten(Belagverlegung v) => [
  for (final t in v.teile)
    for (final s in t.sorten) '${s.laenge.cm}x${s.breite.cm}:${s.stueck}',
]..sort();

/// Was die Verschnittoptimierung (M9-01) für alle Stücke einer Verlegung
/// liefert (mm).
int _optimiert(Belagverlegung v) => optimiereZuschnitt([
  for (final t in v.teile)
    for (final s in t.stuecke) s.laenge,
], v.lieferlaengen).fold(0, (summe, d) => summe + d.laenge.mm);

/// Zuschnittplan (M9-02) als „Ausgangslänge cm: Schnitte cm“ → Menge;
/// Schnitte sortiert, Artikel zusammengefasst.
Map<String, int> _plan(Iterable<(double, List<double>, int)> zeilen) {
  final plan = <String, int>{};
  for (final (laenge, schnitte, menge) in zeilen) {
    final schluessel =
        '$laenge: ${([...schnitte]..sort((a, b) => b.compareTo(a))).join(' + ')}';
    plan.update(schluessel, (n) => n + menge, ifAbsent: () => menge);
  }
  return plan;
}

Map<String, int> _neuerPlan(Belagverlegung v) => _plan([
  for (final z in Zuschnittplan.aus([
    for (final t in v.teile)
      for (final d in t.zuschnitt) (artikel: _diele(60), stueck: d, anzahl: 1),
  ]).zeilen)
    (z.ausgangslaenge.cm, [for (final s in z.schnitte) s.cm], z.menge),
]);

int _summe(Map<int, int> anzahl) =>
    anzahl.entries.fold(0, (summe, e) => summe + e.key * e.value);

/// Die Verteilung je Stück (bis 11.11.2026), als Gegenprobe für die
/// schnellere je Länge und Rest (`verteile`): gleiche Ergebnisse.
List<String> _verteileJeStueck(List<int> stuecke, List<int> laengen, int u) {
  final folge = [...stuecke]..sort((a, b) => b - a);
  final l = [...laengen]..sort();
  final offen = <(int, List<int>)>[];
  final reste = <int>[];
  for (var i = 0; i < folge.length; i++) {
    final stueck = folge[i];
    var beste = -1;
    for (var j = 0; j < reste.length; j++) {
      if (reste[j] >= stueck && (beste < 0 || reste[j] < reste[beste])) {
        beste = j;
      }
    }
    if (beste < 0) {
      int? wahl;
      var besterRest = 0;
      for (final laenge in l) {
        if (laenge + u < stueck) continue;
        var rest = laenge + u - stueck;
        for (var k = i + 1; k < folge.length && rest >= folge.last; k++) {
          if (folge[k] <= rest) rest -= folge[k];
        }
        if (wahl == null || rest < besterRest) {
          wahl = laenge;
          besterRest = rest;
        }
      }
      offen.add((wahl!, [stueck]));
      reste.add(wahl + u - stueck);
    } else {
      offen[beste].$2.add(stueck);
      reste[beste] -= stueck;
    }
  }
  return [
    for (final (j, (laenge, schnitte)) in offen.indexed)
      '${l.firstWhere((x) => x >= laenge - reste[j])}: $schnitte',
  ];
}

void main() {
  group('Musterverfahren (R-B17, Planungskern v6 Regeln 1.3, 1.4)', () {
    const u = dielenUeberlaenge;
    const muster = Musterregel.dielen;
    List<String> text(List<Lieferdiele> dielen) => [
      for (final d in dielen) '${d.laenge.mm}: ${_mm(d.schnitte)}',
    ];
    List<String> verteilt(
      List<int> stuecke, [
      List<Millimeter> laengen = const [_m4, _m5, _m6],
    ]) => text(
      verteile(
        [for (final s in stuecke) Millimeter(s)],
        laengen,
        ueberlaenge: u,
        muster: muster,
      ),
    );
    List<String> zugeschnitten(
      List<int> stuecke, [
      List<Millimeter> laengen = const [_m4, _m5, _m6],
    ]) => text(
      zuschneiden(
        [for (final s in stuecke) Millimeter(s)],
        laengen,
        ueberlaenge: u,
        muster: muster,
      ),
    );

    test('Regeln: 5 mm Sägeschnitt, 3 Stücke, Reste ab 30 cm, 1 %', () {
      expect(saegeschnitt, const Millimeter(5));
      expect(stueckeJeDiele, 3);
      expect(mindestrest, const Millimeter(300));
      expect(mehrlaengeFuerWenigerDielen, 0.01);
      expect(muster.schnitt, saegeschnitt);
      expect(muster.hoechstens, stueckeJeDiele);
      expect(muster.wiederverwendetAb, mindestrest);
      expect(muster.mehrlaenge, mehrlaengeFuerWenigerDielen);
      const frei = Musterregel.frei;
      expect(frei.schnitt, const Millimeter(0));
      expect(frei.hoechstens, isNull);
      expect(frei.wiederverwendetAb, const Millimeter(0));
      expect(frei.mehrlaenge, 0);
      // nimmt ein weiteres Stück auf: Rest ab 30 cm, unter 3 Stücken
      expect(muster.nimmtAuf(2, 300), isTrue);
      expect(muster.nimmtAuf(2, 299), isFalse);
      expect(muster.nimmtAuf(3, 1000), isFalse);
      expect(frei.nimmtAuf(100, 0), isTrue);
      expect(frei.nimmtAuf(1, -1), isFalse);
      // passt: absteigend geschnitten, je Rest geprüft
      expect(muster.passt(6030, [3000, 3000]), isTrue);
      expect(muster.passt(6030, [3015, 3015]), isFalse);
      expect(muster.passt(4030, [3725, 290]), isTrue);
      expect(muster.passt(4030, [3726, 290]), isFalse);
      expect(muster.passt(6030, [2000, 2000, 1000, 500]), isFalse);
      expect(muster.passt(6030, []), isTrue);
      expect(frei.passt(4000, [2000, 2000]), isTrue);
      expect(frei.passt(4000, [2000, 2001]), isFalse);
      expect(muster.kuerzeste([4000, 5000], 30, [3800, 200]), 5000);
      expect(frei.kuerzeste([4000, 5000], 30, [3800, 200]), 4000);
    });

    test('Sägeschnitt zwischen zwei Stücken: 2 × 3000 mm aus 6 m, 2 × 3015 '
        'nicht', () {
      expect(verteilt([3000, 3000], const [_m6]), ['6000: [3000, 3000]']);
      expect(verteilt([3015, 3015], const [_m6]), [
        '6000: [3015]',
        '6000: [3015]',
      ]);
      // 2 × 2015 + 5 mm passen nicht in 4000 + 30: 5000
      expect(verteilt([2015, 2015]), ['5000: [2015, 2015]']);
      expect(verteilt([2000, 2000]), ['4000: [2000, 2000]']);
    });

    test('höchstens 3 Stücke je Diele', () {
      expect(verteilt([1000, 1000, 1000, 1000, 1000]), [
        '4000: [1000, 1000, 1000]',
        '4000: [1000, 1000]',
      ]);
      // ohne Musterverfahren vier in eine Diele
      expect(
        text(
          verteile(List.filled(5, const Millimeter(1000)), const [
            _m4,
            _m5,
            _m6,
          ], ueberlaenge: u),
        ),
        ['4000: [1000, 1000, 1000, 1000]', '4000: [1000]'],
      );
      // die neue Diele zählt nur 3 Stücke: 3700 mit Rest 115 statt 4000
      expect(verteilt([3000, 300, 300, 300], const [Millimeter(3700), _m4]), [
        '3700: [3000, 300, 300]',
        '3700: [300]',
      ]);
    });

    test('Reste ab 30 cm: ein Stück nur aus einem Rest ab 300 mm', () {
      expect(verteilt([3725, 290], const [_m4]), ['4000: [3725, 290]']);
      expect(verteilt([3726, 290], const [_m4]), [
        '4000: [3726]',
        '4000: [290]',
      ]);
      expect(verteilt([3800, 200], const [_m4]), [
        '4000: [3800]',
        '4000: [200]',
      ]);
      // die neue Diele zählt den Rest erst ab 300 mm: 4100 nimmt alle drei
      // (3475 + 250 + 250 mit Resten 650 und 395), 4000 nur zwei
      expect(verteilt([3475, 250, 250], const [_m4, Millimeter(4100)]), [
        '4100: [3475, 250, 250]',
      ]);
    });

    test('zuschneiden: auch je Lieferlänge und Diele für Diele, dann die '
        '1-%-Regel', () {
      // alle Längen: 3800 in 4000 (Rest 225 zu kurz), 200 extra; nur 5000
      // nimmt beide
      expect(verteilt([3800, 200], const [_m4, _m5]), [
        '4000: [3800]',
        '4000: [200]',
      ]);
      expect(zugeschnitten([3800, 200], const [_m4, _m5]), [
        '5000: [3800, 200]',
      ]);
      // nur in 6000 verteilt, dann gekürzt: 2 × 1900 brauchen nur 4000
      expect(zugeschnitten([1900, 1900, 1900, 1900, 1900, 1900]), [
        '6000: [1900, 1900, 1900]',
        '6000: [1900, 1900, 1900]',
      ]);
      expect(zugeschnitten([5800, 1900, 1900]), [
        '6000: [5800]',
        '4000: [1900, 1900]',
      ]);
      expect(zugeschnitten([]), isEmpty);
      // eine Länge: keine weiteren Kandidaten
      expect(zugeschnitten([3000, 3000], const [_m6]), ['6000: [3000, 3000]']);
    });

    test('1-%-Regel: bis 1 % mehr mit weniger Dielen gewinnt', () {
      List<Lieferdiele> dielen(List<int> laengen) => [
        for (final l in laengen) Lieferdiele(Millimeter(l), const []),
      ];
      final kurz = dielen(List.filled(10, 5000)); // 50 m, 10 Dielen
      final knapp = dielen([...List.filled(8, 6000), 2500]); // 50,5 m, 9
      final zuViel = dielen([...List.filled(8, 6000), 2501]); // 50,501 m, 9
      expect(besteVerteilung([kurz, knapp]), same(knapp));
      expect(besteVerteilung([knapp, kurz]), same(knapp));
      expect(besteVerteilung([kurz, zuViel]), same(kurz));
      expect(besteVerteilung([zuViel, kurz]), same(kurz));
      // ohne Toleranz die kürzeste
      expect(besteVerteilung([knapp, kurz], mehrlaenge: 0), same(kurz));
      // gleich viele Dielen: die kürzere, bei Gleichstand die erste
      final laenger = dielen([...List.filled(9, 5000), 5400]); // 50,4 m, 10
      expect(besteVerteilung([laenger, kurz]), same(kurz));
      expect(besteVerteilung([kurz, laenger]), same(kurz));
      final gleich = dielen(List.filled(10, 5000));
      expect(besteVerteilung([kurz, gleich]), same(kurz));
      expect(besteVerteilung([gleich, kurz]), same(gleich));
      expect(besteVerteilung([kurz]), same(kurz));
    });

    test('verlegeBelag: Dielen nach dem Musterverfahren, Holzfliesen frei', () {
      final stand = _rechteck(4800, 3090);
      expect(verlegeBelag(stand, _diele(60))!.muster, Musterregel.dielen);
      expect(
        verlegeBelag(stand, _diele(60), dielenmuster: Musterregel.frei)!.muster,
        Musterregel.frei,
      );
    });
  });

  group('zuschneiden', () {
    test('je Länge und Rest gerechnet wie je Stück (Laufzeit, 11.11.2026)', () {
      final zufall = Random(7);
      for (var fall = 0; fall < 300; fall++) {
        final laengen = [4000, 5000, 6000];
        final sorten = [
          for (var k = 0; k < 1 + zufall.nextInt(5); k++)
            300 + zufall.nextInt(5700),
        ];
        final stuecke = [
          for (var k = 0; k < zufall.nextInt(60); k++)
            sorten[zufall.nextInt(sorten.length)],
        ];
        final u = fall.isEven ? 0 : 30;
        expect(
          [
            for (final d in verteile(
              [for (final s in stuecke) Millimeter(s)],
              [for (final l in laengen) Millimeter(l)],
              ueberlaenge: Millimeter(u),
            ))
              '${d.laenge.mm}: ${_mm(d.schnitte)}',
          ],
          _verteileJeStueck(stuecke, laengen, u),
          reason: 'Fall $fall: $stuecke',
        );
      }
    });

    List<String> zuschnitt(
      List<int> stuecke, [
      List<Millimeter> laengen = const [_m4, _m5, _m6],
      Millimeter ueberlaenge = const Millimeter(0),
    ]) => [
      for (final d in zuschneiden(
        [for (final s in stuecke) Millimeter(s)],
        laengen,
        ueberlaenge: ueberlaenge,
      ))
        '${d.laenge.mm}: ${_mm(d.schnitte)}',
    ];

    test('3 cm Überlänge (Planungskern v6 / Entscheidung 11.11.2026): eine '
        'Lieferlänge nimmt Stücke bis zu ihrer Länge plus 3 cm auf', () {
      const u = dielenUeberlaenge;
      expect(zuschnitt([6030], const [_m4, _m5, _m6], u), ['6000: [6030]']);
      expect(zuschnitt([], const [_m4, _m5, _m6], u), isEmpty);
      expect(zuschnitt([3015, 3015], const [_m4, _m5, _m6], u), [
        '6000: [3015, 3015]',
      ]);
      expect(zuschnitt([4020], const [_m4, _m5, _m6], u), ['4000: [4020]']);
      expect(zuschnitt([4031], const [_m4, _m5, _m6], u), ['5000: [4031]']);
      // ohne Überlänge passen sie nicht
      expect(zuschnitt([3015, 3015]), ['4000: [3015]', '4000: [3015]']);
      // Überlänge macht die Verteilung nie schlechter: F19 (Kreis Ø 360 cm)
      // liefert mit ihr verteilt 170 m, ohne 168 m – es gilt die ohne
      final kreis = [
        for (final t in _verlegt(
          Planungsstand.start.mitGrundriss(KreisGrundriss.vorgabe),
        ).teile)
          for (final s in t.stuecke) s.laenge,
      ];
      int geliefert(Millimeter ueberlaenge) => Dielenliste.aus(
        zuschneiden(kreis, const [_m4, _m5, _m6], ueberlaenge: ueberlaenge),
      ).geliefert.mm;
      expect(geliefert(u), geliefert(const Millimeter(0)));
      expect(geliefert(u), 168000);
      // auch mit einem Stück genau in der längsten Lieferlänge
      kreis.add(_m6);
      expect(geliefert(u), 174000);
      // gleich viel geliefert: die mit weniger Dielen
      final eine = zuschneiden(const [_m6], const [_m6]);
      final zwei = zuschneiden(
        const [Millimeter(3000), Millimeter(3000)],
        const [Millimeter(3000)],
      );
      expect(besteVerteilung([zwei, eine], mehrlaenge: 0), same(eine));
      expect(besteVerteilung([eine, zwei], mehrlaenge: 0), same(eine));
      expect(besteVerteilung([eine, eine], mehrlaenge: 0), same(eine));
      expect(() => zuschnitt([6001]), throwsArgumentError);
      // geplant zählt höchstens die Lieferlänge: kein negativer Verschnitt
      final liste = Dielenliste.aus(
        zuschneiden(const [Millimeter(6030)], const [_m6], ueberlaenge: u),
      );
      expect(liste.geplant, _m6);
      expect(liste.verschnitt, 0);
    });

    test('je Reihe die kürzeste passende Länge (M5-02)', () {
      expect(zuschnitt([4800, 3090]), ['5000: [4800]', '4000: [3090]']);
      expect(zuschnitt([]), isEmpty);
    });

    test('Reststücke auf weitere Reihen: 4000 mm für zwei Reihen mit je '
        '200 cm Rest (F09)', () {
      expect(zuschnitt([6000, 2000, 6000, 2000]), [
        '6000: [6000]',
        '6000: [6000]',
        '4000: [2000, 2000]',
      ]);
      // der Rest einer angefangenen Diele nimmt das nächste Stück auf
      expect(zuschnitt([3600, 1400]), ['5000: [3600, 1400]']);
    });

    test('kleinster passender Rest einer angefangenen Diele', () {
      // Reste 1000 (aus 5000) und 500 (aus 6000): 400 kommt in den 500er
      expect(zuschnitt([5500, 4000, 400]), [
        '6000: [5500, 400]',
        '4000: [4000]',
      ]);
      // gleich großer Rest zählt als passend: Schnitt ohne Zugabe
      expect(zuschnitt([2000, 2000]), ['4000: [2000, 2000]']);
    });

    test('neue Diele: kleinster Rest nach dem Auffüllen, bei Gleichstand die '
        'kürzere', () {
      // 2400 + 2400 in 5000 (Rest 200) statt einzeln in 4000 (F06)
      expect(zuschnitt([2400, 2400]), ['5000: [2400, 2400]']);
      // 3000 + 3000: 6000 hat Rest 0, 4000 und 5000 nicht
      expect(zuschnitt([3000, 3000]), ['6000: [3000, 3000]']);
      // Rest 0 in 4000, 5000 (mit 1000) und 6000: die kürzere gewinnt
      expect(zuschnitt([3000, 1000, 1000, 1000]), [
        '4000: [3000, 1000]',
        '4000: [1000, 1000]',
      ]);
      // ohne Folgestücke: kürzeste passende
      expect(zuschnitt([4100]), ['5000: [4100]']);
    });

    test('zum Schluss die kürzeste Länge, die die Stücke aufnimmt (F21)', () {
      // 3600 beginnt in 5000, weil 1400 nachkommen könnte – hier nicht
      expect(zuschnitt([3600, 3600, 1400]), [
        '5000: [3600, 1400]',
        '4000: [3600]',
      ]);
    });

    test('Lieferlängen in beliebiger Reihenfolge, Stück zu lang = Fehler', () {
      expect(zuschnitt([3000], const [_m6, _m4]), ['4000: [3000]']);
      expect(
        () => zuschnitt([6001]),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'länger als jede Lieferlänge',
          ),
        ),
      );
    });

    test('Lieferdiele: Schnitte unveränderlich, genutzte Länge', () {
      final d = Lieferdiele(_m5, const [Millimeter(3000), Millimeter(1500)]);
      expect(d.genutzt, const Millimeter(4500));
      expect(() => d.schnitte.add(_m4), throwsUnsupportedError);
      expect(Lieferdiele(_m4, const []).genutzt, const Millimeter(0));
    });
  });

  group('Dielenliste', () {
    test(
      'Anzahl je Lieferlänge, geplant, geliefert und Verschnitt (R-B11)',
      () {
        final liste = Dielenliste.aus([
          Lieferdiele(_m5, const [Millimeter(4800)]),
          Lieferdiele(_m4, const [Millimeter(3000), Millimeter(500)]),
          Lieferdiele(_m5, const [Millimeter(4900)]),
        ]);
        expect(_anzahl(liste), {4000: 1, 5000: 2});
        expect(liste.anzahl.keys.first, _m4);
        expect(liste.geplant, const Millimeter(13200));
        expect(liste.geliefert, const Millimeter(14000));
        expect(liste.verschnitt, closeTo(800 / 14000, 1e-12));
        expect(() => liste.anzahl[_m6] = 1, throwsUnsupportedError);
      },
    );

    test('leer: kein Verschnitt', () {
      expect(Dielenliste.leer.anzahl, isEmpty);
      expect(Dielenliste.leer.verschnitt, 0);
      expect(Dielenliste.aus(const []).verschnitt, 0);
    });

    test('Summe und Häufigkeit (M4-14)', () {
      final a = Dielenliste.aus([
        Lieferdiele(_m5, const [Millimeter(4000)]),
      ]);
      final b = Dielenliste.aus([
        Lieferdiele(_m5, const [Millimeter(5000)]),
        Lieferdiele(_m6, const [Millimeter(6000)]),
      ]);
      final summe = a + b;
      expect(_anzahl(summe), {5000: 2, 6000: 1});
      expect(summe.geplant, const Millimeter(15000));
      expect(summe.geliefert, const Millimeter(16000));
      final dreimal = b * 3;
      expect(_anzahl(dreimal), {5000: 3, 6000: 3});
      expect(dreimal.geplant, const Millimeter(33000));
      expect(dreimal.geliefert, const Millimeter(33000));
    });
  });

  group('Teilverlegung: Nummern wie „Dielen nach Nummer“', () {
    test('gleiche Länge und zugeschnittene Breite = gleiche Nummer', () {
      Dielenstueck stueck(int laenge, double breite) =>
          Dielenstueck(0, Millimeter(laenge), const [], breite: breite);
      final teil = Teilverlegung(
        [
          stueck(4800, 66),
          stueck(4800, 66),
          stueck(3000, 66),
          stueck(4800, 36.4),
          stueck(3000, 66),
        ],
        lieferlaengen: const [_m4, _m5, _m6],
        bezeichnung: 'A1',
      );
      expect(teil.bezeichnung, 'A1');
      expect(teil.nummern, [1, 1, 2, 3, 2]);
      expect(
        [
          for (final s in teil.sorten)
            (s.nummer, s.laenge.mm, s.breite.mm, s.stueck),
        ],
        [(1, 4800, 60, 2), (2, 3000, 60, 2), (3, 4800, 30, 1)],
      );
      expect(teil.zuschnitt, hasLength(4));
      expect(() => teil.nummern.add(1), throwsUnsupportedError);
      expect(teil.sorten.clear, throwsUnsupportedError);
      expect(teil.stuecke.clear, throwsUnsupportedError);
      expect(teil.zuschnitt.clear, throwsUnsupportedError);
    });
  });

  group('verlegeBelag', () {
    test('F01: 48 Reihen à 480 cm, 48 × 5000 mm, Verschnitt 4 %', () {
      final v = _verlegt(
        Planungsstand.start.mitGrundriss(
          RechteckGrundriss(const Millimeter(4800), const Millimeter(3090)),
        ),
      );
      expect(v.teile, hasLength(1));
      expect(v.teile.single.bezeichnung, isNull);
      expect(_sorten(v), ['480.0x3.0:1', '480.0x6.0:47']);
      expect(_anzahl(v.dielenliste), {5000: 48});
      expect(v.dielenliste.verschnitt, closeTo(0.04, 1e-12));
      expect(v.ausgangspunkt, Punkt.ursprung);
      expect(v.grenzen, (x: const Millimeter(4800), y: const Millimeter(65)));
      expect(v.kurzeZuschnitte, isTrue);
      expect(v.teile.clear, throwsUnsupportedError);
    });

    test(
      '3 cm Überlänge (Planungskern v6 / Entscheidung 11.11.2026): '
      'Reihen bis 603 cm ohne Stoß aus einer 6-m-Diele, darüber gestoßen',
      () {
        final v = _verlegt(_rechteck(6030, 1000));
        expect(v.ueberlaenge, dielenUeberlaenge);
        expect(
          v.teile.single.stuecke.every((s) => s.laenge.mm == 6030),
          isTrue,
        );
        expect(_anzahl(v.dielenliste), {6000: 16});
        expect(v.dielenliste.verschnitt, 0);
        expect(v.grenzen.x, const Millimeter(6030));
        // 603,1 cm: Stoß bei 600 cm, die Reste 3,1 cm aus einer 4-m-Diele
        final lang = _verlegt(_rechteck(6031, 1000));
        expect(_anzahl(lang.dielenliste), {4000: 1, 6000: 16});
        expect(lang.grenzen.x, _m6);
        // 6,00 m: eine 6-m-Diele je Reihe wie bisher
        expect(_anzahl(_verlegt(_rechteck(6000, 1000)).dielenliste), {
          6000: 16,
        });
      },
    );

    test('F01 mit 6 mm Fuge (Planungskern v6, Entscheidung Alexander '
        '11.11.2026): 47 statt 48 Reihen, Randreihe 4,8 statt 3,0 cm', () {
      final v = verlegeBelag(
        Planungsstand.start.mitGrundriss(
          RechteckGrundriss(const Millimeter(4800), const Millimeter(3090)),
        ),
        _diele(60),
      )!;
      expect(_sorten(v), ['480.0x4.8:1', '480.0x6.0:46']);
      expect(_anzahl(v.dielenliste), {5000: 47});
      expect(v.grenzen, (x: const Millimeter(4800), y: const Millimeter(66)));
    });

    test('nichts zu verlegen: offene Freiform, kein Belag, Systemdiele, '
        'unvollständige Abmessungen', () {
      final offen = Planungsstand(
        grundriss: FreiformGrundriss(const [Punkt(0, 0), Punkt(1000, 0)]),
      );
      expect(verlegeBelag(offen, _diele(60)), isNull);
      expect(verlegeBelag(Planungsstand.start, null), isNull);
      expect(
        verlegeBelag(
          Planungsstand.start,
          _diele(60, const [_m4], Artikelart.systemdiele),
        ),
        isNull,
      );
      expect(verlegeBelag(Planungsstand.start, _diele(60, const [])), isNull);
      final ohneBreite = Artikel(
        nummer: const Artikelnummer('1'),
        titel: 'Diele',
        art: Artikelart.diele,
        einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
        abmessungen: Abmessungen(laengen: const [_m4]),
        holzart: robinie,
        serie: basic,
      );
      expect(verlegeBelag(Planungsstand.start, ohneBreite), isNull);
      // geschlossene Freiform wird verlegt
      final zu = Planungsstand(
        grundriss: FreiformGrundriss(const [
          Punkt(0, 0),
          Punkt(1000, 0),
          Punkt(1000, 130),
        ], geschlossen: true),
      );
      expect(verlegeBelag(zu, _diele(60)), isNotNull);
    });

    test('erzwungene Länge, solange der Belag sie liefert (M5-02, F13)', () {
      final stand = _rechteck(8000, 3090);
      expect(_anzahl(_verlegt(stand.mitDielenlaenge(_m4)).dielenliste), {
        4000: 96,
      });
      // F09: automatisch 600 + 200 cm, die 200er paarweise in 4000 mm
      expect(_anzahl(_verlegt(stand).dielenliste), {4000: 24, 6000: 48});
      // Länge, die der Belag nicht liefert: Automatik
      expect(_anzahl(_verlegt(stand.mitDielenlaenge(_m7)).dielenliste), {
        4000: 24,
        6000: 48,
      });
      // ganze Länge für die Stückliste (M9-04): erzwungene oder längste
      expect(_verlegt(stand.mitDielenlaenge(_m4)).laengste, _m4);
      expect(_verlegt(stand).laengste, _m6);
      expect(_verlegt(stand.mitDielenlaenge(_m7)).laengste, _m6);
    });

    test('kurze Stücke verbinden nur bei Dielen (R-B12)', () {
      // obere Reihe von 30 bis 90 cm, Stoß bei 60,6 cm: 30,6 + 29,4 cm
      final form = Planungsstand(
        grundriss: FreiformGrundriss(const [
          Punkt.ursprung,
          Punkt(1300, 0),
          Punkt(1300, 611),
          Punkt(900, 611),
          Punkt(900, 1222),
          Punkt(300, 1222),
          Punkt(300, 611),
          Punkt(0, 611),
        ], geschlossen: true),
      ).mitKurzeStueckeVerbinden(true);
      List<int> laengen(Artikel belag) => _mm([
        for (final s in _verlegt(form, belag).teile.single.stuecke) s.laenge,
      ]);
      expect(laengen(_fliese), [606, 606, 88, 306, 294]);
      final diele = _diele(606, const [Millimeter(606)]);
      expect(laengen(diele), [606, 606, 88, 600]);
      expect(
        _mm([
          for (final s in _verlegt(
            form.mitKurzeStueckeVerbinden(false),
            diele,
          ).teile.single.stuecke)
            s.laenge,
        ]),
        [606, 606, 88, 306, 294],
      );
    });

    test('Verschiebung über die Grenze wird begrenzt (M5-07)', () {
      final stand = _rechteck(
        4800,
        3090,
      ).mitAusgangspunkt(x: const Millimeter(9000), y: const Millimeter(-200));
      final v = _verlegt(stand);
      expect(v.ausgangspunkt, const Punkt(4800, -65));
      final innen = _verlegt(
        _rechteck(
          4800,
          3090,
        ).mitAusgangspunkt(x: const Millimeter(-30), y: const Millimeter(20)),
      );
      expect(innen.ausgangspunkt, const Punkt(-30, 20));
    });

    test('leerer Ausschnitt bleibt frei, anderer Belag ist eine eigene '
        'Teilfläche (F21, F22)', () {
      final ausschnitt = Ausschnitt(
        bezeichnung: 'A1',
        x: const Millimeter(1000),
        y: const Millimeter(1000),
        laenge: const Millimeter(1200),
        breite: const Millimeter(1330),
      );
      final leer = _rechteck(
        3600,
        4000,
      ).mitNeuemAusschnitt().mitAusschnitt(0, ausschnitt);
      final v = _verlegt(leer);
      expect(v.teile, hasLength(1));
      // 19 Reihen ganz durch den Ausschnitt: 100 + 140 cm, die übrigen
      // (auch die zwei angeschnittenen) ausgeklinkt 360 cm
      expect(_sorten(v), [
        '100.0x6.0:19',
        '140.0x6.0:19',
        '360.0x3.0:1',
        '360.0x6.0:42',
      ]);
      // wie der alte Planer: 38 × 5000 + 5 × 4000 mm (F21)
      expect(_anzahl(v.dielenliste), {4000: 5, 5000: 38});
      final anders = leer.mitAusschnitt(
        0,
        ausschnitt.mitFunktion(Ausschnittfunktion.andererBelag),
      );
      final w = _verlegt(anders);
      expect([for (final t in w.teile) t.bezeichnung], [null, 'A1']);
      expect(
        _sorten(v),
        [for (final s in _sorten(w)) s]
          ..removeWhere((s) => s.startsWith('120.0')),
      );
      // Teilfläche 120 × 133 cm ab ihrer Ecke: 20 Reihen + 3 cm
      expect(
        [
          for (final s in w.teile.last.sorten)
            (s.laenge.mm, s.breite.mm, s.stueck),
        ],
        [(1200, 60, 20), (1200, 25, 1)],
      );
      expect(w.teile.last.nummern.first, 1);
      // alter Planer 4 × 6000 + 1 × 3000 mm; 3000 gibt es nicht (R-A06)
      expect(_anzahl(Dielenliste.aus(w.teile.last.zuschnitt)), {
        4000: 1,
        6000: 4,
      });
      expect(_anzahl(w.dielenliste), {4000: 6, 5000: 38, 6000: 4});
    });

    test('Ausschnitt ganz in einer Reihe unterbricht die Diele', () {
      // 12 cm breite Dielen, Reihe 125 mm, Pfosten 100 × 100 mm darin
      final stand = _streifen(3000, 125).mitNeuemAusschnitt().mitAusschnitt(
        0,
        Ausschnitt(
          bezeichnung: 'P',
          x: const Millimeter(1000),
          y: const Millimeter(10),
          laenge: const Millimeter(100),
          breite: const Millimeter(100),
        ),
      );
      final v = _verlegt(stand, _diele(120));
      expect(_mm([for (final s in v.teile.single.stuecke) s.laenge]), [
        1000,
        1900,
      ]);
      // zwei Pfosten nebeneinander in derselben Reihe
      final zwei = stand.mitNeuemAusschnitt().mitAusschnitt(
        1,
        Ausschnitt(
          bezeichnung: 'Q',
          x: const Millimeter(2000),
          y: const Millimeter(10),
          laenge: const Millimeter(100),
          breite: const Millimeter(100),
        ),
      );
      expect(
        _mm(
          [
            for (final s in _verlegt(zwei, _diele(120)).teile.single.stuecke)
              s.laenge,
          ]..sort(),
        ),
        [900, 900, 1000],
      );
    });

    test('Holzfliesen 606 × 606 mm in Reihen mit Fuge (F25)', () {
      final v = _verlegt(_rechteck(4800, 3090), _fliese);
      // 8 Spalten (7 × 60,6 + 55,8 cm), 6 Reihen (5 × 61,1 + 3,5 cm)
      expect(_sorten(v), [
        '55.8x3.0:1',
        '55.8x60.6:5',
        '60.6x3.0:7',
        '60.6x60.6:35',
      ]);
      expect(_anzahl(v.dielenliste), {606: 48});
      // F25: 0,99 % – längs gerechnet wie bei Dielen
      expect((v.dielenliste.verschnitt * 10000).round() / 100, 0.99);
      expect(v.grenzen, (x: const Millimeter(606), y: const Millimeter(611)));
      // Holzfliesen ohne Überlänge
      expect(v.ueberlaenge, const Millimeter(0));
    });
  });

  _referenzkonfigurationen();
  _referenzfaelle();
}

/// F01 … F25 (M1-03): Dielenliste und Verschnitt gegen die Materialliste
/// des alten Planers – Deckbelag und Anfangsdielen ohne Freidielen (die
/// rechnet die Materialliste, R-B09).
void _referenzkonfigurationen() {
  Referenzkonfiguration fall(String id) => Referenzkonfiguration.ausJson(
    jsonDecode(File('test/referenzkonfigurationen/$id.json').readAsStringSync())
        as Map<String, Object?>,
  );
  const arten = {
    'Fugenschnitt': Verlegeart.fugenschnitt,
    'Halbverband': Verlegeart.halbverband,
    'Drittelverband': Verlegeart.drittelverband,
    'Wechselverband': Verlegeart.wechselverband,
  };

  Belagverlegung verlege(Referenzkonfiguration f) {
    final e = f.eingaben;
    final kanten = e['kanten_cm']! as Map<String, Object?>;
    var stand =
        _rechteck((kanten['A-B']! as int) * 10, (kanten['B-C']! as int) * 10)
            .mitVerlegeart(arten[e['verlegeart']]!)
            .mitVerlegerichtung(
              e['verlegerichtung'] == 'Senkrecht'
                  ? Verlegerichtung.senkrecht
                  : Verlegerichtung.waagrecht,
            );
    if (e['dielenlaenge'] case final String t when t.startsWith('fest ')) {
      stand = stand.mitDielenlaenge(Millimeter(int.parse(t.substring(5)) * 10));
    }
    for (final a in e['ausschnitte']! as List<Object?>) {
      final m = a! as Map<String, Object?>;
      stand = stand.mitNeuemAusschnitt().mitAusschnitt(
        stand.ausschnitte.length,
        Ausschnitt(
          bezeichnung: m['name']! as String,
          x: Millimeter((m['x_cm']! as int) * 10),
          y: Millimeter((m['y_cm']! as int) * 10),
          laenge: Millimeter((m['laenge_cm']! as int) * 10),
          breite: Millimeter((m['breite_cm']! as int) * 10),
          funktion: m['funktion'] == 'leere Fläche'
              ? Ausschnittfunktion.leer
              : Ausschnittfunktion.andererBelag,
        ),
      );
    }
    final belag = e['belag']! as String;
    return _verlegt(
      stand,
      belag.contains('fliese')
          ? _fliese
          : _diele(int.parse(RegExp(r'(\d+) x').firstMatch(belag)!.group(1)!)),
    );
  }

  Map<int, int> alt(Referenzkonfiguration f) {
    final anzahl = <int, int>{};
    for (final m in f.materialliste) {
      if ((m.typ.startsWith('Deckbelag') || m.typ == 'Anfangsdiele') &&
          !m.bezeichnung.contains('Freidiele')) {
        anzahl.update(
          m.laengeMm ?? 606,
          (n) => n + m.anzahl,
          ifAbsent: () => m.anzahl,
        );
      }
    }
    return anzahl;
  }

  group('Referenzkonfigurationen', () {
    // gleiche Lieferlängen wie der alte Planer
    for (final id in [
      'F01', 'F02', 'F06', 'F07', 'F08', 'F09', 'F10', 'F11', 'F12', 'F13', //
      'F20', 'F21', 'F23', 'F24', 'F25',
    ]) {
      test('$id: Dielenliste wie im alten Planer', () {
        final f = fall(id);
        final v = verlege(f);
        expect(_anzahl(v.dielenliste), alt(f));
        // Verschnitt, wo angezeigt; F21 siehe unten
        if (f.verschnittProzent case final p? when id != 'F21') {
          expect((v.dielenliste.verschnitt * 10000).round() / 100, p);
        }
      });
    }

    test('F21: gleiche Lieferung, Verschnitt 4,57 statt 4,36 % – geplant '
        'sind 43 × 360 + 19 × (100 + 140) cm, der alte Rechenweg ist aus '
        'den Daten nicht nachvollziehbar', () {
      final v = verlege(fall('F21'));
      expect(v.dielenliste.geplant, const Millimeter(200400));
      expect(v.dielenliste.geliefert, const Millimeter(210000));
      expect(fall('F21').verschnittProzent, 4.36);
    });

    test('M9-01: optimiert nie mehr Dielen als der alte Planer – F22 '
        'spart 6 m (Reste der Teilfläche A1 in der Hauptfläche)', () {
      for (final id in [
        'F01', 'F02', 'F06', 'F07', 'F08', 'F09', 'F10', 'F11', 'F12', //
        'F13', 'F20', 'F21', 'F22', 'F23', 'F24', 'F25',
      ]) {
        final f = fall(id);
        expect(
          _optimiert(verlege(f)),
          lessThanOrEqualTo(_summe(alt(f))),
          reason: id,
        );
      }
      expect(_optimiert(verlege(fall('F22'))), 231000);
      expect(_summe(alt(fall('F22'))), 237000);
    });

    test('M9-02: Zuschnitt Deckbelag wie im alten Planer (Anfangsdielen '
        'zusammengefasst, B-033)', () {
      for (final id in [
        'F01', 'F02', 'F06', 'F07', 'F08', 'F09', 'F10', 'F11', 'F12', //
        'F13', 'F20', 'F21', 'F23', 'F24',
      ]) {
        final f = fall(id);
        final alt = _plan([
          for (final z in f.zuschnitt)
            if (z.artikel.startsWith('Terrassendiele'))
              (z.ausgangslaengeCm, z.schnitteCm, z.menge),
        ]);
        expect(_neuerPlan(verlege(f)), alt, reason: id);
      }
    });

    test('F22: Teilfläche A1 in 4 × 6000 + 4000 statt 3000 mm (R-A06)', () {
      final f = fall('F22');
      final erwartet = alt(f)
        ..remove(3000)
        ..update(4000, (n) => n + 1);
      expect(_anzahl(verlege(f).dielenliste), erwartet);
    });
  });
}

/// Referenzfälle (M1-02): „Dielen nach Nummer“ der Planungsunterlage gegen
/// die Verlegung, je Fall mit Richtung und Verlegeart laut Zeichnung.
void _referenzfaelle() {
  final faelle = {
    for (final f in Directory(
      'test/referenzfaelle',
    ).listSync().whereType<File>())
      if (Referenzfall.ausJson(
            jsonDecode(f.readAsStringSync()) as Map<String, Object?>,
          )
          case final fall)
        fall.id: (
          fall,
          (jsonDecode(f.readAsStringSync())
                  as Map<String, Object?>)['eingaben']!
              as Map<String, Object?>,
        ),
  };

  Belagverlegung verlege(
    String id, {
    Verlegerichtung? richtung,
    Verlegeart art = Verlegeart.fugenschnitt,
    List<Millimeter> laengen = const [_m4, _m5, _m6],
  }) {
    final (fall, eingaben) = faelle[id]!;
    final r = fall.grundriss;
    final k = r.kantenCm;
    Millimeter mm(String kante) => Millimeter((k[kante]! * 10).round());
    final grundriss = switch (r.form) {
      'Rechteck' => RechteckGrundriss(mm('A-B'), mm('B-C')),
      'L-Form' => LGrundriss(mm('A-B'), mm('B-C'), mm('C-D'), mm('D-E')),
      _ => TGrundriss(
        mm('B-C'),
        mm('C-D'),
        mm('D-E'),
        mm('E-F'),
        mm('G-H'),
        mm('H-A'),
      ),
    };
    final punkt = switch (eingaben['ausgangspunkt']) {
      {'punkt': final String p} => p.codeUnitAt(0) - 0x41,
      _ => 0,
    };
    final stand = Planungsstand(grundriss: grundriss)
        .mitVerlegerichtung(
          richtung ??
              (fall.verlegerichtung == 'Senkrecht'
                  ? Verlegerichtung.senkrecht
                  : Verlegerichtung.waagrecht),
        )
        .mitVerlegeart(art)
        .mitAusgangspunkt(ecke: punkt);
    final belag = fall.belag ?? fall.dielen.first.artikel;
    return _verlegt(
      stand,
      belag.contains('liese')
          ? _fliese
          : _diele(
              int.parse(RegExp(r'(\d+) x').firstMatch(belag)!.group(1)!),
              laengen,
            ),
    );
  }

  List<String> alt(String id) => [
    for (final d in faelle[id]!.$1.dielen)
      '${d.laengeCm}x${d.breiteCm}:${d.stueck}',
  ]..sort();

  Map<int, int> altLieferung(String id) {
    final anzahl = <int, int>{};
    for (final z in faelle[id]!.$1.zuschnittDeckbelag) {
      anzahl.update(
        (z.ausgangslaengeCm * 10).round(),
        (n) => n + z.menge,
        ifAbsent: () => z.menge,
      );
    }
    return anzahl;
  }

  group('Referenzfälle: Dielen nach Nummer', () {
    // Lieferlängen 4/5/6 m wie im alten Planer: auch die Lieferung stimmt
    for (final (id, richtung) in [
      ('2025-08-26-719-v2', null),
      ('2026-04-29-2412-v5', null),
      // Seite 1 nennt „Waagrecht“, die Zeichnung zeigt senkrecht (M1-02)
      ('2026-05-03-347-v4', Verlegerichtung.senkrecht),
      ('2026-05-12-1823-v4', null),
      ('2026-05-28-4655-v2', null),
      ('2026-06-30-2295-v5', Verlegerichtung.senkrecht),
      ('2026-08-06-2810-v3', null),
      ('2026-08-17-1838-v2', null),
    ]) {
      test('$id: Dielen und Lieferung wie in der Unterlage', () {
        final v = verlege(id, richtung: richtung);
        expect(_sorten(v), alt(id));
        expect(_anzahl(v.dielenliste), altLieferung(id));
        // M9-02: Zuschnitt Deckbelag wie in der Unterlage
        expect(
          _neuerPlan(v),
          _plan([
            for (final z in faelle[id]!.$1.zuschnittDeckbelag)
              (z.ausgangslaengeCm, z.schnitteCm, z.menge),
          ]),
        );
      });
    }

    // Zwischenlängen 3,0/4,5/5,5 m gibt es nicht mehr (R-A06, B-035): die
    // Stücke stimmen, geliefert wird in der nächsten Lieferlänge
    for (final (id, art, lieferung) in [
      ('2026-04-28-4413-v11', Verlegeart.fugenschnitt, {5000: 44}),
      ('2026-04-28-859-v5', Verlegeart.fugenschnitt, {5000: 21}),
      // 404 cm im Drittelverband: 134,7 + 269,3 cm
      ('2026-05-03-4381-v2', Verlegeart.drittelverband, {6000: 27}),
      // 97 × 200 cm: alt 31 × 600 + 450 + 400 cm, neu je zwei in 4000 mm
      ('2026-05-19-3958-v4', Verlegeart.fugenschnitt, {4000: 49}),
      ('2026-06-07-4340-v4', Verlegeart.fugenschnitt, {4000: 5, 5000: 49}),
      ('2026-06-11-3389-v3', Verlegeart.fugenschnitt, {6000: 30}),
      ('2026-06-25-1275-v3', Verlegeart.fugenschnitt, {6000: 5}),
      ('2026-07-07-2794-v2', Verlegeart.fugenschnitt, {5000: 154, 6000: 154}),
      ('2026-07-31-3374-v3', Verlegeart.fugenschnitt, {4000: 1, 5000: 60}),
      ('2026-08-26-1067-v2', Verlegeart.fugenschnitt, {4000: 1, 6000: 55}),
    ]) {
      test('$id: Dielen wie in der Unterlage, Lieferung 4/5/6 m', () {
        final v = verlege(id, art: art);
        expect(_sorten(v), alt(id));
        expect(_anzahl(v.dielenliste), lieferung);
        expect(
          altLieferung(id).keys
              .any((l) => !const {4000, 5000, 6000}.contains(l)),
          isTrue,
        );
      });
    }

    test('M9-01: optimiert nie mehr Dielen als der alte Planer – mit seinen '
        'Zwischenlängen 3,0/4,5/5,5 m; ohne sie (R-A06) mehr, wo ein Stück '
        'genau in eine Zwischenlänge passt', () {
      const zwischen = [
        Millimeter(3000),
        _m4,
        Millimeter(4500),
        _m5,
        Millimeter(5500),
        _m6,
      ];
      const mehr = {
        '2026-04-28-4413-v11': 22000, // 44 × 440 cm: 500 statt 450 cm
        '2026-04-28-859-v5': 10500,
        '2026-05-03-4381-v2': 9500, // 404 cm im Drittelverband
        '2026-06-11-3389-v3': 15000, // 30 × 550 statt 600 cm
        '2026-07-07-2794-v2': 77000, // 154 × 450 statt 500 cm
        '2026-08-26-1067-v2': 1000, // 111 × 300 cm: ein Rest in 400 cm
      };
      for (final (id, richtung, art) in [
        ('2025-08-26-719-v2', null, Verlegeart.fugenschnitt),
        ('2026-04-29-2412-v5', null, Verlegeart.fugenschnitt),
        (
          '2026-05-03-347-v4',
          Verlegerichtung.senkrecht,
          Verlegeart.fugenschnitt,
        ),
        ('2026-05-12-1823-v4', null, Verlegeart.fugenschnitt),
        ('2026-05-28-4655-v2', null, Verlegeart.fugenschnitt),
        (
          '2026-06-30-2295-v5',
          Verlegerichtung.senkrecht,
          Verlegeart.fugenschnitt,
        ),
        ('2026-08-06-2810-v3', null, Verlegeart.fugenschnitt),
        ('2026-08-17-1838-v2', null, Verlegeart.fugenschnitt),
        ('2026-04-28-4413-v11', null, Verlegeart.fugenschnitt),
        ('2026-04-28-859-v5', null, Verlegeart.fugenschnitt),
        ('2026-05-03-4381-v2', null, Verlegeart.drittelverband),
        ('2026-05-19-3958-v4', null, Verlegeart.fugenschnitt),
        ('2026-06-07-4340-v4', null, Verlegeart.fugenschnitt),
        ('2026-06-11-3389-v3', null, Verlegeart.fugenschnitt),
        ('2026-06-25-1275-v3', null, Verlegeart.fugenschnitt),
        ('2026-07-07-2794-v2', null, Verlegeart.fugenschnitt),
        ('2026-07-31-3374-v3', null, Verlegeart.fugenschnitt),
        ('2026-08-26-1067-v2', null, Verlegeart.fugenschnitt),
      ]) {
        final alt = _summe(altLieferung(id));
        final neu = _optimiert(verlege(id, richtung: richtung, art: art));
        expect(neu - alt, lessThanOrEqualTo(mehr[id] ?? 0), reason: id);
        if (mehr[id] case final m?) expect(neu - alt, m, reason: id);
        // Holzfliesen haben nur 606 mm
        if (id == '2026-08-17-1838-v2') continue;
        expect(
          _optimiert(
            verlege(id, richtung: richtung, art: art, laengen: zwischen),
          ),
          lessThanOrEqualTo(alt),
          reason: '$id mit Zwischenlängen',
        );
      }
    });

    test('Fehler des alten Planers: 7000 mm für Dielen mit 4/5/6 m (F14, '
        'B-035) – mit 7 m stimmen die Stücke, mit 6 m nicht', () {
      for (final id in ['2026-04-13-1946-v6', '2026-04-29-164-v4']) {
        expect(
          _sorten(verlege(id, laengen: const [_m4, _m5, _m6, _m7])),
          alt(id),
          reason: id,
        );
        expect(_sorten(verlege(id)), isNot(alt(id)), reason: id);
      }
    });

    test('Ausklinkung: neu die volle Breite des Stücks, alt die schmale '
        '(2026-07-31-3374-v5)', () {
      final id = '2026-07-31-3374-v5';
      final neu = _sorten(verlege(id));
      expect(neu, contains('425.0x6.0:20'));
      expect(
        alt(id),
        containsAll(['425.0x6.0:18', '425.0x4.5:1', '425.0x2.5:1']),
      );
    });
  });
}
