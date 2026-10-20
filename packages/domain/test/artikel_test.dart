import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

Artikel _diele({
  String nummer = '10-10-073-R',
  String titel = 'Terrassendiele Robinie PREMIUM SELECT 60 x 23 mm',
  Serie? serie = Serie.premiumSelect,
  Artikelart art = Artikelart.diele,
  Iterable<String> bilder = const ['a.webp'],
}) => Artikel(
  nummer: Artikelnummer.pruefe(nummer),
  titel: titel,
  art: art,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  abmessungen: Abmessungen(
    breite: const Millimeter(60),
    staerke: const Millimeter(23),
    laengen: const [Millimeter(6000), Millimeter(4000), Millimeter(5000)],
  ),
  preisBrutto: const Cent(449),
  gewicht: const Gramm(1035),
  serie: serie,
  profil: Profil.genutet,
  oberseite: Oberseite.bombiert,
  bilder: bilder,
);

void main() {
  group('Artikelnummer', () {
    test('wird getrimmt und darf nicht leer sein', () {
      expect(Artikelnummer.pruefe(' 10-10-073 ').wert, '10-10-073');
      expect(() => Artikelnummer.pruefe('  '), throwsArgumentError);
    });
  });

  group('Artikelart', () {
    test('Bereiche', () {
      final bereiche = {for (final art in Artikelart.values) art: art.bereich};
      expect(bereiche, {
        Artikelart.diele: Bereich.belag,
        Artikelart.systemdiele: Bereich.belag,
        Artikelart.holzfliese: Bereich.belag,
        Artikelart.unterkonstruktion: Bereich.unterkonstruktion,
        Artikelart.aluUnterkonstruktion: Bereich.unterkonstruktion,
        Artikelart.clip: Bereich.befestigung,
        Artikelart.schraube: Bereich.befestigung,
        Artikelart.stellfuss: Bereich.auflager,
        Artikelart.pad: Bereich.auflager,
        Artikelart.padUnterStellfuss: Bereich.auflager,
        Artikelart.bodenanker: Bereich.auflager,
        Artikelart.laengsverbinder: Bereich.unterkonstruktion,
        Artikelart.querverbinder: Bereich.unterkonstruktion,
        Artikelart.eckverbinder: Bereich.unterkonstruktion,
        Artikelart.variablerVerbinder: Bereich.unterkonstruktion,
        Artikelart.blendenhalter: Bereich.anschluss,
        Artikelart.verblendung: Bereich.anschluss,
        Artikelart.rinne: Bereich.anschluss,
        Artikelart.rinnenzubehoer: Bereich.anschluss,
        Artikelart.gummiband: Bereich.zubehoer,
        Artikelart.pflege: Bereich.zubehoer,
        Artikelart.werkzeug: Bereich.zubehoer,
        Artikelart.dienstleistung: Bereich.zubehoer,
        Artikelart.sonstiges: Bereich.zubehoer,
      });
    });
    test('Holzartikel: Dielen, Systemdielen, Holz-UK', () {
      expect(Artikelart.values.where((a) => a.istHolz), [
        Artikelart.diele,
        Artikelart.systemdiele,
        Artikelart.unterkonstruktion,
      ]);
    });
  });

  group('Abmessungen', () {
    test('Längen aufsteigend ohne Doppelte, längste Länge', () {
      final a = Abmessungen(
        laengen: const [Millimeter(5000), Millimeter(4000), Millimeter(5000)],
      );
      expect(a.laengen, [const Millimeter(4000), const Millimeter(5000)]);
      expect(a.laengste, const Millimeter(5000));
      expect(() => a.laengen.add(const Millimeter(1)), throwsUnsupportedError);
      expect(Abmessungen().laengste, isNull);
      expect([Abmessungen().breite, Abmessungen().staerke], [null, null]);
    });
    test('Maße müssen größer als 0 sein', () {
      expect(
        () => Abmessungen(breite: const Millimeter(0)),
        throwsArgumentError,
      );
      expect(
        () => Abmessungen(staerke: const Millimeter(-1)),
        throwsArgumentError,
      );
      expect(
        () => Abmessungen(laengen: const [Millimeter(0)]),
        throwsArgumentError,
      );
      expect(
        Abmessungen(breite: const Millimeter(1)).breite,
        const Millimeter(1),
      );
    });
  });

  group('Artikel', () {
    test('hält alle Angaben', () {
      final a = _diele(titel: '  Diele  ');
      expect(
        [a.nummer.wert, a.titel, a.art],
        ['10-10-073-R', 'Diele', Artikelart.diele],
      );
      expect(a.einheit, Verkaufseinheit(Mengeneinheit.laufmeter));
      expect(a.abmessungen.laengste, const Millimeter(6000));
      expect([a.preisBrutto, a.gewicht], [const Cent(449), const Gramm(1035)]);
      expect(
        [a.serie, a.profil, a.oberseite],
        [Serie.premiumSelect, Profil.genutet, Oberseite.bombiert],
      );
      expect(a.bilder, ['a.webp']);
      expect(() => a.bilder.add('b'), throwsUnsupportedError);
      expect('$a', '10-10-073-R Diele');
    });
    test('Zubehör ohne Maße und Preis', () {
      final a = Artikel(
        nummer: const Artikelnummer('50-60-010'),
        titel: 'GUMO',
        art: Artikelart.pad,
        einheit: Verkaufseinheit(Mengeneinheit.karton, inhalt: 70),
      );
      expect(a.abmessungen.laengen, isEmpty);
      expect([
        a.preisBrutto,
        a.gewicht,
        a.serie,
        a.profil,
        a.oberseite,
      ], everyElement(isNull));
      expect(a.bilder, isEmpty);
    });
    test('gleich, wenn die Artikelnummer gleich ist', () {
      expect(_diele(titel: 'A'), _diele(titel: 'B'));
      expect(_diele().hashCode, _diele(titel: 'B').hashCode);
      expect(_diele(), isNot(_diele(nummer: '10-10-074-R')));
      expect(_diele(), isNot(Object()));
    });
    test('Pflichtangaben', () {
      expect(() => _diele(titel: ' '), throwsArgumentError);
      expect(() => _diele(bilder: ['1', '2', '3', '4']), throwsArgumentError);
      expect(_diele(bilder: ['1', '2', '3']).bilder, hasLength(3));
    });
    test('Holzartikel brauchen eine Serie, andere keine', () {
      expect(() => _diele(serie: null), throwsArgumentError);
      expect(() => _diele(art: Artikelart.clip), throwsArgumentError);
      expect(_diele(art: Artikelart.clip, serie: null).serie, isNull);
    });
  });
}
