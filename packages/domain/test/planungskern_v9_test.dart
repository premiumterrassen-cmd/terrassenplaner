// Planungsregeln Alexander (Planungskern v9, 12.11.2026), Regel 11.1:
// Vorgabe Dielenlänge höchstens/mindestens (R-B19).
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

import 'altplaner.dart';

const _m3 = Millimeter(3000);
const _m4 = Millimeter(4000);
const _m5 = Millimeter(5000);
const _m6 = Millimeter(6000);

Artikel _artikel(
  Artikelart art, {
  List<Millimeter> laengen = const [_m4, _m5, _m6],
  Profil profil = Profil.genutet,
}) => Artikel(
  nummer: Artikelnummer('10-10-${art.index}'),
  titel: 'Artikel ${art.name}',
  art: art,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  abmessungen: Abmessungen(
    breite: const Millimeter(60),
    staerke: const Millimeter(21),
    laengen: laengen,
  ),
  holzart: art.istHolz ? robinie : null,
  serie: art.istHolz ? basic : null,
  profil: art.istHolz ? profil : null,
);

final _diele = _artikel(Artikelart.diele);

Map<int, int> _anzahl(Dielenliste liste) => {
  for (final MapEntry(:key, :value) in liste.anzahl.entries) key.mm: value,
};

Planungsstand _rechteck(int ab, int bc) =>
    Planungsstand(grundriss: RechteckGrundriss(Millimeter(ab), Millimeter(bc)));

void main() {
  group('Vorgabe Dielenlänge (Regel 11.1, R-B19)', () {
    test('Längen innerhalb der Grenzen, Grenzen eingeschlossen', () {
      const alle = [_m3, _m4, _m5, _m6];
      expect(laengenInVorgabe(alle), alle);
      expect(laengenInVorgabe(alle, hoechstens: _m5), [_m3, _m4, _m5]);
      expect(laengenInVorgabe(alle, mindestens: _m4), [_m4, _m5, _m6]);
      expect(laengenInVorgabe(alle, hoechstens: _m5, mindestens: _m4), [
        _m4,
        _m5,
      ]);
      expect(laengenInVorgabe(alle, hoechstens: const Millimeter(2999)), [
        for (final _ in <int>[]) _m3,
      ]);
      expect(laengenInVorgabe(alle, mindestens: const Millimeter(6001)), [
        for (final _ in <int>[]) _m3,
      ]);
    });

    test('gilt für Dielen und Blenden, nicht für UK, MASSIV und Fliesen', () {
      expect(laengenvorgabeGilt(_diele), isTrue);
      expect(laengenvorgabeGilt(_artikel(Artikelart.verblendung)), isTrue);
      for (final art in [
        Artikelart.systemdiele,
        Artikelart.unterkonstruktion,
        Artikelart.holzfliese,
      ]) {
        final a = _artikel(art);
        expect(laengenvorgabeGilt(a), isFalse);
        expect(
          lieferlaengenNachVorgabe(a, const [_m4, _m5, _m6], hoechstens: _m4),
          const [_m4, _m5, _m6],
        );
        expect(
          laengenvorgabeNichtErfuellbar(a, const [_m4], hoechstens: _m3),
          isFalse,
        );
      }
    });

    test('passende Lieferlängen; passt keine, alle (Hinweis)', () {
      const alle = [_m4, _m5, _m6];
      expect(lieferlaengenNachVorgabe(_diele, alle, hoechstens: _m5), [
        _m4,
        _m5,
      ]);
      expect(lieferlaengenNachVorgabe(_diele, alle, hoechstens: _m3), alle);
      expect(
        laengenvorgabeNichtErfuellbar(_diele, alle, hoechstens: _m3),
        isTrue,
      );
      expect(
        laengenvorgabeNichtErfuellbar(_diele, alle, hoechstens: _m4),
        isFalse,
      );
      // ohne Vorgabe immer erfüllt, ohne Lieferlängen nie ein Hinweis
      expect(laengenvorgabeNichtErfuellbar(_diele, alle), isFalse);
      expect(
        laengenvorgabeNichtErfuellbar(_diele, const [], hoechstens: _m3),
        isFalse,
      );
    });

    test('Planungsstand: Plätze 14/15, Gleichheit, Hash, bleibt bei '
        'Änderungen', () {
      const start = Planungsstand.start;
      expect(start.dielenlaengeHoechstens, isNull);
      expect(start.dielenlaengeMindestens, isNull);
      final hoch = start.mitDielenlaengeHoechstens(_m5);
      final tief = start.mitDielenlaengeMindestens(_m4);
      final beide = hoch.mitDielenlaengeMindestens(_m4);
      expect(hoch.dielenlaengeHoechstens, _m5);
      expect(tief.dielenlaengeMindestens, _m4);
      expect(beide.dielenlaengeHoechstens, _m5);
      expect(beide.dielenlaengeMindestens, _m4);
      for (final s in [hoch, tief]) {
        expect(s == start, isFalse);
        expect(s.hashCode == start.hashCode, isFalse);
        expect(Planungsstand.ausBytes(s.zuBytes()), s);
      }
      expect(hoch == tief, isFalse);
      expect(Planungsstand.ausBytes(beide.zuBytes()), beide);
      expect(Planungsstand.ausBytes(start.zuBytes()), start);
      expect(
        Planungsstand.ausBytes(start.zuBytes()).dielenlaengeHoechstens,
        isNull,
      );
      expect(hoch.mitDielenlaengeHoechstens(null), start);
      expect(tief.mitDielenlaengeMindestens(null), start);
      for (final s in [
        beide.mitDielenlaenge(_m4),
        beide.mitBelag(const Artikelnummer('10-10-060-R')),
        beide.mitKurzeStueckeVerbinden(true),
        beide.gedreht(90),
      ]) {
        expect(s.dielenlaengeHoechstens, _m5);
        expect(s.dielenlaengeMindestens, _m4);
      }
      expect(beide.vorgabelaengen(_diele, const [_m4, _m5, _m6]), [_m4, _m5]);
    });

    test('Belag: nur die passenden Längen, die erzwungene Länge geht vor', () {
      // F09: 8 m automatisch 600 + 200 cm
      final stand = _rechteck(8000, 3090);
      Belagverlegung verlegt(Planungsstand s) => verlegeBelag(
        s,
        _diele,
        fuge: altplanerFuge,
        dielenmuster: altplanerMuster,
      )!;
      expect(_anzahl(verlegt(stand).dielenliste), {4000: 24, 6000: 48});
      final hoechstens5 = verlegt(stand.mitDielenlaengeHoechstens(_m5));
      expect(hoechstens5.laengste, _m5);
      expect(
        hoechstens5.dielenliste.anzahl.keys.every((l) => l <= _m5),
        isTrue,
      );
      final mindestens5 = verlegt(stand.mitDielenlaengeMindestens(_m5));
      expect(
        mindestens5.dielenliste.anzahl.keys.every((l) => l >= _m5),
        isTrue,
      );
      // erzwungene Länge vor der Vorgabe
      expect(
        _anzahl(
          verlegt(stand.mitDielenlaengeHoechstens(_m5).mitDielenlaenge(_m6))
              .dielenliste,
        ).keys,
        [6000],
      );
      // nicht erfüllbar: alle Lagerlängen wie ohne Vorgabe
      expect(
        _anzahl(
          verlegt(stand.mitDielenlaengeHoechstens(const Millimeter(3500)))
              .dielenliste,
        ),
        {4000: 24, 6000: 48},
      );
    });

    test('Hinweis in den Meldungen nur, wenn nicht erfüllbar und keine '
        'erzwungene Länge gilt', () {
      final stand = _rechteck(4000, 3000);
      List<Belagmeldung> meldungen(Planungsstand s, [Artikel? belag]) =>
          belagmeldungen(s, belag ?? _diele, null);
      expect(
        meldungen(stand.mitDielenlaengeHoechstens(_m3)),
        contains(Belagmeldung.laengenvorgabeNichtErfuellbar),
      );
      expect(
        meldungen(stand.mitDielenlaengeMindestens(const Millimeter(7000))),
        contains(Belagmeldung.laengenvorgabeNichtErfuellbar),
      );
      expect(
        meldungen(stand.mitDielenlaengeHoechstens(_m4)),
        isNot(contains(Belagmeldung.laengenvorgabeNichtErfuellbar)),
      );
      // erzwungene, lieferbare Länge: die Vorgabe zählt nicht
      expect(
        meldungen(stand.mitDielenlaengeHoechstens(_m3).mitDielenlaenge(_m4)),
        isNot(contains(Belagmeldung.laengenvorgabeNichtErfuellbar)),
      );
      // erzwungene Länge nicht lieferbar: Automatik mit Vorgabe
      expect(
        meldungen(
          stand
              .mitDielenlaengeHoechstens(_m3)
              .mitDielenlaenge(const Millimeter(7000)),
        ),
        containsAll([
          Belagmeldung.laengeNichtLieferbar,
          Belagmeldung.laengenvorgabeNichtErfuellbar,
        ]),
      );
      // MASSIV: Längenmix, keine Vorgabe
      expect(
        meldungen(
          stand.mitDielenlaengeHoechstens(_m3),
          _artikel(Artikelart.systemdiele),
        ),
        isNot(contains(Belagmeldung.laengenvorgabeNichtErfuellbar)),
      );
      expect(Belagmeldung.laengenvorgabeNichtErfuellbar.unterpunkt, 1);
      expect(Belagmeldung.laengenvorgabeNichtErfuellbar.warnung, isFalse);
      expect(Belagmeldung.laengenvorgabeNichtErfuellbar.nummer, 10);
      expect(
        Unterlagentexte.deutsch.belagmeldung(
          Belagmeldung.laengenvorgabeNichtErfuellbar,
          null,
        ),
        'Keine Lieferlänge dieses Belags erfüllt die Vorgabe Dielenlänge. '
        'Geplant wird mit allen Lagerlängen.',
      );
      expect(
        Unterlagentexte.englisch.belagmeldung(
          Belagmeldung.laengenvorgabeNichtErfuellbar,
          null,
        ),
        startsWith('No delivery length'),
      );
    });

    test('Treppe: Dielen in den Längen der Vorgabe', () {
      final stand = Planungsstand.start.mitNeuerTreppe().mitTreppe(
        0,
        const Treppe(seite: 2),
      );
      final ohne = treppenbedarf(stand, belag: _diele);
      expect(ohne.bedarf, isNotEmpty);
      final mit = treppenbedarf(
        stand.mitDielenlaengeHoechstens(_m4),
        belag: _diele,
      );
      expect(mit.bedarf, isNotEmpty);
      expect(mit.bedarf.every((m) => m.laenge == _m4), isTrue);
      final mindestens = treppenbedarf(
        stand.mitDielenlaengeMindestens(_m6),
        belag: _diele,
      );
      expect(mindestens.bedarf.every((m) => m.laenge == _m6), isTrue);
    });

    test('Blende: Bretter in den Längen der Vorgabe, nicht die UK', () {
      final belag = _diele;
      final blende = Artikel(
        nummer: const Artikelnummer('blende-80'),
        titel: 'Blende 80',
        art: Artikelart.diele,
        einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
        abmessungen: Abmessungen(
          breite: const Millimeter(80),
          staerke: const Millimeter(21),
          laengen: const [_m4, _m5, _m6],
        ),
        holzart: robinie,
        serie: basic,
        profil: Profil.glattkant,
      );
      final regelwerk = Regelwerk(
        Artikeldatei(
          quelle: 'test',
          version: '1',
          eintraege: [
            Artikeleintrag(artikel: belag),
            Artikeleintrag(artikel: blende),
          ],
        ),
      );
      final stand = Planungsstand.start
          .mitAngrenzend(0, an: true)
          .mitVerblendet(1, an: true)
          .mitVerblendet(2, an: true)
          .mitVerblendet(3, an: true);
      const hoehen = [
        Millimeter(86),
        Millimeter(86),
        Millimeter(86),
        Millimeter(86),
      ];
      List<Millimeter?> laengen(Planungsstand s) => [
        for (final m in verblendungsbedarf(
          s,
          hoehen: hoehen,
          belag: belag,
          regelwerk: regelwerk,
        ).bedarf)
          if (m.zusatz == Materialzusatz.verblendung) m.laenge,
      ];
      // F37: 4850 mm braucht ohne Vorgabe ein 5-m-Brett
      expect(laengen(stand), contains(_m5));
      final mit = laengen(stand.mitDielenlaengeHoechstens(_m4));
      expect(mit, isNotEmpty);
      expect(mit.every((l) => l! <= _m4), isTrue);
    });
  });
}
