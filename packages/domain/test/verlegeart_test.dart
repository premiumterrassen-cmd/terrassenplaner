import 'dart:convert';
import 'dart:io';

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

const _null = Millimeter(0);
const _m6 = Millimeter(6000);

List<int> _mm(List<Millimeter> werte) => [for (final w in werte) w.mm];

/// Stoßlinien in mm für eine Fläche von 0 bis [laenge].
List<int> _stoesse(Verlegeart art, int reihe, int laenge, int raster) =>
    _mm(art.stoesse(reihe, _null, Millimeter(laenge), Millimeter(raster)));

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
  test('Nummern im Transportformat', () {
    expect([for (final v in Verlegeart.values) v.nummer], [0, 1, 2, 3]);
  });

  group('Stoßlinien', () {
    test('Fugenschnitt: in jeder Reihe an denselben Stellen', () {
      for (final reihe in [0, 1, 2, 3]) {
        expect(_stoesse(Verlegeart.fugenschnitt, reihe, 8000, 6000), [6000]);
        expect(_stoesse(Verlegeart.fugenschnitt, reihe, 13000, 6000), [
          6000,
          12000,
        ]);
      }
      expect(_stoesse(Verlegeart.fugenschnitt, 0, 6000, 6000), isEmpty);
      expect(_stoesse(Verlegeart.fugenschnitt, 0, 12000, 6000), [6000]);
      expect(_stoesse(Verlegeart.fugenschnitt, 0, 12001, 6000), [6000, 12000]);
    });

    test('Halbverband: jede zweite Reihe um eine halbe Diele versetzt', () {
      expect(_stoesse(Verlegeart.halbverband, 0, 8000, 6000), [6000]);
      expect(_stoesse(Verlegeart.halbverband, 1, 8000, 6000), [3000]);
      expect(_stoesse(Verlegeart.halbverband, 2, 8000, 6000), [6000]);
      expect(_stoesse(Verlegeart.halbverband, 3, 13000, 6000), [3000, 9000]);
      expect(_stoesse(Verlegeart.halbverband, 1, 4800, 4800), [2400]);
    });

    test('Drittelverband: Reihe für Reihe um ein Drittel versetzt', () {
      expect(_stoesse(Verlegeart.drittelverband, 0, 8000, 6000), [6000]);
      expect(_stoesse(Verlegeart.drittelverband, 1, 8000, 6000), [2000]);
      expect(_stoesse(Verlegeart.drittelverband, 2, 8000, 6000), [4000]);
      expect(_stoesse(Verlegeart.drittelverband, 3, 8000, 6000), [6000]);
      expect(_stoesse(Verlegeart.drittelverband, 4, 13000, 6000), [2000, 8000]);
      expect(_stoesse(Verlegeart.drittelverband, 2, 4800, 4800), [3200]);
    });

    test('Wechselverband: jede zweite Reihe von der Gegenseite', () {
      expect(_stoesse(Verlegeart.wechselverband, 0, 8000, 6000), [6000]);
      expect(_stoesse(Verlegeart.wechselverband, 1, 8000, 6000), [2000]);
      expect(_stoesse(Verlegeart.wechselverband, 3, 13000, 6000), [1000, 7000]);
      expect(_stoesse(Verlegeart.wechselverband, 1, 6000, 6000), isEmpty);
      expect(_stoesse(Verlegeart.wechselverband, 1, 6001, 6000), [1]);
      expect(_stoesse(Verlegeart.wechselverband, 1, 12000, 6000), [6000]);
      expect(_stoesse(Verlegeart.wechselverband, 1, 4800, 4800), isEmpty);
    });

    test('Fläche nicht bei 0: Linien ab ihrem Anfang', () {
      const von = Millimeter(1000);
      const bis = Millimeter(9000);
      expect(_mm(Verlegeart.fugenschnitt.stoesse(0, von, bis, _m6)), [7000]);
      expect(_mm(Verlegeart.halbverband.stoesse(1, von, bis, _m6)), [4000]);
      expect(_mm(Verlegeart.wechselverband.stoesse(1, von, bis, _m6)), [3000]);
    });

    test('Ausgangspunkt mitten in der Fläche (M5-05): Linie durch ihn', () {
      const von = Millimeter(-3394);
      const bis = Millimeter(2185);
      const raster = Millimeter(5579);
      const a = Millimeter(0);
      List<int> linien(Verlegeart art, int reihe) =>
          _mm(art.stoesse(reihe, von, bis, raster, ausgang: a));
      expect(linien(Verlegeart.fugenschnitt, 0), [0]);
      expect(linien(Verlegeart.fugenschnitt, -7), [0]);
      expect(linien(Verlegeart.wechselverband, -1), isEmpty);
      expect(linien(Verlegeart.wechselverband, -2), [0]);
      expect(linien(Verlegeart.halbverband, -1), [-2789]);
      expect(linien(Verlegeart.drittelverband, -1), [-1860]);
      expect(linien(Verlegeart.drittelverband, -2), [1860]);
      // Linie genau auf dem Rand der Fläche zählt nicht
      expect(
        _mm(
          Verlegeart.fugenschnitt.stoesse(
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
          Verlegeart.fugenschnitt.stoesse(
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
        for (final reihe in [0, 1, 2]) {
          expect(_stoesse(art, reihe, 8000, 0), isEmpty);
          expect(_stoesse(art, reihe, 8000, -6000), isEmpty);
          expect(_stoesse(art, reihe, 1, 6000), isEmpty);
        }
        expect(_stoesse(art, 1, 0, 6000), isEmpty);
        expect(
          _mm(art.stoesse(1, const Millimeter(8000), _null, _m6)),
          isEmpty,
        );
      }
    });
  });

  test('Raster: längste Länge, höchstens die Ausdehnung', () {
    expect(stossraster(const Millimeter(4800), _m6), const Millimeter(4800));
    expect(stossraster(const Millimeter(8000), _m6), _m6);
    expect(stossraster(_m6, _m6), _m6);
  });

  test('Stoßmuster wie im alten Planer (F01, F06–F13)', () {
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
      // 309 cm bei 60 mm Dielen und 5 mm Fuge: 48 Reihen
      final geplant = _zaehle([
        for (var reihe = 0; reihe < 48; reihe++)
          for (final s in reihenstuecke(
            _null,
            laenge,
            art.stoesse(reihe, _null, laenge, raster),
            laengste: raster,
          ))
            s.mm,
      ]);
      final alt = _zaehle([
        for (final z in fall.zuschnitt)
          if (z.artikel.startsWith('Terrassendiele'))
            for (var i = 0; i < z.menge; i++)
              for (final s in z.schnitteCm) (s * 10).round(),
      ]);
      expect(geplant, alt, reason: id);
    }
  });
}
