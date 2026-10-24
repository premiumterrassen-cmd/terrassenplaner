import 'dart:convert';

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

import 'argument_fehler.dart';

Artikel _artikel(
  String nummer,
  Artikelart art, {
  Serie? serie,
  Profil? profil,
  int? breite,
  int? staerke,
}) => Artikel(
  nummer: Artikelnummer(nummer),
  titel: 'Artikel $nummer',
  art: art,
  einheit: Verkaufseinheit(Mengeneinheit.stueck),
  abmessungen: Abmessungen(
    breite: breite == null ? null : Millimeter(breite),
    staerke: staerke == null ? null : Millimeter(staerke),
  ),
  holzart: serie == null ? null : robinie,
  serie: serie,
  profil: profil,
);

Artikeleintrag _diele(
  String nummer, {
  required Profil profil,
  int breite = 60,
  Serie serie = premiumSelect,
  List<String> befestigung = const [],
}) => Artikeleintrag(
  artikel: _artikel(
    nummer,
    Artikelart.diele,
    serie: serie,
    profil: profil,
    breite: breite,
    staerke: 23,
  ),
  verweise: {
    'moeglicheBefestigungDeck': [for (final b in befestigung) Artikelnummer(b)],
  },
);

final _clip = Artikeleintrag(artikel: _artikel('80-10-001', Artikelart.clip));
final _duo = Artikeleintrag(artikel: _artikel('80-10-002', Artikelart.clip));
final _schraube = Artikeleintrag(
  artikel: _artikel('80-20-001', Artikelart.schraube),
);
final _fussPrivat = Artikeleintrag(
  artikel: _artikel('70-10-001', Artikelart.stellfuss),
);
final _fussGewerblich = Artikeleintrag(
  artikel: _artikel('70-10-002', Artikelart.stellfuss),
);
final _uk = Artikeleintrag(
  artikel: _artikel(
    '20-10-001',
    Artikelart.unterkonstruktion,
    serie: premiumSelect,
    breite: 70,
    staerke: 45,
  ),
  verweise: {
    'moeglicherStellfussPrivat': const [Artikelnummer('70-10-001')],
    'moeglicherStellfussGewerblich': const [
      Artikelnummer('70-10-002'),
      Artikelnummer('70-10-001'),
    ],
  },
  angaben: const {
    'Abstand_Stelzfuesse': 500,
    'Abstand_UK': 400,
    'UK_Abstand_vom_Rand': 50,
    'MinHoehe': 30,
    'MaxHoehe': 200,
    'Reichweite': 1,
  },
  benoetigt: const {
    Artikelnummer('80-20-001'): 4,
    Artikelnummer('80-10-001'): 2,
  },
);

Regelwerk _regelwerk(List<Artikeleintrag> zusaetzlich) => Regelwerk(
  Artikeldatei(
    quelle: 'test.xlsx',
    version: '1',
    eintraege: [
      _clip,
      _duo,
      _schraube,
      _fussPrivat,
      _fussGewerblich,
      _uk,
      ...zusaetzlich,
    ],
  ),
);

void main() {
  final genutet = _diele(
    '10-10-073-R',
    profil: Profil.genutet,
    befestigung: ['80-10-002', '80-10-001'],
  );
  final regelwerk = _regelwerk([genutet]);

  test('Beziehungen nennen ihre Spalte der Upload-Datei', () {
    expect(Beziehung.values.map((b) => b.spalte), [
      'moeglicheBefestigungDeck',
      'moeglichesZubehoer',
      'moeglicherStellfussPrivat',
      'moeglicherStellfussGewerblich',
      'moeglicheUnterlegpads',
      'moeglicheLaengsverbinder',
      'moeglicheQuerverbinder',
      'moeglicheVerblendung',
      'moeglicheDrainage',
      'moeglicheStartEndClip',
      'moeglicheEckverbinder',
      'moeglicheVariableverbinder',
    ]);
  });

  group('moeglich', () {
    test('liefert die Verweise in Datenreihenfolge', () {
      expect(
        regelwerk.moeglich(genutet.artikel.nummer, Beziehung.befestigung),
        [_duo.artikel, _clip.artikel],
      );
    });

    test('ist leer, wenn die Daten nichts angeben', () {
      expect(
        regelwerk.moeglich(genutet.artikel.nummer, Beziehung.drainage),
        isEmpty,
      );
    });

    test('unbekannter Artikel ist ein Fehler', () {
      expect(
        () => regelwerk.moeglich(
          const Artikelnummer('99-99-999'),
          Beziehung.befestigung,
        ),
        wirftArgumentFehler('nummer', '99-99-999', 'Artikel unbekannt'),
      );
    });

    test('Verweis auf unbekannten Artikel ist ein Fehler', () {
      final kaputt = _diele(
        '10-10-074-R',
        profil: Profil.genutet,
        befestigung: ['80-99-999'],
      );
      expect(
        () =>
            _regelwerk([kaputt])
                .moeglich(kaputt.artikel.nummer, Beziehung.befestigung),
        wirftArgumentFehler('nummer', '80-99-999', 'Artikel unbekannt'),
      );
    });
  });

  test('Stellfüße je Nutzung', () {
    final uk = _uk.artikel.nummer;
    expect(regelwerk.stellfuesse(uk, gewerblich: false), [_fussPrivat.artikel]);
    expect(regelwerk.stellfuesse(uk, gewerblich: true), [
      _fussGewerblich.artikel,
      _fussPrivat.artikel,
    ]);
  });

  test('Pflichtzubehör mit Anzahl', () {
    expect(regelwerk.pflichtzubehoer(_uk.artikel.nummer), {
      _schraube.artikel: 4,
      _clip.artikel: 2,
    });
    expect(regelwerk.pflichtzubehoer(_clip.artikel.nummer), isEmpty);
  });

  group('abstaende', () {
    test('liest alle Angaben', () {
      final a = regelwerk.abstaende(_uk.artikel.nummer);
      expect(
        [
          a.stelzfuesse,
          a.uk,
          a.ukVomRand,
          a.minHoehe,
          a.maxHoehe,
          a.reichweite,
        ],
        [
          const Millimeter(500),
          const Millimeter(400),
          const Millimeter(50),
          const Millimeter(30),
          const Millimeter(200),
          true,
        ],
      );
    });

    test('fehlende Angaben bleiben leer', () {
      final a = regelwerk.abstaende(_clip.artikel.nummer);
      expect(
        [
          a.stelzfuesse,
          a.uk,
          a.ukVomRand,
          a.minHoehe,
          a.maxHoehe,
          a.reichweite,
        ],
        [null, null, null, null, null, false],
      );
    });

    test('Reichweite nur bei 1', () {
      final ohne = Artikeleintrag(
        artikel: _artikel('70-10-009', Artikelart.stellfuss),
        angaben: const {'Reichweite': 0},
      );
      expect(
        _regelwerk([ohne]).abstaende(ohne.artikel.nummer).reichweite,
        isFalse,
      );
    });
  });

  test('Artikel eines Bereichs in Datenreihenfolge', () {
    final zweite = _diele('10-10-080-R', profil: Profil.glattkant);
    final werk = _regelwerk([genutet, zweite]);
    expect(werk.imBereich(Bereich.belag), [genutet.artikel, zweite.artikel]);
    expect(werk.imBereich(Bereich.befestigung), [
      _clip.artikel,
      _duo.artikel,
      _schraube.artikel,
    ]);
    expect(werk.imBereich(Bereich.anschluss), isEmpty);
  });

  group('befestigungWiderspruch (B-094, B-090)', () {
    test('genutet mit Clips passt', () {
      expect(regelwerk.befestigungWiderspruch(genutet.artikel.nummer), isNull);
    });

    test('genutet mit Schraube widerspricht', () {
      final diele = _diele(
        '10-10-075-R',
        profil: Profil.genutet,
        befestigung: ['80-10-001', '80-20-001'],
      );
      expect(
        _regelwerk([diele]).befestigungWiderspruch(diele.artikel.nummer),
        'clipFixx verlangt clip, verweist aber auf 80-20-001',
      );
    });

    test('genutet ab DUO-Breite nennt duoClipFixx', () {
      final diele = _diele(
        '10-10-076-R',
        profil: Profil.genutet,
        breite: 120,
        befestigung: ['80-20-001'],
      );
      expect(
        _regelwerk([diele]).befestigungWiderspruch(diele.artikel.nummer),
        'duoClipFixx verlangt clip, verweist aber auf 80-20-001',
      );
    });

    test('glattkant mit Schrauben passt, mit Clips nicht', () {
      final gut = _diele(
        '10-10-077-R',
        profil: Profil.glattkant,
        befestigung: ['80-20-001'],
      );
      final schlecht = _diele(
        '10-10-078-R',
        profil: Profil.glattkant,
        befestigung: ['80-10-001', '80-20-001', '80-10-002'],
      );
      final werk = _regelwerk([gut, schlecht]);
      expect(werk.befestigungWiderspruch(gut.artikel.nummer), isNull);
      expect(
        werk.befestigungWiderspruch(schlecht.artikel.nummer),
        'verschraubungVonOben verlangt schraube, verweist aber auf '
        '80-10-001, 80-10-002',
      );
    });

    test('ohne Holz, Profil oder Breite keine Prüfung', () {
      final ohneBreite = Artikeleintrag(
        artikel: _artikel(
          '10-10-079-R',
          Artikelart.diele,
          serie: premiumSelect,
          profil: Profil.genutet,
        ),
        verweise: {
          'moeglicheBefestigungDeck': const [Artikelnummer('80-20-001')],
        },
      );
      final werk = _regelwerk([ohneBreite]);
      expect(werk.befestigungWiderspruch(ohneBreite.artikel.nummer), isNull);
      expect(werk.befestigungWiderspruch(_uk.artikel.nummer), isNull);
      expect(werk.befestigungWiderspruch(_clip.artikel.nummer), isNull);
    });
  });

  group('regeln (M2-06)', () {
    test('fasst Auswahl, Pflichtzubehör und Abstände zusammen', () {
      final r = regelwerk.regeln(_uk.artikel.nummer);
      expect(r.version, '1');
      expect(r.moeglich, {
        Beziehung.stellfussPrivat: [_fussPrivat.artikel],
        Beziehung.stellfussGewerblich: [
          _fussGewerblich.artikel,
          _fussPrivat.artikel,
        ],
      });
      expect(r.pflichtzubehoer, {_schraube.artikel: 4, _clip.artikel: 2});
      expect(r.abstaende.uk, const Millimeter(400));
    });

    test('Rundreise über JSON erhält alles', () {
      final r = _regelwerk([genutet]).regeln(genutet.artikel.nummer);
      final json = jsonDecode(jsonEncode(r.alsJson())) as Map<String, Object?>;
      final zurueck = Artikelregeln.ausJson(json, {robinie.id: robinie});
      expect(zurueck.alsJson(), r.alsJson());
      expect(zurueck.version, r.version);
      expect(zurueck.moeglich[Beziehung.befestigung]!.map((a) => a.titel), [
        _duo.artikel.titel,
        _clip.artikel.titel,
      ]);

      final uk = regelwerk.regeln(_uk.artikel.nummer);
      final ukZurueck = Artikelregeln.ausJson(
        jsonDecode(jsonEncode(uk.alsJson())) as Map<String, Object?>,
        {robinie.id: robinie},
      );
      expect(ukZurueck.pflichtzubehoer.values, [4, 2]);
      final a = ukZurueck.abstaende;
      expect(
        [
          a.stelzfuesse,
          a.uk,
          a.ukVomRand,
          a.minHoehe,
          a.maxHoehe,
          a.reichweite,
        ],
        [
          const Millimeter(500),
          const Millimeter(400),
          const Millimeter(50),
          const Millimeter(30),
          const Millimeter(200),
          true,
        ],
      );
      expect(uk.abstaende.alsJson(), {
        'stelzfuesse_mm': 500,
        'uk_mm': 400,
        'uk_vom_rand_mm': 50,
        'min_hoehe_mm': 30,
        'max_hoehe_mm': 200,
        'reichweite': true,
      });
      final leer = Abstaende.ausJson(const Abstaende().alsJson());
      expect([leer.uk, leer.reichweite], [null, false]);
    });

    test('Ergebnis ist unveränderlich', () {
      final r = regelwerk.regeln(_uk.artikel.nummer);
      expect(r.moeglich.clear, throwsUnsupportedError);
      expect(r.pflichtzubehoer.clear, throwsUnsupportedError);
    });
  });

  test('finde liefert passende Artikel in Datenreihenfolge', () {
    final glatt = _diele('10-10-080-R', profil: Profil.glattkant);
    final werk = _regelwerk([genutet, glatt]);
    expect(werk.finde(const Artikelfilter(profil: Profil.glattkant)), [
      glatt.artikel,
    ]);
    expect(werk.finde(const Artikelfilter()).length, 8);
  });
}
