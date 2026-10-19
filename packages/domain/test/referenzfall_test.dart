import 'dart:convert';
import 'dart:io';

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

/// Alle Referenzfälle aus `test/referenzfaelle/` (M1-02).
final _dateien =
    Directory('test/referenzfaelle')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

Map<String, Object?> _json(File f) =>
    jsonDecode(f.readAsStringSync()) as Map<String, Object?>;

/// Kleinstmöglicher Fall – prüft das Lesen fehlender Angaben.
Map<String, Object?> _minimal() => {
  'id': '2026-01-02-3-v1',
  'quelle': {
    'konfigurationsnummer': '2026-01-02-3',
    'version': 1,
    'datum': '2026-01-02',
    'seiten': 4,
    'export': false,
  },
  'eingaben': {
    'grundriss': {
      'form': 'Rechteck',
      'eckpunkte': ['A', 'B', 'C', 'D'],
      'kanten_cm': {'A-B': 300, 'B-C': null},
      'radius_cm': null,
      'ausschnitte': [
        {
          'name': 'A1',
          'kanten_cm': {'A1-B1': 50},
          'funktion': 'leere Fläche',
        },
      ],
      'rundungen': false,
    },
    'flaeche_m2': null,
    'volumen_m3': null,
    'belag': null,
    'verlegerichtung': null,
    'ausgangspunkt': null,
    'unterkonstruktion': null,
    'verblendung': null,
    'aufbauhoehen_cm': null,
    'winkel_grad': null,
  },
  'erwartet': {
    'unterkonstruktion_stueckliste': [
      {'artikel': 'UK', 'laenge_cm': 600, 'stueck': 2, 'farbe': 'red'},
    ],
    'zuschnitt_unterkonstruktion': <Object?>[],
    'dielen': [
      {'artikel': 'Diele', 'laenge_cm': 290, 'breite_cm': 6, 'stueck': 3},
    ],
    'zuschnitt_deckbelag': [
      {
        'artikel': 'Diele',
        'ausgangslaenge_cm': 600,
        'menge': 1,
        'schnitte_cm': [290, 290, 0],
      },
      {
        'artikel': 'Diele',
        'ausgangslaenge_cm': 300,
        'menge': 1,
        'schnitte_cm': [290],
      },
    ],
    'materialliste': [
      {
        'artikelnummer': null,
        'bezeichnung': 'Stelzlager',
        'laenge_mm': null,
        'anzahl': 4,
        'einheit': 'Stück',
        'typ': 'Stellfuss',
      },
    ],
  },
  'hinweise': ['Beispiel'],
};

void main() {
  group('Referenzfall lesen', () {
    test('liest alle Angaben und lässt Fehlendes leer', () {
      final fall = Referenzfall.ausJson(_minimal());
      expect(fall.id, '2026-01-02-3-v1');
      expect(fall.konfigurationsnummer, '2026-01-02-3');
      expect(fall.version, 1);
      expect(fall.datum, DateTime(2026, 1, 2));
      expect(fall.mitExport, isFalse);
      expect(fall.grundriss.form, 'Rechteck');
      expect(fall.grundriss.eckpunkte, hasLength(4));
      expect(fall.grundriss.kantenCm, {'A-B': 300.0, 'B-C': null});
      expect(fall.grundriss.rundungen, isFalse);
      final ausschnitt = fall.grundriss.ausschnitte.single;
      expect(
        [ausschnitt.name, ausschnitt.funktion, ausschnitt.kantenCm['A1-B1']],
        ['A1', 'leere Fläche', 50.0],
      );
      expect([
        fall.flaecheM2,
        fall.volumenM3,
        fall.belag,
        fall.aufbauhoehenCm,
      ], everyElement(isNull));
      expect([fall.verlegerichtung, fall.unterkonstruktion], [null, null]);
      final uk = fall.ukStueckliste.single;
      expect([uk.artikel, uk.laengeCm, uk.stueck], ['UK', 600.0, 2]);
      expect(fall.zuschnittUnterkonstruktion, isEmpty);
      final diele = fall.dielen.single;
      expect(
        [diele.artikel, diele.laengeCm, diele.breiteCm, diele.stueck],
        ['Diele', 290.0, 6.0, 3],
      );
      final zuschnitt = fall.zuschnittDeckbelag.first;
      expect(
        [zuschnitt.artikel, zuschnitt.ausgangslaengeCm, zuschnitt.menge],
        ['Diele', 600.0, 1],
      );
      expect(zuschnitt.schnitteCm, [290.0, 290.0, 0.0]);
      expect(zuschnitt.restCm, 20.0);
      expect(fall.deckbelagStuecke, 3, reason: 'Schnitt 0 zählt nicht');
      expect(fall.dielenStuecke, 3);
      final material = fall.materialliste.single;
      expect(
        [material.artikelnummer, material.bezeichnung, material.laengeMm],
        [null, 'Stelzlager', null],
      );
      expect(
        [material.anzahl, material.einheit, material.typ],
        [4, 'Stück', 'Stellfuss'],
      );
      expect(fall.hinweise, ['Beispiel']);
    });

    test('Aufbauhöhen werden als Zahlen gelesen', () {
      final json = _minimal();
      (json['eingaben']! as Map<String, Object?>)['aufbauhoehen_cm'] = {
        'A': 21.6,
        'B': 8,
      };
      expect(Referenzfall.ausJson(json).aufbauhoehenCm, {'A': 21.6, 'B': 8.0});
    });
  });

  group('Referenzfälle aus den Planungsunterlagen', () {
    test('sind vorhanden (47 Planungsunterlagen)', () {
      expect(_dateien, hasLength(47));
    });

    for (final datei in _dateien) {
      final name = datei.uri.pathSegments.last;
      group(name, () {
        final roh = datei.readAsStringSync();
        final fall = Referenzfall.ausJson(_json(datei));

        test('Dateiname = Konfigurationsnummer und Version', () {
          expect(name, '${fall.id}.json');
          expect(fall.id, '${fall.konfigurationsnummer}-v${fall.version}');
          expect(fall.konfigurationsnummer, matches(r'^\d{4}-\d\d-\d\d-\d+$'));
        });

        test('ohne Personendaten', () {
          expect(roh, isNot(contains('@')));
          for (final feld in ['Name:', 'Adresse:', 'Telefon:', 'E-Mail:']) {
            expect(roh, isNot(contains(feld)));
          }
          // Lange Ziffernfolgen wären Telefonnummern oder Herstellernummern.
          expect(roh, isNot(matches(RegExp(r'\d{8,}'))));
        });

        test('Schnitte passen in die Ausgangslänge', () {
          for (final z in [
            ...fall.zuschnittUnterkonstruktion,
            ...fall.zuschnittDeckbelag,
          ]) {
            expect(z.restCm, greaterThanOrEqualTo(-0.01), reason: z.artikel);
          }
        });

        test('Dielen nach Nummer = zugeschnittene Stücke', () {
          if (fall.dielen.isEmpty || fall.zuschnittDeckbelag.isEmpty) return;
          expect(fall.dielenStuecke, fall.deckbelagStuecke);
        });

        test('Materialliste nur aus einem Export', () {
          if (!fall.mitExport) expect(fall.materialliste, isEmpty);
        });
      });
    }
  });
}
