import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

import 'altplaner.dart';

Artikel _artikel(
  String nummer,
  String titel,
  Artikelart art, {
  int inhalt = 1,
  Mengeneinheit einheit = Mengeneinheit.stueck,
  int? laenge,
  int? preis,
}) => Artikel(
  nummer: Artikelnummer(nummer),
  titel: titel,
  art: art,
  einheit: Verkaufseinheit(einheit, inhalt: inhalt),
  abmessungen: Abmessungen(
    laengen: [?(laenge == null ? null : Millimeter(laenge))],
  ),
  preisBrutto: preis == null ? null : Cent(preis),
);

Artikel _clip(String vpe, int inhalt, {bool duo = false}) => _artikel(
  '${duo ? '80-10-002' : '80-10-001'}-$vpe',
  '${duo ? 'DUO-' : ''}CLIP-FIXX® "BLACK EDITION" - VPE $vpe',
  Artikelart.clip,
  inhalt: inhalt,
);

Artikel _schraube(String nummer, int laenge, int inhalt) => _artikel(
  nummer,
  'Terrassenschrauben 5,0 x $laenge mm, $inhalt Stück',
  Artikelart.schraube,
  inhalt: inhalt,
  einheit: Mengeneinheit.verpackungseinheit,
  laenge: laenge,
);

final _clips = [_clip('50', 50), _clip('100', 100), _clip('250', 250)];
final _duos = [
  _clip('50', 50, duo: true),
  _clip('100', 100, duo: true),
  _clip('250', 250, duo: true),
];
final _schrauben = [
  _schraube('50-50-101', 50, 100),
  _schraube('50-50-102', 50, 200),
  _schraube('50-50-103', 60, 100),
  _schraube('50-50-104', 60, 200),
];
final _montagehilfe = _artikel(
  '50-80-009',
  'ALTO Montagehilfe Abstandshalter, VPE zu 4 Stück',
  Artikelart.werkzeug,
);
final _abstandshalter = _artikel(
  '50-90-004',
  'Abstandshalter 4 mm 100 Stück',
  Artikelart.werkzeug,
  inhalt: 100,
  einheit: Mengeneinheit.karton,
);

Artikel _diele(
  String nummer, {
  required Profil profil,
  int breite = 60,
  int staerke = 23,
  Serie serie = premiumSelect,
}) => Artikel(
  nummer: Artikelnummer(nummer),
  titel: 'Diele $nummer',
  art: Artikelart.diele,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  abmessungen: Abmessungen(
    breite: Millimeter(breite),
    staerke: Millimeter(staerke),
    laengen: const [Millimeter(4000), Millimeter(5000), Millimeter(6000)],
  ),
  holzart: robinie,
  serie: serie,
  profil: profil,
);

Artikeleintrag _eintrag(
  Artikel a, {
  List<Artikel> befestigung = const [],
  int? ukAbstand = 400,
}) => Artikeleintrag(
  artikel: a,
  verweise: {
    Beziehung.befestigung.spalte: [for (final b in befestigung) b.nummer],
  },
  angaben: {'Abstand_UK': ?ukAbstand},
);

final _genutet60 = _diele('10-10-073-R', profil: Profil.genutet);
final _genutet100 = _diele('10-10-143-R', profil: Profil.genutet, breite: 100);
final _eco100 = _diele(
  '10-10-142-S',
  profil: Profil.genutet,
  breite: 100,
  serie: ecoSelect,
);
final _glatt100 = _diele(
  '10-10-146',
  profil: Profil.glattkant,
  breite: 100,
  staerke: 21,
  serie: basic,
);
final _glatt60 = _diele('10-10-071-R', profil: Profil.glattkant);
final _glatt100premium = _diele(
  '10-10-146-R',
  profil: Profil.glattkant,
  breite: 100,
);
final _glatt26 = _diele(
  '10-10-999',
  profil: Profil.glattkant,
  staerke: 26,
  serie: basic,
);
final _glatt30 = _diele(
  '10-10-998',
  profil: Profil.glattkant,
  staerke: 31,
  serie: basic,
);

Regelwerk _regelwerk({bool mitMontagehilfe = true}) => Regelwerk(
  Artikeldatei(
    quelle: 'test',
    version: '1',
    eintraege: [
      // Reihenfolge der VPE bewusst gemischt: das Ergebnis folgt den Daten
      _eintrag(_genutet60, befestigung: _clips),
      // DUO-Belag mit einem falschen CLIP-FIXX-Verweis: nur DUO gilt
      _eintrag(_genutet100, befestigung: [..._duos, _clips.first]),
      _eintrag(_eco100, befestigung: [..._duos.take(1), ..._clips]),
      _eintrag(_glatt100, befestigung: [..._schrauben, _clips.first]),
      _eintrag(_glatt60, befestigung: _schrauben, ukAbstand: 500),
      _eintrag(_glatt100premium, befestigung: _schrauben),
      _eintrag(_glatt26, befestigung: _schrauben, ukAbstand: 300),
      _eintrag(_glatt30, befestigung: _schrauben, ukAbstand: null),
      for (final a in [..._clips, ..._duos, ..._schrauben]) _eintrag(a),
      // Einweg-Abstandshalter vor der Montagehilfe: wird nicht gewählt
      _eintrag(_abstandshalter),
      if (mitMontagehilfe) _eintrag(_montagehilfe),
    ],
  ),
);

/// Dielen der Startfläche 480 × 309 cm (F01) mit [breite].
List<Dielenstueck> _verlegt({
  int laenge = 4800,
  int breite = 60,
  double winkel = 0,
  int laengste = 6000,
}) => verlegeDielen(
  Kontur.rechteck(laenge.toDouble(), 3090),
  winkel: winkel,
  ausgangspunkt: Punkt.ursprung,
  dielenbreite: Millimeter(breite),
  verlegeart: Verlegeart.fugenschnitt,
  laengste: Millimeter(laengste),
  fuge: altplanerFuge,
);

Map<String, int> _mittel(Befestigungsbedarf b) => {
  for (final m in b.mittel) m.nummer.wert: m.anzahl,
};

void main() {
  group('Befestigungsart (M5-09)', () {
    test('Clips nur genutet, glattkant verschraubt (B-094, B-090)', () {
      expect(Befestigungsart.fuer(Profil.genutet), [Befestigungsart.clips]);
      expect(Befestigungsart.fuer(Profil.glattkant), [
        Befestigungsart.verschraubt,
        Befestigungsart.verschraubtMitAbstandshaltern,
      ]);
      expect(Befestigungsart.fuer(null), isEmpty);
      expect(
        Befestigungsart.clips.wirksam(Profil.glattkant),
        Befestigungsart.verschraubt,
      );
      expect(
        Befestigungsart.verschraubtMitAbstandshaltern.wirksam(Profil.glattkant),
        Befestigungsart.verschraubtMitAbstandshaltern,
      );
      expect(
        Befestigungsart.verschraubt.wirksam(Profil.genutet),
        Befestigungsart.clips,
      );
      expect(Befestigungsart.clips.wirksam(null), isNull);
    });

    test('Nummern im Transportformat', () {
      expect([for (final a in Befestigungsart.values) a.nummer], [0, 1, 2]);
      for (final a in Befestigungsart.values) {
        expect(Befestigungsart.ausNummer(a.nummer), a);
      }
      expect(
        () => Befestigungsart.ausNummer(3),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'unbekannte Befestigungsart 3',
          ),
        ),
      );
    });
  });

  group('Befestigungspunkte (M5-09)', () {
    test('Übergangs-UK (M8-02): Linien über die Ausdehnung, auch versetzt '
        'und gedreht', () {
      Dielenstueck stueck(List<Punkt> umriss) =>
          Dielenstueck(0, const Millimeter(1000), umriss, breite: 1000);
      // versetzt: 1000 bis 2000 mm, 3 Felder
      final versetzt = uebergangsUk(
        [
          stueck(const [
            Punkt(1000, 0),
            Punkt(2000, 0),
            Punkt(2000, 60),
            Punkt(1000, 60),
          ]),
        ],
        winkel: 0,
        ukAbstand: const Millimeter(400),
      );
      expect(versetzt.linien, [
        1000,
        closeTo(1333.33, 0.01),
        closeTo(1666.67, 0.01),
        2000,
      ]);
      expect(versetzt.lagen.single, (
        anfang: 1000.0,
        ende: 2000.0,
        unten: 0.0,
        oben: 60.0,
      ));
      // Dreieck unter 30°: die Lage hängt von der Drehrichtung ab
      final gedreht = uebergangsUk(
        [
          stueck(const [Punkt(1000, 0), Punkt(2000, 0), Punkt(1000, 1000)]),
        ],
        winkel: 30,
        ukAbstand: const Millimeter(400),
      );
      expect(gedreht.lagen.single.anfang, closeTo(866.03, 0.01));
      expect(gedreht.lagen.single.ende, closeTo(1732.05, 0.01));
      expect(gedreht.lagen.single.unten, closeTo(-1000, 0.01));
      expect(gedreht.lagen.single.oben, closeTo(366.03, 0.01));
      expect(gedreht.linien, hasLength(4));
      expect(
        uebergangsUk(const [], winkel: 0, ukAbstand: const Millimeter(400)),
        (lagen: const <Uklage>[], linien: const <double>[]),
      );
    });

    test('F01: 48 Reihen × 13 UK-Linien, Anfangs- und Endreihe je 13', () {
      final p = befestigungspunkte(
        _verlegt(),
        winkel: 0,
        ukAbstand: const Millimeter(400),
      );
      expect(p, (punkte: 624, randpunkte: 26));
    });

    test('F09: 800 cm mit Stoß bei 600 cm – 22 Auflagen je Reihe', () {
      final p = befestigungspunkte(
        _verlegt(laenge: 8000),
        winkel: 0,
        ukAbstand: const Millimeter(400),
      );
      expect(p, (punkte: 48 * 22, randpunkte: 2 * 22));
    });

    test('Abstand, der nicht aufgeht: Felder aufgerundet', () {
      // 480 cm mit höchstens 35 cm: 14 Felder, 15 Linien
      expect(
        befestigungspunkte(
          _verlegt(),
          winkel: 0,
          ukAbstand: const Millimeter(350),
        ).punkte,
        48 * 15,
      );
      // 481 cm mit 40 cm: 13 Felder, 14 Linien
      expect(
        befestigungspunkte(
          _verlegt(laenge: 4810),
          winkel: 0,
          ukAbstand: const Millimeter(400),
        ).punkte,
        48 * 14,
      );
    });

    test('senkrecht: Linien quer zur Verlegerichtung (F02)', () {
      // 74 Reihen à 309 cm, 309 cm mit 40 cm: 8 Felder, 9 Linien
      final p = befestigungspunkte(
        _verlegt(winkel: 90),
        winkel: 90,
        ukAbstand: const Millimeter(400),
      );
      expect(p, (punkte: 74 * 9, randpunkte: 2 * 9));
    });

    test('ohne Dielen keine Punkte; ein kurzes Stück liegt zweimal auf', () {
      expect(
        befestigungspunkte(
          const [],
          winkel: 0,
          ukAbstand: const Millimeter(400),
        ),
        (punkte: 0, randpunkte: 0),
      );
      final kurz = Dielenstueck(0, const Millimeter(100), const [
        Punkt(0, 0),
        Punkt(100, 0),
        Punkt(100, 65),
        Punkt(0, 65),
      ], breite: 65);
      expect(
        befestigungspunkte([kurz], winkel: 0, ukAbstand: const Millimeter(400)),
        (punkte: 2, randpunkte: 2),
      );
    });
  });

  group('Verkaufseinheiten (M5-09)', () {
    test('wenig Überhang, dann wenig Packungen (F01: 637 → 650)', () {
      Map<String, int> v(int stueck) => {
        for (final (a, n) in verpackt(stueck, _clips)) a.nummer.wert: n,
      };
      expect(v(637), {
        '80-10-001-50': 1,
        '80-10-001-100': 1,
        '80-10-001-250': 2,
      });
      expect(v(500), {'80-10-001-250': 2});
      expect(v(1), {'80-10-001-50': 1});
      expect(v(50), {'80-10-001-50': 1});
      expect(v(51), {'80-10-001-100': 1});
      expect(v(101), {'80-10-001-50': 1, '80-10-001-100': 1});
      expect(v(151), {'80-10-001-100': 2});
      expect(v(201), {'80-10-001-250': 1});
      expect(v(1078), {'80-10-001-100': 1, '80-10-001-250': 4});
      expect(v(0), isEmpty);
      expect(v(-3), isEmpty);
      expect(verpackt(10, const []), isEmpty);
    });

    test('gleich viele Packungen: die zuerst gefundene (Datenreihenfolge)', () {
      Artikel einheit(String n, int inhalt) =>
          _artikel(n, n, Artikelart.clip, inhalt: inhalt);
      final e = [einheit('a', 100), einheit('b', 150), einheit('c', 200)];
      String text(int n) =>
          [for (final (a, anzahl) in verpackt(n, e)) '$anzahl × ${a.nummer}']
              .join(', ');
      // 300 auch als 2 × 150, 450 auch als 3 × 150
      expect(text(300), '1 × a, 1 × c');
      expect(text(350), '1 × b, 1 × c');
      expect(text(450), '1 × a, 1 × b, 1 × c');
      expect(text(500), '1 × a, 2 × c');
      // ohne Bedarf immer dieselbe leere Liste
      expect(identical(verpackt(0, e), verpackt(-1, e)), isTrue);
    });

    test('gleich viele Packungen: die zuerst gefundene Zusammensetzung', () {
      // 200 = 2 × 100 = 60 + 140: beide zwei Packungen ohne Überhang – es
      // bleibt die über die erste Einheit gefundene
      final e = [
        _artikel('a', 'VPE 100', Artikelart.clip, inhalt: 100),
        _artikel('b', 'VPE 60', Artikelart.clip, inhalt: 60),
        _artikel('c', 'VPE 140', Artikelart.clip, inhalt: 140),
      ];
      expect(
        [for (final (a, n) in verpackt(200, e)) (a.nummer.wert, n)],
        [('a', 2)],
      );
    });

    test('nur eine Einheit: aufgerundet', () {
      expect(verpackt(390, [_abstandshalter]).single.$2, 4);
      expect(verpackt(400, [_abstandshalter]).single.$2, 4);
      expect(verpackt(401, [_abstandshalter]).single.$2, 5);
    });
  });

  group('Befestigungsbedarf (M5-09)', () {
    final regelwerk = _regelwerk();

    test('F01 genutet 60 mm: CLIP-FIXX für die Kreuzungen ohne Anfangs- und '
        'Endreihe + 5 %, die Randreihen sichtbar verschraubt (B-094, '
        'Planungskern v6 Regel 4.1, Entscheidung 11.11.2026)', () {
      final b = befestigungsbedarf(
        regelwerk,
        _genutet60,
        Befestigungsart.clips,
        _verlegt(),
        winkel: 0,
      );
      // Gegenstück glattkant: „von oben“ ist wählbar und tauscht die
      // Diele (Planungskern v6 Regel 4.4)
      expect(b.arten, Befestigungsart.values);
      expect(b.wechsel, {
        Befestigungsart.verschraubt: _glatt60.nummer,
        Befestigungsart.verschraubtMitAbstandshaltern: _glatt60.nummer,
      });
      expect(b.art, Befestigungsart.clips);
      expect(b.punkte, 624);
      // (624 − 26) × 1,05 = 627,9 → 628 Clips (vorher 624 + 13 = 637):
      // Clipschrauben im Lieferumfang, keine eigene Position (B-074);
      // 26 Schrauben 5,0 × 50 mm wie beim Gegenstück glattkant
      expect(_mittel(b), {
        '80-10-001-50': 1,
        '80-10-001-100': 1,
        '80-10-001-250': 2,
        '50-50-101': 1,
      });
      expect(b.mittel[2].titel, 'CLIP-FIXX® "BLACK EDITION" - VPE 250');
      // Bedarf in Stück für die Materialliste (M9-03): alle VPE eines Clips
      expect([for (final x in b.bedarf) x.stueck], [628, 26]);
      expect(b.bedarf.first.einheiten, _clips);
      expect(
        b.bedarf.last.einheiten,
        _schrauben.where((s) => s.abmessungen.laengste == const Millimeter(50)),
      );
      expect(b.bedarf.every((x) => !x.jePlanung), isTrue);
      // eine andere Wahl gilt bei genuteten Dielen nicht
      expect(
        befestigungsbedarf(
          regelwerk,
          _genutet60,
          Befestigungsart.verschraubtMitAbstandshaltern,
          _verlegt(),
          winkel: 0,
        ).art,
        Befestigungsart.clips,
      );
    });

    test('auf der UK-Verlegung (M6-10): Kreuzungen mit den echten Hölzern', () {
      final uk = Artikel(
        nummer: const Artikelnummer('10-10-031'),
        titel: 'UK',
        art: Artikelart.unterkonstruktion,
        einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
        abmessungen: Abmessungen(
          breite: const Millimeter(40),
          staerke: const Millimeter(60),
        ),
        holzart: robinie,
        serie: basic,
      );
      final dielen = _verlegt();
      final eng = ukVerlegung(
        Planungsstand.start,
        uk,
        abstand: const Millimeter(300),
        dielen: dielen,
      );
      final b = befestigungsbedarf(
        regelwerk,
        _genutet60,
        Befestigungsart.clips,
        dielen,
        winkel: 0,
        uk: eng,
      );
      // 17 Hölzer (30 cm), die Feldbreite des Aufrufs gilt dann nicht
      expect(b.punkte, 48 * 17);
    });

    test('Feldbreite (M6-09): 30 cm statt 40 cm – mehr UK-Linien, mehr '
        'Clips; über der Firmenregel gilt 40 cm (R-C01)', () {
      int punkte(int? feldbreite) => befestigungsbedarf(
        regelwerk,
        _genutet60,
        Befestigungsart.clips,
        _verlegt(),
        winkel: 0,
        feldbreite: feldbreite == null ? null : Millimeter(feldbreite),
      ).punkte;
      // 480 cm: 13 Linien mit 40 cm, 17 mit 30 cm – je 48 Reihen
      expect(punkte(null), 624);
      expect(punkte(300), 48 * 17);
      expect(punkte(400), 624);
      expect(punkte(600), 624);
    });

    test('PREMIUM SELECT genutet ab 100 mm: DUO-CLIP-FIXX (Abnahme, B-094, '
        'B-150)', () {
      final b = befestigungsbedarf(
        regelwerk,
        _genutet100,
        Befestigungsart.clips,
        _verlegt(breite: 100),
        winkel: 0,
      );
      // 30 Reihen × 13 = 390; Randreihen 2 × 13 mit je zwei Schrauben wie
      // beim Gegenstück glattkant 100 mm (R-B02): 52; Clips (390 − 26) ×
      // 1,05 = 382,2 → 383 → 400
      expect(b.punkte, 390);
      expect(_mittel(b), {
        '80-10-002-50': 1,
        '80-10-002-100': 1,
        '80-10-002-250': 1,
        '50-50-101': 1,
      });
      expect(b.bedarf.last.stueck, 52);
      expect(
        b.mittel
            .where((m) => m.nummer.wert.startsWith('80-'))
            .map((m) => m.titel),
        everyElement(startsWith('DUO-')),
      );
    });

    test('glattkant mit genutetem Gegenstück: sichtverdeckt wählbar, '
        'tauscht die Diele (Planungskern v6 Regel 4.4)', () {
      final b = befestigungsbedarf(
        regelwerk,
        _glatt100premium,
        Befestigungsart.verschraubt,
        _verlegt(breite: 100),
        winkel: 0,
      );
      expect(b.arten, Befestigungsart.values);
      expect(b.wechsel, {Befestigungsart.clips: _genutet100.nummer});
      expect(b.art, Befestigungsart.verschraubt);
      expect(b.wechsel.clear, throwsUnsupportedError);
    });

    test('ECO SELECT genutet 100 mm: CLIP-FIXX (B-094); ohne Gegenstück '
        'auch die Randreihen mit Clips', () {
      final b = befestigungsbedarf(
        regelwerk,
        _eco100,
        Befestigungsart.clips,
        _verlegt(breite: 100),
        winkel: 0,
      );
      // 390 × 1,05 = 409,5 → 410 → 450
      expect(_mittel(b), {'80-10-001-100': 2, '80-10-001-250': 1});
      expect(b.bedarf.single.stueck, 410);
    });

    test('glattkant 100 mm: zwei Schrauben je Punkt, 50 mm (R-B02, B-090)', () {
      final b = befestigungsbedarf(
        regelwerk,
        _glatt100,
        Befestigungsart.clips,
        _verlegt(breite: 100),
        winkel: 0,
      );
      // kein genutetes Gegenstück (BASIC 100 mm): nur verschraubt
      expect(b.arten, [
        Befestigungsart.verschraubt,
        Befestigungsart.verschraubtMitAbstandshaltern,
      ]);
      expect(b.wechsel, isEmpty);
      expect(b.art, Befestigungsart.verschraubt);
      expect(b.punkte, 390);
      // 780 Schrauben → 4 × 200
      expect(_mittel(b), {'50-50-102': 4});
      final mit = befestigungsbedarf(
        regelwerk,
        _glatt100,
        Befestigungsart.verschraubtMitAbstandshaltern,
        _verlegt(breite: 100),
        winkel: 0,
      );
      expect(mit.art, Befestigungsart.verschraubtMitAbstandshaltern);
      // eine Packung Montagehilfe für die Fuge (Alexander 04.11.2026)
      expect(_mittel(mit), {'50-50-102': 4, '50-80-009': 1});
      // Schrauben je Fläche, Montagehilfe einmal je Planung (M9-03)
      expect(
        [for (final x in mit.bedarf) (x.stueck, x.jePlanung)],
        [(780, false), (1, true)],
      );
      expect(mit.bedarf.last.einheiten, [_montagehilfe]);
      expect(
        b.bedarf.single.einheiten,
        _schrauben.where((s) => s.abmessungen.laengste == const Millimeter(50)),
      );
    });

    test('glattkant 60 mm: eine Schraube je Punkt; UK höchstens 40 cm', () {
      final b = befestigungsbedarf(
        regelwerk,
        _glatt60,
        Befestigungsart.verschraubt,
        _verlegt(),
        winkel: 0,
      );
      // Abstand_UK 500 in den Daten, die Holzart erlaubt 400 (R-C01)
      expect(b.punkte, 624);
      expect(_mittel(b), {'50-50-101': 1, '50-50-102': 3});
    });

    test('Schraubenlänge: mindestens doppelte Dielenstärke', () {
      // 26 mm → 60 mm; UK-Abstand 30 cm aus den Daten: 17 Linien
      final b26 = befestigungsbedarf(
        regelwerk,
        _glatt26,
        Befestigungsart.verschraubt,
        _verlegt(),
        winkel: 0,
      );
      expect(b26.punkte, 48 * 17);
      expect(_mittel(b26), {'50-50-103': 1, '50-50-104': 4});
      // 31 mm: keine passt, die längste; ohne Abstand_UK der der Holzart
      final b30 = befestigungsbedarf(
        regelwerk,
        _glatt30,
        Befestigungsart.verschraubt,
        _verlegt(),
        winkel: 0,
      );
      expect(b30.punkte, 624);
      expect(_mittel(b30), {'50-50-103': 1, '50-50-104': 3});
      // genau doppelt (25 mm → 50 mm) reicht (M5-10: keine Meldung)
      final glatt25 = _diele(
        '10-15-011',
        profil: Profil.glattkant,
        staerke: 25,
        serie: massiv,
      );
      final mit25 = Regelwerk(
        Artikeldatei(
          quelle: 'test',
          version: '1',
          eintraege: [
            _eintrag(glatt25, befestigung: _schrauben),
            for (final a in _schrauben) _eintrag(a),
          ],
        ),
      );
      final b25 = befestigungsbedarf(
        mit25,
        glatt25,
        Befestigungsart.verschraubt,
        _verlegt(),
        winkel: 0,
      );
      expect(_mittel(b25).keys, everyElement(startsWith('50-50-10')));
      expect(_mittel(b25).keys, isNot(contains('50-50-103')));
      expect(_mittel(b25).keys, isNot(contains('50-50-104')));
      expect(
        befestigungsmeldungen(mit25, glatt25, Befestigungsart.verschraubt),
        isEmpty,
      );
    });

    test('ohne Montagehilfe in den Daten nur die Schrauben', () {
      final b = befestigungsbedarf(
        _regelwerk(mitMontagehilfe: false),
        _glatt100,
        Befestigungsart.verschraubtMitAbstandshaltern,
        _verlegt(breite: 100),
        winkel: 0,
      );
      expect(_mittel(b), {'50-50-102': 4});
    });

    test('ohne Befestigungsverweise oder Profil keine Artikel', () {
      final ohne = _diele('10-10-000', profil: Profil.genutet);
      final ohneSchrauben = _diele('10-10-001', profil: Profil.glattkant);
      final ohneProfil = Artikel(
        nummer: const Artikelnummer('10-10-002'),
        titel: 'Diele',
        art: Artikelart.diele,
        einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
        abmessungen: Abmessungen(breite: const Millimeter(60)),
        holzart: robinie,
        serie: premiumSelect,
      );
      final r = Regelwerk(
        Artikeldatei(
          quelle: 'test',
          version: '1',
          eintraege: [
            _eintrag(ohne),
            _eintrag(ohneSchrauben),
            _eintrag(ohneProfil),
          ],
        ),
      );
      final b = befestigungsbedarf(
        r,
        ohne,
        Befestigungsart.clips,
        _verlegt(),
        winkel: 0,
      );
      expect(b.art, Befestigungsart.clips);
      expect(b.punkte, 624);
      expect(b.mittel, isEmpty);
      expect(
        befestigungsbedarf(
          r,
          ohneSchrauben,
          Befestigungsart.verschraubt,
          _verlegt(),
          winkel: 0,
        ).mittel,
        isEmpty,
      );
      final keiner = befestigungsbedarf(
        r,
        ohneProfil,
        Befestigungsart.clips,
        _verlegt(),
        winkel: 0,
      );
      expect(keiner, same(Befestigungsbedarf.keiner));
      expect(keiner.arten, isEmpty);
      expect(keiner.art, isNull);
      expect(keiner.punkte, 0);
    });

    test('Holzfliese und Artikel ohne Holz: keine Befestigung', () {
      final fliese = _artikel('40-10-001', 'Fliese', Artikelart.holzfliese);
      final r = Regelwerk(
        Artikeldatei(quelle: 't', version: '1', eintraege: [_eintrag(fliese)]),
      );
      expect(
        befestigungsbedarf(
          r,
          fliese,
          Befestigungsart.clips,
          const [],
          winkel: 0,
        ),
        same(Befestigungsbedarf.keiner),
      );
      final ohneBreite = Artikel(
        nummer: const Artikelnummer('10-10-003'),
        titel: 'Diele',
        art: Artikelart.diele,
        einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
        holzart: robinie,
        serie: premiumSelect,
        profil: Profil.genutet,
      );
      expect(
        befestigungsbedarf(
          Regelwerk(
            Artikeldatei(
              quelle: 't',
              version: '1',
              eintraege: [_eintrag(ohneBreite)],
            ),
          ),
          ohneBreite,
          Befestigungsart.clips,
          const [],
          winkel: 0,
        ),
        same(Befestigungsbedarf.keiner),
      );
    });

    test('Position: Gleichheit und Text', () {
      const a = Befestigungsposition(Artikelnummer('1'), 'Clip', 2);
      expect(a.hashCode, Object.hash(const Artikelnummer('1'), 'Clip', 2));
      expect(a, const Befestigungsposition(Artikelnummer('1'), 'Clip', 2));
      expect(
        a.hashCode,
        const Befestigungsposition(Artikelnummer('1'), 'Clip', 2).hashCode,
      );
      expect(
        a == const Befestigungsposition(Artikelnummer('2'), 'Clip', 2),
        isFalse,
      );
      expect(
        a == const Befestigungsposition(Artikelnummer('1'), 'Cli', 2),
        isFalse,
      );
      expect(
        a == const Befestigungsposition(Artikelnummer('1'), 'Clip', 3),
        isFalse,
      );
      expect(a == Object(), isFalse);
      expect('$a', '2 × 1 Clip');
    });
  });
}
