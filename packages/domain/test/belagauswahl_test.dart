import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

Artikel _diele(
  String nummer, {
  String titel = 'Terrassendiele Robinie',
  Artikelart art = Artikelart.diele,
  Serie serie = premiumSelect,
  Profil? profil = Profil.genutet,
  Oberseite? oberseite = Oberseite.glatt,
  Verkaufseinheit? einheit,
  int? preis = 1250,
  int? breite = 60,
  int staerke = 22,
  List<int> laengen = const [4000],
}) => Artikel(
  nummer: Artikelnummer(nummer),
  titel: titel,
  art: art,
  einheit: einheit ?? Verkaufseinheit(Mengeneinheit.laufmeter),
  abmessungen: Abmessungen(
    breite: breite == null ? null : Millimeter(breite),
    staerke: Millimeter(staerke),
    laengen: [for (final l in laengen) Millimeter(l)],
  ),
  preisBrutto: preis == null ? null : Cent(preis),
  holzart: robinie,
  serie: serie,
  profil: profil,
  oberseite: oberseite,
);

Artikel _fliese({int preis = 2000, List<int> laengen = const [606]}) => Artikel(
  nummer: const Artikelnummer('70-10-001'),
  titel: 'Terrassenfliese Robinie',
  art: Artikelart.holzfliese,
  einheit: Verkaufseinheit(Mengeneinheit.stueck),
  abmessungen: Abmessungen(
    breite: const Millimeter(606),
    staerke: const Millimeter(22),
    laengen: [for (final l in laengen) Millimeter(l)],
  ),
  preisBrutto: Cent(preis),
);

final _genutet = Belagangebot.aus(_diele('10-10-060-R'));
final _glattkant = Belagangebot.aus(
  _diele(
    '10-20-100',
    titel: 'Diele glattkant',
    serie: basic,
    profil: Profil.glattkant,
    oberseite: Oberseite.bombiert,
    breite: 100,
    staerke: 26,
    laengen: [3000, 5000],
  ),
);
final _fliesenangebot = Belagangebot.aus(_fliese());

void main() {
  group('Kategorie', () {
    test('genutet, glattkant, ohne Profil, Holzfliese', () {
      expect(_genutet.kategorie, Belagkategorie.unsichtbar);
      expect(_glattkant.kategorie, Belagkategorie.sichtbar);
      expect(
        Belagkategorie.von(_diele('1', profil: null)),
        Belagkategorie.sichtbar,
      );
      expect(_fliesenangebot.kategorie, Belagkategorie.holzfliese);
    });
  });

  group('Preise je lfm und je m² (Deckbreite = Breite + 5 mm Fuge)', () {
    test('Verkauf je lfm', () {
      expect(_genutet.preisJeLfm, const Cent(1250));
      // 12,50 € ÷ 0,065 m
      expect(_genutet.preisJeM2, const Cent(19231));
      final zwei = Belagangebot.aus(
        _diele(
          '1',
          einheit: Verkaufseinheit(Mengeneinheit.laufmeter, inhalt: 2),
          preis: 2500,
        ),
      );
      expect(zwei.preisJeLfm, const Cent(1250));
    });

    test('Verkauf je m² (Paket 1,5 m²)', () {
      final b = Belagangebot.aus(
        _diele(
          '1',
          art: Artikelart.systemdiele,
          serie: massiv,
          einheit: Verkaufseinheit(Mengeneinheit.quadratmeter, inhalt: 1.5),
          preis: 13500,
        ),
      );
      expect(b.preisJeLfm, const Cent(585));
      expect(b.preisJeM2, const Cent(9000));
    });

    test('Verkauf je Stück mit einer Länge', () {
      final b = Belagangebot.aus(
        _diele(
          '1',
          einheit: Verkaufseinheit(Mengeneinheit.stueck),
          preis: 4000,
        ),
      );
      expect(b.preisJeLfm, const Cent(1000));
      expect(b.preisJeM2, const Cent(15385));
    });

    test('ohne eindeutige Länge, Preis oder Breite keine Preise', () {
      for (final a in [
        _diele(
          '1',
          einheit: Verkaufseinheit(Mengeneinheit.stueck),
          laengen: [3000, 4000],
        ),
        _diele('1', einheit: Verkaufseinheit(Mengeneinheit.set), laengen: []),
        _diele('1', preis: null),
        _diele('1', breite: null),
      ]) {
        final b = Belagangebot.aus(a);
        expect([b.preisJeLfm, b.preisJeM2], [null, null], reason: '$a');
      }
    });

    test('Holzfliese nur je m²', () {
      // 20,00 € ÷ (0,606 m × 0,606 m)
      expect(_fliesenangebot.preisJeM2, const Cent(5446));
      expect(_fliesenangebot.preisJeLfm, isNull);
      expect(Belagangebot.aus(_fliese(laengen: [606, 1212])).preisJeM2, isNull);
    });
  });

  group('Filter', () {
    final alle = [_genutet, _glattkant, _fliesenangebot];
    List<Belagangebot> mit(Belagfilter f) => alle.where(f.passt).toList();

    test('leerer Filter passt auf alles', () {
      expect(mit(const Belagfilter()), alle);
    });

    test('je Merkmal', () {
      expect(mit(const Belagfilter(kategorie: Belagkategorie.sichtbar)), [
        _glattkant,
      ]);
      expect(mit(const Belagfilter(serien: {basic})), [_glattkant]);
      expect(mit(const Belagfilter(oberseiten: {Oberseite.glatt})), [_genutet]);
      expect(mit(const Belagfilter(breiten: {Millimeter(100)})), [_glattkant]);
      expect(mit(const Belagfilter(staerken: {Millimeter(22)})), [
        _genutet,
        _fliesenangebot,
      ]);
      expect(mit(const Belagfilter(laengen: {Millimeter(5000)})), [_glattkant]);
    });

    test('Mehrfachauswahl', () {
      expect(mit(const Belagfilter(serien: {basic, premiumSelect})), [
        _genutet,
        _glattkant,
      ]);
    });

    test('Suche in Titel und Artikelnummer, ohne Groß/klein', () {
      expect(mit(const Belagfilter(suche: ' GLATTKANT ')), [_glattkant]);
      expect(mit(const Belagfilter(suche: '10-10')), [_genutet]);
      expect(mit(const Belagfilter(suche: '-r')), [_genutet]);
      expect(mit(const Belagfilter(suche: 'fliese')), [_fliesenangebot]);
    });

    test('Kopie ändert nur die genannten Felder', () {
      const f = Belagfilter(
        kategorie: Belagkategorie.sichtbar,
        serien: {basic},
        oberseiten: {Oberseite.bombiert},
        breiten: {Millimeter(100)},
        staerken: {Millimeter(26)},
        laengen: {Millimeter(3000)},
        suche: 'x',
      );
      final gleich = f.kopie();
      expect(
        [
          gleich.kategorie,
          gleich.serien,
          gleich.oberseiten,
          gleich.breiten,
          gleich.staerken,
          gleich.laengen,
          gleich.suche,
        ],
        [
          Belagkategorie.sichtbar,
          {basic},
          {Oberseite.bombiert},
          {const Millimeter(100)},
          {const Millimeter(26)},
          {const Millimeter(3000)},
          'x',
        ],
      );
      final anders = f.kopie(
        kategorie: Belagkategorie.holzfliese,
        serien: {},
        oberseiten: {},
        breiten: {},
        staerken: {},
        laengen: {},
        suche: '',
      );
      expect(anders.kategorie, Belagkategorie.holzfliese);
      expect([
        anders.serien,
        anders.oberseiten,
        anders.breiten,
        anders.staerken,
        anders.laengen,
      ], everyElement(isEmpty));
      expect(anders.suche, '');
      expect(f.kopie(ohneKategorie: true).kategorie, isNull);
    });
  });

  group('Belagauswahl', () {
    final auswahl = Belagauswahl('v1', [_glattkant, _genutet, _fliesenangebot]);

    test('Vorgabe ist der erste Belag der Artikeldaten', () {
      expect(auswahl.vorgabe, _glattkant);
      expect(Belagauswahl('v0', const []).vorgabe, isNull);
      expect(Belagauswahl('v0', const []).gewaehlt(null), isNull);
    });

    test('gewählter Belag, sonst die Vorgabe', () {
      expect(auswahl.gewaehlt(const Artikelnummer('10-10-060-R')), _genutet);
      expect(auswahl.gewaehlt(null), _glattkant);
      expect(auswahl.gewaehlt(const Artikelnummer('weg')), _glattkant);
    });

    test('unveränderlich', () {
      expect(() => auswahl.belaege.add(_genutet), throwsUnsupportedError);
    });

    test('gefiltert in Datenreihenfolge', () {
      expect(auswahl.gefiltert(const Belagfilter(staerken: {Millimeter(22)})), [
        _genutet,
        _fliesenangebot,
      ]);
    });

    test('Werte für die Filter, sortiert und ohne Doppelte', () {
      expect(auswahl.kategorien, Belagkategorie.values);
      expect(Belagauswahl('v', [_glattkant]).kategorien, [
        Belagkategorie.sichtbar,
      ]);
      expect(auswahl.serien, [basic, premiumSelect]);
      expect(auswahl.oberseiten, [Oberseite.glatt, Oberseite.bombiert]);
      expect(Belagauswahl('v', [_glattkant, _genutet]).oberseiten, [
        Oberseite.glatt,
        Oberseite.bombiert,
      ]);
      expect(auswahl.breiten, const [
        Millimeter(60),
        Millimeter(100),
        Millimeter(606),
      ]);
      expect(auswahl.staerken, const [Millimeter(22), Millimeter(26)]);
      expect(auswahl.laengen, const [
        Millimeter(606),
        Millimeter(3000),
        Millimeter(4000),
        Millimeter(5000),
      ]);
    });

    test('JSON hin und zurück', () {
      final zurueck = Belagauswahl.ausJson(auswahl.alsJson(), {
        robinie.id: robinie,
      });
      expect(zurueck.version, 'v1');
      expect(zurueck.belaege.map((b) => b.artikel), [
        _glattkant.artikel,
        _genutet.artikel,
        _fliesenangebot.artikel,
      ]);
      expect(zurueck.belaege.map((b) => (b.preisJeLfm, b.preisJeM2)), [
        (_glattkant.preisJeLfm, _glattkant.preisJeM2),
        (const Cent(1250), const Cent(19231)),
        (null, const Cent(5446)),
      ]);
      expect(zurueck.belaege[1].artikel.serie, premiumSelect);
    });
  });
}
