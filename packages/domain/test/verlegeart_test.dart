import 'dart:convert';
import 'dart:io';

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

const _null = Millimeter(0);
const _m6 = Millimeter(6000);

List<int> _mm(List<Millimeter> werte) => [for (final w in werte) w.mm];

/// Linien in mm für eine Fläche von 0 bis [laenge].
List<int> _linien(Verlegeart art, int versatz, int laenge, int raster) =>
    _mm(art.linien(versatz, _null, Millimeter(laenge), Millimeter(raster)));

/// Verbandwahl für eine Fläche von 0 bis [bis] mit 6-m-Dielen und 3 cm
/// Überlänge.
Verbandwahl _wahl(Verlegeart art, int bis) => Verbandwahl(
  art,
  von: _null,
  bis: Millimeter(bis),
  raster: stossraster(Millimeter(bis), _m6, ueberlaenge: dielenUeberlaenge),
  hoechstlaenge: _m6 + dielenUeberlaenge,
);

/// Stöße (mm) der Reihe [reihe] für die [abschnitte] (mm).
List<List<int>> _reihe(Verbandwahl w, int reihe, List<(int, int)> abschnitte) =>
    [
      for (final s in w.stoesse(reihe, [
        for (final (a, b) in abschnitte) (Millimeter(a), Millimeter(b)),
      ]))
        _mm(s),
    ];

Referenzkonfiguration _fall(String id) => Referenzkonfiguration.ausJson(
  jsonDecode(File('test/referenzkonfigurationen/$id.json').readAsStringSync())
      as Map<String, Object?>,
);

/// Anzahl der Dielenstücke je Länge in mm.
Map<int, int> _zaehle(Iterable<int> stuecke) {
  final anzahl = <int, int>{};
  for (final s in stuecke) {
    anzahl[s] = (anzahl[s] ?? 0) + 1;
  }
  return anzahl;
}

void main() {
  test('Nummern im Transportformat und Teilung der Stoßweite', () {
    expect([for (final v in Verlegeart.values) v.nummer], [0, 1, 2, 4, 3]);
    expect([for (final v in Verlegeart.values) v.teilung], [1, 2, 3, 4, 4]);
  });

  group('Linien je Versatz', () {
    test('ohne Versatz: alle Reihen an denselben Stellen', () {
      for (final art in Verlegeart.values) {
        expect(_linien(art, 0, 8000, 6000), [6000]);
        expect(_linien(art, 0, 13000, 6000), [6000, 12000]);
      }
      expect(_linien(Verlegeart.fugenschnitt, 0, 6000, 6000), isEmpty);
      expect(_linien(Verlegeart.fugenschnitt, 0, 12000, 6000), [6000]);
      expect(_linien(Verlegeart.fugenschnitt, 0, 12001, 6000), [6000, 12000]);
    });

    test('Versatz in Teilen der Stoßweite (½, ⅓, ¼)', () {
      expect(_linien(Verlegeart.halbverband, 1, 8000, 6000), [3000]);
      expect(_linien(Verlegeart.halbverband, 1, 13000, 6000), [3000, 9000]);
      expect(_linien(Verlegeart.drittelverband, 1, 8000, 6000), [2000]);
      expect(_linien(Verlegeart.drittelverband, 2, 8000, 6000), [4000]);
      expect(_linien(Verlegeart.viertelverband, 1, 8000, 6000), [1500, 7500]);
      expect(_linien(Verlegeart.viertelverband, 3, 8000, 6000), [4500]);
      expect(_linien(Verlegeart.wechselverband, 2, 8000, 6000), [3000]);
      // auf ganze mm gerundet (404 cm im Drittel: 134,7 cm)
      expect(_linien(Verlegeart.drittelverband, 1, 4040, 4040), [1347]);
    });

    test('negativer Versatz ab der Gegenseite: gespiegeltes Raster', () {
      List<int> g(Verlegeart art, int versatz, int bis) => _mm(
        art.linien(
          -versatz,
          _null,
          Millimeter(bis),
          _m6,
          ausgang: Millimeter(bis),
        ),
      );
      expect(g(Verlegeart.halbverband, 0, 8000), [2000]);
      expect(g(Verlegeart.halbverband, 1, 8000), [5000]);
      expect(g(Verlegeart.viertelverband, 1, 13000), [5500, 11500]);
      expect(g(Verlegeart.drittelverband, 1, 4040), [2040]);
      expect(g(Verlegeart.halbverband, 0, 6000), isEmpty);
      expect(g(Verlegeart.halbverband, 0, 6001), [1]);
      expect(g(Verlegeart.halbverband, 0, 12000), [6000]);
    });

    test('Fläche nicht bei 0: Linien ab ihrem Anfang', () {
      const von = Millimeter(1000);
      const bis = Millimeter(9000);
      expect(_mm(Verlegeart.fugenschnitt.linien(0, von, bis, _m6)), [7000]);
      expect(_mm(Verlegeart.halbverband.linien(1, von, bis, _m6)), [4000]);
    });

    test('Ausgangspunkt mitten in der Fläche (M5-05): Linie durch ihn', () {
      const von = Millimeter(-3394);
      const bis = Millimeter(2185);
      const raster = Millimeter(5579);
      const a = Millimeter(0);
      List<int> linien(Verlegeart art, int versatz) =>
          _mm(art.linien(versatz, von, bis, raster, ausgang: a));
      expect(linien(Verlegeart.fugenschnitt, 0), [0]);
      expect(linien(Verlegeart.halbverband, 1), [-2789]);
      expect(linien(Verlegeart.drittelverband, 1), [1860]);
      expect(linien(Verlegeart.drittelverband, 2), [-1860]);
      // Linie genau auf dem Rand der Fläche zählt nicht
      expect(
        _mm(
          Verlegeart.fugenschnitt.linien(
            0,
            _null,
            const Millimeter(8000),
            _m6,
            ausgang: const Millimeter(2000),
          ),
        ),
        [2000],
      );
      expect(
        _mm(
          Verlegeart.fugenschnitt.linien(
            0,
            _null,
            const Millimeter(13000),
            _m6,
            ausgang: const Millimeter(-6000),
          ),
        ),
        [6000, 12000],
      );
    });

    test('ohne Raster oder Fläche keine Linien', () {
      for (final art in Verlegeart.values) {
        for (final versatz in [art.teilung - 1, 1 - art.teilung]) {
          List<int> l(int bis, int raster, [int von = 0]) => _mm(
            art.linien(
              versatz,
              Millimeter(von),
              Millimeter(bis),
              Millimeter(raster),
            ),
          );
          expect(l(8000, 0), isEmpty);
          expect(l(8000, -6000), isEmpty);
          expect(l(1, 6000), isEmpty);
          expect(l(0, 6000), isEmpty);
          expect(l(0, 6000, 8000), isEmpty);
        }
      }
    });
  });

  group('Verbandwahl (R-B18, Planungskern v7 Regel 9.3)', () {
    test('Mindeststück 40 cm, Abstand der Nachbarreihen 30 cm', () {
      expect(verbandMindeststueck, const Millimeter(400));
      expect(verbandMindestabstand, const Millimeter(300));
    });

    test('Fugenschnitt: Linien ohne Versatz in jedem Abschnitt, auch '
        'kurzen – wie bisher', () {
      final w = _wahl(Verlegeart.fugenschnitt, 8000);
      for (final reihe in [0, 1, 2]) {
        expect(_reihe(w, reihe, [(0, 8000), (5000, 7000)]), [
          [6000],
          [6000],
        ]);
      }
    });

    test('Halb-, Drittel-, Viertelverband: Reihe für Reihe versetzt', () {
      List<List<int>> folge(Verlegeart art, int bis, int n) {
        final w = _wahl(art, bis);
        return [
          for (var r = 0; r < n; r++) _reihe(w, r, [(0, bis)]).single,
        ];
      }

      expect(folge(Verlegeart.halbverband, 8000, 4), [
        [6000],
        [3000],
        [6000],
        [3000],
      ]);
      expect(folge(Verlegeart.drittelverband, 8000, 4), [
        [6000],
        [2000],
        [4000],
        [6000],
      ]);
      expect(folge(Verlegeart.viertelverband, 8000, 5), [
        [6000],
        [1500, 7500],
        [3000],
        [4500],
        [6000],
      ]);
      // negative Reihen (andere Seite des Ausgangspunkts) reihum weiter
      final w = _wahl(Verlegeart.drittelverband, 8000);
      expect(_reihe(w, -1, [(0, 8000)]).single, [4000]);
    });

    test('Wechselverband: unregelmäßig, nie wie die beiden Reihen davor, '
        'gleiche Fläche gleiche Planung', () {
      List<List<int>> folge() {
        final w = _wahl(Verlegeart.wechselverband, 13000);
        return [
          for (var r = 0; r < 40; r++) _reihe(w, r, [(0, 13000)]).single,
        ];
      }

      final a = folge();
      expect(folge(), a);
      // Versatz aus der ersten Linie (Raster 6000, Viertel 1500)
      final versatz = [
        for (final js in a) (6000 - js.first % 6000) ~/ 1500 % 4,
      ];
      for (var i = 2; i < versatz.length; i++) {
        expect(versatz[i], isNot(versatz[i - 1]), reason: 'Reihe $i');
        expect(versatz[i], isNot(versatz[i - 2]), reason: 'Reihe $i');
      }
      // unregelmäßig: nicht nur zwei Lagen im Wechsel
      expect(versatz.toSet().length, 4);
      expect(versatz.sublist(0, 6), isNot([0, 1, 2, 3, 0, 1]));
    });

    test('Fläche nicht länger als eine Diele (mit Überlänge): kein Stoß', () {
      for (final art in Verlegeart.values.skip(1)) {
        final w = _wahl(art, 6030);
        expect(_reihe(w, 1, [(0, 6030)]), [<int>[]]);
      }
      expect(_reihe(_wahl(Verlegeart.halbverband, 6031), 1, [(0, 6031)]), [
        [3000],
      ]);
    });

    test('Abschnitt, der in eine Diele passt, bleibt ganz', () {
      final w = _wahl(Verlegeart.halbverband, 13000);
      expect(_reihe(w, 1, [(0, 6030), (6500, 13000)]), [
        <int>[],
        [9000],
      ]);
    });

    test('Stücke mindestens 40 cm: anderer Versatz oder gespiegelt', () {
      // Reihe 0 bevorzugt 6000 – das Endstück wäre 10 cm: gespiegelt von
      // 13 m ab (Linie bei 1 m)
      expect(_reihe(_wahl(Verlegeart.halbverband, 13000), 0, [(0, 6100)]), [
        [1000],
      ]);
      // bis 12 m liegen die gespiegelten Linien gleich: Versatz ½
      expect(_reihe(_wahl(Verlegeart.halbverband, 12000), 0, [(0, 6100)]), [
        [3000],
      ]);
      // Abschnitt 5,95–12,5 m: ohne Versatz 5 cm, mit ½ 0,5 m … – gespiegelt
      // von 13 m ab (Linie bei 7 m) bleiben 1,05 + 5,5 m
      final w = _wahl(Verlegeart.halbverband, 13000);
      final js = _reihe(w, 0, [(5950, 12500)]).single;
      var a = 5950;
      for (final c in [...js, 12500]) {
        expect(c - a, inInclusiveRange(400, 6030));
        a = c;
      }
      expect(js, [7000]);
    });

    test('Stöße nicht neben denen der Reihe davor', () {
      // nach einem Stoß bei 3 m liegen 3 und 9 m daneben (Abstand unter
      // dem halben Versatz 1,5 m): 6 m
      final w = _wahl(Verlegeart.halbverband, 12000);
      expect(_reihe(w, 1, [(0, 6100)]), [
        [3000],
      ]);
      expect(_reihe(w, 1, [(0, 12000)]), [
        [6000],
      ]);
      // geht es nicht anders, die erste gültige Lage (0–9,1 m: nur 6 m)
      final eng = _wahl(Verlegeart.halbverband, 12000);
      expect(_reihe(eng, 0, [(0, 12000)]), [
        [6000],
      ]);
      expect(_reihe(eng, 1, [(0, 9100)]), [
        [6000],
      ]);
      // im Drittelverband zählen die beiden Reihen davor
      final drittel = _wahl(Verlegeart.drittelverband, 12000);
      expect(_reihe(drittel, 0, [(0, 12000)]), [
        [6000],
      ]);
      expect(_reihe(drittel, 1, [(0, 12000)]), [
        [2000, 8000],
      ]);
      expect(_reihe(drittel, 2, [(0, 12000)]), [
        [4000, 10000],
      ]);
      expect(_reihe(drittel, 0, [(0, 9100)]), [
        [6000],
      ]);
    });

    test('ohne gültige Lage: gleich lange Stücke', () {
      final w = Verbandwahl(
        Verlegeart.halbverband,
        von: _null,
        bis: const Millimeter(20000),
        raster: _m6,
        hoechstlaenge: const Millimeter(6030),
        mindeststueck: const Millimeter(3100),
      );
      expect(_reihe(w, 0, [(0, 6100)]), [
        [3050],
      ]);
      expect(_reihe(w, 1, [(0, 12100)]), [
        [4033, 8067],
      ]);
    });
  });

  test('Raster: längste Länge, höchstens die Ausdehnung', () {
    expect(stossraster(const Millimeter(4800), _m6), const Millimeter(4800));
    expect(stossraster(const Millimeter(8000), _m6), _m6);
    expect(stossraster(_m6, _m6), _m6);
  });

  test('Raster mit 3 cm Überlänge (Planungskern v6 / Entscheidung '
      '11.11.2026): bis 603 cm eine Diele, darüber die längste Länge', () {
    const u = dielenUeberlaenge;
    expect(u, const Millimeter(30));
    expect(
      stossraster(const Millimeter(6030), _m6, ueberlaenge: u),
      const Millimeter(6030),
    );
    expect(stossraster(const Millimeter(6031), _m6, ueberlaenge: u), _m6);
    expect(stossraster(const Millimeter(6030), _m6), _m6);
  });

  test('Stoßmuster wie im alten Planer (F01, F09–F11, F13); F06–F08 und '
      'F12 nach dem Planungskern v7 (R-B18)', () {
    const arten = {
      'Fugenschnitt': Verlegeart.fugenschnitt,
      'Halbverband': Verlegeart.halbverband,
      'Drittelverband': Verlegeart.drittelverband,
      'Wechselverband': Verlegeart.wechselverband,
    };
    for (final id in [
      'F01',
      'F06',
      'F07',
      'F08',
      'F09',
      'F10',
      'F11',
      'F12',
      'F13',
    ]) {
      final fall = _fall(id);
      final eingaben = fall.eingaben;
      final art = arten[eingaben['verlegeart']]!;
      final kanten = eingaben['kanten_cm']! as Map<String, Object?>;
      final laenge = Millimeter((kanten['A-B']! as int) * 10);
      final fest = switch (eingaben['dielenlaenge']) {
        final String t when t.startsWith('fest ') => Millimeter(
          int.parse(t.substring(5)) * 10,
        ),
        _ => null,
      };
      final raster = stossraster(laenge, fest ?? _m6);
      final wahl = Verbandwahl(
        art,
        von: _null,
        bis: laenge,
        raster: raster,
        hoechstlaenge: fest ?? _m6,
      );
      // 309 cm bei 60 mm Dielen und 5 mm Fuge: 48 Reihen
      final reihen = [
        for (var reihe = 0; reihe < 48; reihe++)
          reihenstuecke(
            _null,
            laenge,
            wahl.stoesse(reihe, [(_null, laenge)]).single,
            laengste: raster,
          ),
      ];
      final geplant = _zaehle([
        for (final r in reihen)
          for (final s in r) s.mm,
      ]);
      final alt = _zaehle([
        for (final z in fall.zuschnitt)
          if (z.artikel.startsWith('Terrassendiele'))
            for (var i = 0; i < z.menge; i++)
              for (final s in z.schnitteCm) (s * 10).round(),
      ]);
      switch (id) {
        // Planungskern v7 Regel 9.3: Verband nur, wenn die Fläche länger
        // als eine Diele ist – 480 cm liegen ganz (alt 240 + 240 cm usw.)
        case 'F06' || 'F07' || 'F08':
          expect(geplant, {4800: 48}, reason: id);
        // Planungskern v7 Regel 9.3: Wechselverband unregelmäßig (alt
        // 600 + 200 und 200 + 600 cm im Wechsel); Stücke 40 cm bis 6 m
        case 'F12':
          expect(geplant, isNot(alt), reason: id);
          for (final r in reihen) {
            expect(_mm(r).reduce((a, b) => a + b), 8000);
            for (final s in r) {
              expect(s.mm, inInclusiveRange(400, 6000), reason: id);
            }
          }
        default:
          expect(geplant, alt, reason: id);
      }
    }
  });
}
