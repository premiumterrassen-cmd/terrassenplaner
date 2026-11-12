import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

List<Millimeter> _mm(List<int> werte) => [for (final w in werte) Millimeter(w)];

const _rechteck = [
  Punkt(0, 0),
  Punkt(4800, 0),
  Punkt(4800, 3090),
  Punkt(0, 3090),
];

void main() {
  group('Höhenfläche (Planungskern v7, Regel 9.1): weitere Punkte', () {
    test('Dreieck: Punkt außen wirkt nicht, innen schon', () {
      const dreieck = [Punkt(0, 0), Punkt(3000, 0), Punkt(0, 3000)];
      final aussen = Hoehenflaeche(dreieck, _mm([100, 100, 100, 40]), const [
        Punkt(2000, 2000),
      ]);
      expect(aussen.bei(const Punkt(1500, 1400)), const Millimeter(100));
      final innen = Hoehenflaeche(dreieck, _mm([100, 100, 100, 40]), const [
        Punkt(500, 500),
      ]);
      expect(innen.bei(const Punkt(500, 500)), const Millimeter(40));
    });

    test('zwei weitere Punkte mit eigener Höhe; einer auf Ecke A', () {
      final f = Hoehenflaeche(_rechteck, _mm([100, 100, 100, 100, 40, 70]), [
        const Punkt(1000, 1000),
        const Punkt(3800, 2000),
      ]);
      expect(f.bei(const Punkt(1000, 1000)), const Millimeter(40));
      expect(f.bei(const Punkt(3800, 2000)), const Millimeter(70));
      final a = Hoehenflaeche(_rechteck, _mm([100, 100, 100, 100, 40]), const [
        Punkt.ursprung,
      ]);
      expect(a.bei(Punkt.ursprung), const Millimeter(40));
    });

    test('schräges Vieleck: innen und außen an allen Kanten, Rand knapp '
        'außerhalb zählt', () {
      // schiefes Viereck, keine Kante achsparallel
      const ecken = [
        Punkt(100, 200),
        Punkt(3100, 700),
        Punkt(2600, 3300),
        Punkt(300, 2800),
      ];
      Millimeter mitte(Punkt weiterer) => Hoehenflaeche(
        ecken,
        _mm([100, 100, 100, 100, 40]),
        [weiterer],
      ).bei(weiterer);
      // innen: dort gilt der Punkt
      expect(mitte(const Punkt(1500, 1500)), const Millimeter(40));
      expect(mitte(const Punkt(2900, 1200)), const Millimeter(40));
      expect(mitte(const Punkt(400, 2500)), const Millimeter(40));
      expect(mitte(const Punkt(200, 300)), const Millimeter(40));
      // 0,5 mm außerhalb der schrägen Kante A — B: auf dem Rand
      expect(mitte(const Punkt(1600.0822, 449.5068)), const Millimeter(40));
      // außen neben jeder Kante: ohne Wirkung
      for (final p in const [
        Punkt(1600, 200),
        Punkt(3100, 2000),
        Punkt(1400, 3300),
        Punkt(100, 1500),
        Punkt(3000, 300),
      ]) {
        expect(mitte(p), const Millimeter(100), reason: '$p');
      }
      // 0,5 mm außerhalb der Kante rechts im Rechteck: auf dem Rand
      expect(
        Hoehenflaeche(_rechteck, _mm([100, 100, 100, 100, 40]), const [
          Punkt(4800.5, 1500),
        ]).bei(const Punkt(4800.5, 1500)),
        const Millimeter(40),
      );
    });

    test('fast auf einer Linie (Rundungsreste): Verlauf, quer flach', () {
      // drei Punkte auf der Geraden y = x / 3 mit krummen Zahlen
      const p1 = Punkt(0.37, 0.37 / 3);
      const p2 = Punkt(1234.567, 1234.567 / 3);
      const p3 = Punkt(3001.003, 3001.003 / 3);
      final f = Hoehenflaeche(
        const [p1, p2, p3],
        _mm([100, 141, 220]),
        const [],
      );
      expect(f.bei(p2), const Millimeter(141));
      // quer zur Linie bleibt die Höhe wie auf der Linie
      final aufLinie = f.bei(const Punkt(2000, 2000 / 3)).mm;
      final quer = f.bei(
        const Punkt(2000 - 300 / 3.1623, 2000 / 3 + 900 / 3.1623),
      );
      expect((quer.mm - aufLinie).abs(), lessThanOrEqualTo(2));
    });
  });

  test('auf einer Linie, die äußeren nicht zuerst: Verlauf zwischen den '
      'beiden äußeren', () {
    final f = Hoehenflaeche(
      const [Punkt(1000, 1000), Punkt(0, 2000), Punkt(2000, 0)],
      _mm([160, 100, 200]),
      const [],
    );
    expect(f.bei(const Punkt(0, 2000)), const Millimeter(100));
    expect(f.bei(const Punkt(2000, 0)), const Millimeter(200));
    expect(f.bei(const Punkt(500, 1500)), const Millimeter(130));
  });

  group('Planungsstand: Prüfungen (Planungskern v7)', () {
    const f01 = Planungsstand.start;

    test('neuer Höhenpunkt in der Mitte, auch wenn A nicht im Ursprung '
        'liegt', () {
      final gedreht = f01.mitGrundriss(f01.grundriss.gedreht(90));
      expect(gedreht.punktA == Punkt.ursprung, isFalse);
      final neu = gedreht.mitNeuemHoehenpunkt();
      final ort = neu.ortVon(neu.hoehenpunkte.single);
      final mitte = gedreht.kontur.huellrechteck.mitte;
      expect(ort.abstand(mitte), lessThan(1));
    });

    test('Index vor der Prüfung des Inhalts', () {
      final neu = f01.mitNeuemHoehenpunkt();
      expect(
        () => neu.mitHoehenpunkt(3, (
          x: const Millimeter(0),
          y: const Millimeter(0),
          hoehe: const Millimeter(0),
        )),
        throwsRangeError,
      );
      final t = f01.mitNeuerTreppe();
      expect(
        () => t.mitTreppe(2, const Treppe(seite: 9)),
        throwsA(isA<RangeError>().having((e) => e.name, 'name', 'index')),
      );
      expect(
        () => f01.mitEckhoehe(6, const Millimeter(0)),
        throwsA(
          isA<RangeError>()
              .having((e) => e.name, 'name', 'ecke')
              .having((e) => e.invalidValue, 'invalidValue', 6)
              .having((e) => e.start, 'start', 0)
              .having((e) => e.end, 'end', 3),
        ),
      );
    });

    test('Seite außerhalb: Wert und Grenzen im Fehler; Kreis nur Seite 0; '
        'offene Freiform ohne Seiten', () {
      expect(
        () => f01.mitVerblendet(1, an: true).seitenlaenge(5),
        throwsA(
          isA<RangeError>()
              .having((e) => e.invalidValue, 'invalidValue', 5)
              .having((e) => e.start, 'start', 0)
              .having((e) => e.end, 'end', 3),
        ),
      );
      final kreis = f01.mitForm(Terrassenform.kreis).mitVerblendet(0, an: true);
      expect(
        () => kreis.mitBlendenhoehe(1, const Millimeter(100)),
        throwsRangeError,
      );
      final offen = f01.mitGrundriss(
        FreiformGrundriss(const [Punkt(0, 0), Punkt(1000, 0), Punkt(0, 1000)]),
      );
      expect(() => offen.seitenlaenge(0), throwsRangeError);
    });

    test('Meldungen der Eingabefehler', () {
      expect(
        () => f01.mitFeldbreite(const Millimeter(50)),
        throwsA(
          isA<ArgumentError>()
              .having((e) => e.name, 'name', 'feldbreite')
              .having((e) => e.message, 'message', 'muss 100 bis 1000 mm sein'),
        ),
      );
      expect(
        () => f01.mitVerblendet(1, an: true).mitBlendenteilen(1, const [
          (von: Millimeter(10), bis: Millimeter(5)),
        ]),
        throwsA(
          isA<ArgumentError>()
              .having((e) => e.name, 'name', 'teile')
              .having((e) => e.message, 'message', 'ungültiges Teilstück'),
        ),
      );
    });
  });

  test('Höhenreferenzpunkte im Anschlussergebnis: je Punkt seine geprüfte '
      'Höhe', () {
    final stand = Planungsstand.start
        .mitNeuemHoehenpunkt()
        .mitNeuemHoehenpunkt();
    final e = anschlussergebnis(stand, hoehen: _mm([86, 86, 86, 86, 50, 70]));
    expect([for (final p in e.hoehenpunkte) p.hoehe.mm], [50, 70]);
  });

  test('Blende: niedrigste Stelle auch zwischen den Abtastpunkten genau '
      'genug (alle 10 cm)', () {
    // Ablauf auf der Kante A — B (50 cm) mitten zwischen zwei Abtastpunkten:
    // alle 10 cm abgetastet 5,5 cm, nicht die 4 cm des Ablaufs selbst
    final stand = Planungsstand.start
        .mitGrundriss(
          RechteckGrundriss(const Millimeter(500), const Millimeter(500)),
        )
        .mitVerblendet(0, an: true)
        .mitGefaelle(true)
        .mitNeuemHoehenpunkt()
        .mitHoehenpunkt(0, (
          x: const Millimeter(250),
          y: const Millimeter(0),
          hoehe: const Millimeter(40),
        ));
    final s = blendenstrecken(stand, _mm([200, 200, 200, 200, 40]));
    expect(s.single.hoehe, const Millimeter(55));
  });
}
