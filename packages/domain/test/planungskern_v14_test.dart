// Planungsregeln Alexander (Planungskern v14, 13.11.2026), Regel 16.2:
// Schutzband KOPPLEX-1 und Unterleger KOPPLEX-3 nach Lieferland (R-C70,
// R-C71).
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

import 'altplaner.dart';
import 'auflagerdaten.dart';

Artikel _band(String nummer, String titel, {int? laenge, int inhalt = 1}) =>
    Artikel(
      nummer: Artikelnummer(nummer),
      titel: titel,
      art: Artikelart.gummiband,
      einheit: Verkaufseinheit(Mengeneinheit.stueck, inhalt: inhalt),
      abmessungen: Abmessungen(
        laengen: [?(laenge == null ? null : Millimeter(laenge))],
      ),
    );

final _gumoK = _band(
  'k-120',
  'Schutzband GUMO K 75 mm, selbstklebend, 10 Rollen à 10 m',
  laenge: 10000,
);
final _kopplex1kurz = _band(
  'k-001',
  'KOPPLEX-1, EPDM-Vollgummi, 10m-Rolle 75mm x 1mm',
);
final _kopplex1lang = _band(
  'k-007',
  'KOPPLEX-1, EPDM-Vollgummi, 20m-Rolle 75mm x 1mm',
);
final _kopplex3 = _band(
  'k-003',
  'KOPPLEX-3, EPDM-Vollgummi, 10m-Rolle 40mm x 3mm',
);
final _kopplexOhneLaenge = _band('k-009', 'KOPPLEX-1 Rest');
final _kopplexWerkzeug = Artikel(
  nummer: const Artikelnummer('k-010'),
  titel: 'KOPPLEX-1 Abroller, 10m-Rolle',
  art: Artikelart.werkzeug,
  einheit: Verkaufseinheit(Mengeneinheit.stueck),
);

final _diele = Artikel(
  nummer: const Artikelnummer('10-10-073-R'),
  titel: 'Diele',
  art: Artikelart.diele,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  abmessungen: Abmessungen(
    breite: const Millimeter(60),
    staerke: const Millimeter(23),
    laengen: const [Millimeter(4000), Millimeter(5000), Millimeter(6000)],
  ),
  holzart: robinie,
  serie: premiumSelect,
  profil: Profil.genutet,
);

Regelwerk _regelwerk(List<Artikel> weitere) => Regelwerk(
  Artikeldatei(
    quelle: 'test',
    version: '1',
    eintraege: [
      Artikeleintrag(
        artikel: _diele,
        verweise: {
          Beziehung.zubehoer.spalte: [_gumoK.nummer],
        },
        angaben: const {'Abstand_UK': 400},
      ),
      Artikeleintrag(artikel: _gumoK),
      for (final a in weitere) Artikeleintrag(artikel: a),
    ],
  ),
);

final _mitKopplex = _regelwerk([
  _kopplexOhneLaenge,
  _kopplexWerkzeug,
  _kopplex1lang,
  _kopplex3,
  _kopplex1kurz,
]);

List<Dielenstueck> _verlegt() => verlegeDielen(
  Kontur.rechteck(4800, 3090),
  winkel: 0,
  ausgangspunkt: Punkt.ursprung,
  dielenbreite: const Millimeter(60),
  verlegeart: Verlegeart.fugenschnitt,
  laengste: const Millimeter(6000),
  fuge: altplanerFuge,
);

Map<String, int> _band40m(Regelwerk r, [Lieferland? land]) => {
  for (final MapEntry(:key, :value)
      in (land == null
              ? berechnetesZubehoer(
                  r,
                  _diele,
                  Befestigungsbedarf.keiner,
                  _verlegt(),
                  winkel: 0,
                  oelflaeche: 0,
                )
              : berechnetesZubehoer(
                  r,
                  _diele,
                  Befestigungsbedarf.keiner,
                  _verlegt(),
                  winkel: 0,
                  oelflaeche: 0,
                  lieferland: land,
                ))
          .entries)
    key.wert: value,
};

void main() {
  group('Lieferland und Bandlänge (Planungskern v14, Regel 16.2)', () {
    test('KOPPLEX außer in die Schweiz; ohne Angabe Deutschland', () {
      expect(Lieferland.deutschland.mitKopplex, isTrue);
      expect(Lieferland.oesterreich.mitKopplex, isTrue);
      expect(Lieferland.schweiz.mitKopplex, isFalse);
      expect(standardLieferland, Lieferland.deutschland);
      expect(unterlegbandJeAuflager, const Millimeter(80));
      expect(unterlegbandStattPadsUnter, const Millimeter(8));
    });

    test('Bandlänge aus der Länge der Artikeldaten oder „m-Rolle“ im Titel, '
        'mal Rollen im Karton', () {
      expect(bandlaenge(_gumoK), 100000);
      expect(bandlaenge(_kopplex1kurz), 10000);
      expect(bandlaenge(_kopplex1lang), 20000);
      expect(bandlaenge(_band('x', '5 Rollen à 20m-Rolle')), 100000);
      expect(bandlaenge(_band('x', 'Band 12 m-Rolle', laenge: 3000)), 3000);
      expect(bandlaenge(_kopplexOhneLaenge), isNull);
    });

    test('KOPPLEX-1 und -3 aus den Artikeldaten, am Titel erkannt; Schweiz '
        'und fehlende Artikel: keins', () {
      expect(schutzbandKopplex(_mitKopplex, Lieferland.deutschland), [
        _kopplex1lang,
        _kopplex1kurz,
      ]);
      expect(schutzbandKopplex(_mitKopplex, Lieferland.oesterreich), [
        _kopplex1lang,
        _kopplex1kurz,
      ]);
      expect(schutzbandKopplex(_mitKopplex, Lieferland.schweiz), isEmpty);
      expect(unterlegband(_mitKopplex, Lieferland.deutschland), _kopplex3);
      expect(unterlegband(_mitKopplex, Lieferland.schweiz), isNull);
      final ohne = _regelwerk(const []);
      expect(schutzbandKopplex(ohne, Lieferland.deutschland), isEmpty);
      expect(unterlegband(ohne, Lieferland.deutschland), isNull);
      // KOPPLEX-3 auch als Pad geführt
      final pad = Artikel(
        nummer: const Artikelnummer('k-004'),
        titel: 'KOPPLEX-3 10m-Rolle',
        art: Artikelart.pad,
        einheit: Verkaufseinheit(Mengeneinheit.stueck),
      );
      expect(unterlegband(_regelwerk([pad]), Lieferland.deutschland), pad);
    });

    test('KOPPLEX-3: 8 cm je Auflagepunkt, ganze Rollen', () {
      expect(unterlegbandEinheiten(1, _kopplex3), 1);
      expect(unterlegbandEinheiten(125, _kopplex3), 1);
      expect(unterlegbandEinheiten(126, _kopplex3), 2);
      expect(unterlegbandEinheiten(0, _kopplex3), 0);
    });
  });

  group('Schutzband auf der UK (R-C70)', () {
    test('Deutschland und Österreich: KOPPLEX-1 in 20- und 10-m-Rollen mit '
        'wenig Überhang statt GUMO K', () {
      // 13 Linien × 309 cm = 40,17 m → 2 × 20 m + 1 × 10 m
      expect(_band40m(_mitKopplex), {'k-007': 2, 'k-001': 1});
      expect(_band40m(_mitKopplex, Lieferland.oesterreich), {
        'k-007': 2,
        'k-001': 1,
      });
    });

    test('Schweiz und ohne KOPPLEX in den Artikeldaten: GUMO K wie bisher', () {
      expect(_band40m(_mitKopplex, Lieferland.schweiz), {'k-120': 1});
      expect(_band40m(_regelwerk(const [])), {'k-120': 1});
    });

    test('nur 10-m-Rollen: so viele, wie die Länge braucht', () {
      final kurz = _regelwerk([_kopplex1kurz]);
      expect(_band40m(kurz), {'k-001': 5});
    });
  });

  group('Unterleger KOPPLEX-3 statt GUMO L 2/5 mm (R-C71)', () {
    const f01 = Planungsstand.start;
    final verlegung = ukVerlegung(
      f01,
      ukArtikel,
      abstand: const Millimeter(400),
    );
    final bereiche = auflagerbereiche(
      auflagerRegelwerk,
      ukArtikel,
      gewerblich: false,
      auflagen: f01.auflagen,
    );
    Auflagerbedarf bedarf(List<int> hoehen, {Artikel? band}) => auflagerbedarf(
      f01.mitGefaelle(hoehen.length > 1),
      verlegung,
      uk: ukArtikel,
      abstand: const Millimeter(600),
      flaeche: Hoehenflaeche(f01.grundriss.ecken, [
        for (final h in hoehen) Millimeter(h),
      ]),
      aufbauhoehe: const Millimeter(82),
      bereiche: bereiche,
      regelwerk: auflagerRegelwerk,
      unterlegband: band,
    );

    test('F01: je Auflager zwei Stücke à 8 cm statt zwei Pads 2 mm – '
        '182 × 8 cm = 14,56 m → 2 Rollen', () {
      final b = bedarf([86], band: _kopplex3);
      expect(
        [for (final z in b.zeilen) (z.titel, z.anzahl)],
        [('2 × ${_kopplex3.titel}', 91)],
      );
      final m = b.bedarf.single;
      expect(m.einheiten, [_kopplex3]);
      expect(m.stueck, 2);
      expect(m.inEinheiten, isTrue);
      // ohne Band wie bisher
      final alt = bedarf([86]);
      expect(alt.zeilen.single.titel, '2 × Unterleger 2 mm');
      expect(alt.bedarf.single.einheiten, [pad2]);
      expect(alt.bedarf.single.stueck, 182);
    });

    test('F30: GUMO L 8 mm bleibt für den Höhenausgleich, nur 2 mm wird '
        'Band; Stelzfüße unverändert', () {
      final b = bedarf([150, 150, 86, 86], band: _kopplex3);
      final titel = {for (final z in b.zeilen) z.titel: z.anzahl};
      expect(titel['2 × ${_kopplex3.titel}'], 13);
      expect(titel['2 × Unterleger 8 mm'], 13);
      expect(titel['Keil 18-32'], 13);
      final mengen = {for (final m in b.bedarf) m.einheiten.first: m.stueck};
      // 26 Stücke à 8 cm = 2,08 m → 1 Rolle
      expect(mengen[_kopplex3], 1);
      expect(mengen[pad8], 26);
      expect(mengen.containsKey(pad2), isFalse);
      expect(mengen[keil18], 13);
      // Band-Bedarf nur einmal und in Einheiten
      expect(
        b.bedarf
            .where((m) => m.einheiten.first == _kopplex3)
            .single
            .inEinheiten,
        isTrue,
      );
      expect(
        b.bedarf.where((m) => m.einheiten.first == pad8).single.inEinheiten,
        isFalse,
      );
    });

    test('8 + 5 mm: das 8-mm-Pad bleibt, statt 5 mm ein Stück Band', () {
      // Spalt 13 mm: 8 + 5 (86 + 10 = 96 − 82 − 1)
      final b = bedarf([96], band: _kopplex3);
      expect(b.zeilen.single.titel, 'Unterleger 8 mm + ${_kopplex3.titel}');
      final mengen = {for (final m in b.bedarf) m.einheiten.first: m.stueck};
      expect(mengen, {pad8: 91, _kopplex3: 1});
    });

    test('nur Pads ab 8 mm: kein Band in der Materialliste', () {
      // Spalt 16 mm: 8 + 8
      final b = bedarf([99], band: _kopplex3);
      expect(b.zeilen.single.titel, '2 × Unterleger 8 mm');
      expect([for (final m in b.bedarf) m.einheiten.first], [pad8]);
    });
  });
}
