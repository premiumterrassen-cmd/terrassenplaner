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

    test('senkrecht: Grenze in y ist 0; kurze Reihe ohne Stoß', () {
      final v = verlegeBelag(
        _rechteck(1000, 2003).mitVerlegerichtung(Verlegerichtung.senkrecht),
        _massiv(),
      )!;
      expect(v.grenzen.y, const Millimeter(0));
      expect(v.grenzen.x, isNot(const Millimeter(0)));
      for (final t in v.teile) {
        for (final s in t.stuecke) {
          expect(s.laenge, const Millimeter(2003));
        }
      }
      expect(v.dielenliste.anzahl.keys, [const Millimeter(2000)]);
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
      // ohne Stoß, wenn der Abschnitt in die längste Länge passt
      expect(wahl.stoesse(3, [(const Millimeter(0), const Millimeter(2005))]), [
        <Millimeter>[],
      ]);
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

    test('UK aus ECO SELECT, nicht MASSIV (Regel 1a.7, Frage 100)', () {
      expect(ukPasstZuBelag(_uk(ecoSelect), _massiv()), isTrue);
      expect(ukPasstZuBelag(_uk(massiv), _massiv()), isFalse);
      expect(robinie.serie(massiv).ukSerie, ecoSelect);
      expect(robinie.serie(ecoSelect).ukSerie, isNull);
      expect(robinie.serie(massiv).ukLieferlaengen, const [
        Millimeter(4000),
        Millimeter(5000),
        Millimeter(6000),
      ]);
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
