import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

/// Geometrie der Pläne nach dem Planungskern v6 Abschnitt 6 (R-E01 bis
/// R-E03).
void main() {
  const rechteck = [
    Punkt(0, 0),
    Punkt(4800, 0),
    Punkt(4800, 3090),
    Punkt(0, 3090),
  ];

  group('Eckbuchstaben (R-E03)', () {
    test('A … Z, dann AA, AB … wie im Planungskern', () {
      expect(
        [
          for (final i in [0, 1, 25, 26, 27, 51, 52]) eckbuchstabe(i),
        ],
        ['A', 'B', 'Z', 'AA', 'AB', 'AZ', 'BA'],
      );
    });

    test('A oben links, weiter im Uhrzeigersinn – egal wo und in welcher '
        'Richtung der Umriss beginnt', () {
      expect(eckenBenennen(rechteck), ['A', 'B', 'C', 'D']);
      // unten rechts begonnen, im Uhrzeigersinn
      expect(eckenBenennen([...rechteck.skip(2), ...rechteck.take(2)]), [
        'C',
        'D',
        'A',
        'B',
      ]);
      // gegen den Uhrzeigersinn ab unten links
      expect(eckenBenennen(rechteck.reversed.toList()), ['D', 'C', 'B', 'A']);
    });

    test('oben: kleinstes y, bei Gleichstand kleinstes x', () {
      // Trapez: zwei Ecken oben auf gleicher Höhe, die linke ist A
      const trapez = [
        Punkt(1000, 2000),
        Punkt(0, 2000),
        Punkt(300, 0),
        Punkt(700, 0),
      ];
      expect(eckenBenennen(trapez), ['C', 'D', 'A', 'B']);
      // Spitze oben rechts liegt höher als die Ecke links
      const schief = [Punkt(0, 100), Punkt(500, 0), Punkt(400, 900)];
      expect(eckenBenennen(schief), ['C', 'A', 'B']);
    });

    test('offener Linienzug und weniger als drei Ecken: Reihenfolge der '
        'Punkte', () {
      expect(eckenBenennen(rechteck.reversed.toList(), geschlossen: false), [
        'A',
        'B',
        'C',
        'D',
      ]);
      expect(eckenBenennen(const [Punkt(5, 5), Punkt(0, 0)]), ['A', 'B']);
      expect(eckenBenennen(const []), isEmpty);
    });

    test('Grundriss: Vorlage, gedrehte Form, offene Freiform, Kreis', () {
      final r = RechteckGrundriss(
        const Millimeter(4800),
        const Millimeter(3090),
      );
      expect([for (var i = 0; i < 4; i++) r.eckname(i)], ['A', 'B', 'C', 'D']);
      // um 90° gedreht: der erste Punkt liegt jetzt oben rechts
      final gedreht = r.gedreht(90);
      expect(gedreht.ecken.first, const Punkt(3090, 0));
      expect(
        [for (var i = 0; i < 4; i++) gedreht.eckname(i)],
        ['B', 'C', 'D', 'A'],
      );
      final offen = FreiformGrundriss(rechteck.reversed.toList());
      expect(
        [for (var i = 0; i < 4; i++) offen.eckname(i)],
        ['A', 'B', 'C', 'D'],
      );
      final zu = FreiformGrundriss(
        rechteck.reversed.toList(),
        geschlossen: true,
      );
      expect(zu.eckname(0), 'D');
      final kreis = KreisGrundriss(const Millimeter(3000));
      expect(kreis.eckname(0), 'A');
      expect(r.eckname(4), 'E');
    });

    test('Berechnung: nach Umlauf, offen nach Reihenfolge', () {
      final rueckwaerts = rechteck.reversed.toList();
      expect(Berechnung(umriss: rueckwaerts, flaeche: 1).eckbuchstaben, [
        'D',
        'C',
        'B',
        'A',
      ]);
      expect(
        Berechnung(
          umriss: rueckwaerts,
          flaeche: 0,
          geschlossen: false,
        ).eckbuchstaben,
        ['A', 'B', 'C', 'D'],
      );
    });
  });

  group('Stoßlinien (R-E01)', () {
    Dielenstueck stueck(
      int reihe,
      double x0,
      double x1,
      double y0,
      double y1,
    ) => Dielenstueck(reihe, Millimeter((x1 - x0).round()), [
      Punkt(x0, y0),
      Punkt(x1, y0),
      Punkt(x1, y1),
      Punkt(x0, y1),
    ], breite: y1 - y0);

    test('je Reihe mittig zwischen Ende und Anfang, über die gemeinsame '
        'Breite; Lücke über 10 mm ist kein Stoß', () {
      final linien = stosslinien([
        [
          stueck(0, 3000, 4800, 10, 60),
          stueck(0, 0, 3000, 0, 66),
          stueck(1, 0, 1800, 66, 132),
          stueck(1, 1805, 4800, 66, 132),
          stueck(2, 0, 1000, 132, 198),
          stueck(2, 1010, 2000, 132, 198),
          stueck(2, 2011, 4800, 132, 198),
        ],
      ], 0);
      expect(linien, hasLength(3));
      expect(linien[0].von, const Punkt(3000, 10));
      expect(linien[0].bis, const Punkt(3000, 60));
      expect(linien[1].von, const Punkt(1802.5, 66));
      expect(linien[1].bis, const Punkt(1802.5, 132));
      expect(linien[2].von, const Punkt(1005, 132));
    });

    test('Verlegemuster (Planungskern v7 Regel 9.3, R-B18): Stöße je Reihe '
        'versetzt im Plan', () {
      final belag = Artikel(
        nummer: const Artikelnummer('10-10-046'),
        titel: 'Diele',
        art: Artikelart.diele,
        einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
        abmessungen: Abmessungen(
          breite: const Millimeter(80),
          staerke: const Millimeter(23),
          laengen: const [Millimeter(6000)],
        ),
        holzart: robinie,
        serie: basic,
        profil: Profil.genutet,
      );
      final stand = Planungsstand.start
          .mitGrundriss(
            RechteckGrundriss(const Millimeter(8000), const Millimeter(1000)),
          )
          .mitVerlegeart(Verlegeart.halbverband);
      final v = verlegeBelag(stand, belag)!;
      final linien = stosslinien([for (final t in v.teile) t.stuecke], 0);
      // 12 Reihen à 86 mm: im Wechsel bei 6 m und 3 m
      expect([
        for (final l in linien) l.von.x,
      ], List.generate(12, (i) => i.isEven ? 6000 : 3000));
    });

    test('Teilflächen getrennt: gleiche Reihennummer stößt nicht über die '
        'Teilfläche hinaus', () {
      final linien = stosslinien([
        [stueck(0, 0, 1000, 0, 66)],
        [stueck(0, 1000, 2000, 0, 66)],
      ], 0);
      expect(linien, isEmpty);
    });

    test(
      'gedreht verlegt (90°): Stoß quer zur Diele in Planungskoordinaten',
      () {
        Punkt dreh(Punkt p) => p.gedreht(3.141592653589793 / 2);
        Dielenstueck senkrecht(double y0, double y1) =>
            Dielenstueck(0, Millimeter((y1 - y0).round()), [
              for (final p in [
                Punkt(y0, -66),
                Punkt(y1, -66),
                Punkt(y1, 0),
                Punkt(y0, 0),
              ])
                dreh(p),
            ], breite: 66);
        final linie = stosslinien([
          [senkrecht(0, 2000), senkrecht(2000, 3000)],
        ], 90).single;
        expect(linie.von.x, closeTo(66, 1e-9));
        expect(linie.von.y, closeTo(2000, 1e-9));
        expect(linie.bis.x, closeTo(0, 1e-9));
        expect(linie.bis.y, closeTo(2000, 1e-9));
      },
    );
  });

  group('Achsmaßkette (R-E02)', () {
    UkLinie linie(double x, {bool belegt = true}) => (
      x: x,
      abschnitte: belegt ? const [(0.0, 3090.0)] : const [],
      stoesse: const [],
    );

    test('Rand, jede belegte Achse einmal, Rand – unten am Umriss', () {
      final kette = achsmasskette(
        UkVerlegung(
          linien: [
            linie(420),
            linie(20),
            linie(420),
            linie(800, belegt: false),
          ],
        ),
        rechteck,
      )!;
      expect(kette.marken, const [
        Punkt(0, 3090),
        Punkt(20, 3090),
        Punkt(420, 3090),
        Punkt(4800, 3090),
      ]);
      expect(kette.normale, const Punkt(0, 1));
      expect(kette.abstaende, [20, 400, 4380]);
    });

    test('unter zwei Achsen keine Kette', () {
      expect(
        achsmasskette(
          UkVerlegung(linien: [linie(20), linie(400, belegt: false)]),
          rechteck,
        ),
        isNull,
      );
    });

    test('Dielen senkrecht (90°): Kette links, Normale nach links', () {
      final kette = achsmasskette(
        UkVerlegung(linien: [linie(20), linie(420)], winkel: 90),
        rechteck,
      )!;
      final erwartet = const [
        Punkt(0, 0),
        Punkt(0, 20),
        Punkt(0, 420),
        Punkt(0, 3090),
      ];
      for (final (i, m) in kette.marken.indexed) {
        expect(m.x, closeTo(erwartet[i].x, 1e-9));
        expect(m.y, closeTo(erwartet[i].y, 1e-9));
      }
      expect(kette.normale.x, closeTo(-1, 1e-9));
      expect(kette.normale.y, closeTo(0, 1e-9));
    });
  });

  group('Zahlen der Achsmaßkette (R-E02, Regel 12.1 ohne Überlappung)', () {
    test('passt jede Zahl, steht jede einzeln; unter 10 cm keine', () {
      List<String> texte(List<Kettenzahl> z) => [for (final k in z) k.text];
      final z = kettenzahlen(const [380, 400, 400, 20, 220], (t) => 100);
      expect(texte(z), ['38', '40', '40', '22']);
      expect(
        [for (final k in z) (k.von, k.bis)],
        [(0, 1), (1, 2), (2, 3), (4, 5)],
      );
      // genau passend und genau aneinander: beide stehen
      expect(texte(kettenzahlen(const [400, 400], (t) => 400)), ['40', '40']);
      expect(texte(kettenzahlen(const [100, 99.9], (t) => 0)), ['10']);
      expect(kettenzahlen(const [], (t) => 0), isEmpty);
    });

    test('25 m Kante: gleiche Abstände zusammengefasst, nie übereinander', () {
      // 38 / 61 × 40 / 22 cm; PDF-Maßstab ≈ 0,0186 pt/mm, 7 pt Schrift
      final abstaende = [380.0, for (var i = 0; i < 61; i++) 400.0, 220.0];
      double platz(String t) => t.length * 207.0 + 161;
      final z = kettenzahlen(abstaende, platz);
      expect([for (final k in z) k.text], ['38', '61 × 40', '22']);
      expect([for (final k in z) (k.von, k.bis)], [(0, 1), (1, 62), (62, 63)]);
    });

    test('was dann noch die vorige Zahl berührt, entfällt', () {
      // „2 × 40“ (700 breit) passt nicht neben „38“, „22“ schon
      final z = kettenzahlen(const [
        380,
        400,
        400,
        20,
        220,
      ], (t) => t.length * 200.0);
      expect([for (final k in z) k.text], ['38', '22']);
    });

    test('Masskette.zahlen rechnet mit ihren Abständen', () {
      final k = Masskette(const [
        Punkt(0, 0),
        Punkt(0, 400),
        Punkt(0, 800),
      ], const Punkt(1, 0));
      expect(k.zahlen((t) => 1000), [(von: 0, bis: 2, text: '2 × 40')]);
    });
  });

  group('Rinnenband (Planungskern v11, Regel 13.1.6, R-E07)', () {
    const kante = (
      seite: 0,
      von: Punkt.ursprung,
      bis: Punkt(4800, 0),
      innen: Punkt(0, 1),
    );

    test('Band 15,1 cm innen an der Kante, Mitte für das Etikett', () {
      final r = Rinnenband.an(kante);
      expect(r.ecken, const [
        Punkt.ursprung,
        Punkt(4800, 0),
        Punkt(4800, 151),
        Punkt(0, 151),
      ]);
      expect(r.laenge, 4800);
      expect(r.mitte, const Punkt(2400, 75.5));
      expect(r.ecken.clear, throwsUnsupportedError);
      expect(
        () => Rinnenband(const [Punkt.ursprung]),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'ecken')),
      );
      // nicht im Ursprung: Auflagerprofile parallel zur Kante
      final versetzt = Rinnenband.an((
        seite: 0,
        von: const Punkt(100, 200),
        bis: const Punkt(1100, 200),
        innen: const Punkt(0, 1),
      ));
      expect(versetzt.auflagerprofile.first.von.x, closeTo(100, 1e-9));
      expect(versetzt.auflagerprofile.first.von.y, closeTo(225, 1e-9));
    });

    test('mit Belag: innen bis an die versetzten Ecken (Trapez)', () {
      // zweite Rinne an der rechten Seite: die Ecke rückt 15,7 cm nach
      // innen, das Band endet anteilig (15,1 von 15,7 cm) davor
      final r = Rinnenband.an(kante, const [
        Punkt(0, 157),
        Punkt(4643, 157),
        Punkt(4643, 3090),
        Punkt(0, 3090),
      ]);
      expect(r.ecken.take(3), const [
        Punkt.ursprung,
        Punkt(4800, 0),
        Punkt(4649, 151),
      ]);
      expect(r.ecken[3].x, closeTo(0, 1e-9));
      expect(r.ecken[3].y, closeTo(151, 1e-9));
      expect(r.laenge, 4800);
      // letzte Seite: die zweite Ecke ist die erste des Umrisses
      final letzte = Rinnenband.an(
        (
          seite: 1,
          von: const Punkt(100, 0),
          bis: Punkt.ursprung,
          innen: const Punkt(0, 1),
        ),
        const [Punkt(0, 157), Punkt(100, 157)],
      );
      expect(letzte.ecken[2], const Punkt(0, 151));
      expect(letzte.ecken[3], const Punkt(100, 151));
    });

    test('zwei Auflagerprofile 2,5 cm vom Rand, Schlitze alle 5 cm', () {
      final r = Rinnenband.an(kante);
      final va = r.auflagerprofile;
      expect(va, hasLength(2));
      expect(va.first.von.x, 0);
      expect(va.first.von.y, closeTo(25, 1e-9));
      expect(va.first.bis.x, 4800);
      expect(va.first.bis.y, closeTo(25, 1e-9));
      expect(va.last.von.y, closeTo(126, 1e-9));
      final schlitze = r.schlitze;
      expect(schlitze, hasLength(95));
      expect(schlitze.first.von.x, closeTo(50, 1e-9));
      expect(schlitze.first.von.y, closeTo(35, 1e-9));
      expect(schlitze.first.bis.y, closeTo(116, 1e-9));
      expect(schlitze.last.bis.x, closeTo(4750, 1e-9));
      Rinnenband kurz(double l) => Rinnenband.an((
        seite: 0,
        von: Punkt.ursprung,
        bis: Punkt(l, 0),
        innen: const Punkt(0, 1),
      ));
      expect(kurz(100).schlitze, hasLength(1));
      expect(kurz(99).schlitze, isEmpty);
    });
  });

  group('Transport', () {
    test('Stöße und Kette hin und zurück, auch über mitPlanung', () {
      final bild = Planbild(
        stoesse: const [
          (von: Punkt(1, 2), bis: Punkt(3, 4)),
          (von: Punkt(5, 6), bis: Punkt(7, 8)),
        ],
        achsen: Masskette(const [Punkt(0, 9), Punkt(10, 9)], const Punkt(0, 1)),
      );
      final b = Berechnung(
        umriss: rechteck,
        flaeche: 1,
        planbild: bild,
      ).mitPlanung(1);
      expect(b.planbild, same(bild));
      final zurueck = Berechnung.ausBytes(b.zuBytes()).planbild;
      expect(zurueck.stoesse, bild.stoesse);
      expect(zurueck.achsen!.marken, bild.achsen!.marken);
      expect(zurueck.achsen!.normale, const Punkt(0, 1));
      expect(zurueck.rinnen, isEmpty);
    });

    test('Rinnen hin und zurück', () {
      final band = Rinnenband(const [
        Punkt(1, 2),
        Punkt(3, 4),
        Punkt(5, 6),
        Punkt(7, 8),
      ]);
      final b = Berechnung(
        umriss: rechteck,
        flaeche: 1,
        planbild: Planbild(rinnen: [band, band]),
      );
      final zurueck = Berechnung.ausBytes(b.zuBytes()).planbild.rinnen;
      expect([for (final r in zurueck) r.ecken], [band.ecken, band.ecken]);
      expect(Planbild(rinnen: [band]).rinnen.clear, throwsUnsupportedError);
    });

    test('ohne: leer; alte Puffer ohne das Feld', () {
      final leer = Berechnung.ausBytes(
        Berechnung(umriss: rechteck, flaeche: 1).zuBytes(),
      ).planbild;
      expect(leer.stoesse, isEmpty);
      expect(leer.achsen, isNull);
      expect(Planbild.leer.stoesse, isEmpty);
      final fbb = fb.Builder()..startTable(0);
      fbb.finish(fbb.endTable());
      final alt = Berechnung.ausBytes(fbb.buffer).planbild;
      expect(alt.stoesse, isEmpty);
      expect(alt.achsen, isNull);
    });

    test('Listen sind unveränderlich', () {
      final bild = Planbild(
        stoesse: [(von: Punkt.ursprung, bis: Punkt.ursprung)],
      );
      expect(bild.stoesse.clear, throwsUnsupportedError);
      final kette = Masskette([Punkt.ursprung], const Punkt(0, 1));
      expect(kette.marken.clear, throwsUnsupportedError);
      expect(kette.abstaende, isEmpty);
    });
  });
}
