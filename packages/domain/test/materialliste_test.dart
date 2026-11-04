import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

import 'argument_fehler.dart';

const _m4 = Millimeter(4000);
const _m5 = Millimeter(5000);

Artikel _diele({
  String nummer = '10-10-073-R',
  int? preis = 1290,
  num inhalt = 1,
  Mengeneinheit einheit = Mengeneinheit.laufmeter,
  Artikelart art = Artikelart.diele,
}) => Artikel(
  nummer: Artikelnummer(nummer),
  titel: 'Terrassendiele Robinie $nummer',
  art: art,
  einheit: Verkaufseinheit(einheit, inhalt: inhalt),
  abmessungen: Abmessungen(
    breite: const Millimeter(60),
    laengen: const [_m4, _m5],
  ),
  preisBrutto: preis == null ? null : Cent(preis),
  holzart: art.istHolz ? robinie : null,
  serie: art.istHolz ? premiumSelect : null,
  bilder: const ['Diele_60x21.jpg'],
);

Artikel _clip(String vpe, int inhalt, int preis) => Artikel(
  nummer: Artikelnummer('80-10-001-$vpe'),
  titel: 'CLIP-FIXX® "BLACK EDITION" - VPE $vpe',
  art: Artikelart.clip,
  einheit: Verkaufseinheit(Mengeneinheit.verpackungseinheit, inhalt: inhalt),
  preisBrutto: Cent(preis),
);

final _clips = [_clip('50', 50, 2500), _clip('100', 100, 4500)];

final _montagehilfe = Artikel(
  nummer: const Artikelnummer('50-80-009'),
  titel: 'ALTO Montagehilfe Abstandshalter, VPE zu 4 Stück',
  art: Artikelart.werkzeug,
  einheit: Verkaufseinheit(Mengeneinheit.set),
  preisBrutto: const Cent(1999),
);

/// UK-Holz je Stück verkauft (M6 liefert solche Bedarfe).
final _uk = Artikel(
  nummer: const Artikelnummer('10-10-031-S'),
  titel: 'Unterkonstruktionsholz Robinie 40 x 60 mm',
  art: Artikelart.unterkonstruktion,
  einheit: Verkaufseinheit(Mengeneinheit.stueck),
  abmessungen: Abmessungen(laengen: const [_m4]),
  preisBrutto: const Cent(2999),
  holzart: robinie,
  serie: ecoSelect,
);

void main() {
  group('Materialbedarf (M9-03)', () {
    test('braucht Einheiten; ein Stück mit Länge genau einen Artikel', () {
      expect(
        () => Materialbedarf(const [], 1),
        wirftArgumentFehler('einheiten', const <Artikel>[], 'mindestens eine'),
      );
      expect(
        () => Materialbedarf(_clips, 1, laenge: _m5),
        wirftArgumentFehler(
          'einheiten',
          _clips,
          'ein Stück mit Länge hat genau einen Artikel',
        ),
      );
      expect(
        () => Materialbedarf([_diele()], -1),
        wirftArgumentFehler('stueck', -1, 'nicht negativ'),
      );
      expect(Materialbedarf([_diele()], 0).stueck, 0);
    });

    test('Häufigkeit vervielfacht, ein Bedarf je Planung bleibt (M4-14)', () {
      final b =
          Materialbedarf(
            [_diele()],
            3,
            laenge: _m5,
            zusatz: Materialzusatz.freidiele,
          ) *
          4;
      expect(b.stueck, 12);
      expect(b.laenge, _m5);
      expect(b.zusatz, Materialzusatz.freidiele);
      expect(b.jePlanung, isFalse);
      final einmal = Materialbedarf([_montagehilfe], 1, jePlanung: true);
      expect(identical(einmal * 5, einmal), isTrue);
      expect('$b', '12 × 10-10-073-R Terrassendiele Robinie 10-10-073-R');
    });

    test('Einheiten unveränderlich', () {
      final b = Materialbedarf(_clips, 637);
      expect(() => b.einheiten.add(_montagehilfe), throwsUnsupportedError);
    });
  });

  group('Materialliste (M9-03)', () {
    test('Dielen je Stück und Länge, Preise je lfm (B-055 nur Anzeige)', () {
      final liste = Materialliste.aus([
        Materialbedarf([_diele()], 48, laenge: _m5),
      ]);
      final p = liste.positionen.single;
      expect(p.position, 1);
      expect(p.nummer, const Artikelnummer('10-10-073-R'));
      expect(p.titel, 'Terrassendiele Robinie 10-10-073-R');
      expect(p.bild, 'Diele_60x21.jpg');
      expect(p.bereich, Bereich.belag);
      expect(p.einheit, Mengeneinheit.stueck);
      expect(p.laenge, _m5);
      expect(p.anzahl, 48);
      expect(p.berechnet, isNull);
      expect(p.zusatz, isNull);
      // 12,90 €/lfm × 5 m = 64,50 € je Diele, 240 lfm = 3.096,00 €
      expect(p.preisJeLfm, const Cent(1290));
      expect(p.einzelpreis, const Cent(6450));
      expect(p.positionspreis, const Cent(309600));
      expect(p.gesamtlaenge, const Millimeter(240000));
      expect(liste.summe, const Cent(309600));
      // 3.096,00 € brutto → 2.601,68 € netto, 494,32 € MwSt.
      expect(liste.mehrwertsteuer, const Cent(49432));
      expect(liste.vollstaendig, isTrue);
      expect(liste.istLeer, isFalse);
    });

    test('je lfm: Positionspreis aus den Gesamt-lfm, einmal gerundet', () {
      // 25,01 € für 2 lfm: 12,505 €/lfm
      final diele = _diele(preis: 2501, inhalt: 2);
      final p = Materialliste.aus([
        Materialbedarf([diele], 3, laenge: const Millimeter(4500)),
      ]).positionen.single;
      // 12,505 × 4,5 = 56,2725 → 56,27 €; 12,505 × 13,5 = 168,8175 → 168,82 €
      expect(p.preisJeLfm, const Cent(1251));
      expect(p.einzelpreis, const Cent(5627));
      expect(p.positionspreis, const Cent(16882));
      expect(p.gesamtlaenge, const Millimeter(13500));
    });

    test('Stückware mit Länge: Einzelpreis je Stück, Preis je lfm', () {
      final p = Materialliste.aus([
        Materialbedarf([_uk], 13, laenge: _m4),
      ]).positionen.single;
      expect(p.bereich, Bereich.unterkonstruktion);
      expect(p.einheit, Mengeneinheit.stueck);
      expect(p.einzelpreis, const Cent(2999));
      expect(p.positionspreis, const Cent(38987));
      // 29,99 € ÷ 4 m = 7,4975 → 7,50 €/lfm
      expect(p.preisJeLfm, const Cent(750));
      expect(p.gesamtlaenge, const Millimeter(52000));
    });

    test('Verkaufseinheiten erst über alle Flächen verpackt (F01: 637 '
        'Clips)', () {
      final liste = Materialliste.aus([
        Materialbedarf(_clips, 300),
        Materialbedarf(_clips, 337),
      ]);
      // 650 Clips: 6 × VPE 100 + 1 × VPE 50 (wenig Überhang, wenig Packungen)
      expect(
        [for (final p in liste.positionen) (p.nummer.wert, p.anzahl)],
        [('80-10-001-100', 6), ('80-10-001-50', 1)],
      );
      final vpe = liste.positionen.first;
      expect(vpe.einheit, Mengeneinheit.verpackungseinheit);
      expect(vpe.laenge, isNull);
      expect(vpe.einzelpreis, const Cent(4500));
      expect(vpe.positionspreis, const Cent(27000));
      expect(vpe.preisJeLfm, isNull);
      expect(vpe.gesamtlaenge, isNull);
      expect(liste.summe, const Cent(29500));
    });

    test('ein Bedarf je Planung zählt einmal (Montagehilfe)', () {
      final einmal = Materialbedarf([_montagehilfe], 1, jePlanung: true);
      final zwei = Materialbedarf([_montagehilfe], 2, jePlanung: true);
      expect(
        Materialliste.aus([einmal, zwei, einmal]).positionen.single.anzahl,
        2,
      );
      expect(Materialliste.aus([zwei, einmal]).positionen.single.anzahl, 2);
      // ohne „je Planung“ eigene Gruppe, dort wird addiert
      expect(
        Materialliste.aus([
          einmal,
          Materialbedarf([_montagehilfe], 1),
          Materialbedarf([_montagehilfe], 1),
        ]).positionen.single.anzahl,
        3,
      );
    });

    test('gleiche Position aus mehreren Flächen addiert, 0 Stück entfällt', () {
      final liste = Materialliste.aus([
        Materialbedarf([_diele()], 10, laenge: _m5),
        Materialbedarf([_diele()], 0, laenge: _m4),
        Materialbedarf([_diele()], 5, laenge: _m5) * 2,
        Materialbedarf(_clips, 0),
      ]);
      expect(liste.positionen.single.anzahl, 20);
      expect(Materialliste.aus(const []).istLeer, isTrue);
    });

    test('Reihenfolge: Bereich, Artikelnummer, Länge, Zusatz', () {
      final andere = _diele(nummer: '10-10-001');
      final liste = Materialliste.aus([
        Materialbedarf([_montagehilfe], 1),
        Materialbedarf(_clips, 50),
        Materialbedarf([_uk], 2, laenge: _m4),
        Materialbedarf(
          [_diele()],
          1,
          laenge: _m5,
          zusatz: Materialzusatz.freidiele,
        ),
        Materialbedarf([_diele()], 2, laenge: _m5),
        Materialbedarf([_diele()], 3, laenge: _m4),
        Materialbedarf([andere], 4, laenge: _m5),
      ]);
      expect(
        [
          for (final p in liste.positionen)
            (p.position, p.nummer.wert, p.laenge?.mm, p.zusatz),
        ],
        [
          (1, '10-10-001', 5000, null),
          (2, '10-10-073-R', 4000, null),
          (3, '10-10-073-R', 5000, null),
          (4, '10-10-073-R', 5000, Materialzusatz.freidiele),
          (5, '10-10-031-S', 4000, null),
          (6, '80-10-001-50', null, null),
          (7, '50-80-009', null, null),
        ],
      );
      // Freidielen kosten nichts (B-079)
      final frei = liste.positionen[3];
      expect(frei.einzelpreis, const Cent(0));
      expect(frei.positionspreis, const Cent(0));
      expect(frei.preisJeLfm, const Cent(0));
      expect(frei.gesamtlaenge, const Millimeter(5000));
    });

    test('Freidiele ohne Länge: kein Preis je lfm', () {
      final p = Materialliste.aus([
        Materialbedarf([_montagehilfe], 1, zusatz: Materialzusatz.freidiele),
      ]).positionen.single;
      expect(p.positionspreis, const Cent(0));
      expect(p.preisJeLfm, isNull);
    });

    test('Artikel ohne Preis: Position ohne Preise, Summe unvollständig', () {
      final liste = Materialliste.aus([
        Materialbedarf([_diele(preis: null)], 2, laenge: _m5),
        Materialbedarf([_montagehilfe], 1),
      ]);
      final ohne = liste.positionen.first;
      expect(ohne.einzelpreis, isNull);
      expect(ohne.positionspreis, isNull);
      expect(ohne.preisJeLfm, isNull);
      expect(ohne.gesamtlaenge, const Millimeter(10000));
      expect(liste.summe, const Cent(1999));
      expect(liste.vollstaendig, isFalse);
    });

    test('Holzfliese je Stück, nicht je lfm (Fehler F25 nicht übernommen)', () {
      final fliese = _diele(
        nummer: '40-10-001',
        preis: 1590,
        einheit: Mengeneinheit.stueck,
        art: Artikelart.holzfliese,
      );
      final p = Materialliste.aus([
        Materialbedarf([fliese], 48, laenge: const Millimeter(606)),
      ]).positionen.single;
      expect(p.einzelpreis, const Cent(1590));
      expect(p.positionspreis, const Cent(76320));
    });

    test('geänderte Mengen der Mitarbeiter-Ansicht (R-D04)', () {
      final bedarfe = [
        Materialbedarf([_diele()], 48, laenge: _m5),
        Materialbedarf(_clips, 637),
      ];
      const diele = (
        nummer: Artikelnummer('10-10-073-R'),
        laenge: _m5,
        zusatz: null,
      );
      const vpe50 = (
        nummer: Artikelnummer('80-10-001-50'),
        laenge: null,
        zusatz: null,
      );
      const weg = (
        nummer: Artikelnummer('99-99-999'),
        laenge: null,
        zusatz: null,
      );
      final liste = Materialliste.aus(
        bedarfe,
        mengen: {diele: 50, vpe50: 0, weg: 3},
      );
      final (d, c100, c50) = (
        liste.positionen[0],
        liste.positionen[1],
        liste.positionen[2],
      );
      expect(d.schluessel, diele);
      expect(d.anzahl, 50);
      expect(d.berechnet, 48);
      expect(d.positionspreis, const Cent(322500));
      expect(c100.berechnet, isNull);
      // abgewählt: Menge 0, kein Betrag
      expect(c50.anzahl, 0);
      expect(c50.berechnet, 1);
      expect(c50.positionspreis, const Cent(0));
      expect(liste.positionen, hasLength(3));
      // gleich der berechneten: keine Änderung sichtbar
      expect(
        Materialliste.aus(bedarfe, mengen: {diele: 48}).positionen[0].berechnet,
        isNull,
      );
    });

    test('enthaltene Mehrwertsteuer 19 %: Netto + Steuer = Brutto', () {
      expect(mehrwertsteuerSatz, 19);
      // Grundfall des alten Planers: 2.066,57 €
      expect(enthalteneMehrwertsteuer(const Cent(206657)), const Cent(32996));
      expect(enthalteneMehrwertsteuer(const Cent(119)), const Cent(19));
      expect(enthalteneMehrwertsteuer(const Cent(1)), const Cent(0));
      expect(enthalteneMehrwertsteuer(const Cent(0)), const Cent(0));
    });

    test('Zeile: Gleichheit, Text, Schlüssel', () {
      Materialzeile zeile({int anzahl = 2}) => Materialzeile(
        position: 1,
        nummer: const Artikelnummer('1'),
        titel: 'T',
        bereich: Bereich.zubehoer,
        einheit: Mengeneinheit.karton,
        anzahl: anzahl,
      );
      expect(zeile(), zeile());
      expect(zeile().hashCode, zeile().hashCode);
      expect(zeile(), isNot(zeile(anzahl: 3)));
      expect(zeile(), isNot(Object()));
      expect('${zeile()}', '1. 2 Karton 1 T');
      expect(zeile().schluessel, (
        nummer: const Artikelnummer('1'),
        laenge: null,
        zusatz: null,
      ));
    });

    test('Liste: Gleichheit', () {
      Materialliste liste([int stueck = 48]) => Materialliste.aus([
        Materialbedarf([_diele()], stueck, laenge: _m5),
      ]);
      expect(liste(), liste());
      expect(liste().hashCode, liste().hashCode);
      expect(liste(), isNot(liste(47)));
      expect(liste(), isNot(Materialliste.leer));
      expect(Materialliste.leer, isNot(Object()));
      final ohneSumme = Materialliste(
        liste().positionen,
        summe: const Cent(1),
        mehrwertsteuer: liste().mehrwertsteuer,
      );
      expect(ohneSumme, isNot(liste()));
      final ohneSteuer = Materialliste(
        liste().positionen,
        summe: liste().summe,
        mehrwertsteuer: const Cent(1),
      );
      expect(ohneSteuer, isNot(liste()));
      final unvollstaendig = Materialliste(
        liste().positionen,
        summe: liste().summe,
        mehrwertsteuer: liste().mehrwertsteuer,
        vollstaendig: false,
      );
      expect(unvollstaendig, isNot(liste()));
      expect(
        () => liste().positionen.add(liste().positionen.first),
        throwsUnsupportedError,
      );
    });

    test('Zusatz im Transportformat', () {
      expect(Materialzusatz.freidiele.nummer, 1);
      expect(Materialzusatz.ausNummer(1), Materialzusatz.freidiele);
      expect(Materialzusatz.ausNummer(0), isNull);
      expect(Materialzusatz.ausNummer(9), isNull);
    });

    test('Transport: alle Felder, auch fehlende Werte', () {
      final liste = Materialliste.aus(
        [
          Materialbedarf([_diele()], 48, laenge: _m5),
          Materialbedarf(
            [_diele()],
            1,
            laenge: _m5,
            zusatz: Materialzusatz.freidiele,
          ),
          Materialbedarf([_diele(nummer: '1', preis: null)], 2, laenge: _m4),
          Materialbedarf(_clips, 637),
          Materialbedarf([_montagehilfe], 1, jePlanung: true),
        ],
        mengen: {
          (
            nummer: const Artikelnummer('50-80-009'),
            laenge: null,
            zusatz: null,
          ): 2,
        },
      );
      final fbb = fb.Builder();
      fbb.finish(liste.schreibe(fbb));
      final puffer = fb.BufferContext.fromBytes(fbb.buffer);
      final gelesen = Materialliste.lies(puffer, puffer.derefObject(0));
      expect(gelesen, liste);
      expect(gelesen.vollstaendig, isFalse);
      expect(gelesen.positionen.last.berechnet, 1);
      expect(gelesen.positionen[3].bild, isNull);
    });

    test('Transport: leere Tabelle gibt eine leere Liste', () {
      final fbb = fb.Builder()..startTable(0);
      fbb.finish(fbb.endTable());
      final puffer = fb.BufferContext.fromBytes(fbb.buffer);
      final gelesen = Materialliste.lies(puffer, puffer.derefObject(0));
      expect(gelesen, Materialliste.leer);
      expect(gelesen.vollstaendig, isTrue);
    });

    test('in der Berechnung auf Platz 60', () {
      final liste = Materialliste.aus([
        Materialbedarf([_diele()], 48, laenge: _m5),
      ]);
      final b = Berechnung(umriss: const [], flaeche: 1, materialliste: liste);
      expect(Berechnung.ausBytes(b.zuBytes()).materialliste, liste);
      expect(b.mitPlanung(2).materialliste, Materialliste.leer);
      expect(b.mitPlanung(2, materialliste: liste).materialliste, liste);
      // ohne Platz 60 (ältere Server): leer
      final fbb = fb.Builder()..startTable(0);
      fbb.finish(fbb.endTable());
      expect(Berechnung.ausBytes(fbb.buffer).materialliste, Materialliste.leer);
      expect(
        Berechnung(umriss: const [], flaeche: 1).materialliste,
        Materialliste.leer,
      );
    });
  });
}
