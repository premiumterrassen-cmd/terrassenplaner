import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

Artikeleintrag _eintrag({
  String nummer = 'A',
  String titel = 'Artikel',
  Artikelart art = Artikelart.sonstiges,
  Millimeter? breite,
  Millimeter? staerke,
  List<Millimeter> laengen = const [],
  Cent? preis = const Cent(100),
  List<String> bilder = const ['bild.webp'],
  Serie? serie,
  Profil? profil,
  Map<String, List<Artikelnummer>> verweise = const {},
  Map<String, int> angaben = const {},
  Map<Artikelnummer, int> benoetigt = const {},
}) => Artikeleintrag(
  artikel: Artikel(
    nummer: Artikelnummer(nummer),
    titel: titel,
    art: art,
    einheit: Verkaufseinheit(Mengeneinheit.stueck),
    abmessungen: Abmessungen(
      breite: breite,
      staerke: staerke,
      laengen: laengen,
    ),
    preisBrutto: preis,
    holzart: serie == null ? null : robinie,
    serie: serie,
    profil: profil,
    bilder: bilder,
  ),
  verweise: verweise,
  angaben: angaben,
  benoetigt: benoetigt,
);

List<Befund> _pruefe(List<Artikeleintrag> eintraege) => pruefeArtikel([
  for (final (i, e) in eintraege.indexed) (zeile: i + 2, eintrag: e),
]);

List<String> _texte(List<Artikeleintrag> eintraege) => [
  for (final b in _pruefe(eintraege))
    '${b.kritisch ? 'F' : 'H'} ${b.zeile} ${b.feld}: ${b.text}',
];

Artikeleintrag _diele({
  String nummer = 'D',
  int breite = 60,
  int staerke = 23,
  int laenge = 6000,
  Serie serie = premiumSelect,
  Profil profil = Profil.genutet,
}) => _eintrag(
  nummer: nummer,
  art: Artikelart.diele,
  breite: Millimeter(breite),
  staerke: Millimeter(staerke),
  laengen: [Millimeter(laenge)],
  serie: serie,
  profil: profil,
);

Artikeleintrag _uk(int a, int b, {Serie serie = ecoSelect}) => _eintrag(
  nummer: 'UK',
  art: Artikelart.unterkonstruktion,
  breite: Millimeter(a),
  staerke: Millimeter(b),
  laengen: const [Millimeter(4000)],
  serie: serie,
);

void main() {
  test('saubere Daten ohne Befund', () {
    expect(_pruefe([_diele(), _uk(40, 60), _eintrag()]), isEmpty);
  });

  test('doppelte Artikelnummer nennt die erste Zeile', () {
    expect(_texte([_eintrag(), _eintrag(), _eintrag()]), [
      'F 3 Artikelnummer: doppelt (wie Zeile 2): A',
      'F 4 Artikelnummer: doppelt (wie Zeile 2): A',
    ]);
  });

  test('Verweise auf nicht vorhandene Artikel sind kritisch', () {
    expect(
      _texte([
        _eintrag(
          verweise: {
            'moeglicheBefestigungDeck': const [
              Artikelnummer('A'),
              Artikelnummer('fehlt-1'),
            ],
          },
          benoetigt: const {Artikelnummer('fehlt-2'): 1, Artikelnummer('A'): 2},
        ),
      ]),
      [
        'F 2 moeglicheBefestigungDeck: Artikel fehlt-1 nicht vorhanden',
        'F 2 benoetigtesZubehoer: Artikel fehlt-2 nicht vorhanden',
      ],
    );
  });

  test('unplausibel große Maße', () {
    expect(
      _texte([
        _eintrag(
          breite: const Millimeter(12001),
          staerke: const Millimeter(13000),
          laengen: const [Millimeter(12000), Millimeter(14000)],
        ),
      ]),
      [
        'F 2 Breite_cm: unplausibel groß: 12001 mm',
        'F 2 Staerke_cm: unplausibel groß: 13000 mm',
        'F 2 Laenge_cm: unplausibel groß: 14000 mm',
      ],
    );
    expect(groesstesMass, const Millimeter(12000));
  });

  test('Schraubenlänge muss zum Titel passen (Hinweis)', () {
    Artikeleintrag schraube(String titel, int? laenge) => _eintrag(
      titel: titel,
      art: Artikelart.schraube,
      laengen: [?(laenge == null ? null : Millimeter(laenge))],
    );
    expect(_texte([schraube('Speedfix 5,5x60mm A4', 45)]), [
      'H 2 Laenge_cm: Länge 45 mm passt nicht zum Titel (5,5x60mm)',
    ]);
    expect(_pruefe([schraube('Bohrschraube 4.8 x 38 mm', 38)]), isEmpty);
    expect(_pruefe([schraube('Bohrschraube ohne Maß', 45)]), isEmpty);
    expect(_pruefe([schraube('Speedfix 5,5x60mm', null)]), isEmpty);
    expect(
      _pruefe([
        _eintrag(
          titel: 'Clip 5 x 60 mm',
          art: Artikelart.clip,
          laengen: const [Millimeter(45)],
        ),
      ]),
      isEmpty,
      reason: 'nur Schrauben',
    );
  });

  test('Dielenformat und Lieferlänge aus der Holzart (B-030, B-035)', () {
    expect(_texte([_diele(staerke: 22)]), [
      'F 2 Breite_cm: PREMIUM SELECT genutet 60 x 22 mm nicht im Sortiment (B-030)',
    ]);
    expect(
      _texte([_diele(breite: 120, profil: Profil.genutet, serie: ecoSelect)]),
      [
        'F 2 Breite_cm: ECO SELECT genutet 120 x 23 mm nicht im Sortiment (B-030)',
      ],
    );
    expect(_texte([_diele(laenge: 5500)]), [
      'F 2 Laenge_cm: 5500 mm ist keine Lieferlänge von PREMIUM SELECT (B-035)',
    ]);
    final ohneMasse = _eintrag(
      art: Artikelart.diele,
      serie: basic,
      profil: Profil.glattkant,
      laengen: const [Millimeter(4000)],
    );
    expect(_texte([ohneMasse]), [
      'F 2 Breite_cm: BASIC glattkant null x null mm nicht im Sortiment (B-030)',
    ]);
  });

  test('UK-Format (B-034, B-212)', () {
    expect(_pruefe([_uk(60, 40)]), isEmpty);
    expect(_texte([_uk(60, 80)]), [
      'H 2 Breite_cm: UK 60 x 80 mm nur ungetrocknet (B-212)',
    ]);
    expect(_texte([_uk(60, 90)]), [
      'F 2 Breite_cm: UK 60 x 90 mm nicht im Sortiment (B-034)',
    ]);
    final ohneMasse = _eintrag(art: Artikelart.unterkonstruktion, serie: basic);
    expect(_pruefe([ohneMasse]), isEmpty, reason: 'ohne Maße keine UK-Prüfung');
  });

  test('Höhen und UK-Abstand', () {
    expect(
      _texte([
        _eintrag(angaben: const {'MinHoehe': 60, 'MaxHoehe': 45}),
      ]),
      ['F 2 MinHoehe: größer als MaxHoehe (60 > 45)'],
    );
    expect(
      _pruefe([
        _eintrag(angaben: const {'MinHoehe': 45, 'MaxHoehe': 45}),
      ]),
      isEmpty,
    );
    expect(
      _pruefe([
        _eintrag(angaben: const {'MinHoehe': 45}),
      ]),
      isEmpty,
    );
    expect(
      _texte([
        _uk(40, 60).withAngaben(const {'Abstand_UK': 450}),
      ]),
      ['H 2 Abstand_UK: 450 mm über dem höchsten UK-Achsabstand 400 mm (R-C01)'],
    );
    expect(
      _pruefe([
        _uk(40, 60).withAngaben(const {'Abstand_UK': 400}),
      ]),
      isEmpty,
    );
    expect(
      _pruefe([
        _eintrag(angaben: const {'Abstand_UK': 600}),
      ]),
      isEmpty,
      reason: 'ohne Holzart kein Höchstwert',
    );
  });

  test('Preis und Abbildung fehlen (Hinweise)', () {
    expect(_texte([_eintrag(preis: null, bilder: const [])]), [
      'H 2 Preis_pro_Einheit: kein Preis – Anzeige ohne Preis (B-055)',
      'H 2 Abbildung_1: keine Abbildung – Platzhalter (M2-07)',
    ]);
    expect(_texte([_eintrag(preis: const Cent(0))]), [
      'H 2 Preis_pro_Einheit: kein Preis – Anzeige ohne Preis (B-055)',
    ]);
  });

  test('Befunde sind nach Zeile sortiert', () {
    final befunde = _pruefe([
      _eintrag(nummer: 'X', preis: null),
      _eintrag(nummer: 'Y', angaben: const {'MinHoehe': 2, 'MaxHoehe': 1}),
    ]);
    expect(befunde.map((b) => b.zeile), [2, 3]);
  });
}

extension on Artikeleintrag {
  Artikeleintrag withAngaben(Map<String, int> angaben) => Artikeleintrag(
    artikel: artikel,
    verweise: verweise,
    angaben: angaben,
    benoetigt: benoetigt,
  );
}
