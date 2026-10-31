import 'dart:convert';
import 'dart:io';

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

const _m4 = Millimeter(4000);
const _m5 = Millimeter(5000);
const _m6 = Millimeter(6000);
const _m7 = Millimeter(7000);
const _standard = [_m4, _m5, _m6];

Artikel _belag(Artikelart art, List<Millimeter> laengen) => Artikel(
  nummer: const Artikelnummer('1'),
  titel: 'Belag',
  art: art,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  abmessungen: Abmessungen(laengen: laengen),
  holzart: art.istHolz ? robinie : null,
  serie: art.istHolz ? basic : null,
);

/// Ausgangslängen und Schnitte des Deckbelags im Referenzfall [id].
List<Map<String, Object?>> _zuschnitt(String id) {
  final json = jsonDecode(
    File('test/referenzfaelle/$id.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final erwartet = json['erwartet']! as Map<String, Object?>;
  return [
    for (final z in erwartet['zuschnitt_deckbelag']! as List<Object?>)
      z! as Map<String, Object?>,
  ];
}

/// Alte Länge in mm, aufgerundet auf die heutigen Lieferlängen: 3,0 / 4,5 /
/// 5,5 m gibt es nicht mehr (R-A06).
Millimeter _heute(num cm) =>
    _standard.firstWhere((l) => l.mm >= (cm * 10).round());

/// Lieferlängen einer Reihe im Referenzfall [id], je Dielenartikel einmal.
List<Millimeter> _alteLaengen(String id) =>
    {for (final z in _zuschnitt(id)) _heute(z['ausgangslaenge_cm']! as num)}
        .toList();

void main() {
  group('automatisch (R-B10)', () {
    test('kürzeste Länge, die die Reihe abdeckt', () {
      expect(lieferlaengenFuer(const Millimeter(1), _standard), [_m4]);
      expect(lieferlaengenFuer(const Millimeter(4000), _standard), [_m4]);
      expect(lieferlaengenFuer(const Millimeter(4001), _standard), [_m5]);
      expect(lieferlaengenFuer(const Millimeter(6000), _standard), [_m6]);
    });

    test('längere Reihen: längste Länge, dann der Rest', () {
      expect(lieferlaengenFuer(const Millimeter(6001), _standard), [_m6, _m4]);
      expect(lieferlaengenFuer(const Millimeter(12000), _standard), [_m6, _m6]);
      expect(lieferlaengenFuer(const Millimeter(13000), _standard), [
        _m6,
        _m6,
        _m4,
      ]);
    });

    test('ohne Längen oder ohne Reihe keine Lieferlängen', () {
      expect(lieferlaengenFuer(const Millimeter(4000), const []), isEmpty);
      expect(lieferlaengenFuer(const Millimeter(0), _standard), isEmpty);
      expect(lieferlaengenFuer(const Millimeter(-1), _standard), isEmpty);
    });
  });

  group('erzwungene Länge', () {
    test('nur diese Länge (F13, Fachkonzept 2.2)', () {
      expect(lieferlaengenFuer(const Millimeter(8000), _standard, fest: _m4), [
        _m4,
        _m4,
      ]);
      expect(lieferlaengenFuer(const Millimeter(4800), _standard, fest: _m4), [
        _m4,
        _m4,
      ]);
      expect(lieferlaengenFuer(const Millimeter(3000), _standard, fest: _m6), [
        _m6,
      ]);
    });

    test('liefert der Belag sie nicht, gilt die Automatik', () {
      expect(lieferlaengenFuer(const Millimeter(4800), [_m4, _m5], fest: _m6), [
        _m5,
      ]);
    });
  });

  group('Referenzfälle', () {
    test('F01, F02, F09, F13, F14 und F20', () {
      expect(lieferlaengenFuer(const Millimeter(4800), _standard), [_m5]);
      expect(lieferlaengenFuer(const Millimeter(3090), _standard), [_m4]);
      expect(lieferlaengenFuer(const Millimeter(8000), _standard), [_m6, _m4]);
      expect(lieferlaengenFuer(const Millimeter(3600), _standard), [_m4]);
      // ECO SELECT liefert 7 m; F14 nahm sie fälschlich für eine Serie mit
      // 4/5/6 m (B-035).
      expect(lieferlaengenFuer(const Millimeter(8000), [..._standard, _m7]), [
        _m7,
        _m4,
      ]);
    });

    test('ein Schnitt je Reihe: wie der alte Planer', () {
      for (final id in [
        '2025-08-26-719-v2',
        '2026-04-28-4413-v11',
        '2026-04-28-859-v5',
        '2026-04-29-2412-v5',
        '2026-05-03-347-v4',
        '2026-05-12-1823-v4',
        '2026-05-28-4655-v2',
        '2026-06-25-1275-v3',
        '2026-08-06-2810-v3',
        '2026-08-26-1067-v2',
      ]) {
        final z = _zuschnitt(id).first;
        final reihe = (z['schnitte_cm']! as List<Object?>).single! as num;
        expect(lieferlaengenFuer(Millimeter(reihe.toInt() * 10), _standard), [
          _heute(z['ausgangslaenge_cm']! as num),
        ], reason: id);
      }
    });

    test('Reihen über 6 m: wie der alte Planer', () {
      expect(
        lieferlaengenFuer(const Millimeter(9730), _standard),
        _alteLaengen('2026-06-30-2295-v5'),
      );
      expect(
        lieferlaengenFuer(const Millimeter(10500), _standard),
        _alteLaengen('2026-07-07-2794-v2'),
      );
    });
  });

  test('wählbar nur bei Dielen mit mehreren Längen', () {
    expect(dielenlaengeWaehlbar(_belag(Artikelart.diele, [_m4, _m5])), isTrue);
    expect(dielenlaengeWaehlbar(_belag(Artikelart.diele, [_m4])), isFalse);
    expect(
      dielenlaengeWaehlbar(_belag(Artikelart.systemdiele, [_m4, _m5])),
      isFalse,
    );
    expect(
      dielenlaengeWaehlbar(_belag(Artikelart.holzfliese, [_m4, _m5])),
      isFalse,
    );
  });
}
