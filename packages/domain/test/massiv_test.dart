/// MASSIV-Systemdielen im Längenmix nach dem Planungskern (Planungsregeln
/// Alexander v13, Abschnitt 1a; B-036, B-232; R-B20–R-B24).
library;

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

const _mix = [
  Millimeter(800),
  Millimeter(1200),
  Millimeter(1600),
  Millimeter(2000),
];

Artikel _massiv({
  int breite = 80,
  Verkaufseinheit? einheit,
  Profil profil = Profil.genutet,
}) => Artikel(
  nummer: const Artikelnummer('10-15-004'),
  titel: 'Systemdiele Robinie MASSIV $breite x 25 mm',
  art: Artikelart.systemdiele,
  einheit:
      einheit ??
      Verkaufseinheit(
        Mengeneinheit.verpackungseinheit,
        inhalt: 1.5,
        inhaltEinheit: Mengeneinheit.quadratmeter,
      ),
  abmessungen: Abmessungen(
    breite: Millimeter(breite),
    staerke: const Millimeter(25),
  ),
  preisBrutto: const Cent(14579),
  holzart: robinie,
  serie: massiv,
  profil: profil,
);

Artikel _uk(Serie serie, {int a = 40, int b = 60}) => Artikel(
  nummer: Artikelnummer('UK-${serie.name}'),
  titel: 'UK',
  art: Artikelart.unterkonstruktion,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  abmessungen: Abmessungen(breite: Millimeter(a), staerke: Millimeter(b)),
  holzart: robinie,
  serie: serie,
);

Planungsstand _rechteck(int ab, int bc) => Planungsstand.start.mitGrundriss(
  RechteckGrundriss(Millimeter(ab), Millimeter(bc)),
);

/// Stücke je Reihe von links nach rechts (Längen in mm) und die Stöße
/// (x in mm) – bei 0° liegen die Reihen längs x.
({Map<int, List<int>> laengen, Map<int, List<int>> stoesse}) _reihen(
  Belagverlegung v,
) {
  final laengen = <int, List<int>>{};
  final stoesse = <int, List<int>>{};
  for (final s in v.teile.first.stuecke) {
    laengen.putIfAbsent(s.reihe, () => []).add(s.laenge.mm);
  }
  for (final MapEntry(key: reihe, value: l) in laengen.entries) {
    var x = 0;
    stoesse[reihe] = [for (final n in l.take(l.length - 1)) x += n];
  }
  return (laengen: laengen, stoesse: stoesse);
}

void main() {
  group('Längenmix (Regel 1a.3, B-232)', () {
    test('Raster: 40 cm, kleinere Feldbreite gilt (Frage 102)', () {
      expect(laengenmixRaster, const Millimeter(400));
      expect(laengenmixRasterFuer(null), const Millimeter(400));
      expect(
        laengenmixRasterFuer(const Millimeter(350)),
        const Millimeter(350),
      );
      expect(
        laengenmixRasterFuer(const Millimeter(400)),
        const Millimeter(400),
      );
      expect(
        laengenmixRasterFuer(const Millimeter(500)),
        const Millimeter(400),
      );
      expect(laengenmixMindeststueck, const Millimeter(300));
      expect(laengenmixToleranz, const Millimeter(5));
    });

    test('5 × 1 m: Stöße auf dem Raster, versetzt, Stücke 30 cm bis 2 m, '
        'fairer Mix', () {
      final v = verlegeBelag(_rechteck(5000, 1000), _massiv())!;
      final (:laengen, :stoesse) = _reihen(v);
      expect(laengen, hasLength(12));
      // feste Zufallsfolge wie im Kern: gleiche Fläche, gleiche Planung
      expect(laengen[0], [2000, 1600, 1400]);
      expect(laengen[1], [1200, 1200, 800, 1800]);
      expect(laengen[11], [1600, 1600, 1800]);
      for (final r in laengen.keys) {
        expect(laengen[r]!.fold(0, (a, b) => a + b), 5000);
        for (final l in laengen[r]!) {
          expect(l, inInclusiveRange(300, 2005));
        }
        for (final s in stoesse[r]!) {
          expect(s % 400, 0, reason: 'Stoß $s auf dem Raster');
          // nie neben dem Stoß der Vorreihe
          expect(stoesse[r - 1] ?? const <int>[], isNot(contains(s)));
        }
      }
      // jede Länge des Mixes kommt vor, die Zahl je Länge ist ausgeglichen
      expect(v.dielenliste.anzahl, {
        const Millimeter(800): 11,
        const Millimeter(1200): 9,
        const Millimeter(1600): 13,
        const Millimeter(2000): 11,
      });
      expect(v.lieferlaengen, _mix);
      expect(v.muster, Musterregel.laengenmix);
      expect(v.ueberlaenge, laengenmixToleranz);
      expect(v.laengenmix?.raster, const Millimeter(400));
      expect(v.laengenmix?.anfang, 0);
      // Verschiebung nur quer zu den Dielen
      expect(v.grenzen, (x: const Millimeter(0), y: const Millimeter(86)));
      // jedes Stück aus der kürzesten Lieferlänge, die es aufnimmt
      for (final d in v.teile.first.zuschnitt) {
        expect(d.schnitte, hasLength(1));
        expect(d.laenge, laengenmixLieferlaenge(d.schnitte.single, _mix));
      }
    });

    test('Verlegeart, Dielenlänge und Verschiebung gelten nicht', () {
      final basis = verlegeBelag(_rechteck(5000, 1000), _massiv())!;
      final anders = verlegeBelag(
        _rechteck(5000, 1000)
            .mitVerlegeart(Verlegeart.halbverband)
            .mitDielenlaenge(const Millimeter(2000))
            .mitAusgangspunkt(x: const Millimeter(300)),
        _massiv(),
      )!;
      expect(_reihen(anders).laengen, _reihen(basis).laengen);
    });

    test('feste Stoßlinie (Planungskern Regel 15.4) gilt nicht: Längenmix '
        'unverändert, Hinweis statt Wirkung', () {
      final basis = _rechteck(5000, 1000);
      // Ecke B (5000|0) und C liegen am Rand; mit Ausschnitt-freier Fläche
      // wäre bei Dielen eine Linie durch eine innere Ecke nötig – hier
      // zählt nur, dass der Längenmix keine feste Linie übernimmt
      final mitLinie = basis.mitStosslinie([1, 2]);
      final ohne = verlegeBelag(basis, _massiv())!;
      final mit = verlegeBelag(mitLinie, _massiv())!;
      expect(_reihen(mit).laengen, _reihen(ohne).laengen);
      expect(mit.festeStoesse, 0);
      expect(mit.zusatzstoesse, 0);
      expect(belagmeldungen(mitLinie, _massiv(), mit), [
        Belagmeldung.systemdieleLaengenmix,
        Belagmeldung.stosslinieNichtImMuster,
      ]);
      // L-Form mit innerer Ecke: auch dort bleibt der Mix
      final l = Planungsstand.start.mitForm(Terrassenform.lForm);
      for (var e = 0; e < l.ausgangsecken; e++) {
        final v = verlegeBelag(l.mitStosslinie([e]), _massiv())!;
        expect(v.festeStoesse, 0);
        expect(
          [for (final s in v.teile.first.stuecke) s.laenge],
          [
            for (final s in verlegeBelag(l, _massiv())!.teile.first.stuecke)
              s.laenge,
          ],
        );
      }
    });

    test('senkrecht: Grenze in y ist 0; kurze Reihen bis zur längsten '
        'Diele aus dem Mix (Regel 16.1.3, Kern v25)', () {
      final v = verlegeBelag(
        _rechteck(1000, 2003).mitVerlegerichtung(Verlegerichtung.senkrecht),
        _massiv(),
      )!;
      expect(v.grenzen.y, const Millimeter(0));
      expect(v.grenzen.x, isNot(const Millimeter(0)));
      final reihen = <int, List<int>>{};
      for (final s in v.teile.single.stuecke) {
        reihen.putIfAbsent(s.reihe, () => []).add(s.laenge.mm);
      }
      for (final l in reihen.values) {
        // gestoßen: ein Stück aus dem Mix, das letzte ist das Reststück
        expect(l, hasLength(2));
        expect(l.first % 400, 0);
        expect(l.fold(0, (a, b) => a + b), 2003);
        expect(l.last, greaterThanOrEqualTo(300));
      }
      expect(v.dielenliste.anzahl.keys, isNot([const Millimeter(2000)]));
    });

    test('kurze Reihe: ein Stück unter kürzeste Länge + 30 cm, ab 1,10 m '
        'gestoßen (Regel 16.1.3)', () {
      List<int> reihe(int laenge) => [
        for (final s in verlegeBelag(
          _rechteck(laenge, 500),
          _massiv(),
        )!.teile.single.stuecke)
          if (s.reihe == 0) s.laenge.mm,
      ];
      expect(reihe(1099), [1099]);
      expect(reihe(1100), [800, 300]);
      // 1,50 m Steg: Stoß aus dem Mix, Reststück am Ende
      expect(reihe(1500), [800, 700]);
    });

    test('Feldbreite 35 cm: Stöße im 35-cm-Raster', () {
      final v = verlegeBelag(
        _rechteck(5000, 500).mitFeldbreite(const Millimeter(350)),
        _massiv(),
      )!;
      expect(v.laengenmix?.raster, const Millimeter(350));
      for (final s in _reihen(v).stoesse.values.expand((s) => s)) {
        expect(s % 350, 0);
      }
    });

    test('Teilfläche mit anderem Belag: Raster ab dem Rand der Fläche', () {
      final stand = _rechteck(5000, 1000).mitNeuemAusschnitt().mitAusschnitt(
        0,
        Ausschnitt(
          bezeichnung: 'A1',
          x: const Millimeter(500),
          y: const Millimeter(0),
          laenge: const Millimeter(3000),
          breite: const Millimeter(500),
          funktion: Ausschnittfunktion.andererBelag,
        ),
      );
      final v = verlegeBelag(stand, _massiv())!;
      expect(v.teile, hasLength(2));
      final teil = v.teile.last;
      final reihen = <int, List<Dielenstueck>>{};
      for (final s in teil.stuecke) {
        reihen.putIfAbsent(s.reihe, () => []).add(s);
      }
      for (final r in reihen.values) {
        var x = 500;
        for (final s in r.take(r.length - 1)) {
          x += s.laenge.mm;
          expect(x % 400, 0, reason: 'Stoß $x auf dem Raster der Fläche');
        }
      }
    });

    test('Belaglängen: MASSIV aus der Serie, sonst aus den Artikeldaten', () {
      expect(belaglaengen(_massiv()), _mix);
      final diele = Artikel(
        nummer: const Artikelnummer('1'),
        titel: 'Diele',
        art: Artikelart.diele,
        einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
        abmessungen: Abmessungen(laengen: const [Millimeter(4000)]),
        holzart: robinie,
        serie: basic,
      );
      expect(belaglaengen(diele), const [Millimeter(4000)]);
      expect(
        rasteranfang(_rechteck(5000, 1000).kontur, 180),
        closeTo(-5000, 1e-6),
      );
    });

    test('Lieferlänge eines Stücks', () {
      expect(
        laengenmixLieferlaenge(const Millimeter(805), _mix),
        const Millimeter(800),
      );
      expect(
        laengenmixLieferlaenge(const Millimeter(806), _mix),
        const Millimeter(1200),
      );
      expect(
        laengenmixLieferlaenge(const Millimeter(2100), _mix),
        const Millimeter(2000),
      );
    });

    test('Laengenmixwahl: Vorreihen, nur Mix-Längen, Raster über 50 cm '
        'ist ein Fehler', () {
      final wahl = Laengenmixwahl(_mix, anfang: const Millimeter(0));
      expect(wahl.laengen, [2000, 1200, 1600, 800]);
      expect(wahl.laengste, 2000);
      final a = wahl.stoesse(0, [
        (const Millimeter(0), const Millimeter(6000)),
      ]);
      final b = wahl.stoesse(1, [
        (const Millimeter(0), const Millimeter(6000)),
      ]);
      final c = wahl.stoesse(2, [
        (const Millimeter(0), const Millimeter(6000)),
      ]);
      for (final s in b.single) {
        expect(a.single, isNot(contains(s)));
      }
      for (final s in c.single) {
        expect(b.single, isNot(contains(s)));
      }
      // kurze Abschnitte (Regel 16.1.3): bis zur längsten Länge ein Stoß
      // aus dem Mix, unter kürzeste Länge + 30 cm keiner
      expect(
        wahl.stoesse(3, [(const Millimeter(0), const Millimeter(2005))]).single,
        hasLength(1),
      );
      expect(wahl.kuerzeste, 800);
      expect(wahl.stoesse(4, [(const Millimeter(0), const Millimeter(1099))]), [
        <Millimeter>[],
      ]);
      expect(wahl.stoesse(5, [(const Millimeter(0), const Millimeter(1100))]), [
        [const Millimeter(800)],
      ]);
      // die Grenze gilt für die Länge des Abschnitts, nicht seine Lage
      expect(
        Laengenmixwahl(
          _mix,
          anfang: const Millimeter(0),
        ).stoesse(0, [(const Millimeter(1000), const Millimeter(2099))]),
        [<Millimeter>[]],
      );
      // unter 1,10 m kein Stoß, auch wenn eine Rasterlinie passen würde
      expect(
        Laengenmixwahl(
          _mix,
          anfang: const Millimeter(100),
        ).stoesse(0, [(const Millimeter(0), const Millimeter(1000))]),
        [<Millimeter>[]],
      );
      // passt der Rest hinter dem Stoß samt Toleranz in 2 m (2,003 m),
      // ist er das letzte Stück – in jeder Reihe genau ein Stoß
      final zwei = Laengenmixwahl(const [
        Millimeter(800),
        Millimeter(2000),
      ], anfang: const Millimeter(0));
      final reihen = [
        for (var r = 0; r < 6; r++)
          zwei.stoesse(r, [
            (const Millimeter(0), const Millimeter(2803)),
          ]).single,
      ];
      expect(reihen.map((s) => s.length).toSet(), {1});
      expect(reihen.map((s) => s.single.mm).toSet(), {800, 2000});
      // Rasterlinie ab dem Anfang 10 cm, gemessen vom Anfang (nicht addiert)
      final ab100 = Laengenmixwahl(const [
        Millimeter(800),
        Millimeter(2000),
      ], anfang: const Millimeter(100));
      for (var r = 0; r < 4; r++) {
        final s = ab100.stoesse(r, [
          (const Millimeter(400), const Millimeter(2700)),
        ]).single;
        expect(s, hasLength(1));
        expect({900, 2100}, contains(s.single.mm));
      }
      // kein Stoß nach den Regeln möglich: die kurze Reihe bleibt ein Stück
      final weit = Laengenmixwahl(
        const [Millimeter(800), Millimeter(2000)],
        anfang: const Millimeter(0),
        raster: const Millimeter(600),
      );
      expect(
        weit.stoesse(0, [(const Millimeter(999), const Millimeter(2099))]),
        [<Millimeter>[]],
      );
      expect(
        Laengenmixwahl(const [
          Millimeter(800),
          Millimeter(4000),
        ], anfang: const Millimeter(0)).laengen,
        [800],
      );
      final grob = Laengenmixwahl(
        const [Millimeter(800)],
        anfang: const Millimeter(0),
        raster: const Millimeter(600),
      );
      expect(
        () =>
            grob.stoesse(0, [(const Millimeter(999), const Millimeter(3000))]),
        throwsStateError,
      );
    });

    test('strenge Wahl: nicht neben der Vorreihe, möglichst nicht neben der '
        'Reihe davor; Rest mindestens 30 cm; Raster ab dem Anfang', () {
      // 2,1 m mit 0,8 / 1,2 / 2,0 m: nur 80 oder 120 cm möglich (2,0 m
      // ließe 10 cm Rest) – die Reihen wechseln sich ab
      final wahl = Laengenmixwahl(const [
        Millimeter(800),
        Millimeter(1200),
        Millimeter(2000),
      ], anfang: const Millimeter(0));
      final ab = [(const Millimeter(0), const Millimeter(2100))];
      final folge = [
        for (var r = 0; r < 20; r++) wahl.stoesse(r, ab).single.single.mm,
      ];
      expect(folge.toSet(), {800, 1200});
      for (var r = 1; r < folge.length; r++) {
        expect(folge[r], isNot(folge[r - 1]));
      }
      // mit drei Möglichkeiten auch nicht neben der Reihe davor
      final drei = Laengenmixwahl(_mix, anfang: const Millimeter(0));
      final lang = [(const Millimeter(0), const Millimeter(2300))];
      final stoesse = [
        for (var r = 0; r < 20; r++) drei.stoesse(r, lang).single.single.mm,
      ];
      for (var r = 2; r < stoesse.length; r++) {
        expect(stoesse[r], isNot(stoesse[r - 1]));
        expect(stoesse[r], isNot(stoesse[r - 2]));
      }
      // Raster ab dem Anfang 10 cm
      final versetzt = Laengenmixwahl(_mix, anfang: const Millimeter(100));
      for (var r = 0; r < 10; r++) {
        for (final s in versetzt.stoesse(r, [
          (const Millimeter(100), const Millimeter(6100)),
        ]).single) {
          expect((s.mm - 100) % 400, 0);
        }
      }
    });
  });

  group('UK im Raster (Regel 1a.4, B-232)', () {
    test('Rand bündig, dann 40 cm ab Rand: 38 / 40 / 40 …; jeder Stoß auf '
        'einer Linie, keine Doppel-UK', () {
      final stand = _rechteck(5000, 1000);
      final v = verlegeBelag(stand, _massiv())!;
      final uk = ukVerlegung(
        stand,
        _uk(ecoSelect),
        abstand: const Millimeter(400),
        dielen: [for (final t in v.teile) ...t.stuecke],
        laengenmix: v.laengenmix,
      );
      expect(uk.laengenmix, isTrue);
      expect(uk.lagen, [
        20,
        for (var g = 400; g <= 4800; g += 400) g.toDouble(),
        4980,
      ]);
      for (final s in _reihen(v).stoesse.values.expand((s) => s)) {
        expect(uk.lagen, contains(s.toDouble()));
      }
      // ohne Längenmix: Doppel-UK an den Stößen
      final ohne = ukVerlegung(
        stand,
        _uk(ecoSelect),
        abstand: const Millimeter(400),
        dielen: [for (final t in v.teile) ...t.stuecke],
      );
      expect(ohne.laengenmix, isFalse);
      expect(ohne.lagen.length, greaterThan(uk.lagen.length));
    });

    test('Rasterlinie zu nah am Randholz entfällt', () {
      final stand = _rechteck(4030, 500);
      final v = verlegeBelag(stand, _massiv())!;
      final uk = ukVerlegung(
        stand,
        _uk(ecoSelect),
        abstand: const Millimeter(400),
        laengenmix: v.laengenmix,
      );
      expect(uk.lagen.last, 4010);
      expect(uk.lagen, isNot(contains(4000.0)));
      expect(uk.lagen[uk.lagen.length - 2], 3600);
      // ohne Anfang: der Rand der Fläche
      final rand = ukVerlegung(
        stand,
        _uk(ecoSelect),
        abstand: const Millimeter(400),
        laengenmix: (
          laengen: _mix,
          raster: const Millimeter(400),
          anfang: null,
        ),
      );
      expect(rand.lagen, uk.lagen);
    });

    test('Befestigung: je Reihe jede Linie einmal (Clips = UK-Linien je '
        'Reihe)', () {
      final stand = _rechteck(5000, 1000);
      final v = verlegeBelag(stand, _massiv())!;
      final stuecke = [for (final t in v.teile) ...t.stuecke];
      final uk = ukVerlegung(
        stand,
        _uk(ecoSelect),
        abstand: const Millimeter(400),
        laengenmix: v.laengenmix,
      );
      final reihen = stuecke.map((s) => s.reihe).toSet().length;
      final p = befestigungspunkteAufUk(stuecke, uk);
      expect(p.punkte, reihen * uk.lagen.length);
      expect(p.randpunkte, 2 * uk.lagen.length);
      // ohne Längenmix zählt jedes Ende am Stoß
      final doppelt = befestigungspunkteAufUk(
        stuecke,
        UkVerlegung(linien: uk.linien, breite: uk.breite, winkel: uk.winkel),
      );
      expect(doppelt.punkte, greaterThan(p.punkte));
    });

    test('UK aus ECO SELECT, nicht MASSIV (Regel 1a.7, Frage 100), in '
        '2,00 m (Regel 16.1.1)', () {
      expect(ukPasstZuBelag(_uk(ecoSelect), _massiv()), isTrue);
      expect(ukPasstZuBelag(_uk(massiv), _massiv()), isFalse);
      expect(robinie.serie(massiv).ukSerie, ecoSelect);
      expect(robinie.serie(ecoSelect).ukSerie, isNull);
      expect(robinie.serie(massiv).ukLieferlaengen, const [Millimeter(2000)]);
      expect(
        robinie.serie(massiv).ukTitel,
        'Unterkonstruktion Robinie ECO MASSIV {format}, ohne Keilzinkung',
      );
      expect(robinie.serie(ecoSelect).ukTitel, isNull);
    });
  });

  group('UK zur MASSIV-Systemdiele (Regeln 16.1.1, 16.1.2, 18)', () {
    Artikel ecoUk({
      String titel =
          'Unterkonstruktion Robinie ECO SELECT '
          '60 x 40 mm, keilgezinkt',
    }) => Artikel(
      nummer: const Artikelnummer('10-10-031-S'),
      titel: titel,
      art: Artikelart.unterkonstruktion,
      einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
      abmessungen: Abmessungen(
        breite: const Millimeter(40),
        staerke: const Millimeter(60),
        laengen: const [Millimeter(6000)],
      ),
      preisBrutto: const Cent(1234),
      gewicht: const Gramm(1800),
      holzart: robinie,
      serie: ecoSelect,
      bilder: const ['uk.webp'],
    );

    test('Name „ECO MASSIV …, ohne Keilzinkung“, 2,00 m, Nummer und Preis '
        'bleiben (Regel 18)', () {
      final uk = ukZuBelag(ecoUk(), _massiv());
      expect(
        uk.titel,
        'Unterkonstruktion Robinie ECO MASSIV 60 x 40 mm, ohne Keilzinkung',
      );
      expect(uk.nummer, const Artikelnummer('10-10-031-S'));
      expect(uk.art, Artikelart.unterkonstruktion);
      expect(uk.einheit.einheit, Mengeneinheit.laufmeter);
      expect(uk.preisBrutto, const Cent(1234));
      expect(uk.gewicht, const Gramm(1800));
      expect(uk.bilder, ['uk.webp']);
      expect(uk.holzart, robinie);
      expect(uk.serie, massiv);
      expect(uk.abmessungen.breite, const Millimeter(40));
      expect(uk.abmessungen.staerke, const Millimeter(60));
      expect(uk.abmessungen.laengen, const [Millimeter(2000)]);
      expect(ukLieferlaengen(uk), const [Millimeter(2000)]);
      // ohne Format im Titel: aus den Maßen
      expect(
        ukZuBelag(ecoUk(titel: 'UK'), _massiv()).titel,
        'Unterkonstruktion Robinie ECO MASSIV 40 x 60 mm, ohne Keilzinkung',
      );
      // zu keilgezinkten Dielen bleibt die ECO-SELECT-UK, wie sie ist
      final eco = Artikel(
        nummer: const Artikelnummer('10-10-046-S'),
        titel: 'Diele',
        art: Artikelart.diele,
        einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
        abmessungen: Abmessungen(
          breite: const Millimeter(80),
          staerke: const Millimeter(23),
        ),
        holzart: robinie,
        serie: ecoSelect,
        profil: Profil.genutet,
      );
      expect(identical(ukZuBelag(ecoUk(), eco), ecoUk()), isFalse);
      expect(ukZuBelag(ecoUk(), eco).titel, ecoUk().titel);
      expect(ukLieferlaengen(ukZuBelag(ecoUk(), eco)), const [
        Millimeter(4000),
        Millimeter(5000),
        Millimeter(6000),
      ]);
      // Belag ohne Holzart (Holzfliese, Alu): unverändert
      final fliese = Artikel(
        nummer: const Artikelnummer('F-1'),
        titel: 'Fliese',
        art: Artikelart.holzfliese,
        einheit: Verkaufseinheit(Mengeneinheit.stueck),
      );
      expect(ukZuBelag(ecoUk(), fliese).titel, ecoUk().titel);
    });

    test('Auswahl: ECO MASSIV zur MASSIV-Diele, auch nach JSON', () {
      final auswahl = Ukauswahl.fuer('1', _massiv(), [ecoUk()]);
      final uk = auswahl.vorgabe!.artikel;
      expect(uk.titel, contains('ECO MASSIV'));
      expect(auswahl.vorgabe!.preisJeLfm, const Cent(1234));
      final zurueck = Ukauswahl.ausJson(auswahl.alsJson(), {
        robinie.id: robinie,
      });
      expect(zurueck.vorgabe!.artikel.titel, uk.titel);
      expect(ukLieferlaengen(zurueck.vorgabe!.artikel), const [
        Millimeter(2000),
      ]);
    });

    test('lange UK-Linien aus 2-m-Stücken, je Stoß ein Längsverbinder '
        '45 cm daneben, aus dem Reststück (Regel 16.1.1)', () {
      expect(massivLaengsverbinder, const Millimeter(450));
      final stand = _rechteck(2000, 5000);
      final v = verlegeBelag(stand, _massiv())!;
      final uk = ukVerlegung(
        stand,
        ukZuBelag(ecoUk(), _massiv()),
        abstand: const Millimeter(400),
        dielen: [for (final t in v.teile) ...t.stuecke],
        laengenmix: v.laengenmix,
      );
      final linien = uk.linien.length;
      expect(linien, 6);
      for (final l in uk.linien) {
        expect(l.abschnitte, [(0.0, 5000.0)]);
        expect(l.stoesse, [2000.0, 4000.0]);
      }
      final laengen = [for (final s in uk.stuecke) s.laenge.mm];
      expect(laengen.where((l) => l == 2000), hasLength(2 * linien));
      expect(laengen.where((l) => l == 1000), hasLength(linien));
      expect(laengen.where((l) => l == 450), hasLength(2 * linien));
      expect(uk.stuecke, hasLength(5 * linien));
      expect(
        uk.stuecke.where((s) => s.laenge.mm == 450).map((s) => s.farbe).toSet(),
        {Stueckfarbe.blau},
      );
      expect(uk.stuecke.first.titel, contains('ECO MASSIV'));
      // Verbinder neben der ersten Linie (x = 20): links der Richtung, eine
      // UK-Breite daneben, mittig über dem Stoß
      final erste = uk.linien.first.x;
      expect(
        uk.hoelzer,
        contains((
          von: Punkt(erste - 40, 1775),
          bis: Punkt(erste - 40, 2225),
          farbe: Stueckfarbe.blau,
        )),
      );
      expect(
        uk.hoelzer,
        contains((
          von: Punkt(erste - 40, 3775),
          bis: Punkt(erste - 40, 4225),
          farbe: Stueckfarbe.blau,
        )),
      );
      // nur 2-m-Hölzer; die Verbinder kommen aus den Resten der 1-m-Stücke
      expect(uk.zuschnitt.every((d) => d.laenge.mm == 2000), isTrue);
      // 2 × 2 m + 1 m je Linie, die Verbinder aus den Resten der 1-m-Stücke
      expect(uk.bedarf.single.stueck, 3 * linien);
      // kein Längsverbinder-Artikel, auch wenn die UK einen hätte
      final verbinder = Artikel(
        nummer: const Artikelnummer('50-20-001'),
        titel: 'Längsverbinder',
        art: Artikelart.laengsverbinder,
        einheit: Verkaufseinheit(Mengeneinheit.stueck),
      );
      final regelwerk = Regelwerk(
        Artikeldatei(
          quelle: 't',
          version: '1',
          eintraege: [
            Artikeleintrag(
              artikel: ecoUk(),
              verweise: {
                Beziehung.laengsverbinder.spalte: [verbinder.nummer],
              },
            ),
            Artikeleintrag(artikel: verbinder),
          ],
        ),
      );
      final mit = ukVerlegung(
        stand,
        ukZuBelag(ecoUk(), _massiv()),
        abstand: const Millimeter(400),
        laengenmix: v.laengenmix,
        regelwerk: regelwerk,
      );
      expect(mit.bedarf.expand((b) => b.einheiten), isNot(contains(verbinder)));
      // ohne Längenmix: Verbinder-Artikel, keine Holzverbinder
      final ohne = ukVerlegung(
        stand,
        ukZuBelag(ecoUk(), _massiv()),
        abstand: const Millimeter(400),
        regelwerk: regelwerk,
      );
      expect(ohne.bedarf.last.einheiten, [verbinder]);
      expect(ohne.stuecke.where((s) => s.laenge.mm == 450), isEmpty);
    });

    test('Rand-UK: Verbinder auf der Belagseite; jeder Stoß über einem '
        'Auflager', () {
      // Dreieck: die schräge Kante bekommt eine Rand-UK über 2 m
      final stand = Planungsstand.start.mitGrundriss(
        FreiformGrundriss([
          const Punkt(0, 0),
          const Punkt(3000, 0),
          const Punkt(0, 3000),
        ], geschlossen: true),
      );
      final v = verlegeBelag(stand, _massiv())!;
      final uk = ukVerlegung(
        stand,
        ukZuBelag(ecoUk(), _massiv()),
        abstand: const Millimeter(400),
        dielen: [for (final t in v.teile) ...t.stuecke],
        laengenmix: v.laengenmix,
      );
      final schraeg = uk.rand.singleWhere((r) => r.stoesse.isNotEmpty);
      final richtung = (schraeg.bis - schraeg.von).einheit;
      // 4,24 m: 2,00 + 1,74 + 0,50 m (Reststück mindestens 50 cm)
      expect(schraeg.stoesse, hasLength(2));
      final stoss = schraeg.von + richtung * schraeg.stoesse.first;
      final verbinder = uk.hoelzer.singleWhere(
        (h) =>
            (h.von.abstand(h.bis) - 450).abs() < 1e-6 &&
            ((h.von + h.bis) * 0.5).abstand(stoss) < 41,
      );
      // auf der Belagseite: näher am Schwerpunkt als der Stoß
      const innen = Punkt(1000, 1000);
      expect(
        ((verbinder.von + verbinder.bis) * 0.5).abstand(innen),
        lessThan(stoss.abstand(innen)),
      );
      final auflager = auflagerbedarf(
        stand,
        uk,
        uk: ukZuBelag(ecoUk(), _massiv()),
        abstand: const Millimeter(600),
        flaeche: Hoehenflaeche(const [Punkt.ursprung], const [Millimeter(100)]),
        aufbauhoehe: const Millimeter(90),
      );
      expect(auflager.punkte.any((p) => p.ort.abstand(stoss) < 1e-6), isTrue);
    });

    test('Kreis: Rand-UK am Bogen gerade (Regel 16.3), Linien aus '
        '2-m-Stücken mit Verbindern; jeder Stoß behält trotz Raster '
        '(Regel 16.4) sein Auflager', () {
      final stand = Planungsstand.start.mitGrundriss(
        KreisGrundriss(const Millimeter(4000)),
      );
      final uk = ukZuBelag(ecoUk(), _massiv());
      final v = verlegeBelag(stand, _massiv())!;
      final verlegung = ukVerlegung(
        stand,
        uk,
        abstand: const Millimeter(400),
        dielen: [for (final t in v.teile) ...t.stuecke],
        laengenmix: v.laengenmix,
      );
      final stoesse = [
        for (final l in verlegung.linien)
          for (final y in l.stoesse) Punkt(l.x, y),
        for (final r in verlegung.rand)
          for (final t in r.stoesse) r.von + (r.bis - r.von).einheit * t,
      ];
      expect(stoesse, isNotEmpty);
      // je Stoß ein Verbinder, kein Holz über 2 m
      expect(
        verlegung.stuecke.where((s) => s.laenge.mm == 450),
        hasLength(stoesse.length),
      );
      expect(verlegung.stuecke.every((s) => s.laenge.mm <= 2000), isTrue);
      final auflager = auflagerbedarf(
        stand,
        verlegung,
        uk: uk,
        abstand: const Millimeter(600),
        flaeche: Hoehenflaeche(const [Punkt.ursprung], const [Millimeter(100)]),
        aufbauhoehe: const Millimeter(90),
      );
      for (final s in stoesse) {
        expect(
          auflager.punkte.any((p) => p.ort.abstand(s) < 1e-6),
          isTrue,
          reason: 'Auflager unter dem Stoß $s',
        );
      }
    });

    test('Clips + 25 % statt + 5 % (Regel 16.1.2)', () {
      expect(systemdielenClipZuschlag, 25);
      expect(systemdielenClips(100), 125);
      expect(systemdielenClips(101), 127);
      expect(systemdielenClips(0), 0);
      final clip = Artikel(
        nummer: const Artikelnummer('80-10-001-50'),
        titel: 'CLIP-FIXX VPE 50',
        art: Artikelart.clip,
        einheit: Verkaufseinheit(Mengeneinheit.stueck, inhalt: 50),
      );
      final regelwerk = Regelwerk(
        Artikeldatei(
          quelle: 't',
          version: '1',
          eintraege: [
            Artikeleintrag(
              artikel: _massiv(),
              verweise: {
                Beziehung.befestigung.spalte: [clip.nummer],
              },
            ),
            Artikeleintrag(artikel: clip),
          ],
        ),
      );
      final stand = _rechteck(5000, 1000);
      final v = verlegeBelag(stand, _massiv())!;
      final stuecke = [for (final t in v.teile) ...t.stuecke];
      final uk = ukVerlegung(
        stand,
        ukZuBelag(ecoUk(), _massiv()),
        abstand: const Millimeter(400),
        laengenmix: v.laengenmix,
      );
      final b = befestigungsbedarf(
        regelwerk,
        _massiv(),
        Befestigungsart.clips,
        stuecke,
        winkel: 0,
        uk: uk,
      );
      // ohne Gegenstück: alle Kreuzungen mit Clips
      expect(b.bedarf.single.einheiten, [clip]);
      expect(b.bedarf.single.stueck, systemdielenClips(b.punkte));
      expect(b.bedarf.single.stueck, greaterThan(clipsMitZuschlag(b.punkte)));
    });
  });

  group('Texte MASSIV (Unterlagen und Hinweise, exakt)', () {
    test('Legenden und Meldungen deutsch und englisch', () {
      const de = Unterlagentexte.deutsch;
      const en = Unterlagentexte.englisch;
      expect(
        en.stossHinweisLaengenmix,
        'MASSIV in mixed lengths 0.8 / 1.2 / 1.6 / 2.0 m · joints staggered '
        'row by row (red) · every joint centred on one joist.',
      );
      expect(
        en.ukRasterLaengenmix,
        'Joints centred on the joist (grid 38/40 cm). Joists in 2 m '
        'pieces; at every joist joint a longitudinal connector of approx. '
        '45 cm from the offcut, screwed on the side, joint above a support.',
      );
      expect(
        de.belagmeldung(Belagmeldung.systemdieleLaengenmix, null),
        'MASSIV-Systemdielen liegen im Längenmix 0,8 / 1,2 / 1,6 / 2,0 m mit '
        'je Reihe versetzten Stößen; jeder Stoß liegt mittig auf einer UK '
        '(Raster 38 / 40 cm). Verlegemuster und Dielenlänge gelten dafür '
        'nicht.',
      );
      expect(
        en.belagmeldung(Belagmeldung.systemdieleLaengenmix, null),
        'MASSIV system boards are laid in mixed lengths of 0.8 / 1.2 / 1.6 / '
        '2.0 m with joints staggered row by row; every joint sits centred '
        'on one joist (grid 38 / 40 cm). Laying patterns and board length '
        'do not apply.',
      );
      expect(
        en.belagmeldung(
          Belagmeldung.stosslinieZusatzstoesse,
          null,
          zusatzstoesse: 1,
        ),
        'Between the fixed joint lines the boards would be longer than the '
        'delivery length. The plan adds 1 evenly spaced joint (with double '
        'substructure).',
      );
      expect(
        en.belagmeldung(
          Belagmeldung.stosslinieZusatzstoesse,
          null,
          zusatzstoesse: 2,
        ),
        contains('adds 2 evenly spaced joints (with'),
      );
      expect(
        de.anschlusshinweis(Anschlussmeldung.bogenblende),
        'Blende am Bogen aus senkrechten Stücken: je Stück 2 Schrauben in die '
        'Rand-UK, vorbohren; unten ca. 1 cm Luft lassen, Hirnholz oben und '
        'unten mit Stirnkantenschutz streichen.',
      );
      expect(
        en.anschlusshinweis(Anschlussmeldung.bogenblende),
        'Cladding along the arc made of vertical pieces: 2 screws per piece '
        'into the edge substructure, pre-drill; leave about 1 cm clearance '
        'at the bottom, seal the end grain at top and bottom.',
      );
      expect(
        de.rinnenBelagHinweis,
        'Grau: Entwässerungsrinne RELO V innen an der Kante – der Belag endet '
        '15,7 cm vor der Kante (Profil 15,1 cm und 6 mm Fuge).',
      );
      expect(
        en.rinnenBelagHinweis,
        'Grey: drainage channel RELO V on the inside of the edge – the '
        'decking ends 15.7 cm before the edge (profile 15.1 cm and 6 mm '
        'joint).',
      );
      expect(
        de.rinnenmeldung(Anschlussmeldung.rinneNichtMoeglich),
        'Rinne nicht geplant: nur an geraden, waagerechten oder senkrechten '
        'Kanten ab 30 cm möglich.',
      );
      expect(
        en.rinnenmeldung(Anschlussmeldung.rinneNichtMoeglich),
        'Channel not planned: only possible on straight horizontal or vertical '
        'edges of at least 30 cm.',
      );
    });
  });

  group('Menge je m² in Paketen (Regeln 1a.2, 1a.6)', () {
    test('belegte Fläche und Form', () {
      final v = verlegeBelag(_rechteck(5000, 3000), _massiv())!;
      expect(belegteFlaeche(v), closeTo(15, 1e-6));
      expect(systemdielenRechteck(_rechteck(5000, 3000)), isTrue);
      expect(
        systemdielenRechteck(
          _rechteck(5000, 3000).mitVerlegerichtung(Verlegerichtung.senkrecht),
        ),
        isTrue,
      );
      expect(
        systemdielenRechteck(
          _rechteck(5000, 3000).mitVerlegerichtung(Verlegerichtung.diagonal45),
        ),
        isFalse,
      );
      expect(
        systemdielenRechteck(Planungsstand.start.mitForm(Terrassenform.lForm)),
        isFalse,
      );
      expect(
        systemdielenRechteck(Planungsstand.start.mitForm(Terrassenform.oForm)),
        isFalse,
      );
      expect(
        systemdielenRechteck(Planungsstand.start.mitForm(Terrassenform.kreis)),
        isFalse,
      );
      // um 30° gedrehtes Rechteck, Dielen unter 30° oder 120° (Koordinaten
      // auf 0,1 mm gerundet)
      final schief = Planungsstand(
        grundriss: FreiformGrundriss(const [
          Punkt(0, 0),
          Punkt(3464.1, 2000),
          Punkt(2464.1, 3732.1),
          Punkt(-1000, 1732.1),
        ], geschlossen: true),
      );
      for (final w in [30, 120]) {
        expect(
          systemdielenRechteck(
            schief.mitVerlegerichtung(Verlegerichtung.individuell, winkel: w),
          ),
          isTrue,
          reason: '$w°',
        );
      }
      expect(
        systemdielenRechteck(
          schief.mitVerlegerichtung(Verlegerichtung.individuell, winkel: 60),
        ),
        isFalse,
      );
      expect(
        systemdielenRechteck(
          schief.mitVerlegerichtung(Verlegerichtung.individuell, winkel: 45),
        ),
        isFalse,
      );
      expect(systemdielenRechteck(schief), isFalse);
      // Trapez: eine Kante schräg
      expect(
        systemdielenRechteck(
          Planungsstand(
            grundriss: FreiformGrundriss(const [
              Punkt(0, 0),
              Punkt(4000, 0),
              Punkt(3000, 2000),
              Punkt(0, 2000),
            ], geschlossen: true),
          ),
        ),
        isFalse,
      );
    });

    test(
      'Pakete: Fläche + 5 % bzw. 10 %, aufgerundet; Einheit des Artikels',
      () {
        expect(systemdielenPaket, 1.5);
        expect(systemdielenZuschlagRechteck, 0.05);
        expect(systemdielenZuschlagForm, 0.10);
        // 15 m² × 1,05 = 15,75 m² → 10,5 → 11 Pakete
        expect(systemdielenEinheiten(_massiv(), 15, rechteck: true), 11);
        // 15 m² × 1,10 = 16,5 m² → genau 11 Pakete
        expect(systemdielenEinheiten(_massiv(), 15, rechteck: false), 11);
        expect(systemdielenEinheiten(_massiv(), 15.1, rechteck: false), 12);
        expect(systemdielenEinheiten(_massiv(), 0, rechteck: true), 0);
        // je m²: ganze Pakete in m²
        expect(
          systemdielenEinheiten(
            _massiv(einheit: Verkaufseinheit(Mengeneinheit.quadratmeter)),
            15,
            rechteck: true,
          ),
          17,
        );
        // je lfm: Paketfläche ÷ Breite
        expect(
          systemdielenEinheiten(
            _massiv(einheit: Verkaufseinheit(Mengeneinheit.laufmeter)),
            15,
            rechteck: true,
          ),
          207,
        );
        // unbekannte Einheit: je Paket
        expect(
          systemdielenEinheiten(
            _massiv(einheit: Verkaufseinheit(Mengeneinheit.stueck)),
            15,
            rechteck: true,
          ),
          11,
        );
        expect(
          systemdielenQmJeEinheit(
            _massiv(einheit: Verkaufseinheit(Mengeneinheit.stueck)),
          ),
          1.5,
        );
      },
    );

    test('Materialliste: Pakete unverpackt, Preis je Paket; Holzvolumen', () {
      final a = _massiv();
      final liste = Materialliste.aus([
        Materialbedarf([a], 7, inEinheiten: true),
        Materialbedarf([a], 4, inEinheiten: true) * 1,
      ]);
      final z = liste.positionen.single;
      expect(z.anzahl, 11);
      expect(z.einheit, Mengeneinheit.verpackungseinheit);
      expect(z.einzelpreis, const Cent(14579));
      expect(z.positionspreis, const Cent(14579 * 11));
      expect(
        () => Materialbedarf([a, a], 1, inEinheiten: true),
        throwsArgumentError,
      );
      // 11 Pakete × 1,5 m² × 25 mm
      expect(
        holzvolumen([
          Materialbedarf([a], 11, inEinheiten: true),
        ]),
        closeTo(11 * 1.5 * 0.025, 1e-9),
      );
      // ohne Stärke zählt die Systemdiele nicht
      final ohne = Artikel(
        nummer: const Artikelnummer('x'),
        titel: 'Systemdiele',
        art: Artikelart.systemdiele,
        einheit: a.einheit,
        holzart: robinie,
        serie: massiv,
      );
      expect(
        holzvolumen([
          Materialbedarf([ohne], 1, inEinheiten: true),
        ]),
        isNull,
      );
    });

    test('Preis je m² = Paketpreis ÷ 1,5 (Regel 1a.2)', () {
      final angebot = Belagangebot.aus(_massiv());
      expect(angebot.preisJeM2, const Cent(9719));
      expect(Mengeneinheit.lies('Paket'), Mengeneinheit.verpackungseinheit);
    });
  });
}
