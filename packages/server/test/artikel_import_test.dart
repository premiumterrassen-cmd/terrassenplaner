import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

/// Baut eine kleine xlsx-Datei: Zeilen als Listen; `null` = leere Zelle,
/// `=` vorn = Formel ohne gespeicherten Wert. Texte als Inline-Strings, ab
/// [geteilt] als gemeinsame Strings.
List<int> _xlsx(
  List<List<Object?>> zeilen, {
  String blatt = importBlatt,
  bool geteilt = false,
  bool mitMappe = true,
  bool relativ = false,
}) {
  final gemeinsam = <String>[];
  String spalte(int i) => i < 26
      ? String.fromCharCode(65 + i)
      : 'A${String.fromCharCode(65 + i - 26)}';
  final xml = StringBuffer('<worksheet><sheetData>');
  for (final (z, zeile) in zeilen.indexed) {
    xml.write('<row r="${z + 1}">');
    for (final (s, wert) in zeile.indexed) {
      final ref = '${spalte(s)}${z + 1}';
      if (wert == null) continue;
      if (wert is num) {
        xml.write('<c r="$ref"><v>$wert</v></c>');
      } else if ('$wert'.startsWith('=')) {
        // „=Formel“ ohne Wert, „=Formel|Wert“ mit gespeichertem Wert.
        final teile = '$wert'.substring(1).split('|');
        final gespeichert = teile.length > 1 ? '<v>${teile[1]}</v>' : '';
        xml.write('<c r="$ref"><f>${teile[0]}</f>$gespeichert</c>');
      } else if (geteilt) {
        gemeinsam.add('$wert');
        xml.write('<c r="$ref" t="s"><v>${gemeinsam.length - 1}</v></c>');
      } else {
        xml.write('<c r="$ref" t="inlineStr"><is><t>$wert</t></is></c>');
      }
    }
    xml.write('</row>');
  }
  xml.write('</sheetData></worksheet>');
  final archiv = Archive();
  void datei(String pfad, String inhalt) {
    final bytes = utf8.encode(inhalt);
    archiv.addFile(ArchiveFile(pfad, bytes.length, bytes));
  }

  if (mitMappe) {
    datei(
      'xl/workbook.xml',
      '<workbook xmlns:r="r"><sheets><sheet name="Anleitung" r:id="rId9"/>'
          '<sheet name="$blatt" r:id="rId1"/></sheets></workbook>',
    );
  }
  datei(
    'xl/_rels/workbook.xml.rels',
    '<Relationships><Relationship Target="${relativ ? '' : '/xl/'}'
        'worksheets/sheet1.xml" '
        'Id="rId1"/></Relationships>',
  );
  datei('xl/worksheets/sheet1.xml', '$xml');
  if (geteilt) {
    datei(
      'xl/sharedStrings.xml',
      '<sst>${[for (final t in gemeinsam) '<si><t>$t</t></si>'].join()}</sst>',
    );
  }
  return ZipEncoder().encodeBytes(archiv);
}

const _kopf = [
  'Artikelnummer',
  'Artikelbezeichnung',
  'ArtikelbezeichnungKonfi',
  'Artikeltyp',
  'Zubehoergruppe',
  'Materialobergruppe',
  'VPE',
  'Inhalt_pro_Einheit',
  'Preis_pro_Einheit',
  'Breite_cm',
  'Staerke_cm',
  'Laenge_cm',
  'Abbildung_1',
  'Abbildung_2',
  'moeglicheBefestigungDeck',
  'Abstand_UK',
  'Reichweite',
  'benoetigtesZubehoer',
  'benoetigtesZubehoer_anzahl',
  'marke',
  'Einstandspreis',
];

List<Object?> _zeile({
  String nummer = '10-10-073-R',
  String titel =
      'Terrassendiele Robinie PREMIUM SELECT 60 x 23 mm, genutet, bombiert',
  String konfi = '',
  String typ = 'Deckbelag',
  String gruppe = '',
  String obergruppe = 'Unsichtbar befestigt',
  String vpe = 'lfm',
  Object? inhalt = 1,
  Object? preis = '6,09',
  Object? breite = 60,
  Object? staerke = 23,
  Object? laenge = 6000,
  String bild1 = 'profil.webp',
  String bild2 = '',
  String befestigung = '80-10-001-50, 80-10-001-100,0',
  Object? abstandUk = 400,
  String reichweite = '',
  String benoetigt = '',
  String anzahl = '',
}) => [
  nummer,
  titel,
  konfi,
  typ,
  gruppe,
  obergruppe,
  vpe,
  inhalt,
  preis,
  breite,
  staerke,
  laenge,
  bild1,
  bild2,
  befestigung,
  abstandUk,
  reichweite,
  benoetigt,
  anzahl,
  'fixing',
  'GEHEIM-EK-4711',
];

/// Die von den Dielen referenzierten Clips (stehen am Ende des Blatts).
List<List<Object?>> _clips() => [
  for (final vpe in [50, 100])
    _zeile(
      nummer: '80-10-001-$vpe',
      titel: 'CLIP-FIXX VPE $vpe',
      typ: 'BefestigungDeck,Zubehoer',
      vpe: 'Karton',
      inhalt: vpe,
      breite: null,
      staerke: null,
      laenge: null,
      befestigung: '',
      abstandUk: null,
    ),
];

ImportErgebnis _import(List<List<Object?>> zeilen, {bool geteilt = false}) =>
    importiereArtikel(
      _xlsx([_kopf, ...zeilen, ..._clips()], geteilt: geteilt),
      quelle: 'test.xlsx',
    );

void main() {
  group('xlsx-Leser', () {
    test(
      'liest Inline- und gemeinsame Texte, Zahlen, überspringt Leerzeilen',
      () {
        for (final geteilt in [false, true]) {
          final blatt = leseBlatt(
            _xlsx([
              ['A', 'B', null, 'D'],
              ['x', 1.5, null, 'y'],
              [null, ' '],
              ['z'],
            ], geteilt: geteilt),
            importBlatt,
          );
          expect(blatt.kopf, ['A', 'B', 'D']);
          expect(blatt.zeilen.map((z) => z.nummer), [2, 4]);
          expect(blatt.zeilen.first.werte, {'A': 'x', 'B': '1.5', 'D': 'y'});
          expect(blatt.zeilen.last.werte, {'A': 'z'});
          expect(blatt.formelnOhneWert, 0);
        }
      },
    );

    test('relativer Pfad zum Blatt', () {
      final blatt = leseBlatt(
        _xlsx([
          ['A'],
          ['x'],
        ], relativ: true),
        importBlatt,
      );
      expect(blatt.zeilen.single.werte, {'A': 'x'});
    });

    test('Spalten jenseits von Z und Formeln ohne Wert', () {
      final kopf = [for (var i = 0; i < 28; i++) 'S$i'];
      final blatt = leseBlatt(
        _xlsx([
          kopf,
          [
            for (var i = 0; i < 28; i++)
              i == 27 ? 'AB' : (i == 1 ? '=A2' : (i == 2 ? '=A3|7' : null)),
          ],
        ]),
        importBlatt,
      );
      expect(blatt.kopf.last, 'S27');
      expect(blatt.zeilen.single.werte, {'S2': '7', 'S27': 'AB'});
      expect(blatt.formelnOhneWert, 1);
    });

    test('Fehler: keine xlsx, Blatt fehlt, Teil fehlt, leeres Blatt', () {
      expect(
        () => leseBlatt(utf8.encode('kein zip'), importBlatt),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'm',
            'keine xlsx-Datei',
          ),
        ),
      );
      expect(
        () => leseBlatt(
          _xlsx([
            ['A'],
          ], blatt: 'Anderes'),
          importBlatt,
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'm',
            contains('fehlt'),
          ),
        ),
      );
      expect(
        () => leseBlatt(
          _xlsx([
            ['A'],
          ], mitMappe: false),
          importBlatt,
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'm',
            'xl/workbook.xml fehlt in der xlsx-Datei',
          ),
        ),
      );
      expect(
        () => leseBlatt(_xlsx([]), importBlatt),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'm',
            contains('leer'),
          ),
        ),
      );
    });
  });

  group('Artikelart aus den Typ-Texten', () {
    test('alle Typen des alten Planers', () {
      final faelle = <(String, String, String), Artikelart?>{
        ('Deckbelag', 'Terrassendiele Robinie', ''): Artikelart.diele,
        ('Deckbelag', 'Systemdiele Robinie MASSIV', ''): Artikelart.systemdiele,
        ('Deckbelag,Zubehoer', 'Fliese', ''): Artikelart.holzfliese,
        ('Unterkonstruktion', 'Unterkonstruktion Robinie', ''):
            Artikelart.unterkonstruktion,
        ('Unterkonstruktion', 'ALUecofix L', ''):
            Artikelart.aluUnterkonstruktion,
        ('BefestigungDeck', 'Terrassenschraube', ''): Artikelart.schraube,
        ('BefestigungDeck,Zubehoer', 'CLIP-FIXX', ''): Artikelart.clip,
        ('Stellfuss,Zubehoer', 'Stelzlager', ''): Artikelart.stellfuss,
        ('Unterlegpads,Zubehoer', 'GUMO', ''): Artikelart.pad,
        ('_Unterlegpads,Zubehoer', 'Pad', ''): Artikelart.pad,
        ('PadUnterStelzfuss,Zubehoer', 'Gummipad', ''):
            Artikelart.padUnterStellfuss,
        ('Bodenanker', 'Anker', ''): Artikelart.bodenanker,
        ('Laengsverbinder', 'Kopplung', ''): Artikelart.laengsverbinder,
        ('Querverbinder', 'Quer', ''): Artikelart.querverbinder,
        ('Eckverbinder', 'T-Träger', ''): Artikelart.eckverbinder,
        ('VariablerEckverbinder', '2D', ''): Artikelart.variablerVerbinder,
        ('Blendenhalter', 'Halter', ''): Artikelart.blendenhalter,
        ('Verblendung', 'Blende', ''): Artikelart.verblendung,
        ('Drainage', 'Rinne', ''): Artikelart.rinne,
        ('_Unterrinne', 'Unterrinne', ''): Artikelart.rinnenzubehoer,
        ('_HalterEntwässerungsrinne', 'Set', ''): Artikelart.rinnenzubehoer,
        ('DrainageZubehoer', 'RELO VA', ''): Artikelart.rinnenzubehoer,
        ('EPDM-Band,Zubehoer', 'Band', ''): Artikelart.gummiband,
        ('Zubehoer', 'RIBOL', 'Terrassenöl RIBOL'): Artikelart.pflege,
        ('Zubehoer', 'Lieferfahrzeug', 'Anlieferung'):
            Artikelart.dienstleistung,
        ('Zubehoer', 'Keile', 'Höhenausgleich'): Artikelart.stellfuss,
        ('Zubehoer', 'GUMO', 'Pads & EPDM Bänder'): Artikelart.pad,
        ('Zubehoer', 'Bohrschraube 4,2', 'Clips & Schrauben'):
            Artikelart.schraube,
        ('Zubehoer', 'DUO-Clip', 'Clips & Schrauben'): Artikelart.clip,
        ('Zubehoer', 'Bit TX25', ''): Artikelart.werkzeug,
        ('Zubehoer', 'TX20 weiss 50 mm', ''): Artikelart.werkzeug,
        ('Zubehoer', 'Handschuh', ''): Artikelart.werkzeug,
        ('Zubehoer', 'Unkrautvlies', ''): Artikelart.sonstiges,
        ('Gartenzwerg', 'x', ''): null,
      };
      for (final MapEntry(key: (typ, titel, gruppe), :value)
          in faelle.entries) {
        expect(
          artikelartFuer(typ, titel, gruppe),
          value,
          reason: '$typ / $titel',
        );
      }
    });
  });

  group('Import', () {
    test('Diele vollständig, ohne Hersteller und Einkaufsdaten', () {
      final ergebnis = _import([_zeile()]);
      expect(ergebnis.befunde, isEmpty);
      expect(ergebnis.erfolgreich, isTrue);
      final datei = ergebnis.datei!;
      expect(datei.quelle, 'test.xlsx');
      expect(datei.version, matches(RegExp(r'^[0-9a-f]{16}$')));
      final e = datei[const Artikelnummer('10-10-073-R')]!;
      final a = e.artikel;
      expect(
        [a.nummer.wert, a.art, a.holzart, a.serie, a.profil, a.oberseite],
        [
          '10-10-073-R',
          Artikelart.diele,
          robinie,
          premiumSelect,
          Profil.genutet,
          Oberseite.bombiert,
        ],
      );
      expect(a.einheit, Verkaufseinheit(Mengeneinheit.laufmeter));
      expect(a.preisBrutto, const Cent(609));
      expect(
        [a.abmessungen.breite, a.abmessungen.staerke, a.abmessungen.laengste],
        [const Millimeter(60), const Millimeter(23), const Millimeter(6000)],
      );
      expect(a.bilder, ['profil.webp']);
      expect(e.verweise, {
        'moeglicheBefestigungDeck': [
          const Artikelnummer('80-10-001-50'),
          const Artikelnummer('80-10-001-100'),
        ],
      });
      expect(e.angaben, {'Abstand_UK': 400});
      final json = jsonEncode(datei.alsJson());
      expect(json, isNot(contains('GEHEIM-EK')), reason: 'B-020');
      expect(json.toLowerCase(), isNot(contains('fixing')), reason: 'B-023');
    });

    test('Whitelist: nur bekannte Spalten werden gelesen', () {
      expect(gelesenenSpalten, isNot(contains('marke')));
      expect(gelesenenSpalten, isNot(contains('Einstandspreis')));
      expect(
        gelesenenSpalten.any((s) => s.toLowerCase().contains('ek')),
        isFalse,
      );
    });

    test('Profil, Oberseite, UK, Zubehör, Schalter, benötigtes Zubehör', () {
      final datei = _import([
        _zeile(
          nummer: 'A',
          titel: 'Terrassendiele Robinie ECO SELECT 100 x 23 mm, glattkant',
          obergruppe: '',
          befestigung: 'D',
        ),
        _zeile(
          nummer: 'B',
          titel: 'Systemdiele Robinie MASSIV 80 x 25 mm',
          obergruppe: 'Sichtbar befestigt',
          befestigung: 'D',
          breite: 80,
          staerke: 25,
          laenge: 2000,
        ),
        _zeile(
          nummer: 'C',
          titel: 'Unterkonstruktion Robinie BASIC 45 x 60 mm',
          typ: 'Unterkonstruktion',
          breite: 45,
          staerke: 60,
        ),
        _zeile(
          nummer: 'D',
          titel: 'Speedfix Flügelbohrschraube',
          typ: 'BefestigungDeck,Zubehoer',
          vpe: 'Karton',
          inhalt: 100,
          preis: null,
          breite: null,
          staerke: 0,
          laenge: 45,
          bild1: 'Kein Bild',
          bild2: 'schraube.webp',
          befestigung: '',
          abstandUk: null,
          reichweite: 'true',
          benoetigt: '80-10-001-50;80-10-001-100',
          anzahl: '1; 3',
        ),
        _zeile(
          nummer: 'E',
          titel: '',
          konfi: 'Titel aus Konfi',
          typ: 'Zubehoer',
          vpe: 'Stück',
          inhalt: null,
          reichweite: 'false',
        ),
      ], geteilt: true).datei!;
      Artikeleintrag e(String n) => datei[Artikelnummer(n)]!;
      expect(
        [e('A').artikel.serie, e('A').artikel.profil, e('A').artikel.oberseite],
        [ecoSelect, Profil.glattkant, Oberseite.glatt],
      );
      expect(
        [e('B').artikel.art, e('B').artikel.profil, e('B').artikel.oberseite],
        [Artikelart.systemdiele, Profil.glattkant, Oberseite.glatt],
      );
      expect(
        [
          e('C').artikel.art,
          e('C').artikel.serie,
          e('C').artikel.profil,
          e('C').artikel.oberseite,
        ],
        [Artikelart.unterkonstruktion, basic, null, null],
      );
      final d = e('D');
      expect(
        [
          d.artikel.art,
          d.artikel.titel,
          d.artikel.holzart,
          d.artikel.preisBrutto,
        ],
        [Artikelart.schraube, 'Speedfix Flügelbohrschraube', null, null],
      );
      expect(
        d.artikel.einheit,
        Verkaufseinheit(Mengeneinheit.karton, inhalt: 100),
      );
      expect(
        [d.artikel.abmessungen.breite, d.artikel.abmessungen.staerke],
        [null, null],
      );
      expect(d.artikel.bilder, ['schraube.webp'], reason: 'ohne „Kein Bild“');
      expect(keinBild, 'Kein Bild');
      expect(d.verweise, isEmpty);
      expect(d.angaben, {'Reichweite': 1});
      expect(d.benoetigt, {
        const Artikelnummer('80-10-001-50'): 1,
        const Artikelnummer('80-10-001-100'): 3,
      });
      expect(
        [
          e('E').artikel.titel,
          e('E').artikel.art,
          e('E').artikel.einheit.inhalt,
        ],
        ['Titel aus Konfi', Artikelart.sonstiges, 1],
      );
      expect(e('E').angaben, {'Abstand_UK': 400, 'Reichweite': 0});
    });

    test('Titel aus ArtikelbezeichnungKonfi (Name wie im Planer)', () {
      final datei = _import([
        _zeile(
          nummer: 'K',
          titel: 'schwarz beschichtet, Clipbefestigung zur Verschraubung',
          konfi: 'CLIP-FIXX® "BLACK EDITION" - VPE 50',
          typ: 'BefestigungDeck,Zubehoer',
          vpe: 'Karton',
          inhalt: 50,
          breite: null,
          staerke: null,
          laenge: null,
          befestigung: '',
        ),
      ]).datei!;
      final a = datei[const Artikelnummer('K')]!.artikel;
      expect(
        [a.titel, a.art],
        ['CLIP-FIXX® "BLACK EDITION" - VPE 50', Artikelart.clip],
      );
    });

    test('Maß unter 1 mm ist nur ein Hinweis', () {
      final ergebnis = _import([
        _zeile(
          titel: 'Unkrautvlies',
          typ: 'Zubehoer',
          vpe: 'Stück',
          staerke: '0,1',
          befestigung: '',
        ),
      ]);
      expect(ergebnis.erfolgreich, isTrue);
      expect(
        ergebnis
            .datei![const Artikelnummer('10-10-073-R')]!
            .artikel
            .abmessungen
            .staerke,
        isNull,
      );
      final hinweis = ergebnis.befunde.single;
      expect(
        [hinweis.zeile, hinweis.feld, hinweis.kritisch],
        [2, 'Staerke_cm', false],
      );
      expect(
        '$hinweis',
        'Hinweis Zeile 2, Staerke_cm: unter 1 mm (0.1) – nicht übernommen',
      );
    });

    test('Version hängt nur vom Inhalt ab', () {
      String v(List<Object?> zeile) => _import([zeile]).datei!.version;
      expect(v(_zeile()), v(_zeile()));
      expect(v(_zeile()), isNot(v(_zeile(preis: '6,10'))));
    });

    test('kritische Befunde verhindern die Artikeldatei', () {
      final faelle = <List<Object?>, (String, String)>{
        _zeile(nummer: ''): ('Artikelnummer', 'fehlt'),
        _zeile(titel: ''): ('Artikelbezeichnung', 'fehlt'),
        _zeile(typ: 'Gartenzwerg'): ('Artikeltyp', 'unbekannt: „Gartenzwerg“'),
        _zeile(vpe: 'Palette'): ('VPE', 'unbekannte Einheit: „Palette“'),
        _zeile(preis: 'teuer'): ('Preis_pro_Einheit', 'keine Zahl: „teuer“'),
        _zeile(titel: 'Terrassendiele Eiche'): (
          'Artikelbezeichnung',
          'Holzart nicht erkannt',
        ),
        _zeile(titel: 'Terrassendiele Robinie GOLD'): (
          'Artikelbezeichnung',
          'Serie nicht erkannt',
        ),
        _zeile(benoetigt: 'X1;X2', anzahl: '1'): (
          'benoetigtesZubehoer_anzahl',
          'Anzahl fehlt für X2',
        ),
        _zeile(breite: -60): ('breite', 'muss größer als 0 sein'),
      };
      for (final MapEntry(key: zeile, value: (feld, text)) in faelle.entries) {
        final ergebnis = _import([zeile]);
        expect(ergebnis.erfolgreich, isFalse, reason: text);
        expect(ergebnis.datei, isNull);
        final b = ergebnis.befunde.firstWhere((b) => b.kritisch);
        expect([b.zeile, b.feld, b.text], [2, feld, text]);
        expect('$b', startsWith('FEHLER Zeile 2, $feld'));
      }
    });

    test('doppelte Artikelnummer', () {
      final ergebnis = _import([_zeile(), _zeile()]);
      expect(ergebnis.erfolgreich, isFalse);
      expect(
        ergebnis.befunde.single.text,
        'doppelt (wie Zeile 2): 10-10-073-R',
      );
      expect(ergebnis.befunde.single.zeile, 3);
    });

    test('Datei, Blatt und Pflichtspalten', () {
      final keinZip = importiereArtikel(utf8.encode('x'), quelle: 'q');
      expect(
        [keinZip.befunde.single.feld, keinZip.befunde.single.text],
        ['Datei', 'keine xlsx-Datei'],
      );
      final ohneSpalten = importiereArtikel(
        _xlsx([
          ['Titel'],
          ['x'],
        ]),
        quelle: 'q',
      );
      expect(ohneSpalten.befunde.map((b) => b.feld), [
        'Artikelnummer',
        'Artikelbezeichnung',
        'Artikeltyp',
      ]);
      expect(ohneSpalten.befunde.first.text, 'Pflichtspalte fehlt');
      final formeln = importiereArtikel(
        _xlsx([
          _kopf,
          ['=Master!A2', '=Master!E2', ...List.filled(_kopf.length - 2, null)],
        ]),
        quelle: 'Master-Artikelliste_v26.xlsx',
      );
      expect(formeln.erfolgreich, isFalse);
      expect(
        formeln.befunde.single.text,
        '2 Formeln ohne gespeicherten Wert – bitte die Upload-Datei (Werte) '
        'verwenden, nicht die Master-Artikelliste',
      );
    });

    test('eigene Holzarten statt Robinie', () {
      final kastanie = Holzart.ausJson({
        ...robinieDaten,
        'id': 'kastanie',
        'name': 'Kastanie',
      });
      final ergebnis = importiereArtikel(
        _xlsx([
          _kopf,
          _zeile(titel: 'Terrassendiele Kastanie PREMIUM SELECT 60 x 23 mm'),
          ..._clips(),
        ]),
        quelle: 'q',
        holzarten: [kastanie],
      );
      expect(
        ergebnis.datei![const Artikelnummer('10-10-073-R')]!.artikel.holzart,
        kastanie,
      );
    });
  });
}
