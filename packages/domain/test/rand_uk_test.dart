import 'dart:math' as math;

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

/// Kante in der gedrehten Fläche (Dielen längs x), Belag rechts davon.
Randkante _kante(double x0, double y0, double x1, double y1) =>
    (von: Punkt(x0, y0), bis: Punkt(x1, y1), innen: const Punkt(1, 0));

/// UK-Linie bei [x] über [von]–[bis] in y.
UkLinie _linie(double x, [double von = 0, double bis = 1000]) =>
    (x: x, abschnitte: [(von, bis)], stoesse: const []);

/// Kante von (0, 0) nach oben, [grad] gegen die UK-Richtung (y) geneigt.
Randkante _geneigt(double grad, [double hoehe = 1000]) =>
    _kante(0, 0, hoehe * math.tan(grad * math.pi / 180), hoehe);

List<(Punkt, Punkt, bool)> _rand(
  List<Randkante> kanten, [
  List<UkLinie> linien = const [],
]) => [
  for (final r in randbelegung(kanten, linien))
    (r.kante.von, r.kante.bis, r.ergaenzt),
];

void main() {
  group('Rand-UK (Planungsregeln Alexander, Planungskern v6, Regel 3.3)', () {
    test('Kanten parallel zu den Dielen bekommen keine', () {
      expect(
        _rand([_kante(0, 0, 1000, 0), _kante(1000, 500, 0, 500)]),
        isEmpty,
      );
    });

    test('Kante quer zu den Dielen ohne Linie: Rand-UK; liegt eine Linie '
        'höchstens 6 cm daneben, keine', () {
      final k = _kante(0, 0, 0, 1000);
      expect(_rand([k]), [(k.von, k.bis, false)]);
      expect(_rand([k], [_linie(60)]), isEmpty);
      expect(_rand([k], [_linie(-60)]), isEmpty);
      expect(_rand([k], [_linie(61)]), [(k.von, k.bis, false)]);
      expect(_rand([k], [_linie(-61)]), hasLength(1));
    });

    test('höchstens 10 % der Prüfpunkte (alle 10 cm ab 5 cm) ohne UK', () {
      final k = _kante(0, 0, 0, 1000);
      // Prüfpunkte y = 50, 150, … 950; die Linie reicht 6 cm weiter
      expect(_rand([k], [_linie(0, 110, 1000)]), isEmpty);
      expect(_rand([k], [_linie(0, 0, 890)]), isEmpty);
      // 1 von 10 fehlt: noch belegt; 2 von 10: Rand-UK
      expect(_rand([k], [_linie(0, 111, 1000)]), isEmpty);
      expect(_rand([k], [_linie(0, 0, 889)]), isEmpty);
      expect(_rand([k], [_linie(0, 111, 889)]), hasLength(1));
      // beide Grenzen genau getroffen: belegt
      expect(_rand([k], [_linie(0, 110, 890)]), isEmpty);
      expect(_rand([k], [_linie(0, 211, 1000)]), hasLength(1));
      // zwei Abschnitte decken gemeinsam
      expect(
        _rand(
          [k],
          [
            (
              x: 0,
              abschnitte: const [(0.0, 400.0), (600.0, 1000.0)],
              stoesse: const [],
            ),
          ],
        ),
        isEmpty,
      );
    });

    test('schräg über 12° zur UK: Rand-UK, auch wenn Linien sie decken', () {
      // Linien alle 10 cm decken jede Kante bis 20 cm Versatz
      final linien = [for (var x = 0.0; x <= 300; x += 100) _linie(x)];
      final schraeg = _geneigt(12.01);
      expect(_rand([schraeg], linien), [(schraeg.von, schraeg.bis, false)]);
      expect(_rand([_geneigt(11.99)], linien), isEmpty);
      // abwärts und nach links gleich
      final links = _kante(0, 1000, -213, 0);
      expect(_rand([links], linien), hasLength(1));
    });

    test('Dielen enden ab 8 cm quer zur Diele (Regel); darunter nur die '
        'Selbstkontrolle', () {
      final regel = _kante(0, 0, 81, 81);
      expect(_rand([regel]), [(regel.von, regel.bis, false)]);
      // 8 cm quer: Prüfpunkt bei 5 cm ohne UK → ergänzt
      final kurz = _kante(0, 0, 80, 80);
      expect(_rand([kurz]), [(kurz.von, kurz.bis, true)]);
      // kürzer als 10 cm: kein Prüfpunkt, also belegt
      expect(_rand([_kante(0, 0, 0, 99)]), isEmpty);
      expect(_rand([_kante(0, 0, 70, 70)]), isEmpty);
    });
  });

  group('Selbstkontrolle (Regel 3.4)', () {
    test('flache Kante ab 1 cm quer zur Diele ohne UK: ergänzt; flacher '
        'läuft mit der Diele', () {
      final flach = _kante(0, 0, 1000, 10);
      expect(_rand([flach]), [(flach.von, flach.bis, true)]);
      expect(_rand([_kante(0, 0, 1000, 9.99)]), isEmpty);
      // eine Linie je 20 cm deckt sie
      expect(
        _rand([flach], [for (var x = 0.0; x <= 1000; x += 100) _linie(x)]),
        isEmpty,
      );
    });

    test('Rand-UK decken andere Kanten bis 6 cm Abstand; ergänzte stehen '
        'nach denen der Regel', () {
      final senkrecht = _kante(0, 0, 0, 1000);
      // flach (8 cm quer), Prüfpunkt (30|40) liegt 3 cm neben der Rand-UK
      final flach = _kante(0, 0, 60, 80);
      expect(_rand([flach]), [(flach.von, flach.bis, true)]);
      expect(_rand([flach, senkrecht]), [
        (senkrecht.von, senkrecht.bis, false),
      ]);
      // parallel 6 cm daneben: von der ersten gedeckt, 6,1 cm nicht
      final nah = _kante(60, 0, 60, 1000);
      expect(_rand([senkrecht, nah]), hasLength(1));
      expect(_rand([senkrecht, _kante(61, 0, 61, 1000)]), hasLength(2));
      // Abstand zur Strecke, nicht zur Geraden: hinter dem Ende nicht
      expect(_rand([senkrecht, _kante(0, 1100, 0, 2000)]), hasLength(2));
      final weit = _kante(500, 0, 600, 70);
      expect(_rand([weit, senkrecht]), [
        (senkrecht.von, senkrecht.bis, false),
        (weit.von, weit.bis, true),
      ]);
    });
  });

  group('Kanten an Belag (randkanten)', () {
    // Rechteck 0–1000 × 0–500 mit leerem Ausschnitt rechts unten in der
    // Ecke (800–1000 × 0–200) und einem innen (300–500 × 200–300)
    const umriss = [
      Punkt(0, 0),
      Punkt(1000, 0),
      Punkt(1000, 500),
      Punkt(0, 500),
    ];
    const ecke = [
      Punkt(800, 0),
      Punkt(1000, 0),
      Punkt(1000, 200),
      Punkt(800, 200),
    ];
    const innen = [
      Punkt(300, 200),
      Punkt(500, 200),
      Punkt(500, 300),
      Punkt(300, 300),
    ];
    bool drin(List<Punkt> p, Punkt q) => Kontur(p).enthaelt(q);
    bool aufBelag(Punkt q) =>
        drin(umriss, q) && !drin(ecke, q) && !drin(innen, q);

    test('Belagseite: innen am Umriss, außen am Ausschnitt; Stücke am '
        'Ausschnitt in der Ecke fallen weg', () {
      final k = randkanten([umriss, ecke, innen], aufBelag, 40);
      expect(k, [
        (
          von: const Punkt(0, 0),
          bis: const Punkt(800, 0),
          innen: const Punkt(0, 1),
        ),
        (
          von: const Punkt(1000, 200),
          bis: const Punkt(1000, 500),
          innen: const Punkt(-1, 0),
        ),
        (
          von: const Punkt(1000, 500),
          bis: const Punkt(0, 500),
          innen: const Punkt(0, -1),
        ),
        (
          von: const Punkt(0, 500),
          bis: const Punkt(0, 0),
          innen: const Punkt(1, 0),
        ),
        (
          von: const Punkt(1000, 200),
          bis: const Punkt(800, 200),
          innen: const Punkt(0, 1),
        ),
        (
          von: const Punkt(800, 200),
          bis: const Punkt(800, 0),
          innen: const Punkt(-1, 0),
        ),
        (
          von: const Punkt(300, 200),
          bis: const Punkt(500, 200),
          innen: const Punkt(0, -1),
        ),
        (
          von: const Punkt(500, 200),
          bis: const Punkt(500, 300),
          innen: const Punkt(1, 0),
        ),
        (
          von: const Punkt(500, 300),
          bis: const Punkt(300, 300),
          innen: const Punkt(0, 1),
        ),
        (
          von: const Punkt(300, 300),
          bis: const Punkt(300, 200),
          innen: const Punkt(-1, 0),
        ),
      ]);
    });

    test('ein Ausschnitt über den Rand hinaus teilt die Kante am Schnitt; '
        'Teilungen ohne Wechsel bleiben eine Kante', () {
      const raus = [
        Punkt(400, -100),
        Punkt(600, -100),
        Punkt(600, 100),
        Punkt(400, 100),
      ];
      bool belag(Punkt q) => drin(umriss, q) && !drin(raus, q);
      final unten = randkanten(
        [umriss, raus],
        belag,
        40,
      ).where((k) => k.von.y == 0 && k.bis.y == 0).toList();
      expect(unten, [
        (
          von: const Punkt(0, 0),
          bis: const Punkt(400, 0),
          innen: const Punkt(0, 1),
        ),
        (
          von: const Punkt(600, 0),
          bis: const Punkt(1000, 0),
          innen: const Punkt(0, 1),
        ),
      ]);
      // eine Ecke auf der Kante (Ausschnitt berührt sie nur): eine Kante
      const beruehrt = [Punkt(500, 0), Punkt(600, 100), Punkt(400, 100)];
      bool belag2(Punkt q) => drin(umriss, q) && !drin(beruehrt, q);
      expect(
        randkanten(
          [umriss, beruehrt],
          belag2,
          40,
        ).where((k) => k.von.y == 0 && k.bis.y == 0),
        [
          (
            von: const Punkt(0, 0),
            bis: const Punkt(1000, 0),
            innen: const Punkt(0, 1),
          ),
        ],
      );
      // Ecken bis 0,5 mm neben der Kante teilen sie (Rundung)
      List<Randkante> unten3(double hoch) {
        final a = [
          Punkt(800, hoch),
          Punkt(1000, hoch),
          const Punkt(1000, 200),
          const Punkt(800, 200),
        ];
        return randkanten(
          [umriss, a],
          (q) => drin(umriss, q) && !drin(a, q),
          40,
        ).where((k) => k.von.y == 0 && k.bis.y == 0).toList();
      }

      expect(unten3(0.5).single.bis, const Punkt(800, 0));
      expect(unten3(0.3).single.bis, const Punkt(800, 0));
      expect(unten3(0.6).single.bis, const Punkt(1000, 0));
    });

    test('verschoben gleich: Schnitte und Ecken unabhängig vom Ursprung', () {
      const v = Punkt(300, 700);
      final u = [for (final p in umriss) p + v];
      final raus = [
        for (final p in const [
          Punkt(400, -100),
          Punkt(600, -100),
          Punkt(600, 100),
          Punkt(400, 100),
        ])
          p + v,
      ];
      final ecke2 = [
        for (final p in const [
          Punkt(450, 0.3),
          Punkt(550, 0.3),
          Punkt(550, 50),
          Punkt(450, 50),
        ])
          p + v,
      ];
      final unten = randkanten(
        [u, raus],
        (q) => drin(u, q) && !drin(raus, q),
        40,
      ).where((k) => k.von.y == 700 && k.bis.y == 700);
      expect(
        [for (final k in unten) (k.von.x, k.bis.x)],
        [(300.0, 700.0), (900.0, 1300.0)],
      );
      final knapp = randkanten(
        [u, ecke2],
        (q) => drin(u, q) && !drin(ecke2, q),
        40,
      ).where((k) => k.von.y == 700 && k.bis.y == 700);
      expect(
        [for (final k in knapp) (k.von.x, k.bis.x)],
        [(300.0, 750.0), (850.0, 1300.0)],
      );
    });
  });
}
