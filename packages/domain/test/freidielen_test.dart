import 'dart:convert';
import 'dart:io';

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

const _diele = Artikelnummer('10-10-073-R');
const _andere = Artikelnummer('10-10-046-R');
const _fliese = Artikelnummer('40-10-001');

Lieferposition _p(Artikelnummer belag, int laenge, int anzahl) =>
    (belag: belag, laenge: Millimeter(laenge), anzahl: anzahl);

bool _istDiele(Artikelnummer n) => n != _fliese;

Lieferposition? _frei(List<Lieferposition> liste) =>
    freidielenposition(liste, istDiele: _istDiele);

void main() {
  group('Freidielen (M8-04, R-B09, B-228)', () {
    test('unter 25 Dielen keine, ab 25 eine in der längsten Länge', () {
      expect(_frei(const []), isNull);
      expect(_frei([_p(_diele, 5000, 24)]), isNull);
      expect(_frei([_p(_diele, 5000, 25)]), _p(_diele, 5000, 1));
      // F01: 48 Dielen à 5000 mm → eine Freidiele 5000 mm
      expect(_frei([_p(_diele, 5000, 48)]), _p(_diele, 5000, 1));
      // gemischte Längen: gezählt werden alle, geliefert die längste
      expect(
        _frei([
          _p(_diele, 6000, 10),
          _p(_diele, 4000, 30),
          _p(_diele, 5000, 10),
        ]),
        _p(_diele, 6000, 2),
      );
      expect(
        _frei([
          _p(_diele, 4000, 30),
          _p(_diele, 6000, 10),
          _p(_diele, 5000, 10),
        ]),
        _p(_diele, 6000, 2),
      );
    });

    test('Staffel: ab 50 zwei, ab 100 je weitere 50 eine', () {
      for (final (dielen, frei) in [
        (49, 1),
        (50, 2),
        (99, 2),
        (100, 3),
        (149, 3),
        (150, 4),
      ]) {
        expect(
          _frei([_p(_diele, 5000, dielen)])!.anzahl,
          frei,
          reason: '$dielen',
        );
      }
    });

    test('Hauptdiele: der Belag mit den meisten Dielen, Holzfliesen nie', () {
      // F22: Ausschnitt mit anderem Belag – die Freidiele vom Hauptbelag
      expect(
        _frei([_p(_andere, 4000, 20), _p(_diele, 5000, 40)]),
        _p(_diele, 5000, 1),
      );
      expect(
        _frei([_p(_diele, 5000, 40), _p(_andere, 4000, 60)]),
        _p(_andere, 4000, 2),
      );
      // gleich viele: der zuerst geplante
      expect(
        _frei([_p(_diele, 5000, 30), _p(_andere, 4000, 30)]),
        _p(_diele, 5000, 1),
      );
      expect(_frei([_p(_fliese, 606, 80)]), isNull);
      expect(
        _frei([_p(_fliese, 606, 80), _p(_diele, 5000, 30)]),
        _p(_diele, 5000, 1),
      );
    });

    test(
      'Länge wie im alten Planer: die längste geplante Länge (F13, F15)',
      () {
        Referenzkonfiguration fall(String id) => Referenzkonfiguration.ausJson(
          jsonDecode(
            File('test/referenzkonfigurationen/$id.json').readAsStringSync(),
          ) as Map<String, Object?>,
        );
        for (final id in ['F01', 'F02', 'F13', 'F15']) {
          final dielen = fall(id).materialliste
              .where((m) => m.typ == 'Deckbelag' || m.typ == 'Anfangsdiele');
          final frei = dielen.singleWhere(
            (m) => m.bezeichnung.contains('Freidiele'),
          );
          final geplant = dielen.where(
            (m) => !m.bezeichnung.contains('Freidiele'),
          );
          expect(
            frei.laengeMm,
            geplant.map((m) => m.laengeMm!).reduce((a, b) => a > b ? a : b),
            reason: id,
          );
        }
      },
    );
  });
}
