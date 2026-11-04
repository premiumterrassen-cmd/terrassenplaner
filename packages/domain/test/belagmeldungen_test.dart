import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

const _laengen = [Millimeter(4000), Millimeter(5000), Millimeter(6000)];

Artikel _diele({
  String nummer = '10-10-073-R',
  int? breite = 60,
  int? staerke = 23,
  List<Millimeter> laengen = _laengen,
  Artikelart art = Artikelart.diele,
  Profil? profil = Profil.genutet,
  Serie serie = premiumSelect,
  Oberseite? oberseite = Oberseite.glatt,
}) => Artikel(
  nummer: Artikelnummer(nummer),
  titel: 'Diele $nummer',
  art: art,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  abmessungen: Abmessungen(
    breite: breite == null ? null : Millimeter(breite),
    staerke: staerke == null ? null : Millimeter(staerke),
    laengen: laengen,
  ),
  holzart: robinie,
  serie: serie,
  profil: profil,
  oberseite: oberseite,
);

/// Holzfliese 606 × 606 mm (F25).
Artikel _fliese({List<Millimeter> laengen = const [Millimeter(606)]}) =>
    Artikel(
      nummer: const Artikelnummer('40-10-001'),
      titel: 'Fliese',
      art: Artikelart.holzfliese,
      einheit: Verkaufseinheit(Mengeneinheit.stueck),
      abmessungen: Abmessungen(breite: const Millimeter(606), laengen: laengen),
      oberseite: Oberseite.glatt,
    );

Artikel _befestigung(String nummer, Artikelart art, {int? laenge}) => Artikel(
  nummer: Artikelnummer(nummer),
  titel: nummer,
  art: art,
  einheit: Verkaufseinheit(Mengeneinheit.stueck),
  abmessungen: Abmessungen(
    laengen: [?(laenge == null ? null : Millimeter(laenge))],
  ),
);

final _clip = _befestigung('CLIP-FIXX', Artikelart.clip);
final _duo = _befestigung('DUO-CLIP-FIXX', Artikelart.clip);
final _schraube50 = _befestigung(
  'Schraube 50',
  Artikelart.schraube,
  laenge: 50,
);
final _schraube60 = _befestigung(
  'Schraube 60',
  Artikelart.schraube,
  laenge: 60,
);
final _schraubeOhneLaenge = _befestigung('Schraube', Artikelart.schraube);

/// Regelwerk mit dem [belag] und seinen Befestigungsverweisen.
Regelwerk _regelwerk(Artikel belag, List<Artikel> befestigung) => Regelwerk(
  Artikeldatei(
    quelle: 'test',
    version: '1',
    eintraege: [
      Artikeleintrag(
        artikel: belag,
        verweise: {
          Beziehung.befestigung.spalte: [for (final b in befestigung) b.nummer],
        },
      ),
      for (final b in befestigung) Artikeleintrag(artikel: b),
    ],
  ),
);

Planungsstand _freiform(List<Punkt> punkte) =>
    Planungsstand(grundriss: FreiformGrundriss(punkte, geschlossen: true));

/// Rechteck als Freiform – auch schmaler als 50 cm.
Planungsstand _streifen(double laenge, double breite) => _freiform([
  Punkt.ursprung,
  Punkt(laenge, 0),
  Punkt(laenge, breite),
  Punkt(0, breite),
]);

/// Meldungen wie der Server sie rechnet: mit der Verlegung des Belags.
List<Belagmeldung> _meldungen(
  Artikel? belag, {
  Planungsstand stand = const Planungsstand(),
  Regelwerk? regelwerk,
}) => belagmeldungen(
  stand,
  belag,
  verlegeBelag(stand, belag),
  regelwerk: regelwerk,
);

Ausschnitt _ausschnitt({
  Ausschnittform form = Ausschnittform.rechteck,
  Ausschnittfunktion funktion = Ausschnittfunktion.andererBelag,
  int laenge = 3000,
}) => Ausschnitt(
  bezeichnung: 'A1',
  x: const Millimeter(500),
  y: const Millimeter(500),
  laenge: Millimeter(laenge),
  breite: const Millimeter(1000),
  form: form,
  funktion: funktion,
);

void main() {
  group('Belagmeldung (M5-10)', () {
    test('Nummern, Unterpunkte und Art im Transportformat', () {
      expect(
        [for (final m in Belagmeldung.values) m.nummer],
        [for (var i = 0; i < 10; i++) i],
      );
      for (final m in Belagmeldung.values) {
        expect(Belagmeldung.ausNummer(m.nummer), m);
      }
      expect(
        () => Belagmeldung.ausNummer(10),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'unbekannte Belagmeldung 10',
          ),
        ),
      );
      expect(
        {for (final m in Belagmeldung.values) m: m.unterpunkt},
        {
          Belagmeldung.belagErsetzt: 0,
          Belagmeldung.belagOhneMasse: 0,
          Belagmeldung.systemdieleOhneVerlegung: 0,
          Belagmeldung.flaecheKleinerAlsBelag: 0,
          Belagmeldung.fliesenSpitzeWinkel: 0,
          Belagmeldung.bombierungEmpfohlen: 0,
          Belagmeldung.laengeNichtLieferbar: 1,
          Belagmeldung.befestigungsartNichtMoeglich: 5,
          Belagmeldung.befestigungOhneArtikel: 5,
          Belagmeldung.schraubeZuKurz: 5,
        },
      );
      expect(
        [
          for (final m in Belagmeldung.values)
            if (m.warnung) m,
        ],
        [
          Belagmeldung.belagOhneMasse,
          Belagmeldung.flaecheKleinerAlsBelag,
          Belagmeldung.fliesenSpitzeWinkel,
          Belagmeldung.befestigungOhneArtikel,
          Belagmeldung.schraubeZuKurz,
        ],
      );
    });

    test('F01 mit der Vorgabediele: keine Meldung', () {
      final diele = _diele();
      expect(
        _meldungen(
          diele,
          stand: Planungsstand(belag: diele.nummer),
          regelwerk: _regelwerk(diele, [_clip]),
        ),
        isEmpty,
      );
    });

    test('ohne Belag keine Meldung', () {
      expect(_meldungen(null), isEmpty);
      expect(
        _meldungen(
          null,
          stand: const Planungsstand(belag: Artikelnummer('10-10-999')),
        ),
        isEmpty,
      );
    });
  });

  group('Belag 2.1', () {
    test('Belag nicht mehr in den Artikeldaten: Vorgabe (M5-01)', () {
      final diele = _diele();
      expect(
        _meldungen(
          diele,
          stand: const Planungsstand(belag: Artikelnummer('10-10-999')),
        ),
        [Belagmeldung.belagErsetzt],
      );
      // ohne Wahl gilt die Vorgabe ohne Meldung
      expect(_meldungen(diele), isEmpty);
    });

    test('Belag ohne Breite oder Lieferlänge wird nicht verlegt', () {
      expect(_meldungen(_diele(breite: null)), [Belagmeldung.belagOhneMasse]);
      expect(_meldungen(_diele(laengen: const [])), [
        Belagmeldung.belagOhneMasse,
      ]);
      expect(_meldungen(_fliese(laengen: const [])), [
        Belagmeldung.belagOhneMasse,
      ]);
    });

    test('Systemdielen werden noch nicht verlegt (B-036)', () {
      for (final systemdiele in [
        _diele(art: Artikelart.systemdiele, serie: massiv, staerke: 25),
        _diele(art: Artikelart.systemdiele, breite: null, laengen: const []),
      ]) {
        expect(_meldungen(systemdiele), [
          Belagmeldung.systemdieleOhneVerlegung,
        ]);
      }
    });

    test('Fläche schmaler als eine Dielenreihe (120 mm + 5 mm Fuge)', () {
      final diele = _diele(
        breite: 120,
        serie: ecoSelect,
        oberseite: Oberseite.bombiert,
      );
      // 124 mm: volle Reihe mit 1 mm Spielraum, 123 mm: nur ein Zuschnitt
      expect(_meldungen(diele, stand: _streifen(3000, 124)), isEmpty);
      expect(_meldungen(diele, stand: _streifen(3000, 123)), [
        Belagmeldung.flaecheKleinerAlsBelag,
      ]);
      // in der Länge wird jede Diele zugeschnitten
      expect(_meldungen(diele, stand: _streifen(100, 200)), isEmpty);
    });

    test('Teilfläche mit anderem Belag schmaler als eine Diele', () {
      final diele = _diele(
        breite: 120,
        serie: ecoSelect,
        oberseite: Oberseite.bombiert,
      );
      final schmal = Ausschnitt(
        bezeichnung: 'A1',
        x: const Millimeter(500),
        y: const Millimeter(500),
        laenge: const Millimeter(1000),
        breite: const Millimeter(100),
        funktion: Ausschnittfunktion.andererBelag,
      );
      expect(_meldungen(diele, stand: Planungsstand(ausschnitte: [schmal])), [
        Belagmeldung.flaecheKleinerAlsBelag,
      ]);
      // ein leerer Ausschnitt ist keine Teilfläche
      expect(
        _meldungen(
          diele,
          stand: Planungsstand(
            ausschnitte: [schmal.mitFunktion(Ausschnittfunktion.leer)],
          ),
        ),
        isEmpty,
      );
    });

    test('Fläche ohne ganze Holzfliese 606 × 606 mm', () {
      final fliese = _fliese();
      expect(_meldungen(fliese), isEmpty);
      expect(_meldungen(fliese, stand: _streifen(606, 700)), isEmpty);
      expect(_meldungen(fliese, stand: _streifen(605, 700)), [
        Belagmeldung.flaecheKleinerAlsBelag,
      ]);
      expect(_meldungen(fliese, stand: _streifen(3000, 610)), isEmpty);
      expect(_meldungen(fliese, stand: _streifen(3000, 609)), [
        Belagmeldung.flaecheKleinerAlsBelag,
      ]);
      expect(
        _meldungen(
          fliese,
          stand: Planungsstand(ausschnitte: [_ausschnitt(laenge: 500)]),
        ),
        [Belagmeldung.flaecheKleinerAlsBelag],
      );
    });

    test('Holzfliesen mit Ecken unter 90°', () {
      final fliese = _fliese();
      final dreieck = _freiform([
        Punkt.ursprung,
        const Punkt(4000, 0),
        const Punkt(2000, 3000),
      ]);
      expect(_meldungen(fliese, stand: dreieck), [
        Belagmeldung.fliesenSpitzeWinkel,
      ]);
      // Dielen werden schräg zugeschnitten, ohne Meldung
      expect(_meldungen(_diele(), stand: dreieck), isEmpty);
      // 89° spitz, 90° und stumpfe Ecken nicht
      final schief = _freiform([
        Punkt.ursprung,
        const Punkt(4000, 0),
        const Punkt(4000 + 3000 * 0.017452, 3000 * 0.999848),
        const Punkt(0, 3000),
      ]);
      expect(_meldungen(fliese, stand: schief), [
        Belagmeldung.fliesenSpitzeWinkel,
      ]);
      final stumpf = _freiform([
        Punkt.ursprung,
        const Punkt(4000, 0),
        const Punkt(4000, 2000),
        const Punkt(3000, 3000),
        const Punkt(0, 3000),
      ]);
      expect(_meldungen(fliese, stand: stumpf), isEmpty);
    });

    test('Holzfliesen in einer dreieckigen Teilfläche', () {
      final fliese = _fliese();
      expect(
        _meldungen(
          fliese,
          stand: Planungsstand(
            ausschnitte: [_ausschnitt(form: Ausschnittform.dreieck)],
          ),
        ),
        [Belagmeldung.fliesenSpitzeWinkel],
      );
      expect(
        _meldungen(
          fliese,
          stand: Planungsstand(
            ausschnitte: [
              _ausschnitt(
                form: Ausschnittform.dreieck,
                funktion: Ausschnittfunktion.leer,
              ),
            ],
          ),
        ),
        isEmpty,
      );
    });

    test('glatte Diele ab 80 mm: bombiert empfohlen (R-B03)', () {
      expect(_meldungen(_diele(breite: 80)), [
        Belagmeldung.bombierungEmpfohlen,
      ]);
      expect(_meldungen(_diele(breite: 70, serie: massiv)), isEmpty);
      expect(
        _meldungen(_diele(breite: 100, oberseite: Oberseite.bombiert)),
        isEmpty,
      );
      expect(_meldungen(_diele(breite: 100, oberseite: null)), isEmpty);
      // Systemdielen und Fliesen bekommen den Hinweis nicht
      expect(
        _meldungen(
          _diele(art: Artikelart.systemdiele, breite: 100, serie: massiv),
        ),
        [Belagmeldung.systemdieleOhneVerlegung],
      );
    });
  });

  group('Dielenlänge 2.2', () {
    test('erzwungene Länge, die der Belag nicht liefert (B-035)', () {
      const sieben = Planungsstand(dielenlaenge: Millimeter(7000));
      expect(_meldungen(_diele(), stand: sieben), [
        Belagmeldung.laengeNichtLieferbar,
      ]);
      expect(
        _meldungen(
          _diele(),
          stand: const Planungsstand(dielenlaenge: Millimeter(6000)),
        ),
        isEmpty,
      );
      // Fliesen kennen keine erzwungene Länge
      expect(_meldungen(_fliese(), stand: sieben), isEmpty);
      // ohne Lieferlängen zählt nur, dass der Belag nicht verlegt wird
      expect(_meldungen(_diele(laengen: const []), stand: sieben), [
        Belagmeldung.belagOhneMasse,
      ]);
    });
  });

  group('Befestigung 2.6', () {
    test('Verschraubung bei genuteten Dielen: Clips (B-094)', () {
      final diele = _diele();
      final regelwerk = _regelwerk(diele, [_clip]);
      for (final art in [
        Befestigungsart.verschraubt,
        Befestigungsart.verschraubtMitAbstandshaltern,
      ]) {
        expect(
          _meldungen(
            diele,
            stand: Planungsstand(befestigungsart: art),
            regelwerk: regelwerk,
          ),
          [Belagmeldung.befestigungsartNichtMoeglich],
        );
      }
    });

    test('die Vorgabe Clips bei glattkanten Dielen meldet nichts', () {
      final glatt = _diele(profil: Profil.glattkant);
      expect(
        _meldungen(glatt, regelwerk: _regelwerk(glatt, [_schraube50])),
        isEmpty,
      );
    });

    test('ohne passende Clips oder Schrauben in den Verweisen', () {
      final diele = _diele();
      expect(_meldungen(diele, regelwerk: _regelwerk(diele, [_schraube50])), [
        Belagmeldung.befestigungOhneArtikel,
      ]);
      // genutete PREMIUM SELECT ab 100 mm nur mit DUO-CLIP-FIXX (B-094)
      final breit = _diele(breite: 100, oberseite: Oberseite.bombiert);
      expect(_meldungen(breit, regelwerk: _regelwerk(breit, [_clip])), [
        Belagmeldung.befestigungOhneArtikel,
      ]);
      expect(_meldungen(breit, regelwerk: _regelwerk(breit, [_duo])), isEmpty);
      final glatt = _diele(profil: Profil.glattkant);
      expect(_meldungen(glatt, regelwerk: _regelwerk(glatt, [_clip])), [
        Belagmeldung.befestigungOhneArtikel,
      ]);
    });

    test('Schraube unter der doppelten Dielenstärke', () {
      Artikel glatt(int? staerke) =>
          _diele(profil: Profil.glattkant, serie: basic, staerke: staerke);
      List<Belagmeldung> mit(Artikel belag, List<Artikel> schrauben) =>
          _meldungen(
            belag,
            stand: const Planungsstand(
              befestigungsart: Befestigungsart.verschraubtMitAbstandshaltern,
            ),
            regelwerk: _regelwerk(belag, schrauben),
          );
      expect(mit(glatt(31), [_schraube50, _schraube60]), [
        Belagmeldung.schraubeZuKurz,
      ]);
      expect(mit(glatt(30), [_schraube60, _schraube50]), isEmpty);
      expect(mit(glatt(26), [_schraube50]), [Belagmeldung.schraubeZuKurz]);
      expect(mit(glatt(25), [_schraube50]), isEmpty);
      expect(mit(glatt(21), [_schraubeOhneLaenge]), [
        Belagmeldung.schraubeZuKurz,
      ]);
      expect(mit(glatt(null), [_schraube50]), isEmpty);
      // bei Clips zählt die Schraubenlänge nicht
      final genutet = _diele(staerke: 31);
      expect(mit(genutet, [_clip, _schraube50]), [
        Belagmeldung.befestigungsartNichtMoeglich,
      ]);
    });

    test('ohne Regelwerk, unbekannten Belag oder Verlegung keine', () {
      final diele = _diele();
      final stand = const Planungsstand(
        befestigungsart: Befestigungsart.verschraubt,
      );
      expect(_meldungen(diele, stand: stand), isEmpty);
      expect(
        _meldungen(
          diele,
          stand: stand,
          regelwerk: _regelwerk(_diele(nummer: '10-10-001'), const []),
        ),
        isEmpty,
      );
      expect(
        belagmeldungen(stand, diele, null, regelwerk: _regelwerk(diele, [])),
        isEmpty,
      );
    });

    test('ohne Holzart, Serie, Profil oder Breite keine', () {
      final fliese = _fliese();
      expect(
        befestigungsmeldungen(
          _regelwerk(fliese, const []),
          fliese,
          Befestigungsart.verschraubt,
        ),
        isEmpty,
      );
      final ohneProfil = _diele(profil: null);
      expect(
        befestigungsmeldungen(
          _regelwerk(ohneProfil, const []),
          ohneProfil,
          Befestigungsart.verschraubt,
        ),
        isEmpty,
      );
      final ohneBreite = _diele(breite: null);
      expect(
        befestigungsmeldungen(
          _regelwerk(ohneBreite, const []),
          ohneBreite,
          Befestigungsart.verschraubt,
        ),
        isEmpty,
      );
    });

    test('Reihenfolge wie Belagmeldung, ohne Doppelte', () {
      final glatt = _diele(
        nummer: '10-10-146',
        profil: Profil.glattkant,
        serie: basic,
        breite: 100,
        staerke: 31,
      );
      expect(
        _meldungen(
          glatt,
          stand: const Planungsstand(
            belag: Artikelnummer('10-10-999'),
            dielenlaenge: Millimeter(7000),
          ),
          regelwerk: _regelwerk(glatt, [_schraube50]),
        ),
        [
          Belagmeldung.belagErsetzt,
          Belagmeldung.bombierungEmpfohlen,
          Belagmeldung.laengeNichtLieferbar,
          Belagmeldung.schraubeZuKurz,
        ],
      );
    });
  });

  test('Berechnung trägt die Meldungen (Transport, mitPlanung)', () {
    final b = Berechnung(
      umriss: const [Punkt.ursprung],
      flaeche: 1,
      belagmeldungen: const [
        Belagmeldung.laengeNichtLieferbar,
        Belagmeldung.belagErsetzt,
      ],
    );
    expect(Berechnung.ausBytes(b.zuBytes()).belagmeldungen, [
      Belagmeldung.laengeNichtLieferbar,
      Belagmeldung.belagErsetzt,
    ]);
    expect(b.mitPlanung(2).belagmeldungen, b.belagmeldungen);
    expect(Berechnung(umriss: const [], flaeche: 0).zuBytes(), isNot(isEmpty));
    expect(
      Berechnung.ausBytes(Berechnung(umriss: const [], flaeche: 0).zuBytes())
          .belagmeldungen,
      isEmpty,
    );
    expect(
      () => b.belagmeldungen.add(Belagmeldung.schraubeZuKurz),
      throwsA(anything),
    );
  });
}
