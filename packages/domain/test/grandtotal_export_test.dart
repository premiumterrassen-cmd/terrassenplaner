import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

const _m4 = Millimeter(4000);
const _m5 = Millimeter(5000);

/// Erfundene Testartikel – nur Verkaufsdaten.
final _diele = Artikel(
  nummer: const Artikelnummer('10-10-073-R'),
  titel: 'Terrassendiele Robinie 60 x 22 mm',
  art: Artikelart.diele,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  abmessungen: Abmessungen(
    breite: const Millimeter(60),
    staerke: const Millimeter(22),
    laengen: const [_m4, _m5],
  ),
  preisBrutto: const Cent(1290),
  holzart: robinie,
  serie: premiumSelect,
  bilder: const ['Diele 60x22.jpg'],
);

final _uk = Artikel(
  nummer: const Artikelnummer('10-10-031-S'),
  titel: 'Unterkonstruktionsholz Robinie 40 x 60 mm',
  art: Artikelart.unterkonstruktion,
  einheit: Verkaufseinheit(Mengeneinheit.stueck),
  abmessungen: Abmessungen(
    breite: const Millimeter(40),
    staerke: const Millimeter(60),
    laengen: const [_m4],
  ),
  preisBrutto: const Cent(2999),
  holzart: robinie,
  serie: ecoSelect,
);

final _clip = Artikel(
  nummer: const Artikelnummer('80-10-001-250'),
  titel: 'CLIP-FIXX® "BLACK EDITION" - VPE 250',
  art: Artikelart.clip,
  einheit: Verkaufseinheit(Mengeneinheit.verpackungseinheit, inhalt: 250),
  preisBrutto: const Cent(18690),
  gewicht: const Gramm(1500),
);

final _montagehilfe = Artikel(
  nummer: const Artikelnummer('50-80-009'),
  titel: 'Montagehilfe Abstandshalter',
  art: Artikelart.werkzeug,
  einheit: Verkaufseinheit(Mengeneinheit.set),
);

final _alle = {
  for (final a in [_diele, _uk, _clip, _montagehilfe]) a.nummer: a,
};

final _basis = Uri.parse('https://planer.example/app/');

Materialliste _liste({Map<Positionsschluessel, int> mengen = const {}}) =>
    Materialliste.aus([
      Materialbedarf([_diele], 48, laenge: _m5),
      Materialbedarf(
        [_diele],
        1,
        laenge: _m5,
        zusatz: Materialzusatz.freidiele,
      ),
      Materialbedarf([_uk], 13, laenge: _m4),
      Materialbedarf([_clip], 300),
      Materialbedarf([_montagehilfe], 1, jePlanung: true),
    ], mengen: mengen);

void main() {
  group('Export für GrandTotal (M9-08)', () {
    test('17 Spalten wie der CSV-Download des alten Planers', () {
      expect(grandTotalSpalten, hasLength(17));
      expect(
        grandTotalCsv(const []),
        'Bezeichnung;Nomenklatur;Body HTML;Anzahl;Breite;Stärke;Länge;'
        'Artikelnummer;Nettopreis;Bruttopreis;Link zum Bild;Volumen;Gewicht;'
        'Quadratmeter;Gesamtlaufmeter;Artikeltyp;Einheit\r\n',
      );
    });

    test('Zeilen der Materialliste mit Maßen, Preisen und Gewicht', () {
      final zeilen = grandTotalZeilen(
        _liste(),
        (n) => _alle[n],
        bilder: _basis,
      );
      expect(zeilen.map((z) => z.felder), [
        // Dielen: Stück und Länge in mm, Preis je lfm (Plugin rechnet lfm)
        [
          'Terrassendiele Robinie 60 x 22 mm - Länge: 5000 mm',
          'Terrassendiele Robinie 60 x 22 mm',
          '',
          '48',
          '60',
          '22',
          '5000',
          '10-10-073-R',
          // 12,90 € brutto je lfm = 10,8403 € netto
          '10.8403',
          '12.90',
          'https://planer.example/app/artikelbilder/Diele%2060x22.webp',
          // 0,06 × 0,022 × 5 m je Stück
          '0.0066',
          // 4,95 kg je Diele (750 kg/m³, R-A12) × 48
          '237.6',
          '0.3',
          '240',
          'Deckbelag',
          'lfm',
        ],
        // Freidiele (B-079): eigene Zeile, Netto und Brutto 0
        [
          'Terrassendiele Robinie 60 x 22 mm - Länge: 5000 mm - Freidiele',
          'Terrassendiele Robinie 60 x 22 mm',
          '',
          '1',
          '60',
          '22',
          '5000',
          '10-10-073-R',
          '0.0000',
          '0.00',
          'https://planer.example/app/artikelbilder/Diele%2060x22.webp',
          '0.0066',
          '4.95',
          '0.3',
          '5',
          'Deckbelag',
          'lfm',
        ],
        // UK je Stück verkauft: 29,99 € für 4 m = 7,50 € je lfm
        [
          'Unterkonstruktionsholz Robinie 40 x 60 mm - Länge: 4000 mm',
          'Unterkonstruktionsholz Robinie 40 x 60 mm',
          '',
          '13',
          '40',
          '60',
          '4000',
          '10-10-031-S',
          '6.3025',
          '7.50',
          '',
          '0.0096',
          '93.6',
          '0.16',
          '52',
          'Unterkonstruktion',
          'lfm',
        ],
        // Zubehör: Verkaufseinheit, Gewicht je VPE × Anzahl
        [
          'CLIP-FIXX® "BLACK EDITION" - VPE 250',
          'CLIP-FIXX® "BLACK EDITION" - VPE 250',
          '',
          '2',
          '',
          '',
          '',
          '80-10-001-250',
          '157.0588',
          '186.90',
          '',
          '',
          '3',
          '',
          '',
          'BefestigungDeck,Zubehoer',
          'VPE',
        ],
        // ohne Preis und Gewicht: leere Felder
        [
          'Montagehilfe Abstandshalter',
          'Montagehilfe Abstandshalter',
          '',
          '1',
          '',
          '',
          '',
          '50-80-009',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          'Zubehoer',
          'Set',
        ],
      ]);
      expect(zeilen.first.netto, closeTo(10.840336, 1e-6));
      expect(zeilen.last.netto, isNull);
    });

    test('ohne Adresse der App kein Bild-Link', () {
      final zeilen = grandTotalZeilen(_liste(), (n) => _alle[n]);
      expect(zeilen.map((z) => z.bildLink), everyElement(isNull));
    });

    test('abgewählte Positionen (Menge 0) entfallen, geänderte zählen', () {
      final zeilen = grandTotalZeilen(
        _liste(
          mengen: {
            (nummer: _diele.nummer, laenge: _m5, zusatz: null): 50,
            (nummer: _uk.nummer, laenge: _m4, zusatz: null): 0,
          },
        ),
        (n) => _alle[n],
      );
      expect(zeilen.map((z) => z.artikelnummer.wert), [
        '10-10-073-R',
        '10-10-073-R',
        '80-10-001-250',
        '50-80-009',
      ]);
      expect(zeilen.first.anzahl, 50);
      expect(zeilen.first.felder[14], '250');
    });

    test('unbekannter Artikel: ohne Maße, Gewicht und Artikeltyp', () {
      final zeile = grandTotalZeilen(
        _liste(),
        (_) => null,
        bilder: _basis,
      ).first;
      expect(zeile.felder, [
        'Terrassendiele Robinie 60 x 22 mm - Länge: 5000 mm',
        'Terrassendiele Robinie 60 x 22 mm',
        '',
        '48',
        '',
        '',
        '5000',
        '10-10-073-R',
        '10.8403',
        '12.90',
        'https://planer.example/app/artikelbilder/Diele%2060x22.webp',
        '',
        '',
        '',
        '240',
        '',
        'lfm',
      ]);
    });

    test('Holz ohne Holzart (Alu-UK): Gewicht je Einheit × Anzahl', () {
      final alu = Artikel(
        nummer: const Artikelnummer('60-10-001'),
        titel: 'Alu-Unterkonstruktion 40 x 20 mm',
        art: Artikelart.aluUnterkonstruktion,
        einheit: Verkaufseinheit(Mengeneinheit.stueck),
        abmessungen: Abmessungen(
          breite: const Millimeter(40),
          staerke: const Millimeter(20),
        ),
        gewicht: const Gramm(2100),
      );
      final zeile = grandTotalZeilen(
        Materialliste.aus([
          Materialbedarf([alu], 3, laenge: _m4),
        ]),
        (_) => alu,
      ).single;
      expect(zeile.gewicht, const Gramm(6300));
      expect(zeile.volumen, closeTo(0.0032, 1e-12));
      expect(zeile.felder[2], '');
      expect(zeile.artikeltyp, 'Unterkonstruktion');
    });

    test('Holz ohne Stärke: kein Volumen, Gewicht je Einheit', () {
      final diele = Artikel(
        nummer: const Artikelnummer('10-10-999'),
        titel: 'Diele ohne Stärke',
        art: Artikelart.diele,
        einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
        abmessungen: Abmessungen(breite: const Millimeter(60)),
        gewicht: const Gramm(900),
        holzart: robinie,
        serie: premiumSelect,
      );
      final zeile = grandTotalZeilen(
        Materialliste.aus([
          Materialbedarf([diele], 2, laenge: _m5),
        ]),
        (_) => diele,
      ).single;
      expect(zeile.volumen, isNull);
      expect(zeile.gewicht, const Gramm(1800));
      expect(zeile.quadratmeter, closeTo(0.3, 1e-12));
    });

    test('Felder mit ; " oder Zeilenumbruch in Anführungszeichen', () {
      GrandTotalZeile zeile(String titel) => GrandTotalZeile(
        bezeichnung: titel,
        nomenklatur: 'kurz',
        artikelnummer: const Artikelnummer('1'),
        anzahl: 1,
        artikeltyp: 'Zubehoer',
        einheit: 'Stück',
      );
      expect(
        grandTotalCsv([
          zeile('A;B'),
          zeile('Clip "X"'),
          zeile('Zeile\neins'),
          zeile('Zeile\rzwei'),
          zeile('schlicht'),
        ]).split('\r\n').skip(1).toList(),
        [
          '"A;B";kurz;;1;;;;1;;;;;;;;Zubehoer;Stück',
          '"Clip ""X""";kurz;;1;;;;1;;;;;;;;Zubehoer;Stück',
          '"Zeile\neins";kurz;;1;;;;1;;;;;;;;Zubehoer;Stück',
          '"Zeile\rzwei";kurz;;1;;;;1;;;;;;;;Zubehoer;Stück',
          'schlicht;kurz;;1;;;;1;;;;;;;;Zubehoer;Stück',
          '',
        ],
      );
      expect('${zeile('x')}', 'x;kurz;;1;;;;1;;;;;;;;Zubehoer;Stück');
    });

    test('Zahlen auf höchstens 4 Nachkommastellen ohne Nullen am Ende', () {
      List<String> zahlen(double v) => GrandTotalZeile(
        bezeichnung: 'x',
        nomenklatur: 'x',
        artikelnummer: const Artikelnummer('1'),
        anzahl: 1,
        artikeltyp: '',
        einheit: '',
        beschreibung: 'Text',
        volumen: v,
        quadratmeter: v,
      ).felder;
      expect(zahlen(0.00004)[11], '0');
      expect(zahlen(2.5)[13], '2.5');
      expect(zahlen(1234.56789)[11], '1234.5679');
      expect(zahlen(2400)[13], '2400');
      expect(zahlen(10.05)[11], '10.05');
      expect(zahlen(1)[2], 'Text');
    });

    test('Artikeltyp je Artikelart (Warengruppe in GrandTotal)', () {
      expect(
        {for (final a in Artikelart.values) a: grandTotalArtikeltyp(a)},
        {
          Artikelart.diele: 'Deckbelag',
          Artikelart.systemdiele: 'Deckbelag',
          Artikelart.holzfliese: 'Deckbelag,Zubehoer',
          Artikelart.unterkonstruktion: 'Unterkonstruktion',
          Artikelart.aluUnterkonstruktion: 'Unterkonstruktion',
          Artikelart.clip: 'BefestigungDeck,Zubehoer',
          Artikelart.schraube: 'BefestigungDeck,Zubehoer',
          Artikelart.stellfuss: 'Stellfuss,Zubehoer',
          Artikelart.pad: 'Unterlegpads,Zubehoer',
          Artikelart.padUnterStellfuss: 'Unterlegpads,Zubehoer',
          Artikelart.bodenanker: 'Bodenanker',
          Artikelart.laengsverbinder: 'Verbinder,Zubehoer',
          Artikelart.querverbinder: 'Verbinder,Zubehoer',
          Artikelart.eckverbinder: 'Verbinder,Zubehoer',
          Artikelart.variablerVerbinder: 'Verbinder,Zubehoer',
          Artikelart.blendenhalter: 'Verblendung,Zubehoer',
          Artikelart.verblendung: 'Verblendung,Zubehoer',
          Artikelart.rinne: 'Drainage',
          Artikelart.rinnenzubehoer: 'DrainageZubehoer',
          Artikelart.gummiband: 'EPDM-Band,Zubehoer',
          Artikelart.pflege: 'Zubehoer',
          Artikelart.werkzeug: 'Zubehoer',
          Artikelart.dienstleistung: 'Dienstleistung',
          Artikelart.sonstiges: 'Zubehoer',
        },
      );
    });

    test('Dateiname mit Nummer und Version, ohne Prüfcode (M9-05b)', () {
      expect(grandTotalDateiname(), 'GrandTotal_Import.csv');
      expect(
        grandTotalDateiname(
          KonfigurationsStand(
            Konfigurationskennung.lies('2026-10-08-1511-K7QXM'),
            2,
          ),
        ),
        'GrandTotal_Import_2026-10-08-1511_v2.csv',
      );
    });

    test('ganze Datei: Kopf und Zeilen mit CRLF', () {
      final csv = grandTotalCsv(grandTotalZeilen(_liste(), (n) => _alle[n]));
      final zeilen = csv.split('\r\n');
      expect(zeilen, hasLength(7));
      expect(zeilen.first, startsWith('Bezeichnung;Nomenklatur;'));
      expect(
        zeilen[4],
        startsWith('"CLIP-FIXX® ""BLACK EDITION"" - VPE 250";'),
      );
      expect(zeilen.last, '');
    });
  });
}
