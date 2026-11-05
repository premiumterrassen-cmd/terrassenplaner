import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

import 'argument_fehler.dart';

RechteckGrundriss _rechteck(int ab, int bc) =>
    RechteckGrundriss(Millimeter(ab), Millimeter(bc));

void main() {
  group('Rechteck (M4-02)', () {
    test('Start wie im alten Planer: 480 × 309 cm, 14,832 m²', () {
      const r = RechteckGrundriss.start;
      expect([r.ab.mm, r.bc.mm], [4800, 3090]);
      expect(r.form, Terrassenform.rechteck);
      expect(r.masse, [const Millimeter(4800), const Millimeter(3090)]);
      expect(r.kontur.flaeche, 14832000);
      expect(r.kontur.punkte, const [
        Punkt(0, 0),
        Punkt(4800, 0),
        Punkt(4800, 3090),
        Punkt(0, 3090),
      ]);
      expect(Planungsstand.start.grundriss, r);
    });

    test('Fläche folgt den Maßen', () {
      expect(_rechteck(5400, 3600).kontur.flaeche, 19440000);
      expect(_rechteck(500, 30000).kontur.flaeche, 15000000);
    });

    test('Seiten zwischen 50 und 3000 cm', () {
      const text = 'muss zwischen 50 und 3000 cm liegen';
      expect(() => _rechteck(499, 3000), wirftArgumentFehler('ab', 499, text));
      expect(
        () => _rechteck(3000, 30001),
        wirftArgumentFehler('bc', 30001, text),
      );
      expect(Grundriss.kleinsteSeite, const Millimeter(500));
      expect(Grundriss.groessteSeite, const Millimeter(30000));
    });

    test('Gleichheit nach Maßen', () {
      expect(_rechteck(4000, 3000), _rechteck(4000, 3000));
      expect(_rechteck(4000, 3000).hashCode, _rechteck(4000, 3000).hashCode);
      expect(
        _rechteck(4000, 3000).hashCode,
        Object.hashAll(const [
          Terrassenform.rechteck,
          Millimeter(4000),
          Millimeter(3000),
        ]),
      );
      expect(_rechteck(4000, 3000) == _rechteck(4000, 3001), isFalse);
      expect(_rechteck(4000, 3000) == _rechteck(4001, 3000), isFalse);
      expect(_rechteck(4000, 3000) == Object(), isFalse);
    });

    test('aus Form und Maßen', () {
      expect(
        Grundriss.aus(Terrassenform.rechteck, const [
          Millimeter(4000),
          Millimeter(3000),
        ]),
        _rechteck(4000, 3000),
      );
      expect(
        () => Grundriss.aus(Terrassenform.rechteck, const [Millimeter(4000)]),
        wirftArgumentFehler('masse', 1, 'braucht 2 Maße'),
      );
      expect(Terrassenform.rechteck.nummer, 0);
    });
  });

  group('L-Form (M4-03)', () {
    LGrundriss l(int ab, int bc, int cd, int de) => LGrundriss(
      Millimeter(ab),
      Millimeter(bc),
      Millimeter(cd),
      Millimeter(de),
    );

    test('Vorgabe wie im alten Planer: 14,58 m², E—F und F—A abgeleitet', () {
      const v = LGrundriss.vorgabe;
      expect(Terrassenform.lForm.vorgabe, v);
      expect(v.form, Terrassenform.lForm);
      expect(v.masse.map((m) => m.mm), [2700, 1800, 2700, 1800]);
      expect([v.ab, v.bc, v.cd, v.de].map((m) => m.mm), [
        2700,
        1800,
        2700,
        1800,
      ]);
      expect(v.kontur.flaeche, 14580000);
      expect(v.ecken, const [
        Punkt(0, 0),
        Punkt(2700, 0),
        Punkt(2700, 1800),
        Punkt(5400, 1800),
        Punkt(5400, 3600),
        Punkt(0, 3600),
      ]);
      expect(v.kontur.innenwinkel.map((w) => w.round()), [
        90,
        90,
        270,
        90,
        90,
        90,
      ]);
    });

    test('Maße einzeln ändern, Fläche folgt', () {
      final neu = LGrundriss.vorgabe.mitMass(2, const Millimeter(1000));
      expect(neu, l(2700, 1800, 1000, 1800));
      // 370 × 360 ohne den Ausschnitt C—D × B—C = 100 × 180
      expect(neu.kontur.flaeche, 3700 * 3600 - 1000 * 1800);
      expect(l(1800, 1900, 1800, 1900).kontur.flaeche, 10260000);
      expect(neu == LGrundriss.vorgabe, isFalse);
      expect(neu == RechteckGrundriss.start, isFalse);
    });

    test('auch abgeleitete Seiten innerhalb der Grenzen', () {
      const text = 'muss zwischen 50 und 3000 cm liegen';
      expect(
        () => l(2000, 1000, 30010, 1000),
        wirftArgumentFehler('cd', 30010, text),
      );
      expect(
        () => l(20000, 1000, 15000, 1000),
        wirftArgumentFehler('ef', 35000, text),
      );
      expect(
        () => l(2000, 20000, 2000, 15000),
        wirftArgumentFehler('fa', 35000, text),
      );
      expect(
        () => l(2000, 1000, 2000, 499),
        wirftArgumentFehler('de', 499, text),
      );
      expect(l(15000, 1000, 15000, 1000).kontur.punkte[4].x, 30000);
    });

    test('Transport und Formwahl', () {
      final stand = Planungsstand(grundriss: l(2000, 1000, 2500, 1500));
      expect(Planungsstand.ausBytes(stand.zuBytes()), stand);
      expect(Terrassenform.lForm.nummer, 1);
      expect(Terrassenform.lForm.eingabekanten, [
        'A — B',
        'B — C',
        'C — D',
        'D — E',
      ]);
      expect(Terrassenform.rechteck.eingabekanten, ['A — B', 'B — C']);
      expect(Terrassenform.rechteck.vorgabe, RechteckGrundriss.start);
      expect(
        () => Grundriss.aus(Terrassenform.lForm, const [Millimeter(4000)]),
        wirftArgumentFehler('masse', 1, 'braucht 4 Maße'),
      );
    });
  });

  group('T-Form (M4-04)', () {
    TGrundriss t(List<int> mm) => TGrundriss(
      Millimeter(mm[0]),
      Millimeter(mm[1]),
      Millimeter(mm[2]),
      Millimeter(mm[3]),
      Millimeter(mm[4]),
      Millimeter(mm[5]),
    );

    test('Vorgabe wie im alten Planer: 9,72 m², A—B und F—G abgeleitet', () {
      const v = TGrundriss.vorgabe;
      expect(Terrassenform.tForm.vorgabe, v);
      expect(v.form, Terrassenform.tForm);
      expect(Terrassenform.tForm.nummer, 2);
      expect(v.masse.map((m) => m.mm), [1800, 1350, 1800, 1350, 1350, 1800]);
      expect([v.bc, v.cd, v.de, v.ef, v.gh, v.ha].map((m) => m.mm), [
        1800,
        1350,
        1800,
        1350,
        1350,
        1800,
      ]);
      expect(v.kontur.flaeche, 9720000);
      // A—B 405, B—C 180, C—D 135, D—E 180, E—F 135, F—G 180, G—H 135, H—A 180
      final e = v.ecken;
      expect(
        [
          for (var i = 0; i < e.length; i++)
            e[i].abstand(e[(i + 1) % e.length]).round(),
        ],
        [4050, 1800, 1350, 1800, 1350, 1800, 1350, 1800],
      );
      expect(v.kontur.innenwinkel.map((w) => w.round()), [
        90,
        90,
        90,
        270,
        90,
        90,
        270,
        90,
      ]);
    });

    test('Balken links und rechts verschieden hoch, Fläche folgt', () {
      // Balken 100 + 200 + 150 = 450 breit, rechts 150 hoch, links 100 hoch,
      // Steg 200 breit und bis 150 + 120 = 270 tief
      final f = t([1500, 1500, 1200, 2000, 1000, 1000]);
      expect(f.ecken, const [
        Punkt(0, 0),
        Punkt(4500, 0),
        Punkt(4500, 1500),
        Punkt(3000, 1500),
        Punkt(3000, 2700),
        Punkt(1000, 2700),
        Punkt(1000, 1000),
        Punkt(0, 1000),
      ]);
      expect(f.kontur.flaeche, 1000 * 1000 + 2000 * 2700 + 1500 * 1500);
      expect(
        Planungsstand.ausBytes(Planungsstand(grundriss: f).zuBytes()).grundriss,
        f,
      );
    });

    test('Grenzen auch für abgeleitete Seiten', () {
      const text = 'muss zwischen 50 und 3000 cm liegen';
      expect(
        () => t([1800, 15000, 1800, 15000, 1350, 1800]),
        wirftArgumentFehler('ab', 31350, text),
      );
      // F—G = 100 + 60 − 130 = 30 cm zu kurz
      expect(
        () => t([1000, 1350, 600, 1350, 1350, 1300]),
        wirftArgumentFehler('fg', 300, text),
      );
      expect(
        () =>
            t([1800, 1350, 2000, 1350, 1350, 1800])
                .mitMass(5, const Millimeter(3400)),
        wirftArgumentFehler('fg', 400, text),
      );
      expect(Terrassenform.tForm.eingabekanten, [
        'B — C',
        'C — D',
        'D — E',
        'E — F',
        'G — H',
        'H — A',
      ]);
    });
  });

  group('U-Form (M4-05)', () {
    UGrundriss u(List<int> mm) => UGrundriss(
      Millimeter(mm[0]),
      Millimeter(mm[1]),
      Millimeter(mm[2]),
      Millimeter(mm[3]),
      Millimeter(mm[4]),
      Millimeter(mm[5]),
    );

    List<int> seiten(Grundriss g) {
      final e = g.ecken;
      return [
        for (var i = 0; i < e.length; i++)
          e[i].abstand(e[(i + 1) % e.length]).round(),
      ];
    }

    test('Vorgabe wie im alten Planer: 9,72 m², D—E und G—H abgeleitet', () {
      const v = UGrundriss.vorgabe;
      expect(Terrassenform.uForm.vorgabe, v);
      expect(v.form, Terrassenform.uForm);
      expect(Terrassenform.uForm.nummer, 3);
      expect(v.masse.map((m) => m.mm), [1350, 900, 1350, 1350, 2700, 2700]);
      expect([v.ab, v.bc, v.cd, v.ef, v.fg, v.ha].map((m) => m.mm), [
        1350,
        900,
        1350,
        1350,
        2700,
        2700,
      ]);
      expect(v.kontur.flaeche, 9720000);
      // A—B 135, B—C 90, C—D 135, D—E 90, E—F 135, F—G 270, G—H 405, H—A 270
      expect(seiten(v), [1350, 900, 1350, 900, 1350, 2700, 4050, 2700]);
      expect(v.kontur.innenwinkel.map((w) => w.round()), [
        90,
        90,
        270,
        270,
        90,
        90,
        90,
        90,
      ]);
      expect(Terrassenform.uForm.eingabekanten, [
        'A — B',
        'B — C',
        'C — D',
        'E — F',
        'F — G',
        'H — A',
      ]);
    });

    test('Schenkel verschieden lang, Fläche folgt', () {
      // links 100 breit und 300 hoch, Öffnung 200 breit und 120 tief,
      // rechts 150 breit und 250 hoch → D—E = 120 + 250 − 300 = 70
      final f = u([1000, 1200, 2000, 1500, 2500, 3000]);
      expect(f.ecken, const [
        Punkt(0, 0),
        Punkt(1000, 0),
        Punkt(1000, 1200),
        Punkt(3000, 1200),
        Punkt(3000, 500),
        Punkt(4500, 500),
        Punkt(4500, 3000),
        Punkt(0, 3000),
      ]);
      expect(seiten(f), [1000, 1200, 2000, 700, 1500, 2500, 4500, 3000]);
      expect(
        f.kontur.flaeche,
        1000 * 3000 + 2000 * (3000 - 1200) + 1500 * 2500,
      );
      expect(
        Planungsstand.ausBytes(Planungsstand(grundriss: f).zuBytes()).grundriss,
        f,
      );
    });

    test('Grenzen auch für abgeleitete Seiten', () {
      const text = 'muss zwischen 50 und 3000 cm liegen';
      // D—E = 90 + 200 − 270 = 20 cm zu kurz
      expect(
        () => u([1350, 900, 1350, 1350, 2000, 2700]),
        wirftArgumentFehler('de', 200, text),
      );
      expect(
        () => u([15000, 900, 15000, 1350, 2700, 2700]),
        wirftArgumentFehler('gh', 31350, text),
      );
      expect(
        () => u([1350, 400, 1350, 1350, 2700, 2700]),
        wirftArgumentFehler('bc', 400, text),
      );
    });
  });

  group('Freiform (M4-08)', () {
    const quadrat = [
      Punkt(0, 0),
      Punkt(3000, 0),
      Punkt(3000, 2000),
      Punkt(0, 2000),
    ];

    test('leer nach der Formwahl, Punkte setzen, schließen', () {
      final stand = Planungsstand.start.mitForm(Terrassenform.freiform);
      expect(stand.grundriss, FreiformGrundriss.leer);
      expect(Terrassenform.freiform.vorgabe, FreiformGrundriss.leer);
      expect(Terrassenform.freiform.nummer, 6);
      expect(Terrassenform.freiform.eingabekanten, isEmpty);
      var f = FreiformGrundriss.leer;
      for (final p in quadrat) {
        f = f.mitPunkt(p);
      }
      expect(f.punkte, quadrat);
      expect(f.ecken, quadrat);
      expect(f.geschlossen, isFalse);
      expect(f.form, Terrassenform.freiform);
      expect(() => f.kontur, throwsStateError);
      final zu = f.geschlossene();
      expect(zu.geschlossen, isTrue);
      expect(zu.kontur.flaeche, 6000000);
      expect(zu == f, isFalse);
      // verschieden viele Punkte sind nie gleich (auch nicht der Anfang)
      expect(
        FreiformGrundriss.leer.mitPunkt(Punkt.ursprung) ==
            FreiformGrundriss.leer,
        isFalse,
      );
      expect(
        FreiformGrundriss.leer ==
            FreiformGrundriss.leer.mitPunkt(Punkt.ursprung),
        isFalse,
      );
    });

    test('schließen erst ab drei Punkten (Abnahme M4-08)', () {
      final zwei = FreiformGrundriss.leer
          .mitPunkt(Punkt.ursprung)
          .mitPunkt(const Punkt(1000, 0));
      expect(
        zwei.geschlossene,
        wirftArgumentFehler('punkte', 2, 'mindestens 3 Punkte zum Schließen'),
      );
      expect(
        zwei.mitPunkt(const Punkt(0, 1000)).geschlossene().geschlossen,
        isTrue,
      );
    });

    test('keine kreuzenden Kanten, Kanten ab 10 cm', () {
      expect(
        () => FreiformGrundriss(const [
          Punkt(0, 0),
          Punkt(3000, 1000),
          Punkt(2000, 0),
          Punkt(0, 2000),
        ], geschlossen: true),
        wirftArgumentFehler('punkte', 4, 'Kanten dürfen sich nicht kreuzen'),
      );
      const text = 'muss zwischen 10 und 3000 cm liegen';
      expect(
        () => FreiformGrundriss.leer
            .mitPunkt(Punkt.ursprung)
            .mitPunkt(const Punkt(99, 0)),
        wirftArgumentFehler('ab', 99, text),
      );
      // offen zählt die Schlusskante nicht, geschlossen schon
      final offen = FreiformGrundriss(const [
        Punkt(0, 0),
        Punkt(1000, 0),
        Punkt(1000, 1000),
        Punkt(50, 0),
      ]);
      expect(offen.punkte, hasLength(4));
      expect(offen.geschlossene, wirftArgumentFehler('da', 50, text));
      expect(FreiformGrundriss.kleinsteKante, const Millimeter(100));
    });

    test('letzten Punkt ersetzen oder entfernen', () {
      var f = FreiformGrundriss(quadrat);
      f = f.mitLetztemPunkt(const Punkt(0, 2500));
      expect(f.punkte.last, const Punkt(0, 2500));
      expect(f.punkte, hasLength(4));
      f = f.ohneLetztenPunkt();
      expect(f.punkte, quadrat.take(3));
      expect(f.geschlossen, isFalse);
      expect(
        FreiformGrundriss(
          quadrat,
          geschlossen: true,
        ).ohneLetztenPunkt().geschlossen,
        isFalse,
      );
    });

    test('Transportformat: Kennung und Punkte in mm', () {
      final zu = FreiformGrundriss(quadrat, geschlossen: true);
      expect(zu.masse.map((m) => m.mm), [
        1,
        0,
        0,
        3000,
        0,
        3000,
        2000,
        0,
        2000,
      ]);
      expect(FreiformGrundriss.leer.masse.map((m) => m.mm), [0]);
      for (final g in [
        zu,
        FreiformGrundriss(quadrat),
        FreiformGrundriss.leer,
      ]) {
        final stand = Planungsstand(grundriss: g);
        expect(Planungsstand.ausBytes(stand.zuBytes()), stand);
      }
      expect(
        () => Grundriss.aus(Terrassenform.freiform, const [
          Millimeter(0),
          Millimeter(1),
        ]),
        wirftArgumentFehler('masse', 2, 'braucht Kennung und Punktpaare'),
      );
      expect(
        Grundriss.aus(Terrassenform.freiform, const [Millimeter(0)]),
        FreiformGrundriss.leer,
      );
      expect(
        () => Grundriss.aus(Terrassenform.freiform, const [Millimeter(1)]),
        wirftArgumentFehler('punkte', 0, 'mindestens 3 Punkte zum Schließen'),
      );
    });

    test('Berechnung offen: keine Fläche', () {
      final b = Berechnung(umriss: quadrat, flaeche: 0, geschlossen: false);
      final zurueck = Berechnung.ausBytes(b.zuBytes());
      expect(zurueck.geschlossen, isFalse);
      expect(
        Berechnung.ausBytes(Berechnung(umriss: quadrat, flaeche: 1).zuBytes())
            .geschlossen,
        isTrue,
      );
      final fbb = fb.Builder()..startTable(5);
      fbb.finish(fbb.endTable());
      expect(Berechnung.ausBytes(fbb.buffer).geschlossen, isTrue);
    });
  });

  group('Eckpunkte und Kanten bearbeiten (M4-09)', () {
    final rechteck = RechteckGrundriss(
      const Millimeter(4000),
      const Millimeter(3000),
    ).alsFreiform!;

    test('feste Formen als Freiform, der Kreis nicht', () {
      expect(rechteck.geschlossen, isTrue);
      expect(rechteck.punkte, const [
        Punkt(0, 0),
        Punkt(4000, 0),
        Punkt(4000, 3000),
        Punkt(0, 3000),
      ]);
      expect(LGrundriss.vorgabe.alsFreiform!.punkte, LGrundriss.vorgabe.ecken);
      expect(KreisGrundriss.vorgabe.alsFreiform, isNull);
    });

    test('Ecke ziehen, Punkt auf Kante einfügen', () {
      final gezogen = rechteck.mitPunktAn(2, const Punkt(4500, 3500));
      expect(gezogen.punkte[2], const Punkt(4500, 3500));
      expect(gezogen.geschlossen, isTrue);
      final mehr = rechteck.mitPunktAufKante(3);
      expect(mehr.punkte, hasLength(5));
      expect(mehr.punkte[4], const Punkt(0, 1500));
      expect(rechteck.mitPunktAufKante(0).punkte[1], const Punkt(2000, 0));
      expect(
        () => rechteck.mitPunktAn(0, const Punkt(4000, 3000)),
        throwsArgumentError,
      );
      final offen = FreiformGrundriss(const [Punkt(0, 0), Punkt(1000, 0)]);
      expect(offen.mitPunktAn(1, const Punkt(2000, 0)).geschlossen, isFalse);
    });

    test('mindestens 3 Eckpunkte (Abnahme M4-09)', () {
      final dreieck = rechteck.ohnePunkt(3);
      expect(dreieck.punkte, hasLength(3));
      expect(dreieck.geschlossen, isTrue);
      expect(dreieck.kontur.flaeche, 6000000);
      expect(
        () => dreieck.ohnePunkt(0),
        wirftArgumentFehler('punkte', 3, 'mindestens 3 Eckpunkte'),
      );
      // offen darf es weniger werden
      final offen = FreiformGrundriss(const [Punkt(0, 0), Punkt(1000, 0)]);
      expect(offen.ohnePunkt(0).punkte, const [Punkt(1000, 0)]);
    });

    test('Kante parallel verschieben, nur senkrecht zur Kante', () {
      final breiter = rechteck.mitVerschobenerKante(1, const Punkt(500, 777));
      expect(breiter.punkte[1], const Punkt(4500, 0));
      expect(breiter.punkte[2], const Punkt(4500, 3000));
      expect(breiter.kontur.flaeche, 4500 * 3000);
      // letzte Kante D—A
      final links = rechteck.mitVerschobenerKante(3, const Punkt(-200, 50));
      expect(links.punkte[3], const Punkt(-200, 3000));
      expect(links.punkte[0], const Punkt(-200, 0));
      expect(links.geschlossen, isTrue);
    });
  });

  group('Form drehen (M4-10)', () {
    test('Rechteck um 90°: Breite und Tiefe tauschen, wieder an 0|0', () {
      final g = RechteckGrundriss.start.gedreht(90) as FreiformGrundriss;
      expect(g.geschlossen, isTrue);
      expect(g.kontur.flaeche, closeTo(14832000, 1e-3));
      final h = g.kontur.huellrechteck;
      expect([h.min.x, h.min.y, h.max.x, h.max.y], [0, 0, 3090, 4800]);
      // A liegt nach der Drehung oben rechts
      expect(g.punkte.first, const Punkt(3090, 0));
    });

    test('beliebiger Winkel, Fläche bleibt; Kreis unverändert', () {
      final g = LGrundriss.vorgabe.gedreht(30);
      // Rundung auf 1/1000 mm: höchstens Umfang · 0,0005 mm²
      expect(g.kontur.flaeche, closeTo(14580000, 10));
      expect(g.kontur.huellrechteck.min.x, closeTo(0, 1e-3));
      expect(g.kontur.huellrechteck.min.y, closeTo(0, 1e-3));
      expect(KreisGrundriss.vorgabe.gedreht(45), KreisGrundriss.vorgabe);
      // viermal 90° ergibt wieder dieselben Ecken
      var r = RechteckGrundriss.start as Grundriss;
      for (var i = 0; i < 4; i++) {
        r = r.gedreht(90);
      }
      expect(r.ecken, RechteckGrundriss.start.ecken);
    });

    test('Planungsstand: Ausschnitte werden zurückgesetzt', () {
      final o = Planungsstand.start.mitForm(Terrassenform.oForm);
      final gedreht = o.gedreht(90);
      expect(gedreht.ausschnitte, isEmpty);
      expect(gedreht.grundriss.kontur.flaeche, closeTo(19440000, 1e-3));
    });
  });

  group('Zeichenhilfe (M4-08)', () {
    test('Einrasten auf 10 cm', () {
      expect(Zeichenhilfe.raster, const Millimeter(100));
      expect(
        Zeichenhilfe.einrasten(const Punkt(149, 151)),
        const Punkt(100, 200),
      );
      expect(
        Zeichenhilfe.einrasten(const Punkt(-149, -151)),
        const Punkt(-100, -200),
      );
    });

    test('Ausrichten auf 15°-Schritte, Länge bleibt', () {
      expect(Zeichenhilfe.winkelschritt, 15);
      final p = Zeichenhilfe.ausrichten(
        const Punkt(100, 100),
        const Punkt(1100, 160),
      );
      expect(p.x, closeTo(100 + math.sqrt(1000 * 1000 + 60 * 60), 1e-6));
      expect(p.y, closeTo(100, 1e-6));
      // 50° → 45°
      final q = Zeichenhilfe.ausrichten(
        Punkt.ursprung,
        Zeichenhilfe.streckenpunkt(Punkt.ursprung, 1000, 50),
      );
      expect(Zeichenhilfe.winkelVon(Punkt.ursprung, q), closeTo(45, 1e-9));
      expect(q.laenge, closeTo(1000, 1e-9));
    });

    group('Fangen (#128)', () {
      const t = 25.0;

      test('weit weg von Strahl und Raster: genau am Klickort', () {
        // Gemeldeter Fall: 3 m rechts, 45 cm tiefer (8,5°) landete auf 15°.
        const klick = Punkt(3055, 455);
        expect(Zeichenhilfe.fange(Punkt.ursprung, klick, toleranz: t), klick);
        expect(
          Zeichenhilfe.fange(null, const Punkt(55, 47), toleranz: t),
          const Punkt(55, 47),
        );
      });

      test('nahe am Strahl: Winkel rastet, Länge auf 10 cm', () {
        final p = Zeichenhilfe.fange(
          const Punkt(100, 100),
          const Punkt(3080, 115),
          toleranz: t,
        );
        expect(p.x, closeTo(3100, 1e-6));
        expect(p.y, closeTo(100, 1e-6));
        // 45°: Länge 1414 → 1400, Winkel bleibt.
        final q = Zeichenhilfe.fange(
          Punkt.ursprung,
          Zeichenhilfe.streckenpunkt(Punkt.ursprung, 1414, 45.5),
          toleranz: t,
        );
        expect(Zeichenhilfe.winkelVon(Punkt.ursprung, q), closeTo(45, 1e-9));
        expect(q.laenge, closeTo(1400, 1e-9));
      });

      test('nahe am Strahl, Länge weit vom Raster: Länge bleibt', () {
        final p = Zeichenhilfe.fange(
          Punkt.ursprung,
          const Punkt(1250, 10),
          toleranz: t,
        );
        expect(p.x, closeTo(const Punkt(1250, 10).laenge, 1e-6));
        expect(p.y, closeTo(0, 1e-6));
      });

      test('genau an der Grenze fängt es noch, knapp darüber nicht', () {
        expect(
          Zeichenhilfe.fange(null, const Punkt(125, 275), toleranz: t),
          const Punkt(100, 300),
        );
        expect(
          Zeichenhilfe.fange(null, const Punkt(126, 274), toleranz: t),
          const Punkt(126, 274),
        );
        final strahl = Zeichenhilfe.fange(
          Punkt.ursprung,
          const Punkt(2000, 24),
          toleranz: t,
          mitRaster: false,
        );
        expect(strahl.y, closeTo(0, 1e-9));
        expect(
          Zeichenhilfe.fange(
            Punkt.ursprung,
            const Punkt(2000, 26),
            toleranz: t,
            mitRaster: false,
          ),
          const Punkt(2000, 26),
        );
      });

      test('Grenzwerte gelten einschließlich', () {
        // Abstand zum Strahl genau gleich der Toleranz: fängt noch.
        const klick = Punkt(2000, 100);
        final abstand =
            (Zeichenhilfe.ausrichten(Punkt.ursprung, klick) - klick).laenge;
        final p = Zeichenhilfe.fange(
          Punkt.ursprung,
          klick,
          toleranz: abstand,
          mitRaster: false,
        );
        expect(p.y, closeTo(0, 1e-9));
        // Länge genau 2,5 cm neben dem Raster: rastet noch auf 10 cm.
        final q = Zeichenhilfe.fange(
          Punkt.ursprung,
          const Punkt(1025, 0),
          toleranz: t,
        );
        expect(q.x, closeTo(1000, 1e-9));
      });

      test('Raster höchstens ein Viertel der Rasterweite', () {
        expect(
          Zeichenhilfe.fange(null, const Punkt(1230, 1555), toleranz: 80),
          const Punkt(1230, 1555),
        );
        expect(
          Zeichenhilfe.fange(null, const Punkt(1210, 1555), toleranz: 80),
          const Punkt(1200, 1555),
        );
      });

      test('Hilfen einzeln abschaltbar', () {
        const klick = Punkt(1980, 15);
        expect(
          Zeichenhilfe.fange(
            Punkt.ursprung,
            klick,
            toleranz: t,
            mitWinkel: false,
            mitRaster: false,
          ),
          klick,
        );
        expect(
          Zeichenhilfe.fange(
            Punkt.ursprung,
            klick,
            toleranz: t,
            mitWinkel: false,
          ),
          const Punkt(2000, 0),
        );
        final nurWinkel = Zeichenhilfe.fange(
          Punkt.ursprung,
          klick,
          toleranz: t,
          mitRaster: false,
        );
        expect(nurWinkel.x, closeTo(klick.laenge, 1e-9));
        expect(nurWinkel.y, closeTo(0, 1e-9));
      });

      test('derselbe Punkt wie der letzte: kein Winkel, nur Raster', () {
        expect(
          Zeichenhilfe.fange(
            const Punkt(110, 90),
            const Punkt(110, 90),
            toleranz: t,
          ),
          const Punkt(100, 100),
        );
      });
    });

    test('Strecke aus Länge und Winkel (Abnahme M4-08)', () {
      final p = Zeichenhilfe.streckenpunkt(const Punkt(100, 200), 2000, 90);
      expect(p.x, closeTo(100, 1e-9));
      expect(p.y, closeTo(2200, 1e-9));
      final r = Zeichenhilfe.streckenpunkt(Punkt.ursprung, 1000, 180);
      expect(r.x, closeTo(-1000, 1e-9));
      expect(Zeichenhilfe.winkelVon(Punkt.ursprung, const Punkt(0, -10)), 270);
      expect(Zeichenhilfe.winkelVon(Punkt.ursprung, const Punkt(10, 0)), 0);
      expect(
        Zeichenhilfe.winkelVon(const Punkt(5, 5), const Punkt(5, 15)),
        closeTo(90, 1e-9),
      );
    });
  });

  group('Kreis (M4-07)', () {
    test('Vorgabe Ø 360 cm, Fläche exakt π·r²', () {
      const k = KreisGrundriss.vorgabe;
      expect(Terrassenform.kreis.vorgabe, k);
      expect(k.form, Terrassenform.kreis);
      expect(Terrassenform.kreis.nummer, 5);
      expect(Terrassenform.kreis.eingabekanten, ['Radius']);
      expect(k.radius, const Millimeter(1800));
      expect(k.masse, [const Millimeter(1800)]);
      expect(k.ecken, isEmpty);
      // nicht 10,150 m² wie das Vieleck des alten Planers
      expect(k.kontur.flaeche, closeTo(math.pi * 1800 * 1800, 1e-6));
      expect(k.kontur.flaeche / 1e6, closeTo(10.179, 0.0005));
      final u = k.kontur.huellrechteck;
      expect(u.min.x, closeTo(0, 1e-6));
      expect(u.min.y, closeTo(0, 0.1));
      expect(u.max.x, closeTo(3600, 1e-6));
    });

    test('Durchmesser zwischen 50 und 3000 cm, Transport', () {
      const text = 'Durchmesser muss zwischen 50 und 3000 cm liegen';
      expect(
        () => KreisGrundriss(const Millimeter(249)),
        wirftArgumentFehler('radius', 249, text),
      );
      expect(
        () => KreisGrundriss(const Millimeter(15001)),
        wirftArgumentFehler('radius', 15001, text),
      );
      expect(KreisGrundriss(const Millimeter(250)).radius.mm, 250);
      expect(KreisGrundriss(const Millimeter(15000)).radius.mm, 15000);
      final stand = Planungsstand(
        grundriss: KreisGrundriss(const Millimeter(2000)),
      );
      expect(Planungsstand.ausBytes(stand.zuBytes()), stand);
      expect(
        KreisGrundriss.vorgabe.mitMass(0, const Millimeter(1000)),
        KreisGrundriss(const Millimeter(1000)),
      );
      expect(
        Planungsstand.start.mitForm(Terrassenform.kreis).ausschnitte,
        isEmpty,
      );
    });

    test('Berechnung: Ecken getrennt vom Umriss', () {
      final b = Berechnung(
        umriss: const [Punkt(0, 0), Punkt(1, 0), Punkt(0, 1)],
        ecken: const [],
        flaeche: 1,
      );
      final zurueck = Berechnung.ausBytes(b.zuBytes());
      expect(zurueck.ecken, isEmpty);
      expect(zurueck.umriss, hasLength(3));
      expect(() => b.ecken.add(Punkt.ursprung), throwsUnsupportedError);
      final ohne = Berechnung(
        umriss: const [Punkt(0, 0), Punkt(1, 0)],
        flaeche: 1,
      );
      expect(ohne.ecken, ohne.umriss);
      expect(Berechnung.ausBytes(ohne.zuBytes()).ecken, ohne.umriss);
    });
  });

  group('O-Form und Ausschnitt (M4-06)', () {
    Ausschnitt a({
      String bezeichnung = 'A1',
      int x = 1500,
      int y = 900,
      int laenge = 2400,
      int breite = 1800,
    }) => Ausschnitt(
      bezeichnung: bezeichnung,
      x: Millimeter(x),
      y: Millimeter(y),
      laenge: Millimeter(laenge),
      breite: Millimeter(breite),
    );

    test(
      'Vorgabe wie im alten Planer: außen 540 × 360, A1 240 × 180 mittig',
      () {
        final stand = Planungsstand.start.mitForm(Terrassenform.oForm);
        expect(stand.grundriss, OGrundriss.vorgabe);
        expect(stand.grundriss.form, Terrassenform.oForm);
        expect(Terrassenform.oForm.nummer, 4);
        expect(Terrassenform.oForm.vorgabe, OGrundriss.vorgabe);
        expect(Terrassenform.oForm.eingabekanten, ['A — B', 'B — C']);
        expect(stand.ausschnitte, [Ausschnitt.oForm]);
        expect(Ausschnitt.oForm, a());
        expect(OGrundriss.vorgabe.masse.map((m) => m.mm), [5400, 3600]);
        expect(
          [OGrundriss.vorgabe.ab.mm, OGrundriss.vorgabe.bc.mm],
          [5400, 3600],
        );
        expect(stand.grundriss.kontur.flaeche, 19440000);
        final innen = Ausschnitt.oForm.kontur;
        expect(innen.punkte.first, const Punkt(1500, 900));
        expect(innen.punkte[2], const Punkt(3900, 2700));
        // mittig: links/rechts je 150 cm, oben/unten je 90 cm Rand
        expect(5400 - innen.punkte[2].x, 1500);
        expect(3600 - innen.punkte[2].y, 900);
        expect(
          OGrundriss(const Millimeter(4000), const Millimeter(3000)).ecken[2],
          const Punkt(4000, 3000),
        );
      },
    );

    test('andere Form: ohne Ausschnitt', () {
      final o = Planungsstand.start.mitForm(Terrassenform.oForm);
      expect(o.mitForm(Terrassenform.lForm).ausschnitte, isEmpty);
      expect(o.mitForm(Terrassenform.lForm).grundriss, LGrundriss.vorgabe);
      // Außenmaße ändern behält den Ausschnitt
      final groesser = o.mitGrundriss(
        o.grundriss.mitMass(0, const Millimeter(6000)),
      );
      expect(groesser.ausschnitte, [Ausschnitt.oForm]);
    });

    test('Ausschnitt ändern: X, Y, Länge, Breite', () {
      final o = Planungsstand.start.mitForm(Terrassenform.oForm);
      final neu = o.mitAusschnitt(
        0,
        Ausschnitt.oForm.mitMass(1, const Millimeter(-200)),
      );
      expect(neu.ausschnitte.single, a(y: -200));
      expect(Ausschnitt.oForm.mitMass(0, const Millimeter(10)), a(x: 10));
      expect(
        Ausschnitt.oForm.mitMass(2, const Millimeter(100)),
        a(laenge: 100),
      );
      expect(
        Ausschnitt.oForm.mitMass(3, const Millimeter(30000)),
        a(breite: 30000),
      );
      expect(Ausschnitt.oForm.masse.map((m) => m.mm), [1500, 900, 2400, 1800]);
      expect(neu == o, isFalse);
      expect(o.ausschnitte, [Ausschnitt.oForm]);
    });

    test('Grenzen und Bezeichnung', () {
      const text = 'muss zwischen 10 und 3000 cm liegen';
      expect(() => a(laenge: 99), wirftArgumentFehler('laenge', 99, text));
      expect(
        () => a(breite: 30001),
        wirftArgumentFehler('breite', 30001, text),
      );
      expect(Ausschnitt.kleinsteSeite, const Millimeter(100));
      expect(
        () => a(bezeichnung: ''),
        wirftArgumentFehler('bezeichnung', '', 'braucht 1 bis 10 Zeichen'),
      );
      expect(
        () => a(bezeichnung: 'Pool-Ecke-1'),
        wirftArgumentFehler(
          'bezeichnung',
          'Pool-Ecke-1',
          'braucht 1 bis 10 Zeichen',
        ),
      );
      expect(a(bezeichnung: 'Pool-Ecke1').bezeichnung, 'Pool-Ecke1');
    });

    test('Gleichheit', () {
      expect(a(), a());
      expect(a().hashCode, a().hashCode);
      for (final anders in [
        a(bezeichnung: 'A2'),
        a(x: 1),
        a(y: 1),
        a(laenge: 1000),
        a(breite: 1000),
      ]) {
        expect(anders == a(), isFalse);
      }
      expect(a() == Object(), isFalse);
      final o = Planungsstand.start.mitForm(Terrassenform.oForm);
      expect(
        o,
        Planungsstand(grundriss: OGrundriss.vorgabe, ausschnitte: [a()]),
      );
      expect(
        o.hashCode,
        Planungsstand(
          grundriss: OGrundriss.vorgabe,
          ausschnitte: [a()],
        ).hashCode,
      );
      expect(
        o ==
            Planungsstand(
              grundriss: OGrundriss.vorgabe,
              ausschnitte: [a(x: 1)],
            ),
        isFalse,
      );
      expect(o == const Planungsstand(grundriss: OGrundriss.vorgabe), isFalse);
      expect(
        o ==
            Planungsstand(
              grundriss: OGrundriss.vorgabe,
              ausschnitte: [
                a(),
                a(bezeichnung: 'A2'),
              ],
            ),
        isFalse,
      );
    });

    test('Transportformat mit Ausschnitten', () {
      final stand = Planungsstand(
        grundriss: OGrundriss.vorgabe,
        ausschnitte: [
          a(),
          a(bezeichnung: 'A2', x: -500, y: -300),
        ],
      );
      final zurueck = Planungsstand.ausBytes(stand.zuBytes());
      expect(zurueck, stand);
      expect(() => zurueck.ausschnitte.add(a()), returnsNormally);
      // Ausschnitt mit falscher Anzahl Maße
      final fbb = fb.Builder();
      final grundrissMasse = fbb.writeListInt32([4000, 3000]);
      fbb
        ..startTable(2)
        ..addUint8(0, 0)
        ..addOffset(1, grundrissMasse);
      final grundriss = fbb.endTable();
      final name = fbb.writeString('A1');
      final masse = fbb.writeListInt32([1, 2, 3]);
      fbb
        ..startTable(2)
        ..addOffset(0, name)
        ..addOffset(1, masse);
      final ausschnitt = fbb.endTable();
      final liste = fbb.writeList([ausschnitt]);
      fbb
        ..startTable(3)
        ..addOffset(1, grundriss)
        ..addOffset(2, liste);
      fbb.finish(fbb.endTable());
      expect(
        () => Planungsstand.ausBytes(fbb.buffer),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'Ausschnitt braucht 4 Maße, nicht 3',
          ),
        ),
      );
    });

    test('Berechnung trägt die Ausschnitte', () {
      final b = Berechnung(
        umriss: OGrundriss.vorgabe.ecken,
        flaeche: 19440000,
        ausschnitte: [Ausschnitt.oForm.kontur.punkte, a(x: 0).kontur.punkte],
      );
      final zurueck = Berechnung.ausBytes(b.zuBytes());
      expect(zurueck.ausschnitte, hasLength(2));
      expect(zurueck.ausschnitte[0], Ausschnitt.oForm.kontur.punkte);
      expect(zurueck.ausschnitte[1].first, const Punkt(0, 900));
      expect(() => b.ausschnitte.add(const []), throwsUnsupportedError);
      expect(
        () => b.ausschnitte.first.add(Punkt.ursprung),
        throwsUnsupportedError,
      );
      expect(Berechnung(umriss: const [], flaeche: 0).ausschnitte, isEmpty);
    });
  });

  group('Planungsstand', () {
    test('Gleichheit über den Grundriss, Kopie mit neuem Grundriss', () {
      const start = Planungsstand.start;
      expect(start, const Planungsstand());
      expect(
        start.hashCode,
        Object.hash(
          RechteckGrundriss.start,
          Object.hashAll(const []),
          Rundungen.keine,
          null,
          null,
          false,
          Verlegeart.fugenschnitt,
          Verlegerichtung.waagrecht,
          30,
          0,
          const Millimeter(0),
          const Millimeter(0),
          Befestigungsart.clips,
          Object.hash(
            Terrassenart.normal,
            const Millimeter(800),
            false,
            null,
            Object.hashAll(const []),
            null,
            null,
          ),
          Object.hashAllUnordered(const []),
        ),
      );
      final neu = start.mitGrundriss(_rechteck(5400, 3600));
      expect(neu.grundriss, _rechteck(5400, 3600));
      expect(neu == start, isFalse);
      expect(neu, Planungsstand(grundriss: _rechteck(5400, 3600)));
      expect(start == Object(), isFalse);
      final v = Verlauf(start)..setze(const Planungsstand());
      expect(v.kannRueckgaengig, isFalse);
    });

    test('Belag (M5-01): bleibt bei allen Änderungen der Fläche', () {
      const nummer = Artikelnummer('10-10-060-R');
      final stand = Planungsstand.start.mitBelag(nummer);
      expect(Planungsstand.start.belag, isNull);
      expect(stand.belag, nummer);
      expect(stand == Planungsstand.start, isFalse);
      expect(stand.hashCode == Planungsstand.start.hashCode, isFalse);
      expect(Planungsstand.ausBytes(stand.zuBytes()).belag, nummer);
      expect(Planungsstand.ausBytes(Planungsstand.start.zuBytes()).belag, null);
      final mitA = stand.mitNeuemAusschnitt();
      for (final s in [
        stand.mitGrundriss(_rechteck(5000, 3000)),
        stand.mitRundungen(Rundungen.keine),
        stand.mitForm(Terrassenform.oForm),
        stand.gedreht(90),
        mitA,
        mitA.mitAusschnitt(0, mitA.ausschnitte.single),
        mitA.ohneAusschnitt(0),
      ]) {
        expect(s.belag, nummer);
      }
      final geaendert = Planungsstand(
        grundriss: _rechteck(5000, 3000),
        rundungen: Rundungen.aus(const [0, 0, 500]),
      ).mitNeuemAusschnitt().mitBelag(nummer);
      expect(geaendert.grundriss, _rechteck(5000, 3000));
      expect(geaendert.ausschnitte, hasLength(1));
      expect(geaendert.rundungen, Rundungen.aus(const [0, 0, 500]));
    });

    test('Dielenlänge (M5-02): bleibt bei allen Änderungen', () {
      const laenge = Millimeter(4000);
      const nummer = Artikelnummer('10-10-060-R');
      final stand = Planungsstand.start.mitDielenlaenge(laenge);
      expect(Planungsstand.start.dielenlaenge, isNull);
      expect(stand.dielenlaenge, laenge);
      expect(stand == Planungsstand.start, isFalse);
      expect(stand.hashCode == Planungsstand.start.hashCode, isFalse);
      expect(stand.mitDielenlaenge(null), Planungsstand.start);
      expect(Planungsstand.ausBytes(stand.zuBytes()), stand);
      expect(Planungsstand.ausBytes(stand.zuBytes()).dielenlaenge, laenge);
      expect(
        Planungsstand.ausBytes(Planungsstand.start.zuBytes()).dielenlaenge,
        isNull,
      );
      final mitA = stand.mitNeuemAusschnitt();
      for (final s in [
        stand.mitGrundriss(_rechteck(5000, 3000)),
        stand.mitRundungen(Rundungen.keine),
        stand.mitForm(Terrassenform.oForm),
        stand.gedreht(90),
        stand.mitBelag(nummer),
        mitA,
        mitA.mitAusschnitt(0, mitA.ausschnitte.single),
        mitA.ohneAusschnitt(0),
      ]) {
        expect(s.dielenlaenge, laenge);
      }
      final geaendert = Planungsstand(
        grundriss: _rechteck(5000, 3000),
        rundungen: Rundungen.aus(const [0, 0, 500]),
      ).mitNeuemAusschnitt().mitBelag(nummer).mitDielenlaenge(laenge);
      expect(geaendert.grundriss, _rechteck(5000, 3000));
      expect(geaendert.ausschnitte, hasLength(1));
      expect(geaendert.rundungen, Rundungen.aus(const [0, 0, 500]));
      expect(geaendert.belag, nummer);
    });

    test('kurze Stücke verbinden (M5-03): bleibt bei allen Änderungen', () {
      const nummer = Artikelnummer('10-10-060-R');
      final stand = Planungsstand.start.mitKurzeStueckeVerbinden(true);
      expect(Planungsstand.start.kurzeStueckeVerbinden, isFalse);
      expect(stand.kurzeStueckeVerbinden, isTrue);
      expect(stand == Planungsstand.start, isFalse);
      expect(stand.hashCode == Planungsstand.start.hashCode, isFalse);
      expect(stand.mitKurzeStueckeVerbinden(false), Planungsstand.start);
      expect(Planungsstand.ausBytes(stand.zuBytes()), stand);
      expect(
        Planungsstand.ausBytes(Planungsstand.start.zuBytes())
            .kurzeStueckeVerbinden,
        isFalse,
      );
      final mitA = stand.mitNeuemAusschnitt();
      for (final s in [
        stand.mitGrundriss(_rechteck(5000, 3000)),
        stand.mitRundungen(Rundungen.keine),
        stand.mitForm(Terrassenform.oForm),
        stand.gedreht(90),
        stand.mitBelag(nummer),
        stand.mitDielenlaenge(const Millimeter(4000)),
        mitA,
        mitA.mitAusschnitt(0, mitA.ausschnitte.single),
        mitA.ohneAusschnitt(0),
      ]) {
        expect(s.kurzeStueckeVerbinden, isTrue);
      }
      final geaendert =
          Planungsstand(
                grundriss: _rechteck(5000, 3000),
                rundungen: Rundungen.aus(const [0, 0, 500]),
              )
              .mitNeuemAusschnitt()
              .mitBelag(nummer)
              .mitDielenlaenge(const Millimeter(4000))
              .mitKurzeStueckeVerbinden(true);
      expect(geaendert.grundriss, _rechteck(5000, 3000));
      expect(geaendert.ausschnitte, hasLength(1));
      expect(geaendert.rundungen, Rundungen.aus(const [0, 0, 500]));
      expect(geaendert.belag, nummer);
      expect(geaendert.dielenlaenge, const Millimeter(4000));
    });

    test('Verlegeart (M5-04): bleibt bei allen Änderungen', () {
      const nummer = Artikelnummer('10-10-060-R');
      expect(Planungsstand.start.verlegeart, Verlegeart.fugenschnitt);
      for (final art in Verlegeart.values) {
        final stand = Planungsstand.start.mitVerlegeart(art);
        expect(stand.verlegeart, art);
        expect(Planungsstand.ausBytes(stand.zuBytes()), stand);
      }
      final stand = Planungsstand.start.mitVerlegeart(Verlegeart.halbverband);
      expect(stand == Planungsstand.start, isFalse);
      expect(stand.hashCode == Planungsstand.start.hashCode, isFalse);
      expect(stand.mitVerlegeart(Verlegeart.fugenschnitt), Planungsstand.start);
      final mitA = stand.mitNeuemAusschnitt();
      for (final s in [
        stand.mitGrundriss(_rechteck(5000, 3000)),
        stand.mitRundungen(Rundungen.keine),
        stand.mitForm(Terrassenform.oForm),
        stand.gedreht(90),
        stand.mitBelag(nummer),
        stand.mitDielenlaenge(const Millimeter(4000)),
        stand.mitKurzeStueckeVerbinden(true),
        mitA,
        mitA.mitAusschnitt(0, mitA.ausschnitte.single),
        mitA.ohneAusschnitt(0),
      ]) {
        expect(s.verlegeart, Verlegeart.halbverband);
      }
      final geaendert =
          Planungsstand(
                grundriss: _rechteck(5000, 3000),
                rundungen: Rundungen.aus(const [0, 0, 500]),
              )
              .mitNeuemAusschnitt()
              .mitBelag(nummer)
              .mitDielenlaenge(const Millimeter(4000))
              .mitKurzeStueckeVerbinden(true)
              .mitVerlegeart(Verlegeart.drittelverband);
      expect(geaendert.grundriss, _rechteck(5000, 3000));
      expect(geaendert.ausschnitte, hasLength(1));
      expect(geaendert.rundungen, Rundungen.aus(const [0, 0, 500]));
      expect(geaendert.belag, nummer);
      expect(geaendert.dielenlaenge, const Millimeter(4000));
      expect(geaendert.kurzeStueckeVerbinden, isTrue);
    });

    test('Verlegerichtung (M5-05): bleibt bei allen Änderungen', () {
      const nummer = Artikelnummer('10-10-060-R');
      const start = Planungsstand.start;
      expect(start.verlegerichtung, Verlegerichtung.waagrecht);
      expect(start.verlegewinkel, 30);
      expect(start.dielenwinkel, 0);
      for (final richtung in Verlegerichtung.values) {
        final stand = start.mitVerlegerichtung(richtung, winkel: 17);
        expect(stand.verlegerichtung, richtung);
        expect(stand.verlegewinkel, 17);
        expect(Planungsstand.ausBytes(stand.zuBytes()), stand);
      }
      expect(
        [
          for (final r in Verlegerichtung.values)
            start.mitVerlegerichtung(r).dielenwinkel,
        ],
        [0, 90, 45, 135, 30],
      );
      final stand = start.mitVerlegerichtung(
        Verlegerichtung.individuell,
        winkel: 179,
      );
      expect(stand.dielenwinkel, 179);
      expect(
        stand.mitVerlegerichtung(Verlegerichtung.individuell).verlegewinkel,
        179,
      );
      expect(stand == start, isFalse);
      expect(stand.hashCode == start.hashCode, isFalse);
      expect(
        start.mitVerlegerichtung(Verlegerichtung.waagrecht, winkel: 0) == start,
        isFalse,
      );
      expect(
        stand.mitVerlegerichtung(Verlegerichtung.waagrecht, winkel: 30),
        start,
      );
      expect(
        start
            .mitVerlegerichtung(Verlegerichtung.individuell, winkel: 0)
            .dielenwinkel,
        0,
      );
      for (final falsch in [-1, 180]) {
        expect(
          () => start.mitVerlegerichtung(
            Verlegerichtung.individuell,
            winkel: falsch,
          ),
          throwsA(
            isA<ArgumentError>()
                .having((e) => e.name, 'name', 'winkel')
                .having((e) => e.message, 'message', 'muss 0 bis 179 Grad sein')
                .having((e) => e.invalidValue, 'invalidValue', falsch),
          ),
        );
      }
      final mitA = stand.mitNeuemAusschnitt();
      for (final s in [
        stand.mitGrundriss(_rechteck(5000, 3000)),
        stand.mitRundungen(Rundungen.keine),
        stand.mitForm(Terrassenform.oForm),
        stand.gedreht(90),
        stand.mitBelag(nummer),
        stand.mitDielenlaenge(const Millimeter(4000)),
        stand.mitKurzeStueckeVerbinden(true),
        stand.mitVerlegeart(Verlegeart.halbverband),
        mitA,
        mitA.mitAusschnitt(0, mitA.ausschnitte.single),
        mitA.ohneAusschnitt(0),
      ]) {
        expect(s.verlegerichtung, Verlegerichtung.individuell);
        expect(s.verlegewinkel, 179);
      }
      final geaendert =
          Planungsstand(
                grundriss: _rechteck(5000, 3000),
                rundungen: Rundungen.aus(const [0, 0, 500]),
              )
              .mitNeuemAusschnitt()
              .mitBelag(nummer)
              .mitDielenlaenge(const Millimeter(4000))
              .mitKurzeStueckeVerbinden(true)
              .mitVerlegeart(Verlegeart.drittelverband)
              .mitVerlegerichtung(Verlegerichtung.senkrecht);
      expect(geaendert.grundriss, _rechteck(5000, 3000));
      expect(geaendert.ausschnitte, hasLength(1));
      expect(geaendert.rundungen, Rundungen.aus(const [0, 0, 500]));
      expect(geaendert.belag, nummer);
      expect(geaendert.dielenlaenge, const Millimeter(4000));
      expect(geaendert.kurzeStueckeVerbinden, isTrue);
      expect(geaendert.verlegeart, Verlegeart.drittelverband);
    });

    test('Ausgangspunkt (M5-07): Ecke und Verschiebung', () {
      const nummer = Artikelnummer('10-10-060-R');
      const start = Planungsstand.start;
      expect(start.ausgangsecke, 0);
      expect(start.verschiebungX, const Millimeter(0));
      expect(start.verschiebungY, const Millimeter(0));
      expect(start.ausgangsecken, 4);
      expect(start.ausgangspunkt, Punkt.ursprung);
      final stand = start.mitAusgangspunkt(
        ecke: 2,
        x: const Millimeter(-120),
        y: const Millimeter(35),
      );
      expect(stand.ausgangsecke, 2);
      expect(stand.ausgangspunkt, const Punkt(4800, 3090));
      expect(stand.verschiebungX, const Millimeter(-120));
      expect(stand.verschiebungY, const Millimeter(35));
      expect(Planungsstand.ausBytes(stand.zuBytes()), stand);
      expect(stand == start, isFalse);
      expect(stand.hashCode == start.hashCode, isFalse);
      // nur ein Wert ändert sich, die anderen bleiben
      final nurX = stand.mitAusgangspunkt(x: const Millimeter(5));
      expect(nurX.ausgangsecke, 2);
      expect(nurX.verschiebungX, const Millimeter(5));
      expect(nurX.verschiebungY, const Millimeter(35));
      final nurY = stand.mitAusgangspunkt(y: const Millimeter(7));
      expect(nurY.verschiebungX, const Millimeter(-120));
      expect(nurY.verschiebungY, const Millimeter(7));
      expect(stand.mitAusgangspunkt(ecke: 3).verschiebungX.mm, -120);
      for (final s in [
        start.mitAusgangspunkt(ecke: 1),
        start.mitAusgangspunkt(x: const Millimeter(1)),
        start.mitAusgangspunkt(y: const Millimeter(1)),
      ]) {
        expect(s == start, isFalse);
        expect(Planungsstand.ausBytes(s.zuBytes()), s);
      }
      expect(
        stand.mitAusgangspunkt(
          ecke: 0,
          x: const Millimeter(0),
          y: const Millimeter(0),
        ),
        start,
      );
      for (final falsch in [-1, 4, 5]) {
        expect(
          () => start.mitAusgangspunkt(ecke: falsch),
          throwsA(
            isA<RangeError>()
                .having((e) => e.name, 'name', 'ecke')
                .having((e) => e.start, 'start', 0)
                .having((e) => e.end, 'end', 3),
          ),
        );
      }
      expect(start.mitAusgangspunkt(ecke: 3).ausgangsecke, 3);
      final mitA = stand.mitNeuemAusschnitt();
      for (final s in [
        stand.mitGrundriss(_rechteck(5000, 3000)),
        stand.mitRundungen(Rundungen.keine),
        stand.mitForm(Terrassenform.oForm),
        stand.gedreht(90),
        stand.mitBelag(nummer),
        stand.mitDielenlaenge(const Millimeter(4000)),
        stand.mitKurzeStueckeVerbinden(true),
        stand.mitVerlegeart(Verlegeart.halbverband),
        stand.mitVerlegerichtung(Verlegerichtung.senkrecht),
        mitA,
        mitA.mitAusschnitt(0, mitA.ausschnitte.single),
        mitA.ohneAusschnitt(0),
      ]) {
        expect(s.ausgangsecke, 2);
        expect(s.verschiebungX, const Millimeter(-120));
        expect(s.verschiebungY, const Millimeter(35));
      }
      final geaendert = Planungsstand(
        grundriss: _rechteck(5000, 3000),
        rundungen: Rundungen.aus(const [0, 0, 500]),
        verlegerichtung: Verlegerichtung.senkrecht,
      ).mitNeuemAusschnitt().mitAusgangspunkt(ecke: 1);
      expect(geaendert.grundriss, _rechteck(5000, 3000));
      expect(geaendert.ausschnitte, hasLength(1));
      expect(geaendert.rundungen, Rundungen.aus(const [0, 0, 500]));
      expect(geaendert.verlegerichtung, Verlegerichtung.senkrecht);
      // gerundete Ecke: Schnittpunkt der Kanten
      expect(geaendert.mitAusgangspunkt(ecke: 0).ausgangspunkt, Punkt.ursprung);
    });

    test('Befestigungsart (M5-09): Vorgabe Clips, bleibt bei allen '
        'Änderungen, fehlt im Transport = Vorgabe', () {
      const start = Planungsstand.start;
      expect(start.befestigungsart, Befestigungsart.clips);
      final stand = start.mitBefestigungsart(
        Befestigungsart.verschraubtMitAbstandshaltern,
      );
      expect(
        stand.befestigungsart,
        Befestigungsart.verschraubtMitAbstandshaltern,
      );
      for (final art in Befestigungsart.values) {
        final s = start.mitBefestigungsart(art);
        expect(Planungsstand.ausBytes(s.zuBytes()), s);
      }
      expect(stand == start, isFalse);
      expect(stand.hashCode == start.hashCode, isFalse);
      expect(stand.mitBefestigungsart(Befestigungsart.clips), start);
      final mitA = stand.mitNeuemAusschnitt();
      for (final s in [
        stand.mitGrundriss(_rechteck(5000, 3000)),
        stand.mitRundungen(Rundungen.keine),
        stand.mitForm(Terrassenform.oForm),
        stand.gedreht(90),
        stand.mitBelag(const Artikelnummer('10-10-146')),
        stand.mitDielenlaenge(const Millimeter(4000)),
        stand.mitKurzeStueckeVerbinden(true),
        stand.mitVerlegeart(Verlegeart.halbverband),
        stand.mitVerlegerichtung(Verlegerichtung.senkrecht),
        stand.mitAusgangspunkt(ecke: 1),
        mitA,
        mitA.mitAusschnitt(0, mitA.ausschnitte.single),
        mitA.ohneAusschnitt(0),
      ]) {
        expect(
          s.befestigungsart,
          Befestigungsart.verschraubtMitAbstandshaltern,
        );
      }
      final geaendert = start
          .mitVerlegeart(Verlegeart.halbverband)
          .mitAusgangspunkt(ecke: 2, x: const Millimeter(5))
          .mitBefestigungsart(Befestigungsart.verschraubt);
      expect(geaendert.verlegeart, Verlegeart.halbverband);
      expect(geaendert.ausgangsecke, 2);
      expect(geaendert.verschiebungX, const Millimeter(5));
      Uint8List alt(int? art) {
        final fbb = fb.Builder();
        final masseOrt = fbb.writeListInt32([4800, 3090]);
        fbb
          ..startTable(2)
          ..addUint8(0, 0)
          ..addOffset(1, masseOrt);
        final ort = fbb.endTable();
        fbb
          ..startTable(14)
          ..addOffset(1, ort)
          ..addUint8(13, art);
        fbb.finish(fbb.endTable());
        return fbb.buffer;
      }

      expect(Planungsstand.ausBytes(alt(null)), start);
      expect(
        Planungsstand.ausBytes(alt(2)).befestigungsart,
        Befestigungsart.verschraubtMitAbstandshaltern,
      );
      expect(() => Planungsstand.ausBytes(alt(3)), throwsFormatException);
    });

    test('Zubehör „Tatsächlich“ (M8-01): eingeben, zurücknehmen, bleibt bei '
        'allen Änderungen, reist im Transport', () {
      const start = Planungsstand.start;
      expect(start.zubehoer, isEmpty);
      const vlies = Artikelnummer('50-80-006');
      const oel = Artikelnummer('568-250');
      final stand = start
          .mitZubehoermenge(vlies, 3)
          .mitZubehoermenge(oel, 0)
          .mitZubehoermenge(vlies, 4);
      expect(stand.zubehoer, {vlies: 4, oel: 0});
      expect(() => stand.zubehoer[vlies] = 1, throwsUnsupportedError);
      expect(stand.mitZubehoermenge(vlies, null).zubehoer, {oel: 0});
      expect(
        stand.mitZubehoermenge(vlies, null).mitZubehoermenge(oel, null),
        start,
      );
      expect(Planungsstand.ausBytes(stand.zuBytes()), stand);
      expect(Planungsstand.ausBytes(stand.zuBytes()).zubehoer, {
        vlies: 4,
        oel: 0,
      });
      expect(Planungsstand.ausBytes(start.zuBytes()).zubehoer, isEmpty);
      // gleiche Mengen in anderer Reihenfolge: gleich
      final anders = start.mitZubehoermenge(oel, 0).mitZubehoermenge(vlies, 4);
      expect(anders, stand);
      expect(anders.hashCode, stand.hashCode);
      expect(stand == start.mitZubehoermenge(vlies, 4), isFalse);
      expect(
        stand == start.mitZubehoermenge(vlies, 4).mitZubehoermenge(oel, 1),
        isFalse,
      );
      expect(
        stand.hashCode ==
            start.mitZubehoermenge(vlies, 4).mitZubehoermenge(oel, 1).hashCode,
        isFalse,
      );
      expect(
        start.mitZubehoermenge(vlies, 4) == start.mitZubehoermenge(oel, 4),
        isFalse,
      );
      expect(start.mitZubehoermenge(vlies, 99999).zubehoer[vlies], 99999);
      for (final falsch in [-1, 100000]) {
        expect(
          () => start.mitZubehoermenge(vlies, falsch),
          throwsA(
            isA<RangeError>()
                .having((e) => e.invalidValue, 'invalidValue', falsch)
                .having((e) => e.start, 'start', 0)
                .having((e) => e.end, 'end', 99999)
                .having((e) => e.name, 'name', 'anzahl'),
          ),
        );
      }
      final mitA = stand.mitNeuemAusschnitt();
      for (final s in [
        stand.mitGrundriss(_rechteck(5000, 3000)),
        stand.mitRundungen(Rundungen.keine),
        stand.mitForm(Terrassenform.oForm),
        stand.gedreht(90),
        stand.mitBelag(const Artikelnummer('10-10-146')),
        stand.mitDielenlaenge(const Millimeter(4000)),
        stand.mitKurzeStueckeVerbinden(true),
        stand.mitVerlegeart(Verlegeart.halbverband),
        stand.mitVerlegerichtung(Verlegerichtung.senkrecht),
        stand.mitAusgangspunkt(ecke: 1),
        stand.mitBefestigungsart(Befestigungsart.verschraubt),
        mitA,
        mitA.mitAusschnitt(0, mitA.ausschnitte.single),
        mitA.ohneAusschnitt(0),
      ]) {
        expect(s.zubehoer, {vlies: 4, oel: 0});
      }
      expect(
        stand.mitBefestigungsart(Befestigungsart.verschraubt).befestigungsart,
        Befestigungsart.verschraubt,
      );
    });

    test('Ausgangsecke nach Formwechsel: zurück auf A, wenn es sie nicht '
        'mehr gibt (M5-07)', () {
      final l = Planungsstand.start.mitForm(Terrassenform.lForm);
      expect(l.ausgangsecken, 6);
      final f = l.mitAusgangspunkt(ecke: 5, x: const Millimeter(10));
      expect(f.mitForm(Terrassenform.rechteck).ausgangsecke, 0);
      expect(f.mitForm(Terrassenform.rechteck).verschiebungX.mm, 10);
      expect(f.mitForm(Terrassenform.uForm).ausgangsecke, 5);
      final d = Planungsstand.start.mitAusgangspunkt(ecke: 3);
      expect(d.mitForm(Terrassenform.kreis).ausgangsecke, 0);
      expect(d.mitForm(Terrassenform.kreis).ausgangsecken, 1);
      expect(
        d.mitForm(Terrassenform.kreis).ausgangspunkt,
        d.mitForm(Terrassenform.kreis).kontur.punkte.first,
      );
      expect(d.gedreht(90).ausgangsecke, 3);
      // Freiform: ein Punkt weniger
      final frei = Planungsstand(
        grundriss: FreiformGrundriss(const [
          Punkt(0, 0),
          Punkt(2000, 0),
          Punkt(2000, 2000),
          Punkt(0, 2000),
        ], geschlossen: true),
      ).mitAusgangspunkt(ecke: 3);
      expect(
        frei
            .mitGrundriss(
              FreiformGrundriss(const [
                Punkt(0, 0),
                Punkt(2000, 0),
                Punkt(0, 2000),
              ], geschlossen: true),
            )
            .ausgangsecke,
        0,
      );
      expect(
        frei
            .mitGrundriss(
              FreiformGrundriss(const [
                Punkt(0, 0),
                Punkt(2000, 0),
                Punkt(2000, 2000),
                Punkt(0, 2500),
              ], geschlossen: true),
            )
            .ausgangsecke,
        3,
      );
    });

    test('Ausgangspunkt im Transportformat: fehlende Felder sind die Vorgabe, '
        'unbekannte Ecken werden abgewiesen (M5-07)', () {
      Uint8List alt({int? ecke}) {
        final fbb = fb.Builder();
        final masseOrt = fbb.writeListInt32([4800, 3090]);
        fbb
          ..startTable(2)
          ..addUint8(0, 0)
          ..addOffset(1, masseOrt);
        final ort = fbb.endTable();
        fbb
          ..startTable(11)
          ..addOffset(1, ort)
          ..addUint16(10, ecke);
        fbb.finish(fbb.endTable());
        return fbb.buffer;
      }

      expect(Planungsstand.ausBytes(alt()), Planungsstand.start);
      expect(Planungsstand.ausBytes(alt(ecke: 3)).ausgangsecke, 3);
      expect(() => Planungsstand.ausBytes(alt(ecke: 5)), throwsFormatException);
      expect(
        () => Planungsstand.ausBytes(alt(ecke: 4)),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'unbekannte Ausgangsecke 4',
          ),
        ),
      );
    });

    test('Transportformat hin und zurück', () {
      final stand = Planungsstand(grundriss: _rechteck(5400, 3600));
      final bytes = stand.zuBytes();
      expect(Planungsstand.ausBytes(bytes), stand);
      expect(Planungsstand.schema, 1);
      final puffer = fb.BufferContext.fromBytes(bytes);
      final wurzel = puffer.derefObject(0);
      expect(const fb.Uint16Reader().vTableGet(puffer, wurzel, 4, 0), 1);
    });

    test('kaputte Nachrichten werden abgewiesen', () {
      Uint8List tabelle(void Function(fb.Builder) inhalt) {
        final fbb = fb.Builder();
        inhalt(fbb);
        fbb.finish(fbb.endTable());
        return fbb.buffer;
      }

      expect(
        () => Planungsstand.ausBytes(tabelle((fbb) => fbb.startTable(2))),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'Planungsstand ohne Grundriss',
          ),
        ),
      );
      Uint8List mitGrundriss(int form, List<int> masse) => tabelle((fbb) {
        final masseOrt = fbb.writeListInt32(masse);
        fbb
          ..startTable(2)
          ..addUint8(0, form)
          ..addOffset(1, masseOrt);
        final ort = fbb.endTable();
        fbb
          ..startTable(2)
          ..addOffset(1, ort);
      });
      expect(
        () => Planungsstand.ausBytes(mitGrundriss(7, [4000, 3000])),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'unbekannte Terrassenform 7',
          ),
        ),
      );
      expect(
        () => Planungsstand.ausBytes(mitGrundriss(0, [4000])),
        throwsArgumentError,
      );
      expect(
        () => Planungsstand.ausBytes(mitGrundriss(0, [4000, 100])),
        throwsArgumentError,
      );
      final ohneFelder = Planungsstand.ausBytes(mitGrundriss(0, [4000, 3000]));
      expect(ohneFelder.grundriss, _rechteck(4000, 3000));
      expect(ohneFelder.verlegerichtung, Verlegerichtung.waagrecht);
      expect(ohneFelder.verlegewinkel, 30);
      expect(
        () => Planungsstand.ausBytes(
          tabelle((fbb) {
            final masseOrt = fbb.writeListInt32([4000, 3000]);
            fbb
              ..startTable(2)
              ..addOffset(1, masseOrt);
            final ort = fbb.endTable();
            fbb
              ..startTable(8)
              ..addOffset(1, ort)
              ..addUint8(7, 9);
          }),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'unbekannte Nummer 9',
          ),
        ),
      );
      expect(
        () => Planungsstand.ausBytes(
          tabelle((fbb) {
            final masseOrt = fbb.writeListInt32([4000, 3000]);
            fbb
              ..startTable(2)
              ..addOffset(1, masseOrt);
            final ort = fbb.endTable();
            fbb
              ..startTable(10)
              ..addOffset(1, ort)
              ..addUint8(8, 5);
          }),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'unbekannte Nummer 5',
          ),
        ),
      );
    });
  });

  group('Berechnung', () {
    test('Transportformat hin und zurück', () {
      final b = Berechnung(
        umriss: const [Punkt(0, 0), Punkt(4800.5, 0), Punkt(4800.5, 3090)],
        flaeche: 14832000,
      );
      final zurueck = Berechnung.ausBytes(b.zuBytes());
      expect(zurueck.umriss, b.umriss);
      expect(zurueck.flaeche, 14832000);
      expect(zurueck.flaecheQuadratmeter, 14.832);
      expect(() => b.umriss.add(Punkt.ursprung), throwsUnsupportedError);
      expect(zurueck.dielen, isEmpty);
    });

    test('Dielenstücke (M5-05) hin und zurück, unveränderlich', () {
      final dielen = [
        [const Punkt(0, 0), const Punkt(4800, 0), const Punkt(4800, 65)],
        [const Punkt(0, 65), const Punkt(2400.5, 65), const Punkt(0, 130)],
      ];
      final b = Berechnung(
        umriss: const [Punkt(0, 0), Punkt(4800, 0), Punkt(4800, 3090)],
        flaeche: 1,
        ausschnitte: [
          [const Punkt(1, 1), const Punkt(2, 1), const Punkt(2, 2)],
        ],
        dielen: dielen,
      );
      final zurueck = Berechnung.ausBytes(b.zuBytes());
      expect(zurueck.dielen, dielen);
      expect(zurueck.ausschnitte, b.ausschnitte);
      expect(() => b.dielen.add(const []), throwsUnsupportedError);
      expect(() => b.dielen.first.add(Punkt.ursprung), throwsUnsupportedError);
    });

    test('Ausgangspunkt, Grenzen und kurze Zuschnitte (M5-07) hin und '
        'zurück, auch in der Kopie mit Gesamtfläche', () {
      final b = Berechnung(
        umriss: const [Punkt(0, 0), Punkt(4800, 0), Punkt(4800, 3090)],
        ecken: const [Punkt(0, 0), Punkt(4800, 0)],
        geschlossen: false,
        flaeche: 7,
        ausschnitte: [
          [const Punkt(1, 1), const Punkt(2, 1), const Punkt(2, 2)],
        ],
        dielen: [
          [const Punkt(0, 0), const Punkt(4800, 0), const Punkt(4800, 65)],
        ],
        ausgangspunkt: const Punkt(12.5, -3),
        grenzeLinksRechts: const Millimeter(4800),
        grenzeObenUnten: const Millimeter(65),
        kurzeZuschnitte: true,
        nummern: const [1],
        verschnitt: 0.25,
        dielenliste: const [
          (belag: Artikelnummer('x'), laenge: Millimeter(5000), anzahl: 1),
        ],
      );
      for (final k in [Berechnung.ausBytes(b.zuBytes()), b.mitPlanung(9)]) {
        expect(k.ausgangspunkt, const Punkt(12.5, -3));
        expect(k.grenzeLinksRechts, const Millimeter(4800));
        expect(k.grenzeObenUnten, const Millimeter(65));
        expect(k.kurzeZuschnitte, isTrue);
        expect(k.umriss, b.umriss);
        expect(k.ecken, b.ecken);
        expect(k.geschlossen, isFalse);
        expect(k.flaeche, 7);
        expect(k.ausschnitte, b.ausschnitte);
        expect(k.dielen, b.dielen);
      }
      expect(b.gesamtflaeche, 7);
      expect(b.mitPlanung(9).gesamtflaeche, 9);
      final ohne = Berechnung.ausBytes(
        Berechnung(umriss: const [], flaeche: 0).zuBytes(),
      );
      expect(ohne.ausgangspunkt, isNull);
      expect(ohne.grenzeLinksRechts, const Millimeter(0));
      expect(ohne.grenzeObenUnten, const Millimeter(0));
      expect(ohne.kurzeZuschnitte, isFalse);
      expect(ohne.nummern, isEmpty);
      expect(ohne.verschnitt, isNull);
      expect(ohne.dielenliste, isEmpty);
      // die Kopie übernimmt Nummern, die Planungswerte kommen neu
      expect(b.mitPlanung(9).nummern, [1]);
      expect(b.mitPlanung(9).verschnitt, isNull);
      expect(b.mitPlanung(9).dielenliste, isEmpty);
    });

    test('Nummern, Verschnitt und Dielenliste (M5-08) hin und zurück, '
        'unveränderlich', () {
      const liste = [
        (
          belag: Artikelnummer('10-10-001'),
          laenge: Millimeter(4000),
          anzahl: 2,
        ),
        (
          belag: Artikelnummer('10-10-001'),
          laenge: Millimeter(5000),
          anzahl: 48,
        ),
        (belag: Artikelnummer('40-10-001'), laenge: Millimeter(606), anzahl: 7),
      ];
      final b = Berechnung(
        umriss: const [Punkt(0, 0), Punkt(4800, 0), Punkt(4800, 3090)],
        flaeche: 1,
        dielen: [
          [const Punkt(0, 0), const Punkt(4800, 0), const Punkt(4800, 65)],
          [const Punkt(0, 65), const Punkt(4800, 65), const Punkt(4800, 130)],
        ],
        nummern: const [1, 2],
      ).mitPlanung(3, verschnitt: 0.04, dielenliste: liste);
      for (final k in [b, Berechnung.ausBytes(b.zuBytes())]) {
        expect(k.nummern, [1, 2]);
        expect(k.verschnitt, 0.04);
        expect(k.dielenliste, liste);
        expect(k.gesamtflaeche, 3);
      }
      expect(() => b.nummern.add(3), throwsUnsupportedError);
      expect(b.dielenliste.clear, throwsUnsupportedError);
      // Verschnitt 0 bleibt 0, nicht „fehlt“
      expect(
        Berechnung.ausBytes(
          Berechnung(umriss: const [], flaeche: 0, verschnitt: 0).zuBytes(),
        ).verschnitt,
        0,
      );
    });

    test('Befestigung (M5-09) hin und zurück, auch in der Kopie mit '
        'Gesamtfläche', () {
      final b = Berechnung(
        umriss: const [],
        flaeche: 1,
        befestigung: Befestigungsbedarf(
          arten: const [
            Befestigungsart.verschraubt,
            Befestigungsart.verschraubtMitAbstandshaltern,
          ],
          art: Befestigungsart.verschraubtMitAbstandshaltern,
          punkte: 390,
          mittel: const [
            Befestigungsposition(Artikelnummer('50-50-102'), 'Schrauben', 4),
            Befestigungsposition(
              Artikelnummer('50-90-004'),
              'Abstandshalter',
              3,
            ),
          ],
        ),
      );
      for (final k in [Berechnung.ausBytes(b.zuBytes()), b.mitPlanung(2)]) {
        expect(k.befestigung.arten, b.befestigung.arten);
        expect(
          k.befestigung.art,
          Befestigungsart.verschraubtMitAbstandshaltern,
        );
        expect(k.befestigung.punkte, 390);
        expect(k.befestigung.mittel, b.befestigung.mittel);
      }
      expect(
        () => b.befestigung.mittel.add(b.befestigung.mittel.first),
        throwsUnsupportedError,
      );
      final ohne = Berechnung.ausBytes(
        Berechnung(umriss: const [], flaeche: 0).zuBytes(),
      );
      expect(ohne.befestigung.arten, isEmpty);
      expect(ohne.befestigung.art, isNull);
      expect(ohne.befestigung.punkte, 0);
      expect(ohne.befestigung.mittel, isEmpty);
      expect(
        Berechnung(umriss: const [], flaeche: 0).befestigung,
        same(Befestigungsbedarf.keiner),
      );
    });

    test('leere Nachricht: kein Umriss, Fläche 0', () {
      final fbb = fb.Builder()..startTable(2);
      fbb.finish(fbb.endTable());
      final leer = Berechnung.ausBytes(fbb.buffer);
      expect(leer.umriss, isEmpty);
      expect(leer.flaeche, 0);
      expect(leer.ausgangspunkt, isNull);
      expect(leer.kurzeZuschnitte, isFalse);
    });
  });

  test('WAMP-Name der Berechnung', () {
    expect(
      WampNamen.planungBerechnen,
      'de.robinienwelt.terrassenplaner.kunde.planung.berechnen',
    );
  });
}
