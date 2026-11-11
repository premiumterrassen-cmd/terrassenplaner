import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

import 'altplaner.dart';

Artikel _diele(int breite, int staerke) => Artikel(
  nummer: const Artikelnummer('10-10-073'),
  titel: 'Diele',
  art: Artikelart.diele,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  abmessungen: Abmessungen(
    breite: Millimeter(breite),
    staerke: Millimeter(staerke),
    laengen: const [Millimeter(4000), Millimeter(5000), Millimeter(6000)],
  ),
  holzart: robinie,
  serie: basic,
  profil: Profil.genutet,
);

Artikel _uk(int a, int b) => Artikel(
  nummer: const Artikelnummer('10-10-031'),
  titel: 'UK',
  art: Artikelart.unterkonstruktion,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  abmessungen: Abmessungen(breite: Millimeter(a), staerke: Millimeter(b)),
  holzart: robinie,
  serie: basic,
);

final _d60 = _diele(60, 21);
final _uk4060 = _uk(40, 60);
const _abstand = Millimeter(400);

Planungsstand _rechteck(int ab, int bc) => Planungsstand.start.mitGrundriss(
  RechteckGrundriss(Millimeter(ab), Millimeter(bc)),
);

List<Dielenstueck> _dielen(Planungsstand s, [Artikel? belag]) => [
  for (final t in verlegeBelag(s, belag ?? _d60, fuge: altplanerFuge)!.teile)
    ...t.stuecke,
];

UkVerlegung _verlege(
  Planungsstand s, {
  Artikel? belag,
  Artikel? uk,
  bool gedreht = false,
  Regelwerk? regelwerk,
}) => ukVerlegung(
  s,
  uk ?? _uk4060,
  abstand: _abstand,
  dielen: _dielen(s, belag),
  gedreht: gedreht,
  regelwerk: regelwerk,
);

List<String> _liste(UkVerlegung v) => [
  for (final z in Stueckliste.aus(v.stuecke).zeilen)
    '${z.stueck}x${z.laenge.mm} ${z.farbe.name}',
];

Map<int?, int> _bedarf(UkVerlegung v) => {
  for (final b in v.bedarf) b.laenge?.mm: b.stueck,
};

/// UK-Zuschnittplan (M9-02) als „Menge × Ausgangslänge: Schnitte“ in cm.
List<String> _zuschnitt(UkVerlegung v) => [
  for (final z in Zuschnittplan.aus([
    for (final d in v.zuschnitt) (artikel: _uk4060, stueck: d, anzahl: 1),
  ]).zeilen)
    '${z.menge} × ${z.ausgangslaenge.cm}: '
        '${[for (final s in z.schnitte) s.cm].join(' + ')}',
];

void main() {
  group('UK-Verlegung (M6-10)', () {
    test('F01: 13 Hölzer à 309 cm quer zu den Dielen, äußere bündig am Rand '
        '(B-096), 13 × 4000 mm wie im alten Planer', () {
      final v = _verlege(Planungsstand.start);
      expect(v.linien, hasLength(13));
      expect(v.lagen.first, 20);
      expect(v.lagen.last, 4780);
      expect(v.lagen[1], closeTo(20 + 4760 / 12, 1e-9));
      expect(v.breite, const Millimeter(40));
      expect(v.winkel, 0);
      expect(v.linien.first.abschnitte, [(0.0, 3090.0)]);
      expect(v.linien.first.stoesse, isEmpty);
      expect(v.stossanzahl, 0);
      // Länge aller Hölzer (Gummiband, M8-02): 13 × 309 cm
      expect(v.laenge, 13 * 3090);
      expect(UkVerlegung.keine.laenge, 0);
      expect(_liste(v), ['13x3090 blau']);
      expect(_bedarf(v), {4000: 13});
      expect(v.hoelzer.first, (
        von: const Punkt(20, 0),
        bis: const Punkt(20, 3090),
        farbe: Stueckfarbe.blau,
      ));
      expect(v.linien.clear, throwsUnsupportedError);
      expect(v.stuecke.clear, throwsUnsupportedError);
      expect(v.bedarf.clear, throwsUnsupportedError);
      expect(v.hoelzer.clear, throwsUnsupportedError);
    });

    test('UK-Stücklisten der Referenzfälle (M1-02, Rechtecke mit '
        'Robinien-UK): Anzahl, Länge und Farbe wie in der '
        'Planungsunterlage', () {
      // 2026-08-06-2810-v3: 480 × 500 cm, 60 × 22, UK 45 × 60 → 13 × 500 blau
      expect(_liste(_verlege(_rechteck(4800, 5000), uk: _uk(45, 60))), [
        '13x5000 blau',
      ]);
      // 2026-06-25-1275-v3: 300 × 100 cm, 100 × 22, UK 40 × 40 → 9 × 100
      expect(
        _liste(
          _verlege(
            _rechteck(3000, 1000),
            belag: _diele(100, 21),
            uk: _uk(40, 40),
          ),
        ),
        ['9x1000 blau'],
      );
      // 2026-05-12-1823-v4: 562 × 560 cm, 100 × 22 → 15 × 560
      expect(_liste(_verlege(_rechteck(5620, 5600), belag: _diele(100, 21))), [
        '15x5600 blau',
      ]);
      // 2026-05-03-347-v4: Dielen längs der 345-cm-Seite → 10 × 585
      expect(_liste(_verlege(_rechteck(3450, 5850), belag: _diele(60, 26))), [
        '10x5850 blau',
      ]);
      // 2026-05-03-4381-v2: 404 × 304 cm, versetzt (269,3 + 134,7 cm) →
      // doppelte UK an zwei Stoßlinien, 15 × 304
      final versetzt = _rechteck(4040, 3040)
          .mitVerlegeart(Verlegeart.drittelverband)
          .mitDielenlaenge(const Millimeter(4000));
      final v = _verlege(versetzt, belag: _diele(80, 26));
      expect(_liste(v), ['15x3040 blau']);
      expect(_bedarf(v), {4000: 15});
    });

    test('lange Linien gestückelt (R-B10): 1000 cm → 600 rot + 400 blau wie '
        '2026-07-07-2794; Stöße, Längsverbinder je Stoß', () {
      final gross = _rechteck(10500, 10000);
      final v = _verlege(gross, uk: _uk(40, 40));
      expect(_liste(v), ['29x6000 rot', '29x4000 blau']);
      expect(_bedarf(v), {4000: 29, 6000: 29});
      expect(v.linien.first.stoesse, [6000.0]);
      expect(v.stossanzahl, 29);
      expect(v.hoelzer[1].von, const Punkt(20, 6000));
      final verbinder = Artikel(
        nummer: const Artikelnummer('50-20-001'),
        titel: 'Längsverbinder VPE 50',
        art: Artikelart.laengsverbinder,
        einheit: Verkaufseinheit(Mengeneinheit.karton, inhalt: 50),
      );
      Regelwerk regelwerk(List<Artikelnummer> verweise) => Regelwerk(
        Artikeldatei(
          quelle: 't',
          version: '1',
          eintraege: [
            Artikeleintrag(
              artikel: _uk(40, 40),
              verweise: {Beziehung.laengsverbinder.spalte: verweise},
            ),
            Artikeleintrag(artikel: verbinder),
          ],
        ),
      );
      final mit = _verlege(
        gross,
        uk: _uk(40, 40),
        regelwerk: regelwerk([verbinder.nummer]),
      );
      expect(mit.bedarf.last.einheiten, [verbinder]);
      expect(mit.bedarf.last.stueck, 29);
      expect(mit.bedarf.last.laenge, isNull);
      expect(
        _verlege(gross, uk: _uk(40, 40), regelwerk: regelwerk(const [])).bedarf,
        hasLength(2),
      );
      // ohne Stöße keine Längsverbinder, auch wenn es welche gibt
      expect(
        _verlege(
          Planungsstand.start,
          uk: _uk(40, 40),
          regelwerk: regelwerk([verbinder.nummer]),
        ).bedarf,
        hasLength(1),
      );
      // unbekannte UK im Regelwerk: keine Verbinder
      expect(
        _verlege(
          gross,
          uk: _uk(40, 40),
          regelwerk: Regelwerk(
            Artikeldatei(quelle: 't', version: '2', eintraege: const []),
          ),
        ).bedarf,
        hasLength(2),
      );
    });

    test('erzwungene UK-Länge (3.4) gilt für Stücke und Lieferung', () {
      final v = _verlege(
        _rechteck(10500, 10000).mitUkLaenge(const Millimeter(5000)),
      );
      expect(_liste(v), ['58x5000 blau']);
      expect(v.stuecke, hasLength(58));
      expect(_bedarf(v), {5000: 58});
      expect(
        _bedarf(
          _verlege(Planungsstand.start.mitUkLaenge(const Millimeter(6000))),
        ),
        {6000: 13},
      );
    });

    test('doppelte UK an den Stößen der Dielen: F09 800 cm (6000 + 2000 '
        'mm) 22 Hölzer, zwei am Stoß', () {
      final v = _verlege(_rechteck(8000, 3090));
      expect(v.linien, hasLength(22));
      final paare = [
        for (var i = 1; i < v.lagen.length; i++)
          if (v.lagen[i] - v.lagen[i - 1] < 100) v.lagen[i - 1],
      ];
      expect(paare, hasLength(1));
      // die beiden Hölzer liegen bündig links und rechts des Stoßes
      final stoss = paare.single + 20;
      expect(
        _dielen(_rechteck(8000, 3090))
            .any((d) => d.umriss.any((p) => (p.x - stoss).abs() < 5)),
        isTrue,
      );
    });

    test('Stöße: am Rand nicht, nahe zusammengefasst, Lücken über 10 mm '
        'kein Stoß', () {
      Dielenstueck stueck(int reihe, double von, double bis) =>
          Dielenstueck(reihe, Millimeter((bis - von).round()), [
            Punkt(von, reihe * 65.0),
            Punkt(bis, reihe * 65.0),
            Punkt(bis, reihe * 65.0 + 60),
            Punkt(von, reihe * 65.0 + 60),
          ], breite: 65);
      final s = _rechteck(4800, 3090);
      List<double> lagen(List<Dielenstueck> d) =>
          ukVerlegung(s, _uk4060, abstand: _abstand, dielen: d).lagen;
      final ohne = lagen(const []);
      expect(ohne, hasLength(13));
      // Stoß bei 2000 und 2150 (unter dem halben Abstand): ein Paar bei 2075
      final nah = lagen([
        stueck(0, 0, 1997.5),
        stueck(0, 2002.5, 4800),
        stueck(1, 0, 2147.5),
        stueck(1, 2152.5, 4800),
      ]);
      expect(nah, contains(2075 - 20));
      expect(nah, contains(2075 + 20));
      // Stöße 200 mm auseinander: zwei Paare
      final weit = lagen([
        stueck(0, 0, 1997.5),
        stueck(0, 2002.5, 4800),
        stueck(1, 0, 2197.5),
        stueck(1, 2202.5, 4800),
      ]);
      expect(weit, containsAll([1980.0, 2020.0, 2180.0, 2220.0]));
      // am Rand (innerhalb einer UK-Breite) und mit Lücke kein Stoß
      expect(
        lagen([
          stueck(0, 0, 4757.5),
          stueck(0, 4762.5, 4800),
          stueck(1, 0, 30),
          stueck(1, 50, 4800),
        ]),
        ohne,
      );
      expect(lagen([stueck(0, 0, 2000), stueck(0, 2011, 4800)]), ohne);
      expect(
        lagen([stueck(0, 0, 1995), stueck(0, 2005, 4800)]),
        contains(1980.0),
      );
      // Reihenfolge der Stücke beliebig
      expect(
        lagen([stueck(0, 2002.5, 4800), stueck(0, 0, 1997.5)]),
        contains(1980.0),
      );
    });

    test('feste Obergrenze der Felder je Grenze', () {
      expect(hoechsteFelder, 1000);
      final v = ukVerlegung(
        Planungsstand.start,
        _uk4060,
        abstand: const Millimeter(1),
      );
      expect(v.linien, hasLength(1001));
    });

    test('gedreht (B-034): flach liegend so breit wie die breite Seite', () {
      final v = _verlege(Planungsstand.start, gedreht: true);
      expect(v.breite, const Millimeter(60));
      expect(v.lagen.first, 30);
      expect(v.lagen.last, 4770);
      expect(
        _verlege(Planungsstand.start, uk: _uk(60, 40)).breite,
        const Millimeter(40),
      );
    });

    test('Verlegerichtung senkrecht (F02): 9 Hölzer à 480 cm, in der '
        'Zeichnung waagrecht', () {
      final v = _verlege(
        Planungsstand.start.mitVerlegerichtung(Verlegerichtung.senkrecht),
      );
      expect(v.winkel, 90);
      expect(_liste(v), ['9x4800 blau']);
      final h = v.hoelzer.first;
      expect(h.von.y, closeTo(h.bis.y, 1e-6));
      expect((h.bis.x - h.von.x).abs(), closeTo(4800, 1e-6));
      expect(
        v.hoelzer.map((h) => h.von.y).reduce((a, b) => a < b ? a : b),
        closeTo(20, 1e-6),
      );
    });

    test('Ausschnitte: leere sparen die UK aus, mit anderem Belag nicht; '
        'Reste unter 1 cm entfallen', () {
      final leer = Ausschnitt(
        bezeichnung: 'A1',
        x: const Millimeter(1000),
        y: const Millimeter(1000),
        laenge: const Millimeter(1000),
        breite: const Millimeter(1000),
      );
      final s = Planungsstand.start.mitNeuemAusschnitt().mitAusschnitt(0, leer);
      final v = _verlege(s);
      final durch = v.linien.firstWhere((l) => l.x > 1000 && l.x < 2000);
      expect(durch.abschnitte, [(0.0, 1000.0), (2000.0, 3090.0)]);
      expect(v.linien.first.abschnitte, [(0.0, 3090.0)]);
      final anderer = s.mitAusschnitt(
        0,
        Ausschnitt(
          bezeichnung: 'A1',
          x: const Millimeter(1000),
          y: const Millimeter(1000),
          laenge: const Millimeter(1000),
          breite: const Millimeter(1000),
          funktion: Ausschnittfunktion.andererBelag,
        ),
      );
      expect(
        _verlege(anderer).linien.every((l) => l.abschnitte.length == 1),
        isTrue,
      );
      final rand = s.mitAusschnitt(
        0,
        Ausschnitt(
          bezeichnung: 'A1',
          x: const Millimeter(1000),
          y: const Millimeter(5),
          laenge: const Millimeter(1000),
          breite: const Millimeter(3000),
        ),
      );
      final schmal = _verlege(rand).linien
          .firstWhere((l) => l.x > 1000 && l.x < 2000);
      // 0–5 mm fällt weg, 3005–3090 bleibt
      expect(schmal.abschnitte, [(3005.0, 3090.0)]);
      // zwei leere Ausschnitte übereinander: drei Abschnitte
      final zwei = s.mitNeuemAusschnitt().mitAusschnitt(
        1,
        Ausschnitt(
          bezeichnung: 'A2',
          x: const Millimeter(1000),
          y: const Millimeter(2500),
          laenge: const Millimeter(1000),
          breite: const Millimeter(300),
        ),
      );
      expect(
        _verlege(zwei).linien
            .firstWhere((l) => l.x > 1000 && l.x < 2000)
            .abschnitte,
        [(0.0, 1000.0), (2000.0, 2500.0), (2800.0, 3090.0)],
      );
      final ganz = s.mitAusschnitt(
        0,
        Ausschnitt(
          bezeichnung: 'A1',
          x: const Millimeter(1000),
          y: const Millimeter(0),
          laenge: const Millimeter(1000),
          breite: const Millimeter(3090),
        ),
      );
      expect(
        _verlege(ganz).linien
            .firstWhere((l) => l.x > 1000 && l.x < 2000)
            .abschnitte,
        isEmpty,
      );
    });

    test('ohne Maße keine; ohne Lieferlängen je Abschnitt ein Stück ohne '
        'Lieferung', () {
      final alu = Artikel(
        nummer: const Artikelnummer('4250000000000'),
        titel: 'Alu',
        art: Artikelart.aluUnterkonstruktion,
        einheit: Verkaufseinheit(Mengeneinheit.stueck),
        abmessungen: Abmessungen(
          breite: const Millimeter(45),
          staerke: const Millimeter(23),
        ),
      );
      final v = _verlege(Planungsstand.start, uk: alu);
      expect(_liste(v), ['13x3090 rot']);
      expect(v.bedarf, isEmpty);
      final ohneMasse = Artikel(
        nummer: const Artikelnummer('4250000000001'),
        titel: 'Alu',
        art: Artikelart.aluUnterkonstruktion,
        einheit: Verkaufseinheit(Mengeneinheit.stueck),
      );
      expect(
        _verlege(Planungsstand.start, uk: ohneMasse),
        same(UkVerlegung.keine),
      );
      expect(UkVerlegung.keine.breite, const Millimeter(0));
      expect(UkVerlegung.keine.lagen, isEmpty);
    });
  });

  group('Befestigung auf den UK-Hölzern (M6-10)', () {
    test('F01 und F09 wie mit den gleichmäßigen Linien; L-Form nur, wo '
        'die Linie liegt', () {
      for (final s in [Planungsstand.start, _rechteck(8000, 3090)]) {
        final d = _dielen(s);
        expect(
          befestigungspunkteAufUk(d, _verlege(s)),
          befestigungspunkte(d, winkel: 0, ukAbstand: _abstand),
        );
      }
      expect(
        befestigungspunkteAufUk(
          _dielen(Planungsstand.start),
          _verlege(Planungsstand.start),
        ),
        (punkte: 624, randpunkte: 26),
      );
      expect(befestigungspunkteAufUk(const [], _verlege(Planungsstand.start)), (
        punkte: 0,
        randpunkte: 0,
      ));
      final l = Planungsstand.start.mitGrundriss(LGrundriss.vorgabe);
      final lv = _verlege(l);
      final ld = _dielen(l);
      final p = befestigungspunkteAufUk(ld, lv);
      // jedes Stück liegt nur auf den Hölzern unter ihm
      var erwartet = 0;
      for (final s in ld) {
        final xs = [for (final q in s.umriss) q.x];
        final ys = [for (final q in s.umriss) q.y];
        final mitte =
            (ys.reduce((a, b) => a < b ? a : b) +
                ys.reduce((a, b) => a > b ? a : b)) /
            2;
        erwartet += lv.linien
            .where(
              (h) =>
                  h.x > xs.reduce((a, b) => a < b ? a : b) - 20 &&
                  h.x < xs.reduce((a, b) => a > b ? a : b) + 20 &&
                  h.abschnitte.any((a) => a.$1 <= mitte && mitte <= a.$2),
            )
            .length;
      }
      expect(p.punkte, erwartet);
      expect(
        p.punkte,
        lessThan(
          befestigungspunkte(ld, winkel: 0, ukAbstand: _abstand).punkte + 1,
        ),
      );
      // senkrecht verlegt: gedreht gerechnet
      final senk = Planungsstand.start.mitVerlegerichtung(
        Verlegerichtung.senkrecht,
      );
      expect(
        befestigungspunkteAufUk(_dielen(senk), _verlege(senk)).punkte,
        befestigungspunkte(
          _dielen(senk),
          winkel: 90,
          ukAbstand: _abstand,
        ).punkte,
      );
    });
  });

  group('Holzvolumen (M6-10, Kennzahl aus M4-13)', () {
    test('Dielen und UK in Lieferlängen mal Querschnitt; ohne Länge oder '
        'Querschnitt nicht', () {
      final uk = _uk4060;
      // F28: 112 m UK 40 × 60 = 0,2688 m³ wie im alten Planer
      expect(
        holzvolumen([
          Materialbedarf([uk], 9, laenge: const Millimeter(5000)),
          Materialbedarf([uk], 16, laenge: const Millimeter(4000)),
          Materialbedarf([uk], 1, laenge: const Millimeter(3000)),
        ]),
        closeTo(0.2688, 1e-9),
      );
      final clip = Artikel(
        nummer: const Artikelnummer('80-10-001'),
        titel: 'Clip',
        art: Artikelart.clip,
        einheit: Verkaufseinheit(Mengeneinheit.stueck),
      );
      final ohneStaerke = Artikel(
        nummer: const Artikelnummer('10-10-099'),
        titel: 'x',
        art: Artikelart.aluUnterkonstruktion,
        einheit: Verkaufseinheit(Mengeneinheit.stueck),
        abmessungen: Abmessungen(breite: const Millimeter(40)),
      );
      final ohneBreite = Artikel(
        nummer: const Artikelnummer('10-10-098'),
        titel: 'x',
        art: Artikelart.aluUnterkonstruktion,
        einheit: Verkaufseinheit(Mengeneinheit.stueck),
        abmessungen: Abmessungen(staerke: const Millimeter(40)),
      );
      expect(
        holzvolumen([
          Materialbedarf([clip], 600),
          Materialbedarf([uk], 1),
          Materialbedarf([ohneStaerke], 1, laenge: const Millimeter(4000)),
          Materialbedarf([ohneBreite], 1, laenge: const Millimeter(4000)),
        ]),
        isNull,
      );
      expect(
        holzvolumen([
          Materialbedarf([clip], 600),
          Materialbedarf([_d60], 48, laenge: const Millimeter(5000)),
        ]),
        closeTo(48 * 5 * 0.06 * 0.021, 1e-9),
      );
      expect(holzvolumen(const []), isNull);
    });

    test('Berechnung: Transport hin und zurück, Kopie mit Planung', () {
      final b = Berechnung(umriss: const [], flaeche: 0, volumen: 0.435);
      expect(Berechnung.ausBytes(b.zuBytes()).volumen, 0.435);
      expect(
        Berechnung.ausBytes(Berechnung(umriss: const [], flaeche: 0).zuBytes())
            .volumen,
        isNull,
      );
      expect(b.mitPlanung(0, volumen: 1.5).volumen, 1.5);
      expect(b.mitPlanung(0).volumen, isNull);
    });
  });

  group('Unterbau mit UK-Hölzern (M6-10)', () {
    test('Hölzer und Breite der Verlegung, Transport hin und zurück', () {
      final v = _verlege(_rechteck(10500, 10000));
      final u = unterbauFuer(
        Planungsstand.start,
        hoehen: Hoehenpunkte(hoehen: const [Millimeter(86)]),
        uk: _uk4060,
        verlegung: v,
      );
      expect(u.hoelzer, v.hoelzer);
      expect(u.holzbreite, const Millimeter(40));
      final z = Berechnung.ausBytes(
        Berechnung(umriss: const [], flaeche: 0, unterbau: u).zuBytes(),
      ).unterbau;
      expect(z.hoelzer, v.hoelzer);
      expect(z.hoelzer.map((h) => h.farbe).toSet(), {
        Stueckfarbe.rot,
        Stueckfarbe.blau,
      });
      expect(z.holzbreite, const Millimeter(40));
      expect(u.hoelzer.clear, throwsUnsupportedError);
      final ohne = unterbauFuer(
        Planungsstand.start,
        hoehen: Hoehenpunkte(hoehen: const [Millimeter(86)]),
        uk: _uk4060,
        verlegung: UkVerlegung.keine,
      );
      expect(ohne.hoelzer, isEmpty);
      expect(ohne.holzbreite, isNull);
      final leer = Berechnung.ausBytes(
        Berechnung(umriss: const [], flaeche: 0).zuBytes(),
      ).unterbau;
      expect(leer.hoelzer, isEmpty);
      expect(leer.holzbreite, isNull);
      // ältere Unterbau-Tabelle ohne Hölzer
      final fbb = fb.Builder();
      fbb.startTable(1);
      final ort = fbb.endTable();
      fbb
        ..startTable(111)
        ..addOffset(110, ort);
      fbb.finish(fbb.endTable());
      expect(Berechnung.ausBytes(fbb.buffer).unterbau.hoelzer, isEmpty);
    });
  });

  group('Querstreben zwischen den UK-Hölzern (M6-10)', () {
    test('Lage der Hölzer; nicht zwischen den beiden Hölzern am Stoß', () {
      final s = _rechteck(8000, 3090).mitQuerstreben(true);
      final v = _verlege(s);
      final z = ukZusatz(s, _uk4060, ukAbstand: _abstand, linien: v.lagen);
      // 22 Hölzer, 21 Zwischenräume, einer davon am Stoß: 20 Streben je Reihe
      expect(z.streben, hasLength(20 * z.reihen));
      expect(z.streben.first.von.x, 40);
      expect(mindestStrebe, const Millimeter(100));
      final ohne = ukZusatz(s, _uk4060, ukAbstand: _abstand);
      expect(ohne.streben, hasLength(20 * ohne.reihen));
      expect(ohne.streben.first.von.x, 20);
    });

    test('Strebe ab 10 cm lichtem Abstand der Hölzer (mindestStrebe)', () {
      final s = _rechteck(1000, 3090).mitQuerstreben(true);
      // licht 160 − 20 − 40 = 100 mm: Strebe; 260 − 160 − 40 = 60 mm: keine
      // (doppelte UK); 980 − 260 − 40 = 680 mm: Strebe
      final z = ukZusatz(
        s,
        _uk4060,
        ukAbstand: _abstand,
        linien: const [20, 160, 260, 980],
      );
      expect(z.reihen, greaterThan(0));
      expect(z.streben, hasLength(2 * z.reihen));
      expect({for (final st in z.streben) st.von.x}, {40.0, 280.0});
    });
  });

  test('M9-02: UK-Zuschnitt wie in den Zuschnittlisten des alten Planers', () {
    for (final (art, ab, erwartet) in [
      (Verlegeart.fugenschnitt, 4800, ['13 × 400.0: 309.0']), // F01
      (Verlegeart.halbverband, 4800, ['14 × 400.0: 309.0']), // F06
      (Verlegeart.drittelverband, 4800, ['15 × 400.0: 309.0']), // F07
      (Verlegeart.fugenschnitt, 8000, ['22 × 400.0: 309.0']), // F09
      // F10: alter Planer 25 Hölzer – Lage der UK-Linien (M6-10), nicht Zuschnitt
      (Verlegeart.halbverband, 8000, ['24 × 400.0: 309.0']),
      (Verlegeart.drittelverband, 8000, ['24 × 400.0: 309.0']), // F11
    ]) {
      final v = _verlege(_rechteck(ab, 3090).mitVerlegeart(art));
      expect(_zuschnitt(v), erwartet, reason: '$art $ab');
    }
    // F02 senkrecht: alt 5 × 479 + 4 × 481 cm aus 500 cm (Rundung der
    // alten Lage), neu 9 × 480 cm – gleiche Hölzer
    expect(
      _zuschnitt(
        _verlege(
          _rechteck(4800, 3090).mitVerlegerichtung(Verlegerichtung.senkrecht),
        ),
      ),
      ['9 × 500.0: 480.0'],
    );
    // F20 (360 × 400 cm): 10 × 400 cm wie alt; die zwei Stücke à 353 cm
    // des alten Planers gehören zu keinem UK-Holz der Verlegung
    expect(_zuschnitt(_verlege(_rechteck(3600, 4000))), ['10 × 400.0: 400.0']);
  });
}
