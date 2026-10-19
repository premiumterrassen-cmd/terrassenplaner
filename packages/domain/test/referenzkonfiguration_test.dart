import 'dart:convert';
import 'dart:io';

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

/// Alle Referenzkonfigurationen aus `test/referenzkonfigurationen/` (M1-03).
final _dateien =
    Directory('test/referenzkonfigurationen')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

final _faelle = {
  for (final datei in _dateien)
    datei.uri.pathSegments.last.replaceAll(
      '.json',
      '',
    ): Referenzkonfiguration.ausJson(
      jsonDecode(datei.readAsStringSync()) as Map<String, Object?>,
    ),
};

Referenzkonfiguration _fall(String id) => _faelle[id]!;

/// Materialliste als vergleichbare Zeilen.
List<String> _material(String id) => [
  for (final m in _fall(id).materialliste)
    '${m.artikelnummer}|${m.bezeichnung}|${m.laengeMm}|${m.anzahl}|'
        '${m.einheit}|${m.typ}',
];

/// Zuschnittliste als vergleichbare Zeilen.
List<String> _zuschnitt(String id) => [
  for (final z in _fall(id).zuschnitt)
    '${z.artikel}|${z.ausgangslaengeCm}|${z.menge}|${z.schnitteCm}',
];

/// Anzahl der zugeschnittenen Stücke einer Länge.
int _stuecke(String id, double laengeCm) => _fall(id).zuschnitt.fold(
  0,
  (summe, z) =>
      summe + z.menge * z.schnitteCm.where((s) => s == laengeCm).length,
);

Map<String, Object?> _minimal() => {
  'id': 'F99',
  'beschreibung': 'Beispiel',
  'fehlerverdacht': <Object?>[],
  'eingaben': {'form': 'Rechteck'},
  'anzeige': {
    'flaeche_m2': 14.832,
    'verschnitt_prozent': null,
    'volumen_m3': null,
  },
  'materialliste': [
    {
      'artikelnummer': '10-10-073',
      'bezeichnung': 'Diele',
      'laenge_mm': 5000,
      'anzahl': 46,
      'einheit': 'lfm',
      'typ': 'Deckbelag',
    },
  ],
  'zuschnitt': [
    {
      'artikel': 'Diele',
      'ausgangslaenge_cm': 500,
      'menge': 46,
      'schnitte_cm': [480],
    },
  ],
};

void main() {
  group('Referenzkonfiguration lesen', () {
    test('liest alle Angaben und lässt Fehlendes leer', () {
      final fall = Referenzkonfiguration.ausJson(_minimal());
      expect([fall.id, fall.beschreibung], ['F99', 'Beispiel']);
      expect(fall.fehlerverdacht, isEmpty);
      expect(fall.istSollwert, isTrue);
      expect(fall.eingaben, {'form': 'Rechteck'});
      expect(() => fall.eingaben['form'] = 'Kreis', throwsUnsupportedError);
      expect(fall.flaecheM2, 14.832);
      expect([
        fall.verschnittProzent,
        fall.volumenM3,
        fall.treppenmasseCm,
      ], everyElement(isNull));
      final material = fall.materialliste.single;
      expect(
        [material.artikelnummer, material.laengeMm, material.anzahl],
        ['10-10-073', 5000, 46],
      );
      final zuschnitt = fall.zuschnitt.single;
      expect([zuschnitt.ausgangslaengeCm, zuschnitt.restCm], [500.0, 20.0]);
    });

    test('Anzeige mit Verschnitt, Volumen und Treppenmaßen', () {
      final json = _minimal()
        ..['anzeige'] = {
          'flaeche_m2': 14,
          'verschnitt_prozent': 4,
          'volumen_m3': 0.435,
          'treppenmasse_cm': [100, 54, 31.2],
        };
      final fall = Referenzkonfiguration.ausJson(json);
      expect(
        [fall.flaecheM2, fall.verschnittProzent, fall.volumenM3],
        [14.0, 4.0, 0.435],
      );
      expect(fall.treppenmasseCm, [100.0, 54.0, 31.2]);
    });

    test('Fehlerverdacht: kein Sollwert', () {
      final json = _minimal()..['fehlerverdacht'] = ['Fehler'];
      final fall = Referenzkonfiguration.ausJson(json);
      expect(fall.fehlerverdacht, ['Fehler']);
      expect(fall.istSollwert, isFalse);
    });
  });

  group('Referenzkonfigurationen aus dem alten Planer', () {
    test('F01 bis F43 vorhanden, Dateiname = id', () {
      expect(_faelle.keys, [
        for (var i = 1; i <= 43; i++) 'F${i.toString().padLeft(2, '0')}',
      ]);
      for (final MapEntry(:key, :value) in _faelle.entries) {
        expect(value.id, key);
      }
    });

    for (final datei in _dateien) {
      final name = datei.uri.pathSegments.last;
      group(name, () {
        final roh = datei.readAsStringSync();
        final fall = Referenzkonfiguration.ausJson(
          jsonDecode(roh) as Map<String, Object?>,
        );

        test('ohne Preise, Bild-Links und Herstellernummern (B-023)', () {
          for (final verboten in ['€', 'preis', 'Preis', 'http', '@']) {
            expect(roh, isNot(contains(verboten)));
          }
          expect(roh, isNot(matches(RegExp(r'\d{8,}'))));
        });

        test('Schnitte passen in die Ausgangslänge', () {
          for (final z in fall.zuschnitt) {
            expect(z.restCm, greaterThanOrEqualTo(-0.01), reason: z.artikel);
          }
        });

        test('Eingaben vollständig (Startkonfiguration + Abweichung)', () {
          expect(
            fall.eingaben.keys,
            containsAll([
              'form',
              'belag',
              'verlegeart',
              'verlegerichtung',
              'unterkonstruktion',
              'art',
              'nutzung',
              'treppen',
              'verschnittvariante',
            ]),
          );
        });
      });
    }
  });

  group('Befunde zum alten Planer', () {
    test('Fehler des alten Planers sind gekennzeichnet (kein Sollwert)', () {
      expect(
        [
          for (final f in _faelle.values)
            if (!f.istSollwert) f.id,
        ],
        ['F14', 'F25', 'F40'],
      );
    });

    test('Fläche des Rechtecks = Kantenprodukt (ohne Rinne)', () {
      for (final fall in _faelle.values) {
        final kanten = fall.eingaben['kanten_cm']! as Map<String, Object?>;
        final rinnen = fall.eingaben['rinnen']! as Map<String, Object?>;
        if (fall.eingaben['form'] != 'Rechteck' || rinnen.isNotEmpty) continue;
        final flaeche =
            (kanten['A-B']! as num) * (kanten['B-C']! as num) / 10000;
        expect(fall.flaecheM2, closeTo(flaeche, 0.0005), reason: fall.id);
      }
    });

    test('leere Ausschnitte werden nicht abgezogen (O-Form, Rechteck)', () {
      expect(_fall('F18').flaecheM2, closeTo(3.6 * 3.8, 0.0005));
      expect(_fall('F21').flaecheM2, _fall('F20').flaecheM2);
    });

    test('Rinne verkleinert die Fläche', () {
      expect(_fall('F38').flaecheM2, lessThan(_fall('F37').flaecheM2));
    });

    test(
      'ohne Wirkung: Wechselverband 480, Bauelement, Fundament (Fehler)',
      () {
        for (final (fall, gleich) in [
          ('F08', 'F01'),
          ('F36', 'F01'),
          ('F40', 'F39'),
        ]) {
          expect(_material(fall), _material(gleich), reason: fall);
          expect(_zuschnitt(fall), _zuschnitt(gleich), reason: fall);
        }
      },
    );

    test('gewerbliche Nutzung ändert nur die Menge KOPPLEX-3', () {
      final unterschied = [
        for (final (i, zeile) in _material('F35').indexed)
          if (zeile != _material('F01')[i]) zeile,
      ];
      expect(unterschied, hasLength(1));
      expect(unterschied.single, contains('KOPPLEX-3'));
    });

    test('Verblendung: 31 Blendenhalter à 8,6 cm aus dem UK-Zuschnitt', () {
      expect(_stuecke('F01', 8.6), 0);
      expect(_stuecke('F37', 8.6), 31);
      expect(_stuecke('F38', 8.6), 31);
    });

    test('Hochterrasse: UK-Stützen à 39,9 cm', () {
      expect(_stuecke('F28', 39.9), greaterThan(0));
    });

    test('Verschnittvariante 2 nimmt 550er statt 500er Dielen', () {
      expect(_fall('F43').verschnittProzent, 12.73);
      expect(_fall('F43').zuschnitt.first.ausgangslaengeCm, 550);
      expect(_fall('F01').zuschnitt.first.ausgangslaengeCm, 500);
    });

    test('Treppenmaße: regulär, 2- und 3-teilige Fächertreppe', () {
      expect(_fall('F39').treppenmasseCm, [100, 54, 31.2]);
      expect(_fall('F41').treppenmasseCm, [104, 108, 46.8]);
      expect(_fall('F42').treppenmasseCm, [158, 108, 46.8]);
    });
  });
}
