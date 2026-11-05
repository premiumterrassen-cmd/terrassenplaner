import 'dart:convert';
import 'dart:io';

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

Artikel _artikel(
  String nummer,
  String titel,
  Artikelart art, {
  int inhalt = 1,
  Mengeneinheit einheit = Mengeneinheit.stueck,
  int? laenge,
  Zubehoergruppe? gruppe,
}) => Artikel(
  nummer: Artikelnummer(nummer),
  titel: titel,
  art: art,
  einheit: Verkaufseinheit(einheit, inhalt: inhalt),
  abmessungen: Abmessungen(
    laengen: [?(laenge == null ? null : Millimeter(laenge))],
  ),
  zubehoergruppe: gruppe,
);

final _clip50 = _artikel(
  '80-10-001-50',
  'CLIP-FIXX - VPE 50',
  Artikelart.clip,
  inhalt: 50,
);
final _clip250 = _artikel(
  '80-10-001-250',
  'CLIP-FIXX - VPE 250',
  Artikelart.clip,
  inhalt: 250,
);
final _schraube = _artikel(
  '50-50-102',
  'Terrassenschrauben 5,0 x 50 mm, 200 Stück',
  Artikelart.schraube,
  inhalt: 200,
  laenge: 50,
);
final _band = _artikel(
  '50-60-120',
  'Schutzband GUMO K 75 mm, selbstklebend, 10 Rollen à 10 m',
  Artikelart.gummiband,
  einheit: Mengeneinheit.karton,
  inhalt: 10000,
  laenge: 10000,
);
final _rolle = _artikel(
  '50-60-001',
  'Gummiband 10m-Rolle 75 mm',
  Artikelart.gummiband,
  laenge: 10000,
);
final _ohneLaenge = _artikel('50-60-002', 'Band', Artikelart.gummiband);
final _robinie25 = _artikel(
  '568-250',
  'Holzschutz-Öl ROBINIE, 2,5 Liter',
  Artikelart.pflege,
);
final _robinie075 = _artikel(
  '568-075',
  'Holzschutz-Öl ROBINIE, 0,75 Liter',
  Artikelart.pflege,
);
final _natur25 = _artikel(
  '562-250',
  'Holzschutz-Öl NATUR (farblos), 2,5 Liter',
  Artikelart.pflege,
);
final _pinsel = _artikel('562-999', 'Pinsel', Artikelart.pflege);
final _bit20 = _artikel(
  '50-80-002',
  'Bit TX20 für Clipschrauben',
  Artikelart.werkzeug,
);
final _bit25 = _artikel(
  '50-80-003',
  'Bit TX25 für Clipschrauben',
  Artikelart.werkzeug,
);
final _bit25Sonst = _artikel(
  '50-80-099',
  'Bit TX25 Halter',
  Artikelart.sonstiges,
);

Artikel _diele(String nummer, Profil profil, {int breite = 60}) => Artikel(
  nummer: Artikelnummer(nummer),
  titel: 'Diele $nummer',
  art: Artikelart.diele,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  abmessungen: Abmessungen(
    breite: Millimeter(breite),
    staerke: const Millimeter(23),
    laengen: const [Millimeter(4000), Millimeter(5000), Millimeter(6000)],
  ),
  holzart: robinie,
  serie: premiumSelect,
  profil: profil,
);

final _genutet = _diele('10-10-073-R', Profil.genutet);
final _glatt = _diele('10-10-146-R', Profil.glattkant, breite: 100);
final _ohneZubehoer = _diele('10-10-071-R', Profil.glattkant);

Artikeleintrag _eintrag(
  Artikel a, {
  List<Artikel> befestigung = const [],
  List<Artikel> zubehoer = const [],
}) => Artikeleintrag(
  artikel: a,
  verweise: {
    Beziehung.befestigung.spalte: [for (final b in befestigung) b.nummer],
    Beziehung.zubehoer.spalte: [for (final z in zubehoer) z.nummer],
  },
  angaben: const {'Abstand_UK': 400},
);

final _regelwerk = Regelwerk(
  Artikeldatei(
    quelle: 'test',
    version: '1',
    eintraege: [
      _eintrag(
        _genutet,
        befestigung: [_clip50, _clip250],
        zubehoer: [_pinsel, _robinie25, _band, _robinie075, _natur25, _rolle],
      ),
      _eintrag(
        _glatt,
        befestigung: [_schraube],
        zubehoer: [_ohneLaenge, _rolle],
      ),
      _eintrag(_ohneZubehoer, befestigung: [_schraube]),
      for (final a in [
        _clip50,
        _clip250,
        _schraube,
        _band,
        _rolle,
        _ohneLaenge,
        _robinie25,
        _robinie075,
        _natur25,
        _pinsel,
        _bit20,
        _bit25Sonst,
        _bit25,
      ])
        _eintrag(a),
    ],
  ),
);

/// Dielen der Fläche [laenge] × [breite] mm im Winkel [winkel].
List<Dielenstueck> _verlegt({
  int laenge = 4800,
  int breite = 3090,
  int dielenbreite = 60,
  double winkel = 0,
}) => verlegeDielen(
  Kontur.rechteck(laenge.toDouble(), breite.toDouble()),
  winkel: winkel,
  ausgangspunkt: Punkt.ursprung,
  dielenbreite: Millimeter(dielenbreite),
  verlegeart: Verlegeart.fugenschnitt,
  laengste: const Millimeter(6000),
);

final _uk = Artikel(
  nummer: const Artikelnummer('10-10-031'),
  titel: 'UK',
  art: Artikelart.unterkonstruktion,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  abmessungen: Abmessungen(
    breite: const Millimeter(40),
    staerke: const Millimeter(60),
  ),
  holzart: robinie,
  serie: basic,
);

Map<String, int> _mengen(Map<Artikelnummer, int> m) => {
  for (final MapEntry(:key, :value) in m.entries) key.wert: value,
};

Map<String, Object?> _fall(String id) =>
    jsonDecode(File('test/referenzkonfigurationen/$id.json').readAsStringSync())
        as Map<String, Object?>;

void main() {
  group('Länge der Übergangs-UK (M8-02)', () {
    test('F01: 13 Linien × 309 cm, Fugen überbrückt', () {
      expect(
        ukLaenge(_verlegt(), winkel: 0, ukAbstand: const Millimeter(400)),
        closeTo(13 * 3090, 1),
      );
    });

    test('senkrecht (F02): 9 Linien × 480 cm', () {
      expect(
        ukLaenge(
          _verlegt(winkel: 90),
          winkel: 90,
          ukAbstand: const Millimeter(400),
        ),
        closeTo(9 * 4800, 1),
      );
    });

    test('Fugen bis 10 mm überbrückt, größere Lücken nicht', () {
      Dielenstueck reihe(int reihe, double unten) =>
          Dielenstueck(reihe, const Millimeter(400), [
            Punkt(0, unten),
            Punkt(400, unten),
            Punkt(400, unten + 60),
            Punkt(0, unten + 60),
          ], breite: 60);
      double laenge(List<Dielenstueck> s) =>
          ukLaenge(s, winkel: 0, ukAbstand: const Millimeter(400));
      // 400 mm: 2 Linien; Lücke 6 mm wird überbrückt, 10 mm auch, 11 nicht
      expect(laenge([reihe(0, 0), reihe(1, 66)]), closeTo(2 * 126, 1e-6));
      expect(laenge([reihe(0, 0), reihe(1, 70)]), closeTo(2 * 130, 1e-6));
      expect(laenge([reihe(0, 0), reihe(1, 71)]), closeTo(2 * 120, 1e-6));
    });

    test('ohne Dielen keine UK; getrennte Flächen nicht überbrückt', () {
      expect(
        ukLaenge(const [], winkel: 0, ukAbstand: const Millimeter(400)),
        0,
      );
      final getrennt = [
        Dielenstueck(0, const Millimeter(1000), const [
          Punkt(0, 0),
          Punkt(1000, 0),
          Punkt(1000, 60),
          Punkt(0, 60),
        ], breite: 65),
        Dielenstueck(1, const Millimeter(1000), const [
          Punkt(0, 100),
          Punkt(1000, 100),
          Punkt(1000, 160),
          Punkt(0, 160),
        ], breite: 65),
        // überlappt die zweite Reihe: zählt nicht doppelt
        Dielenstueck(1, const Millimeter(1000), const [
          Punkt(0, 130),
          Punkt(1000, 130),
          Punkt(1000, 150),
          Punkt(0, 150),
        ], breite: 65),
      ];
      // 1000 mm mit 40 cm: 3 Felder, 4 Linien à 2 × 60 mm
      expect(
        ukLaenge(getrennt, winkel: 0, ukAbstand: const Millimeter(400)),
        closeTo(4 * 120, 1e-6),
      );
    });
  });

  group('Belagfläche', () {
    test('Länge mal Breite samt Fuge je Stück', () {
      expect(belagflaeche(const []), 0);
      expect(
        belagflaeche([
          Dielenstueck(0, const Millimeter(2000), const [], breite: 500),
          Dielenstueck(1, const Millimeter(1000), const [], breite: 500),
        ]),
        closeTo(1.5, 1e-9),
      );
      expect(belagflaeche(_verlegt()), closeTo(14.832, 1e-6));
    });
  });

  group('Berechnetes Zubehör (M8-02)', () {
    test(
      'F01 genutet: Clips aus der Befestigung, Band, Öl der ersten Sorte',
      () {
        final stuecke = _verlegt();
        final befestigung = befestigungsbedarf(
          _regelwerk,
          _genutet,
          Befestigungsart.clips,
          stuecke,
          winkel: 0,
        );
        final m = berechnetesZubehoer(
          _regelwerk,
          _genutet,
          befestigung,
          stuecke,
          winkel: 0,
        );
        // 637 Clips (M5-09) → 650, 40,17 m Band → 1 Karton à 100 m,
        // 14,832 m² × 0,2 l = 2,97 l → 4 × 0,75 l (wenig Überhang)
        expect(_mengen(m), {
          '80-10-001-50': 3,
          '80-10-001-250': 2,
          '50-60-120': 1,
          '568-075': 4,
        });
        expect(m.keys.first, const Artikelnummer('80-10-001-50'));
      },
    );

    test('größere Fläche: Öl auch im großen Gebinde', () {
      final stuecke = _verlegt(laenge: 8000, breite: 6000);
      final m = berechnetesZubehoer(
        _regelwerk,
        _genutet,
        Befestigungsbedarf.keiner,
        stuecke,
        winkel: 0,
      );
      // 48 m² × 0,2 = 9,6 l → 3 × 2,5 + 3 × 0,75 = 9,75 l
      expect(_mengen(m)['568-250'], 3);
      expect(_mengen(m)['568-075'], 3);
      // 21 Linien × 600 cm = 126 m → 2 Kartons
      expect(_mengen(m)['50-60-120'], 2);
    });

    test('verschraubt: ein Bit TX25, Band in Einzelrollen, ohne Öl', () {
      final stuecke = _verlegt(dielenbreite: 100);
      final befestigung = befestigungsbedarf(
        _regelwerk,
        _glatt,
        Befestigungsart.verschraubt,
        stuecke,
        winkel: 0,
      );
      final m = berechnetesZubehoer(
        _regelwerk,
        _glatt,
        befestigung,
        stuecke,
        winkel: 0,
      );
      // das Band ohne Rollenlänge zählt nicht, das nächste schon: 40,17 m
      expect(_mengen(m), {'50-50-102': 4, '50-80-003': 1, '50-60-001': 5});
    });

    test('ohne Zubehör-Verweise und ohne Dielen: nur die Befestigung', () {
      expect(
        berechnetesZubehoer(
          _regelwerk,
          _ohneZubehoer,
          Befestigungsbedarf.keiner,
          const [],
          winkel: 0,
        ),
        isEmpty,
      );
      expect(
        _mengen(
          berechnetesZubehoer(
            _regelwerk,
            _genutet,
            Befestigungsbedarf.keiner,
            const [],
            winkel: 0,
          ),
        ),
        isEmpty,
      );
    });

    test('Bit nur, wenn die Artikeldaten eines haben', () {
      final ohneBit = Regelwerk(
        Artikeldatei(
          quelle: 'test',
          version: '2',
          eintraege: [
            _eintrag(_ohneZubehoer, befestigung: [_schraube]),
            _eintrag(_schraube),
          ],
        ),
      );
      final stuecke = _verlegt();
      final befestigung = befestigungsbedarf(
        ohneBit,
        _ohneZubehoer,
        Befestigungsart.verschraubt,
        stuecke,
        winkel: 0,
      );
      expect(
        _mengen(
          berechnetesZubehoer(
            ohneBit,
            _ohneZubehoer,
            befestigung,
            stuecke,
            winkel: 0,
          ),
        ).keys,
        ['50-50-102'],
      );
    });
  });

  test('Ölsorte: Titel vor der Literangabe, ohne Komma am Ende', () {
    final ohneKomma = _artikel(
      '568-500',
      'Holzschutz-Öl ROBINIE 5 Liter',
      Artikelart.pflege,
    );
    final regelwerk = Regelwerk(
      Artikeldatei(
        quelle: 'test',
        version: '3',
        eintraege: [
          _eintrag(_genutet, zubehoer: [_robinie25, ohneKomma]),
          _eintrag(_robinie25),
          _eintrag(ohneKomma),
        ],
      ),
    );
    // 48 m² × 0,2 l = 9,6 l: 2 × 5 l = 10 l, beide Gebinde einer Sorte
    final m = berechnetesZubehoer(
      regelwerk,
      _genutet,
      Befestigungsbedarf.keiner,
      _verlegt(laenge: 8000, breite: 6000),
      winkel: 0,
    );
    expect(_mengen(m), {'568-500': 2});
  });

  group('Zeilen Tatsächlich (M8-02, R-D04)', () {
    const a = Artikelnummer('a');
    const b = Artikelnummer('b');
    const c = Artikelnummer('c');
    const d = Artikelnummer('d');

    test('Eingabe vor Berechnung, berechnete zuerst, leere fehlen', () {
      final p = zubehoerpositionen({a: 3, b: 2, d: 0}, {c: 4, b: 0, a: 3});
      expect(p, [
        const Zubehoerposition(a, berechnet: 3),
        const Zubehoerposition(b, berechnet: 2, menge: 0),
        const Zubehoerposition(c, menge: 4),
      ]);
      expect(p[0].geaendert, isFalse);
      expect(p[1].geaendert, isTrue);
      expect(p[2].geaendert, isTrue);
      expect(zubehoerpositionen({}, {d: 0}), isEmpty);
    });

    test('Gleichheit und Text', () {
      const p = Zubehoerposition(a, berechnet: 3, menge: 5);
      expect(p, const Zubehoerposition(a, berechnet: 3, menge: 5));
      expect(
        p.hashCode,
        const Zubehoerposition(a, berechnet: 3, menge: 5).hashCode,
      );
      expect(p == const Zubehoerposition(b, berechnet: 3, menge: 5), isFalse);
      expect(p == const Zubehoerposition(a, berechnet: 4, menge: 5), isFalse);
      expect(p == const Zubehoerposition(a, berechnet: 3, menge: 6), isFalse);
      expect(p == Object(), isFalse);
      expect('$p', 'a: 5 (berechnet 3, Pflicht 0)');
      expect(p.hashCode, Object.hash(a, 3, 5, 0));
      expect(
        p == const Zubehoerposition(a, berechnet: 3, menge: 5, pflicht: 1),
        isFalse,
      );
      expect(const Zubehoerposition(a).menge, 0);
    });
  });

  test('Berechnung trägt die Zeilen (Transport, mitPlanung)', () {
    final b = Berechnung(
      umriss: const [],
      flaeche: 1,
      zubehoer: const [
        Zubehoerposition(Artikelnummer('568-075'), berechnet: 4, menge: 2),
        Zubehoerposition(Artikelnummer('50-80-006'), menge: 7),
        Zubehoerposition(Artikelnummer('50-60-120'), berechnet: 1),
        Zubehoerposition(Artikelnummer('42-02'), berechnet: 6, pflicht: 6),
      ],
    );
    for (final k in [Berechnung.ausBytes(b.zuBytes()), b.mitPlanung(2)]) {
      expect(k.zubehoer, b.zubehoer);
    }
    expect(Berechnung(umriss: const [], flaeche: 1).zubehoer, isEmpty);
    expect(
      Berechnung.ausBytes(Berechnung(umriss: const [], flaeche: 1).zuBytes())
          .zubehoer,
      isEmpty,
    );
    expect(
      () => b.zubehoer.add(const Zubehoerposition(Artikelnummer('x'))),
      throwsUnsupportedError,
    );
  });

  group('Pflichtzubehör (M8-03)', () {
    Artikel teil(String n) => _artikel(n, 'Teil $n', Artikelart.rinnenzubehoer);
    final rinne = _artikel('42-01', 'Rinne', Artikelart.rinne);
    final halter = teil('42-02');
    final schraube = teil('42-03');
    final kreis = teil('42-04');
    final regelwerk = Regelwerk(
      Artikeldatei(
        quelle: 'test',
        version: '4',
        eintraege: [
          Artikeleintrag(
            artikel: rinne,
            benoetigt: {halter.nummer: 2, schraube.nummer: 1},
          ),
          Artikeleintrag(artikel: halter, benoetigt: {schraube.nummer: 3}),
          Artikeleintrag(artikel: schraube),
          // Kreis in den Daten: endet nach fünf Stufen
          Artikeleintrag(artikel: kreis, benoetigt: {kreis.nummer: 1}),
        ],
      ),
    );

    test('feste Anzahl je Artikel, auch was ein Pflichtartikel braucht', () {
      // 3 Rinnen: 6 Halter, 3 + 18 Schrauben
      expect(_mengen(pflichtzubehoer(regelwerk, {rinne.nummer: 3})), {
        '42-02': 6,
        '42-03': 21,
      });
      expect(pflichtzubehoer(regelwerk, {schraube.nummer: 5}), isEmpty);
      expect(
        pflichtzubehoer(regelwerk, {const Artikelnummer('unbekannt'): 1}),
        isEmpty,
      );
      expect(pflichtzubehoer(regelwerk, const {}), isEmpty);
      expect(_mengen(pflichtzubehoer(regelwerk, {kreis.nummer: 1})), {
        '42-04': 5,
      });
      // mehrere Quellen addieren sich
      expect(
        _mengen(
          pflichtzubehoer(regelwerk, {rinne.nummer: 1, halter.nummer: 1}),
        ),
        {'42-02': 2, '42-03': 1 + 6 + 3},
      );
    });

    test('Zeilen: Pflicht zur Berechnung, nicht abwählbar', () {
      const a = Artikelnummer('a');
      const b = Artikelnummer('b');
      const c = Artikelnummer('c');
      final p = zubehoerpositionen(
        {a: 2},
        {a: 0, b: 1, c: 9},
        pflicht: {a: 3, b: 4, c: 1},
      );
      expect(p, [
        const Zubehoerposition(a, berechnet: 5, menge: 3, pflicht: 3),
        const Zubehoerposition(b, berechnet: 4, pflicht: 4),
        const Zubehoerposition(c, berechnet: 1, menge: 9, pflicht: 1),
      ]);
      expect(p.first.geaendert, isTrue);
      expect(p[1].geaendert, isFalse);
    });
  });

  group('Abgleich mit den Referenzkonfigurationen (M1-03)', () {
    // Rollen à 10 m wie das Gummiband des alten Planers (KOPPLEX-1, im neuen
    // Planer GUMO, B-039): gleiche Länge der UK, gleiche Rollenzahl
    for (final (id, laenge, breite, winkel) in [
      ('F01', 4800, 3090, 0.0),
      ('F02', 4800, 3090, 90.0),
      ('F09', 8000, 3090, 0.0),
      ('F20', 3600, 4000, 0.0),
    ]) {
      test('$id: Gummiband-Rollen wie im alten Planer', () {
        final alt = (_fall(id)['materialliste']! as List<Object?>)
            .cast<Map<String, Object?>>()
            .where((m) => (m['bezeichnung']! as String).startsWith('KOPPLEX-1'))
            .single['anzahl'];
        final stuecke = _verlegt(
          laenge: laenge,
          breite: breite,
          winkel: winkel,
        );
        final m = berechnetesZubehoer(
          _regelwerk,
          _glatt,
          Befestigungsbedarf.keiner,
          stuecke,
          winkel: winkel,
        );
        expect(_mengen(m)['50-60-001'], alt);
      });

      test(
        '$id: Gummiband auf der UK-Verlegung (M6-10) wie im alten Planer',
        () {
          final alt = (_fall(id)['materialliste']! as List<Object?>)
              .cast<Map<String, Object?>>()
              .where(
                (m) => (m['bezeichnung']! as String).startsWith('KOPPLEX-1'),
              )
              .single['anzahl'];
          final stand = Planungsstand.start
              .mitGrundriss(
                RechteckGrundriss(Millimeter(laenge), Millimeter(breite)),
              )
              .mitVerlegerichtung(
                winkel == 0
                    ? Verlegerichtung.waagrecht
                    : Verlegerichtung.senkrecht,
              );
          final stuecke = _verlegt(
            laenge: laenge,
            breite: breite,
            winkel: winkel,
          );
          final uk = ukVerlegung(
            stand,
            _uk,
            abstand: const Millimeter(400),
            dielen: stuecke,
          );
          final m = berechnetesZubehoer(
            _regelwerk,
            _glatt,
            Befestigungsbedarf.keiner,
            stuecke,
            winkel: winkel,
            uk: uk,
          );
          expect(_mengen(m)['50-60-001'], alt);
        },
      );
    }

    test('Gummiband: UK-Verlegung statt Übergangs-UK, Feldbreite (M6-09)', () {
      final stuecke = _verlegt();
      int rollen({UkVerlegung? uk, Millimeter? feldbreite}) => _mengen(
        berechnetesZubehoer(
          _regelwerk,
          _glatt,
          Befestigungsbedarf.keiner,
          stuecke,
          winkel: 0,
          uk: uk,
          feldbreite: feldbreite,
        ),
      )['50-60-001']!;
      // F01: 13 × 309 cm = 40,17 m → 5 Rollen; mit 30 cm 17 × 309 → 6
      expect(rollen(), 5);
      expect(rollen(feldbreite: const Millimeter(300)), 6);
      // eine kurze UK-Verlegung (eine Linie à 309 cm): 1 Rolle
      final eine = UkVerlegung(
        linien: const [
          (x: 20, abschnitte: [(0.0, 3090.0)], stoesse: <double>[]),
        ],
      );
      expect(eine.laenge, 3090);
      expect(rollen(uk: eine), 1);
    });

    test('F24 verschraubt: ein Bit, F01 mit Clips: keines', () {
      bool bit(String id) => (_fall(id)['materialliste']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .any((m) => (m['bezeichnung']! as String).contains('Bit TX25'));
      expect(bit('F24'), isTrue);
      expect(bit('F01'), isFalse);
    });
  });
}
