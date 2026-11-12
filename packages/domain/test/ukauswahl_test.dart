import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

Artikel _uk(
  String nummer,
  Serie? serie,
  int? breite,
  int? staerke, {
  Artikelart art = Artikelart.unterkonstruktion,
  Cent? preis = const Cent(890),
  Mengeneinheit einheit = Mengeneinheit.laufmeter,
}) => Artikel(
  nummer: Artikelnummer(nummer),
  titel: 'UK $nummer',
  art: art,
  einheit: Verkaufseinheit(einheit),
  abmessungen: Abmessungen(
    breite: breite == null ? null : Millimeter(breite),
    staerke: staerke == null ? null : Millimeter(staerke),
    laengen: const [Millimeter(6000)],
  ),
  preisBrutto: preis,
  holzart: art.istHolz ? robinie : null,
  serie: serie,
);

Artikel _diele(Serie serie) => Artikel(
  nummer: const Artikelnummer('10-10-073-R'),
  titel: 'Diele',
  art: Artikelart.diele,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  holzart: robinie,
  serie: serie,
  profil: Profil.genutet,
);

/// Planungsstand im Transportformat mit einzelnen Feldern aus M6-03.
Uint8List _alt({String? uk, int? laenge}) {
  final fbb = fb.Builder();
  final masseOrt = fbb.writeListInt32([4800, 3090]);
  fbb
    ..startTable(2)
    ..addUint8(0, 0)
    ..addOffset(1, masseOrt);
  final ort = fbb.endTable();
  final ukOrt = uk == null ? null : fbb.writeString(uk);
  fbb
    ..startTable(27)
    ..addOffset(1, ort)
    ..addOffset(25, ukOrt)
    ..addInt32(26, laenge);
  fbb.finish(fbb.endTable());
  return fbb.buffer;
}

void main() {
  group('passende Unterkonstruktion (M6-03)', () {
    final premium = _diele(premiumSelect);

    test('nur Robinien-UK derselben Serie mit gültigem Format (B-034)', () {
      expect(ukPasstZuBelag(_uk('a', premiumSelect, 45, 60), premium), isTrue);
      // Breite und Stärke tauschbar
      expect(ukPasstZuBelag(_uk('b', premiumSelect, 70, 45), premium), isTrue);
      // anderes Format, andere Serie
      expect(ukPasstZuBelag(_uk('c', premiumSelect, 40, 60), premium), isFalse);
      expect(ukPasstZuBelag(_uk('d', basic, 45, 60), premium), isFalse);
      // ohne Maße nicht prüfbar
      expect(
        ukPasstZuBelag(_uk('e', premiumSelect, null, 60), premium),
        isFalse,
      );
      expect(
        ukPasstZuBelag(_uk('f', premiumSelect, 45, null), premium),
        isFalse,
      );
      // Alu-UK und Belag ohne Holzart (Holzfliese) nie
      final alu = _uk(
        '50-20-007',
        null,
        56,
        40,
        art: Artikelart.aluUnterkonstruktion,
      );
      expect(ukPasstZuBelag(alu, premium), isFalse);
      final fliese = Artikel(
        nummer: const Artikelnummer('10-20-001'),
        titel: 'Fliese',
        art: Artikelart.holzfliese,
        einheit: Verkaufseinheit(Mengeneinheit.stueck),
      );
      expect(ukPasstZuBelag(_uk('a', premiumSelect, 45, 60), fliese), isFalse);
      // keine Diele als UK
      expect(ukPasstZuBelag(premium, premium), isFalse);
    });

    test('ECO SELECT: auch nur ungetrocknet lieferbare Formate (B-212), '
        'entfallene nicht', () {
      final eco = _diele(ecoSelect);
      expect(ukPasstZuBelag(_uk('a', ecoSelect, 40, 60), eco), isTrue);
      expect(ukPasstZuBelag(_uk('b', ecoSelect, 60, 60), eco), isTrue);
      expect(ukPasstZuBelag(_uk('c', ecoSelect, 60, 90), eco), isFalse);
    });

    test('Lieferlängen: Artikeldaten und UK-Längen der Serie (B-035, '
        'B-230)', () {
      expect(ukLieferlaengen(_uk('a', premiumSelect, 45, 60)), const [
        Millimeter(4000),
        Millimeter(5000),
        Millimeter(6000),
      ]);
      // B-230: ECO-SELECT-UK nur 4/5/6 m, die Dielen bis 7 m
      expect(ukLieferlaengen(_uk('b', ecoSelect, 40, 60)), const [
        Millimeter(4000),
        Millimeter(5000),
        Millimeter(6000),
      ]);
      final alu = _uk(
        '50-20-007',
        null,
        56,
        40,
        art: Artikelart.aluUnterkonstruktion,
      );
      expect(ukLieferlaengen(alu), const [Millimeter(6000)]);
    });

    test('Auswahl in Datenreihenfolge, Vorgabe die erste, Preis je lfm', () {
      final artikel = [
        premium,
        _uk('10-10-031-S', ecoSelect, 40, 60),
        _uk('10-10-031-R', premiumSelect, 45, 60),
        _uk('10-10-039-R', premiumSelect, 45, 70, preis: null),
      ];
      final auswahl = Ukauswahl.fuer('v1', premium, artikel);
      expect(
        [for (final a in auswahl.angebote) a.artikel.nummer.wert],
        ['10-10-031-R', '10-10-039-R'],
      );
      expect(auswahl.vorgabe!.preisJeLfm, const Cent(890));
      expect(auswahl.vorgabe!.preisJeM2, isNull);
      expect(auswahl.angebote.last.preisJeLfm, isNull);
      expect(
        auswahl.gewaehlt(const Artikelnummer('10-10-039-R'))!.artikel.nummer,
        const Artikelnummer('10-10-039-R'),
      );
      // unbekannt oder nicht passend: die Vorgabe
      expect(
        auswahl.gewaehlt(const Artikelnummer('10-10-031-S')),
        auswahl.vorgabe,
      );
      expect(auswahl.gewaehlt(null), auswahl.vorgabe);
      expect(auswahl.angebote.clear, throwsUnsupportedError);
      expect(Ukauswahl.fuer('v1', null, artikel).angebote, isEmpty);
      expect(Ukauswahl.fuer('v1', null, artikel).vorgabe, isNull);
      // JSON hin und zurück
      final zurueck = Ukauswahl.ausJson(auswahl.alsJson(), {
        robinie.id: robinie,
      });
      expect(zurueck.version, 'v1');
      expect([
        for (final a in zurueck.angebote) a.artikel,
      ], auswahl.angebote.map((a) => a.artikel));
      expect(zurueck.vorgabe!.preisJeLfm, const Cent(890));
    });

    test('Preis je lfm nur bei Verkauf je lfm, je Einheit', () {
      expect(
        Belagangebot.jeLfm(
          _uk(
            'a',
            null,
            1,
            1,
            art: Artikelart.aluUnterkonstruktion,
            einheit: Mengeneinheit.stueck,
          ),
        ).preisJeLfm,
        isNull,
      );
      final paket = Artikel(
        nummer: const Artikelnummer('x'),
        titel: 'x',
        art: Artikelart.aluUnterkonstruktion,
        einheit: Verkaufseinheit(Mengeneinheit.laufmeter, inhalt: 4),
        preisBrutto: const Cent(1000),
      );
      expect(Belagangebot.jeLfm(paket).preisJeLfm, const Cent(250));
    });
  });

  group('Planungsstand mit UK und UK-Länge (M6-03)', () {
    const start = Planungsstand.start;

    test('Vorgabe: erste passende UK, Länge automatisch', () {
      expect(start.unterkonstruktion, isNull);
      expect(start.ukLaenge, isNull);
    });

    test('ändern, Gleichheit, Hash; bleiben bei anderen Änderungen', () {
      final uk = start.mitUnterkonstruktion(const Artikelnummer('10-10-039-R'));
      expect(uk.unterkonstruktion, const Artikelnummer('10-10-039-R'));
      expect(uk == start, isFalse);
      expect(uk.hashCode == start.hashCode, isFalse);
      final lang = uk.mitUkLaenge(const Millimeter(5000));
      expect(lang.ukLaenge, const Millimeter(5000));
      expect(lang.unterkonstruktion, const Artikelnummer('10-10-039-R'));
      expect(lang == uk, isFalse);
      expect(lang.hashCode == uk.hashCode, isFalse);
      expect(lang.mitUkLaenge(null), uk);
      for (final s in [
        lang.mitBelag(const Artikelnummer('10-10-146')),
        lang.mitTerrassenart(Terrassenart.hochterrasse),
        lang.mitGefaelle(true),
        lang.mitHoehe(const Millimeter(100)),
        lang.mitDielenlaenge(const Millimeter(4000)),
        lang.mitForm(Terrassenform.lForm),
      ]) {
        expect(s.unterkonstruktion, const Artikelnummer('10-10-039-R'));
        expect(s.ukLaenge, const Millimeter(5000));
      }
      expect(
        lang.mitUnterkonstruktion(const Artikelnummer('10-10-031-R')).ukLaenge,
        const Millimeter(5000),
      );
    });

    test('Transport hin und zurück; fehlende Felder sind die Vorgabe', () {
      final stand = start
          .mitUnterkonstruktion(const Artikelnummer('10-10-039-R'))
          .mitUkLaenge(const Millimeter(4000));
      expect(Planungsstand.ausBytes(stand.zuBytes()), stand);
      expect(Planungsstand.ausBytes(_alt()), start);
      final gelesen = Planungsstand.ausBytes(
        _alt(uk: '10-10-031-R', laenge: 6000),
      );
      expect(gelesen.unterkonstruktion, const Artikelnummer('10-10-031-R'));
      expect(gelesen.ukLaenge, const Millimeter(6000));
    });
  });
}
