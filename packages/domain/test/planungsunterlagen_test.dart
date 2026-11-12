import 'dart:math' as math;

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

void main() {
  final datum = DateTime(2026, 11, 5);
  final diele = Artikel(
    nummer: const Artikelnummer('10-10-073'),
    titel: 'Diele 60 x 21 mm',
    art: Artikelart.diele,
    einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
    preisBrutto: const Cent(449),
    abmessungen: Abmessungen(
      breite: const Millimeter(60),
      staerke: const Millimeter(21),
      laengen: const [Millimeter(5000)],
    ),
    holzart: robinie,
    serie: basic,
    profil: Profil.genutet,
  );
  final uk = Artikel(
    nummer: const Artikelnummer('10-10-031'),
    titel: 'UK 40 x 60 mm',
    art: Artikelart.unterkonstruktion,
    einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
    abmessungen: Abmessungen(
      breite: const Millimeter(40),
      staerke: const Millimeter(60),
    ),
    holzart: robinie,
    serie: basic,
  );
  final pad = Artikel(
    nummer: const Artikelnummer('50-60-005'),
    titel: 'Pad',
    art: Artikelart.pad,
    einheit: Verkaufseinheit(Mengeneinheit.karton, inhalt: 70),
    preisBrutto: const Cent(2500),
  );
  final rechteck = [
    const Punkt(0, 0),
    const Punkt(4800, 0),
    const Punkt(4800, 3090),
    const Punkt(0, 3090),
  ];

  List<String> texte(Kapitel k) => [
    k.titel,
    for (final b in k.inhalt)
      ...switch (b) {
        Absatz(:final text) => [text],
        Wertepaare(:final zeilen) => [for (final (a, w) in zeilen) '$a: $w'],
        Tabelle(:final kopf, :final zeilen) => [
          kopf.join(' | '),
          for (final z in zeilen) z.join(' | '),
        ],
        Plan(:final texte) => [for (final t in texte) t.text],
      },
  ];
  Kapitel kapitel(Planungsunterlagen u, String titel) =>
      u.kapitel.singleWhere((k) => k.titel == titel);
  T baustein<T extends Baustein>(Kapitel k, [int nummer = 0]) =>
      k.inhalt.whereType<T>().elementAt(nummer);

  group('ohne Belag', () {
    final b = Berechnung(umriss: rechteck, flaeche: 4800 * 3090);
    Planungsunterlagen erzeuge({
      KonfigurationsStand? stand,
      Kundendaten? kunde,
      Unterlagensprache sprache = Unterlagensprache.deutsch,
    }) => planungsunterlagen(
      planung: Planung.start,
      gesamt: b,
      flaechen: [Flaechenunterlage(b)],
      datum: datum,
      stand: stand,
      kunde: kunde,
      sprache: sprache,
    );

    test('Deckblatt, Terrasse, rechtliche Hinweise; nicht gespeichert', () {
      final u = erzeuge();
      expect(
        [for (final k in u.kapitel) k.titel],
        ['Planungsunterlagen', 'Ihre Terrasse', 'Rechtliche Hinweise'],
      );
      expect(u.texte, same(Unterlagentexte.deutsch));
      expect(u.kopfzeile, 'Ihre Konfigurationsnummer: nicht gespeichert');
      expect(texte(u.kapitel.first), [
        'Planungsunterlagen',
        'Ihre Konfigurationsnummer: nicht gespeichert',
        'Stand: 05.11.2026',
        'Ihre konfigurierte Terrasse',
        'Terrassenfläche: 14,832 m²',
      ]);
      expect(u.kapitel.every((k) => k.neueSeite), isTrue);
      final terrasse = texte(u.kapitel[1]);
      expect(terrasse, [
        'Ihre Terrasse',
        'Fläche: 14,832 m²',
        'Art der Terrasse: normale Terrasse',
        'Untergrund: Schotter (verdichtet)',
        'Art der Terrassennutzung: schwimmende Verlegung',
        'Nutzung: private Nutzung',
        'Auflagen: mit Stelzfüßen und Pads',
        'Terrassengeometrie',
        'A',
        'B',
        'C',
        'D',
        '4,80 m',
        '3,09 m',
        '4,80 m',
        '3,09 m',
      ]);
      final rechtliches = u.kapitel.last;
      expect(texte(rechtliches).skip(4), [
        'Es grüßt Sie das',
        'RobinienWelt TEAM',
        'anfrage@robinienwelt.de',
        'shop.robinienwelt.de',
      ]);
      expect(
        [for (final a in rechtliches.inhalt.cast<Absatz>()) a.fett],
        [false, false, false, false, true, false, false],
      );
    });

    test('mit Konfigurationsnummer, Kundendaten und auf Englisch', () {
      final stand = KonfigurationsStand(
        Konfigurationskennung.lies('2026-10-08-1511-K7QXM'),
        3,
      );
      final u = erzeuge(
        stand: stand,
        kunde: Kundendaten(name: 'Max Muster', telefon: '0123'),
        sprache: Unterlagensprache.englisch,
      );
      expect(
        u.kopfzeile,
        'Your configuration number 2026-10-08-1511-K7QXM · Version 3',
      );
      expect(texte(u.kapitel.first).take(6), [
        'Planning documents',
        'Your details',
        'Name: Max Muster',
        'Phone: 0123',
        'Your configuration number: 2026-10-08-1511-K7QXM',
        'Version: 3',
      ]);
      expect(baustein<Absatz>(u.kapitel.first).fett, isTrue);
      expect(u.kapitel[1].titel, 'Your terrace');
    });

    test('ohne Verlegeplan und UK-Plan: Grundriss mit Namen auf der '
        'Winkelhalbierenden außen und Kanten in m außen (R-E03, R-E04)', () {
      final plan = baustein<Plan>(erzeuge().kapitel[1]);
      expect(plan.linien.single.punkte, rechteck);
      expect(plan.linien.single.staerke, 1);
      expect(plan.linien.single.geschlossen, isTrue);
      // 4 % der größten Ausdehnung: 192 mm
      const a = 4800 * beschriftungsanteil;
      final diagonal = a / math.sqrt2;
      for (final (i, (x, y)) in [
        (-diagonal, -diagonal),
        (4800 + diagonal, -diagonal),
        (4800 + diagonal, 3090 + diagonal),
        (-diagonal, 3090 + diagonal),
      ].indexed) {
        expect(plan.texte[i].ort.x, closeTo(x, 1e-9));
        expect(plan.texte[i].ort.y, closeTo(y, 1e-9));
      }
      expect(
        [for (final t in plan.texte.skip(4)) t.ort],
        const [
          Punkt(2400, -a),
          Punkt(4800 + a, 1545),
          Punkt(2400, 3090 + a),
          Punkt(-a, 1545),
        ],
      );
      // gegen den Uhrzeigersinn gezeichnet: außen bleibt außen
      final links = Berechnung(umriss: rechteck.reversed.toList(), flaeche: 1);
      final andersrum = baustein<Plan>(
        planungsunterlagen(
          planung: Planung.start,
          gesamt: links,
          flaechen: [Flaechenunterlage(links)],
          datum: datum,
        ).kapitel[1],
      );
      expect(andersrum.texte[4].ort, const Punkt(2400, 3090 + a));
      expect(andersrum.texte[0].text, 'D');
    });
  });

  test('offene Freiform und Kreis: Kanten nur zwischen Ecken, ohne Ecken '
      'keine Namen', () {
    final offen = Berechnung(
      umriss: rechteck.take(3).toList(),
      flaeche: 0,
      geschlossen: false,
    );
    final kreis = Berechnung(
      umriss: rechteck,
      ecken: const [],
      flaeche: 1,
      ausschnitte: [rechteck],
    );
    for (final (b, anzahl) in [(offen, 5), (kreis, 0)]) {
      final u = planungsunterlagen(
        planung: Planung.start,
        gesamt: b,
        flaechen: [Flaechenunterlage(b)],
        datum: datum,
      );
      final plan = baustein<Plan>(u.kapitel[1]);
      expect(plan.texte, hasLength(anzahl));
      expect(plan.linien.first.geschlossen, b.geschlossen);
    }
    final u = planungsunterlagen(
      planung: Planung.start,
      gesamt: kreis,
      flaechen: [Flaechenunterlage(kreis)],
      datum: datum,
    );
    final ausschnitt = baustein<Plan>(u.kapitel[1]).linien[1];
    expect(ausschnitt.argb, 0xFF9E9E9E);
  });

  group('mit Belag, UK und Auflagern', () {
    final stand = Planungsstand.start;
    final verlegung = verlegeBelag(stand, diele)!;
    final stuecke = [for (final t in verlegung.teile) ...t.stuecke];
    final materialliste = Materialliste.aus([
      Materialbedarf([diele], 48, laenge: const Millimeter(5000)),
      Materialbedarf(
        [diele],
        1,
        laenge: const Millimeter(5000),
        zusatz: Materialzusatz.freidiele,
      ),
      Materialbedarf([uk], 13, laenge: const Millimeter(4000)),
      Materialbedarf([pad], 91),
      Materialbedarf([pad], 1, zusatz: Materialzusatz.optional),
    ]);
    Berechnung berechnung({
      List<Belagmeldung> meldungen = const [],
      Hoehenpunkte? hoehen,
      List<Auflagermeldung> auflagermeldungen = const [],
      double flaeche = 4800 * 3090,
      List<Millimeter> randErgaenzt = const [],
      Planbild? planbild,
    }) => Berechnung(
      umriss: rechteck,
      planbild: planbild,
      flaeche: flaeche,
      gesamtflaeche: 2 * 4800 * 3090,
      dielen: [for (final s in stuecke) s.umriss],
      nummern: [for (final t in verlegung.teile) ...t.nummern],
      stueckfarben: [for (final _ in stuecke) Stueckfarbe.blau],
      verschnitt: 0.04,
      volumen: 0.427,
      befestigung: Befestigungsbedarf(art: Befestigungsart.clips),
      belagmeldungen: meldungen,
      hoehenpunkte:
          hoehen ??
          Hoehenpunkte(
            hoehen: const [
              Millimeter(150),
              Millimeter(150),
              Millimeter(86),
              Millimeter(86),
            ],
          ),
      materialliste: materialliste,
      stueckliste: Stueckliste.aus([
        Planstueck(
          diele.nummer,
          diele.titel,
          const Millimeter(4800),
          ganzeLaenge: const Millimeter(5000),
        ),
        Planstueck(
          uk.nummer,
          uk.titel,
          const Millimeter(3090),
          ganzeLaenge: const Millimeter(6000),
        ),
        Planstueck(
          uk.nummer,
          uk.titel,
          const Millimeter(360),
          ganzeLaenge: const Millimeter(6000),
          lage: Stuecklage.quer,
        ),
      ]),
      querstreben: const [(von: Punkt(0, 1000), bis: Punkt(400, 1000))],
      unterbau: Unterbau(
        auflagerabstand: const Millimeter(600),
        feldbreite: const Millimeter(400),
        hoelzer: const [
          (von: Punkt(20, 0), bis: Punkt(20, 3090), farbe: Stueckfarbe.blau),
        ],
        holzbreite: const Millimeter(40),
        auflagerpunkte: const [
          (ort: Punkt(20, 0), spalt: Millimeter(5), zeile: 0),
        ],
        zuordnung: const [
          (titel: 'Pad', anzahl: 39, von: Millimeter(5), bis: Millimeter(26)),
          (
            titel: 'Stelzfuß',
            anzahl: 52,
            von: Millimeter(37),
            bis: Millimeter(69),
          ),
        ],
        hoeheVon: const Millimeter(55),
        hoeheBis: const Millimeter(950),
        meldungen: auflagermeldungen,
        randErgaenzt: randErgaenzt,
      ),
    );
    Planungsunterlagen erzeuge(
      List<Berechnung> berechnungen, {
      Planung? planung,
    }) => planungsunterlagen(
      planung:
          planung ??
          Planung([
            for (final _ in berechnungen)
              Terrassenflaeche(stand.mitBelag(diele.nummer)),
          ]),
      gesamt: berechnungen.first,
      flaechen: [
        for (final b in berechnungen)
          Flaechenunterlage(b, belag: diele, uk: uk, verlegung: verlegung),
      ],
      datum: datum,
    );

    test('alle Kapitel wie in den Planungsunterlagen', () {
      final u = erzeuge([berechnung()]);
      expect(
        [for (final k in u.kapitel) (k.titel, k.neueSeite)],
        [
          ('Planungsunterlagen', true),
          ('Ihre Terrasse', true),
          ('Ihre Terrasse – Unterkonstruktion', true),
          ('Ihre Terrasse – Höhenzuordnung der Auflager', false),
          ('Ihre Terrasse – Bemaßung und Höhen', true),
          ('Ihre Terrasse – Terrassenbelag', true),
          ('Ihre Terrasse – Zuschnittsplan Belag', false),
          ('Materialliste', true),
          ('Rechtliche Hinweise', true),
        ],
      );
      expect(texte(u.kapitel.first).skip(4), [
        'Terrassenfläche: 29,664 m²',
        'Volumen: 0,427 m³',
        'Verschnitt: 4,00 %',
        'Summe Materialliste: ${materialliste.summe.anzeige}',
      ]);
    });

    test('Terrasse mit Belag, Befestigung, UK, Feldbreite und Höhen', () {
      final k = erzeuge([berechnung()]).kapitel[1];
      expect(texte(k).take(15), [
        'Ihre Terrasse',
        'Fläche: 14,832 m²',
        'Belag: Diele 60 x 21 mm',
        'Verlegerichtung: waagrecht',
        'Verlegeart: Fugenschnitt',
        'Ausgangspunkt: A (0 cm | 0 cm)',
        'Befestigung: mit Clips',
        'Art der Terrasse: normale Terrasse',
        'Art der Unterkonstruktion: UK 40 x 60 mm',
        'Untergrund: Schotter (verdichtet)',
        'Art der Terrassennutzung: schwimmende Verlegung',
        'Nutzung: private Nutzung',
        'Auflagen: mit Stelzfüßen und Pads',
        'Feldbreite (UK-Achsabstand): 40 cm',
        'Terrassengeometrie',
      ]);
      // keine eigene Draufsicht neben Verlegeplan und UK-Plan (R-E04)
      expect(k.inhalt.whereType<Plan>(), isEmpty);
      final hoehen = baustein<Tabelle>(k);
      expect(hoehen.kopf, ['Eckpunkt', 'Aufbauhöhe (cm)', 'Winkel']);
      expect(hoehen.zeilen, [
        ['A', '15', '90°'],
        ['B', '15', '90°'],
        ['C', '8,6', '90°'],
        ['D', '8,6', '90°'],
      ]);
      expect(hoehen.rechts, {1, 2});
    });

    test('mehr Höhen als Ecken: Winkel leer', () {
      final k = erzeuge([
        berechnung(
          hoehen: Hoehenpunkte(hoehen: List.filled(5, const Millimeter(86))),
        ),
      ]).kapitel[1];
      expect(baustein<Tabelle>(k).zeilen.last, ['E', '8,6', '']);
    });

    test('UK: Plan mit Hölzern, Querstreben und Auflagern, Stückliste ohne '
        'Belag', () {
      final k = erzeuge([berechnung()]).kapitel[2];
      final plan = baustein<Plan>(k);
      expect(plan.linien, hasLength(4));
      expect(plan.linien.first.argb, 0xFF9E9E9E);
      final holz = plan.linien[1];
      expect(holz.gefuellt, isTrue);
      expect(holz.argb, Stueckfarbe.blau.argb);
      expect(holz.punkte, const [
        Punkt(40, -20),
        Punkt(40, 3110),
        Punkt(0, 3110),
        Punkt(0, -20),
      ]);
      final strebe = plan.linien[2];
      expect(strebe.punkte, const [Punkt(0, 1000), Punkt(400, 1000)]);
      expect(strebe.geschlossen, isFalse);
      expect(strebe.staerke, 1.5);
      expect(strebe.argb, Stueckfarbe.gruen.argb);
      expect(plan.linien[3].punkte, const [
        Punkt(-5, -25),
        Punkt(45, -25),
        Punkt(45, 25),
        Punkt(-5, 25),
      ]);
      final liste = baustein<Tabelle>(k);
      expect(liste.zeilen, [
        ['1', 'UK 40 x 60 mm', '309', '1', 'blau'],
        ['2', 'UK 40 x 60 mm', '36', '1', 'grün'],
      ]);
      expect(liste.farben, [Stueckfarbe.blau.argb, Stueckfarbe.gruen.argb]);
    });

    test('UK ohne Holzbreite: 40 mm', () {
      final ohne = Berechnung(
        umriss: rechteck,
        flaeche: 1,
        unterbau: Unterbau(
          hoelzer: const [
            (von: Punkt(0, 0), bis: Punkt(0, 100), farbe: Stueckfarbe.rot),
          ],
        ),
      );
      final u = planungsunterlagen(
        planung: Planung.start,
        gesamt: ohne,
        flaechen: [Flaechenunterlage(ohne)],
        datum: datum,
      );
      final holz = baustein<Plan>(u.kapitel[2]).linien[1];
      expect(holz.punkte.first, const Punkt(20, -20));
      expect(baustein<Tabelle>(u.kapitel[2]).zeilen, isEmpty);
    });

    test('Höhenzuordnung der Auflager', () {
      final k = erzeuge([berechnung()]).kapitel[3];
      expect(texte(k), [
        'Ihre Terrasse – Höhenzuordnung der Auflager',
        'Abstand der Auflager: 60 cm',
        'Auflager | Spalt UK bis Boden (cm) | Anzahl',
        'Pad | 0,5 – 2,6 | 39',
        'Stelzfuß | 3,7 – 6,9 | 52',
      ]);
    });

    test('Bemaßung und Höhen (Planungskern v7, Regel 9.2, R-E05): H je Ecke, '
        'Höhe je Auflager, Farbe je Fußtyp mit Legende', () {
      final b = berechnung(
        planbild: Planbild(
          achsen: Masskette(const [
            Punkt(0, 3090),
            Punkt(20, 3090),
            Punkt(4800, 3090),
          ], const Punkt(0, 1)),
        ),
      );
      final punkte = const <Auflagerpunkt>[
        (ort: Punkt(20, 50), spalt: Millimeter(5), zeile: 0),
        (ort: Punkt(20, 600), spalt: Millimeter(45), zeile: 1),
        (ort: Punkt(20, 1200), spalt: Millimeter(46), zeile: 1),
        (ort: Punkt(20, 3040), spalt: Millimeter(900), zeile: null),
      ];
      final mit = Berechnung(
        umriss: b.umriss,
        flaeche: b.flaeche,
        planbild: b.planbild,
        hoehenpunkte: b.hoehenpunkte,
        unterbau: Unterbau(
          hoelzer: b.unterbau.hoelzer,
          holzbreite: b.unterbau.holzbreite,
          auflagerpunkte: punkte,
          zuordnung: b.unterbau.zuordnung,
        ),
      );
      final u = planungsunterlagen(
        planung: Planung.start,
        gesamt: mit,
        flaechen: [Flaechenunterlage(mit)],
        datum: datum,
      );
      final k = kapitel(u, 'Ihre Terrasse – Bemaßung und Höhen');
      expect(k.neueSeite, isTrue);
      final plan = baustein<Plan>(k);
      expect(plan.linien.first.argb, 0xFF000000);
      expect(plan.linien[1].argb, ukHellfarbe);
      expect(plan.linien[1].gefuellt, isTrue);
      expect(
        [for (final l in plan.linien.skip(2).take(4)) l.argb],
        [auflagerfarben[0], auflagerfarben[1], auflagerfarben[1], 0xFF000000],
      );
      expect(plan.linien[2].punkte.first, const Punkt(-10, 20));
      // Achsmaßkette: Linie und drei Marken
      expect(plan.linien.skip(6), hasLength(4));
      expect(plan.linien.last.argb, achsmassfarbe);
      final texte = [for (final t in plan.texte) t.text];
      expect(
        texte,
        containsAll(['A', 'H = 15 cm', 'H = 8,6 cm', '0,5', '4,5', '90']),
      );
      expect(texte.where((t) => t.startsWith('H = ')), hasLength(4));
      // Höhe des Auflagers unter dem Punkt, H außen hinter dem Buchstaben
      final a = plan.texte.firstWhere((t) => t.text == 'A').ort;
      final h = plan.texte.firstWhere((t) => t.text == 'H = 15 cm').ort;
      expect(h.abstand(Punkt.ursprung), greaterThan(a.abstand(Punkt.ursprung)));
      final spalt = plan.texte.firstWhere((t) => t.text == '0,5').ort;
      // neben dem Holz (quer zur UK), nicht darauf
      expect(spalt.x, lessThan(20));
      expect(spalt.y, closeTo(50, 1e-9));
      expect(baustein<Absatz>(k).text, startsWith('H = Höhe Oberkante'));
      final legende = baustein<Tabelle>(k);
      expect(legende.kopf, ['Auflager', 'Anzahl']);
      expect(legende.zeilen, [
        ['Pad', '1'],
        ['Stelzfuß', '2'],
        ['Kein passendes Auflager', '1'],
      ]);
      expect(legende.farben, [
        auflagerfarben[0],
        auflagerfarben[1],
        0xFF000000,
      ]);
      expect(legende.rechts, {1});
      expect(auflagerfarbe(auflagerfarben.length + 2), auflagerfarben[2]);
    });

    test('Bemaßung: ohne Auflager keine Seite, beim Kreis kein H im Plan', () {
      final ohne = erzeuge([Berechnung(umriss: rechteck, flaeche: 1)]).kapitel
          .map((k) => k.titel);
      expect(ohne.where((t) => t.contains('Bemaßung')), isEmpty);
      final kreis = Berechnung(
        umriss: rechteck,
        ecken: const [Punkt.ursprung],
        flaeche: 1,
        hoehenpunkte: Hoehenpunkte(hoehen: const [Millimeter(86)]),
        unterbau: Unterbau(
          auflagerpunkte: const [
            (ort: Punkt(20, 50), spalt: Millimeter(3), zeile: 0),
          ],
          zuordnung: const [
            (titel: 'Pad', anzahl: 1, von: Millimeter(3), bis: Millimeter(3)),
          ],
        ),
      );
      final u = planungsunterlagen(
        planung: Planung.start,
        gesamt: kreis,
        flaechen: [Flaechenunterlage(kreis)],
        datum: datum,
      );
      final plan = baustein<Plan>(
        kapitel(u, 'Ihre Terrasse – Bemaßung und Höhen'),
      );
      expect([for (final t in plan.texte) t.text], ['0,3']);
    });

    test('Bemaßung ohne Holzbreite: Hölzer 40 mm breit; Verlegeplan ohne UK '
        'zeigt keinen eigenen Grundriss', () {
      final b = Berechnung(
        umriss: rechteck,
        flaeche: 1,
        unterbau: Unterbau(
          hoelzer: const [
            (von: Punkt(0, 0), bis: Punkt(0, 100), farbe: Stueckfarbe.rot),
          ],
          auflagerpunkte: const [
            (ort: Punkt(0, 50), spalt: Millimeter(3), zeile: 0),
          ],
          zuordnung: const [
            (titel: 'Pad', anzahl: 1, von: Millimeter(3), bis: Millimeter(3)),
          ],
        ),
      );
      final u = planungsunterlagen(
        planung: Planung.start,
        gesamt: b,
        flaechen: [Flaechenunterlage(b, belag: diele, verlegung: verlegung)],
        datum: datum,
      );
      final mass = baustein<Plan>(
        kapitel(u, 'Ihre Terrasse – Bemaßung und Höhen'),
      );
      expect(mass.linien[1].punkte.first, const Punkt(20, -20));
      final ohneUk = Berechnung(umriss: rechteck, flaeche: 1);
      final nurBelag = planungsunterlagen(
        planung: Planung.start,
        gesamt: ohneUk,
        flaechen: [
          Flaechenunterlage(ohneUk, belag: diele, verlegung: verlegung),
        ],
        datum: datum,
      );
      expect(nurBelag.kapitel[1].inhalt.whereType<Plan>(), isEmpty);
      expect(
        Unterlagentexte.deutsch.stossHinweis,
        'Rot gestrichelt: Stoß – jedes Dielenende liegt auf einer eigenen '
        'UK (Doppel-UK).',
      );
    });

    test('Belag: Verlegeplan mit Nummern, Dielen nach Nummer, Lieferung und '
        'Zuschnitt', () {
      final u = erzeuge([berechnung()]);
      final k = u.kapitel[5];
      expect(baustein<Absatz>(k).text, startsWith('Hinweis: Die Zahl'));
      final plan = baustein<Plan>(k);
      expect(plan.linien, hasLength(stuecke.length + 1));
      expect(plan.linien[1].staerke, 0.3);
      expect(plan.linien[1].argb, Stueckfarbe.blau.argb);
      final erstes = stuecke.first.umriss;
      expect(
        plan.texte.first.ort.x,
        closeTo(erstes.fold(0.0, (s, p) => s + p.x) / erstes.length, 1e-9),
      );
      expect(plan.texte.first.text, '1');
      final sorten = baustein<Tabelle>(k);
      expect(sorten.zeilen.first, [
        '1',
        'Diele 60 x 21 mm',
        '480 × 6',
        '${verlegung.teile.first.sorten.first.stueck}',
      ]);
      // 309 cm mit 6 mm Fuge (Planungskern v6): 47 Reihen, mit 5 mm 48
      expect(baustein<Tabelle>(k, 1).zeilen, [
        ['500', '47'],
      ]);
      expect(baustein<Tabelle>(u.kapitel[6]).zeilen, [
        ['Diele 60 x 21 mm', '500', '47', '480'],
      ]);
    });

    test('Zuschnitt fasst gleiche Lieferdielen zusammen', () {
      final v = verlegeBelag(
        Planungsstand.start.mitGrundriss(
          RechteckGrundriss(const Millimeter(2000), const Millimeter(700)),
        ),
        diele,
      )!;
      final b = Berechnung(umriss: rechteck, flaeche: 1);
      final u = planungsunterlagen(
        planung: Planung.start,
        gesamt: b,
        flaechen: [Flaechenunterlage(b, belag: diele, verlegung: v)],
        datum: datum,
      );
      final zuschnitt = baustein<Tabelle>(
        u.kapitel.singleWhere((k) => k.titel.endsWith('Zuschnittsplan Belag')),
      );
      expect(zuschnitt.zeilen, [
        ['Diele 60 x 21 mm', '500', '5', '200 | 200'],
        ['Diele 60 x 21 mm', '500', '1', '200'],
      ]);
    });

    test('Materialliste mit Länge, Freidiele, optionaler Position, Preisen '
        'und Hinweis', () {
      final k = kapitel(erzeuge([berechnung()]), 'Materialliste');
      final tabelle = baustein<Tabelle>(k);
      expect(tabelle.zeilen.first.take(4), [
        '1',
        'Diele 60 x 21 mm – Länge: 5000 mm',
        '48 Stück',
        '240,00',
      ]);
      expect(
        tabelle.zeilen[1][1],
        'Diele 60 x 21 mm – Länge: 5000 mm – '
        'Freidiele',
      );
      expect(tabelle.zeilen.first.skip(4), ['4,49', '22,45', '1.077,60']);
      // UK ohne Preis: „–“; Pad ohne lfm: leer
      expect(tabelle.zeilen[2].skip(4), ['–', '–', '–']);
      expect(tabelle.zeilen[3].skip(3), ['', '', '25,00', '50,00']);
      // optional (Planungskern v6 Regel 4.5): mit Preis, nicht in der Summe
      expect(
        tabelle.zeilen.last[1],
        endsWith(' – optional – nicht in der Summe'),
      );
      expect(tabelle.zeilen.last.skip(5), ['25,00', '25,00']);
      expect(tabelle.rechts, {0, 2, 3, 4, 5, 6});
      expect(texte(k).skip(7), [
        'Summe gesamt: ${materialliste.summe.anzeige}',
        'enthaltene 19 % MwSt.: ${materialliste.mehrwertsteuer.anzeige}',
        'Alle Preise inkl. MwSt. und nur zur Information – verbindlich ist '
            'unser Angebot.',
        'Für Positionen mit „–“ ist kein Preis hinterlegt; sie fehlen in der '
            'Summe.',
      ]);
    });

    test('Hinweise je Fläche, mehrere Flächen nummeriert', () {
      final mitMeldung = berechnung(
        meldungen: [Belagmeldung.laengeNichtLieferbar],
        hoehen: Hoehenpunkte(
          hoehen: const [Millimeter(63)],
          mindesthoehe: const Millimeter(63),
          korrigiert: true,
          gedreht: true,
          hoechsthoehe: const Millimeter(524),
          ungueltig: true,
          vorschlag: const Millimeter(113),
        ),
        auflagermeldungen: Auflagermeldung.values,
        // 0,5 m²: Hinweis zur Fläche (Planungskern v6 Regel 1.7)
        flaeche: 500000,
        randErgaenzt: const [Millimeter(2570)],
      );
      final planung = Planung([
        Terrassenflaeche(Planungsstand.start),
        Terrassenflaeche(
          Planungsstand.start.mitDielenlaenge(const Millimeter(7000)),
          haeufigkeit: 2,
        ),
      ]);
      final u = erzeuge([berechnung(), mitMeldung], planung: planung);
      expect(u.kapitel[1].titel, 'Terrasse 1');
      expect(
        texte(u.kapitel.singleWhere((k) => k.titel == 'Terrasse 2')),
        contains('Anzahl gleicher Flächen: 2'),
      );
      expect(texte(u.kapitel.first), contains('Anzahl der Flächen: 2'));
      final hinweise = kapitel(u, 'Hinweise zur Planung');
      expect(hinweise.neueSeite, isFalse);
      expect(texte(hinweise), [
        'Hinweise zur Planung',
        'Terrasse 2',
        '• ${Unterlagentexte.deutsch.flaechenmeldung(Flaechenmeldung.ungewoehnlich)}',
        '• ${Unterlagentexte.deutsch.belagmeldung(Belagmeldung.laengeNichtLieferbar, const Millimeter(7000))}',
        '• ${Unterlagentexte.deutsch.ukGedreht}',
        '• ${Unterlagentexte.deutsch.hoeheKorrigiert(const Millimeter(63))}',
        '• ${Unterlagentexte.deutsch.hoeheUngueltig(const Millimeter(524), const Millimeter(113))}',
        '• ${Unterlagentexte.deutsch.auflagermeldung(Auflagermeldung.unterMindesthoehe, const Millimeter(55))}',
        '• ${Unterlagentexte.deutsch.auflagermeldung(Auflagermeldung.ueberHoechsthoehe, const Millimeter(950))}',
        '• ${Unterlagentexte.deutsch.randUkErgaenzt(const Millimeter(2570))}',
      ]);
      expect(baustein<Absatz>(hinweise).fett, isTrue);
      final eine = erzeuge([
        mitMeldung,
      ], planung: Planung([planung.flaechen.last]));
      expect(texte(kapitel(eine, 'Hinweise zur Planung'))[1], startsWith('• '));
    });
    test('Materialliste: Position nicht im Angebot (Planungskern v7 Regel '
        '9.7) bleibt mit Namen stehen, nicht in der Summe', () {
      final liste = Materialliste.aus(
        [
          Materialbedarf([diele], 48, laenge: const Millimeter(5000)),
          Materialbedarf([pad], 2),
        ],
        ausserhalbAngebot: {(nummer: pad.nummer, laenge: null, zusatz: null)},
      );
      final k = kapitel(
        erzeuge([
          Berechnung(
            umriss: rechteck,
            flaeche: 4800 * 3090,
            materialliste: liste,
          ),
        ]),
        'Materialliste',
      );
      final tabelle = baustein<Tabelle>(k);
      expect(tabelle.zeilen.first[1], startsWith('Diele'));
      expect(tabelle.zeilen.last[1], 'Nicht im Angebot: ${pad.titel}');
      expect(tabelle.zeilen.last.last, '25,00');
      expect(texte(k), contains('Summe gesamt: ${liste.summe.anzeige}'));
      expect(liste.summe, liste.positionen.first.positionspreis);
    });

    test('Hinweise: Kanten und Treppen aus der Prüfliste (Planungskern v7 '
        'Regel 9.5/9.6)', () {
      final treppe = Planungsstand.start.mitNeuerTreppe().mitTreppe(
        0,
        const Treppe(seite: 2),
      );
      const ecken = [
        Punkt(0, 0),
        Punkt(4800, 0),
        Punkt(4800, 50),
        Punkt(4800, 3090),
        Punkt(0, 3090),
      ];
      final u = erzeuge([
        Berechnung(
          umriss: ecken,
          ecken: ecken,
          flaeche: 4800 * 3090,
          anschluss: anschlussergebnis(treppe),
        ),
      ], planung: Planung([Terrassenflaeche(treppe)]));
      final de = Unterlagentexte.deutsch;
      expect(texte(kapitel(u, 'Hinweise zur Planung')), [
        'Hinweise zur Planung',
        '• ${de.kantenwarnung((kante: 'B–C', laenge: const Millimeter(50), art: Kantenmeldung.zuKurz))}',
        '• ${de.treppenmeldung(1, Treppenmeldung.schrittmass)}',
      ]);
    });
  });

  group('Pläne nach dem Planungskern (Abschnitt 6)', () {
    final stand = Planungsstand.start;
    final verlegung = verlegeBelag(stand, diele)!;
    Planungsunterlagen erzeuge(Berechnung b, {Planungsstand? stand}) =>
        planungsunterlagen(
          planung: Planung([Terrassenflaeche(stand ?? Planungsstand.start)]),
          gesamt: b,
          flaechen: [
            Flaechenunterlage(b, belag: diele, uk: uk, verlegung: verlegung),
          ],
          datum: datum,
        );
    final hoelzer = <UkHolz>[
      (
        von: const Punkt(20, 0),
        bis: const Punkt(20, 3090),
        farbe: Stueckfarbe.blau,
      ),
    ];

    test('ohne Stöße und Achsmaßkette: keine Legende, keine Kette', () {
      final u = erzeuge(
        Berechnung(
          umriss: rechteck,
          flaeche: 1,
          dielen: const [],
          unterbau: Unterbau(hoelzer: hoelzer),
        ),
      );
      final ukKapitel = u.kapitel[2];
      expect(
        texte(ukKapitel),
        isNot(contains(Unterlagentexte.deutsch.achsmassHinweis)),
      );
      expect(baustein<Plan>(ukKapitel).linien, hasLength(2));
      final belag = u.kapitel.singleWhere(
        (k) => k.titel.endsWith('Terrassenbelag'),
      );
      expect(
        texte(belag),
        isNot(contains(Unterlagentexte.deutsch.stossHinweis)),
      );
    });

    test('Rinne RELO V im Verlegeplan und im UK-Plan, Legenden und '
        'Hinweise (Planungskern v11, Regel 13.1.6, R-E07)', () {
      final band = Rinnenband.an((
        seite: 0,
        von: Punkt.ursprung,
        bis: const Punkt(4800, 0),
        innen: const Punkt(0, 1),
      ));
      final b = Berechnung(
        umriss: rechteck,
        flaeche: 1,
        unterbau: Unterbau(hoelzer: hoelzer),
        planbild: Planbild(rinnen: [band]),
        anschluss: Anschlussergebnis(
          meldungen: const [
            Anschlussmeldung.unterlueftung,
            Anschlussmeldung.rinnenmontage,
          ],
        ),
      );
      final u = erzeuge(b);
      final de = Unterlagentexte.deutsch;
      final belag = u.kapitel.singleWhere(
        (k) => k.titel.endsWith('Terrassenbelag'),
      );
      expect(texte(belag), contains(de.rinnenBelagHinweis));
      final plan = baustein<Plan>(belag);
      final bandlinien = plan.linien.where((l) => l.argb == rinnenfarbe);
      expect(bandlinien.single.punkte, band.ecken);
      expect(bandlinien.single.gefuellt, isTrue);
      final rand = plan.linien.where((l) => l.argb == rinnenrandfarbe).toList();
      expect(rand, hasLength(1 + band.schlitze.length));
      expect(rand.first.geschlossen, isTrue);
      expect(rand.first.staerke, 0.5);
      expect(rand[1].punkte, [
        band.schlitze.first.von,
        band.schlitze.first.bis,
      ]);
      expect(rand[1].geschlossen, isFalse);
      expect(rand[1].staerke, 0.3);
      expect(plan.texte.last, (ort: band.mitte, text: 'Rinne RELO V'));
      final uk = u.kapitel[2];
      expect(texte(uk), contains(de.rinnenUkHinweis));
      final ukPlan = baustein<Plan>(uk);
      // Rinne unter der UK, die Auflagerprofile darüber
      expect(ukPlan.linien[1].argb, rinnenfarbe);
      expect(ukPlan.linien[1].gefuellt, isTrue);
      expect(ukPlan.linien[2].argb, Stueckfarbe.blau.argb);
      final va = ukPlan.linien.where((l) => l.argb == auflagerprofilfarbe);
      expect(
        [for (final l in va) l.punkte],
        [
          for (final s in band.auflagerprofile) [s.von, s.bis],
        ],
      );
      expect(va.first.staerke, 1.5);
      expect(va.first.geschlossen, isFalse);
      expect(ukPlan.texte.last.text, 'Rinne RELO V');
      // nur Hinweise zur Rinne stehen in den Unterlagen
      expect(texte(kapitel(u, 'Hinweise zur Planung')).skip(2), [
        '• ${de.rinnenmeldung(Anschlussmeldung.rinnenmontage)}',
      ]);
    });

    test('Verlegeplan: Stoßlinien rot gestrichelt, Legende, Eckbuchstaben '
        'und Kantenmaße (R-E01, R-E03)', () {
      final u = erzeuge(
        Berechnung(
          umriss: rechteck,
          flaeche: 1,
          planbild: Planbild(
            stoesse: const [(von: Punkt(3000, 0), bis: Punkt(3000, 66))],
          ),
        ),
      );
      final k = u.kapitel.singleWhere(
        (k) => k.titel.endsWith('Terrassenbelag'),
      );
      expect(baustein<Absatz>(k, 1).text, Unterlagentexte.deutsch.stossHinweis);
      final plan = baustein<Plan>(k);
      final stoss = plan.linien.last;
      expect(stoss.punkte, const [Punkt(3000, 0), Punkt(3000, 66)]);
      expect(stoss.argb, stossfarbe);
      expect(stoss.gestrichelt, isTrue);
      expect(stoss.geschlossen, isFalse);
      expect(stoss.staerke, 1);
      expect(plan.linien.first.gestrichelt, isFalse);
      expect(
        [for (final t in plan.texte) t.text],
        ['A', 'B', 'C', 'D', '4,80 m', '3,09 m', '4,80 m', '3,09 m'],
      );
    });

    test('UK-Plan: Achsmaßkette blau außen, Zahlen in cm ab 10 cm, '
        'Legende (R-E02)', () {
      final b = Berechnung(
        umriss: rechteck,
        flaeche: 1,
        unterbau: Unterbau(hoelzer: hoelzer),
        planbild: Planbild(
          achsen: Masskette(const [
            Punkt(0, 3090),
            Punkt(20, 3090),
            Punkt(420, 3090),
            Punkt(4800, 3090),
          ], const Punkt(0, 1)),
        ),
      );
      final k = erzeuge(b).kapitel[2];
      expect(baustein<Absatz>(k).text, Unterlagentexte.deutsch.achsmassHinweis);
      final plan = baustein<Plan>(k);
      const a = 4800 * beschriftungsanteil;
      const y = 3090 + a * achsmassabstand;
      final kette = plan.linien.skip(2).toList();
      expect(kette, hasLength(5));
      expect(kette.first.punkte, const [
        Punkt(0, y),
        Punkt(20, y),
        Punkt(420, y),
        Punkt(4800, y),
      ]);
      expect(
        kette.every((l) => l.argb == achsmassfarbe && !l.geschlossen),
        isTrue,
      );
      expect(kette[2].punkte, const [
        Punkt(20, y - a * 0.3),
        Punkt(20, y + a * 0.3),
      ]);
      final zahlen = plan.texte.skip(8).toList();
      expect([for (final t in zahlen) t.text], ['40', '438']);
      expect(zahlen.first.ort, const Punkt(220, y + a * 0.7));
      expect(
        [for (final t in plan.texte.take(4)) t.text],
        ['A', 'B', 'C', 'D'],
      );
    });

    test('Eckbuchstaben oben links im Uhrzeigersinn in Höhen und '
        'Ausgangspunkt (R-E03)', () {
      // gedreht: der Umriss beginnt unten links und läuft andersherum
      const ecken = [
        Punkt(0, 3090),
        Punkt(4800, 3090),
        Punkt(4800, 0),
        Punkt(0, 0),
      ];
      final b = Berechnung(
        umriss: ecken,
        flaeche: 1,
        hoehenpunkte: Hoehenpunkte(
          hoehen: List.filled(5, const Millimeter(100)),
        ),
      );
      final gedreht = Planungsstand.start
          .mitGrundriss(FreiformGrundriss(ecken, geschlossen: true))
          .mitAusgangspunkt(ecke: 0);
      final k = erzeuge(b, stand: gedreht).kapitel[1];
      expect(
        [for (final z in baustein<Tabelle>(k).zeilen) z.first],
        ['D', 'C', 'B', 'A', 'E'],
      );
      expect(texte(k), contains('Ausgangspunkt: D (0 cm | 0 cm)'));
    });
  });

  test('Innenwinkel unabhängig vom Umlaufsinn; L-Form 270°', () {
    const l = [
      Punkt(0, 0),
      Punkt(400, 0),
      Punkt(400, 200),
      Punkt(200, 200),
      Punkt(200, 400),
      Punkt(0, 400),
    ];
    expect(innenwinkel(l), [90, 90, 90, 270, 90, 90]);
    expect(innenwinkel(l.reversed.toList()), [90, 90, 270, 90, 90, 90]);
    expect(innenwinkel(const [Punkt(0, 0), Punkt(0, 300), Punkt(400, 0)]), [
      90,
      53,
      37,
    ]);
    expect(innenwinkel(const [Punkt(0, 0), Punkt(1, 0)]), isEmpty);
  });

  group('Kundendaten', () {
    test('aus der Nutzlast, ohne Leerraum, fehlende Felder leer', () {
      final k = Kundendaten.aus({
        'name': ' Max Muster ',
        'adresse': 'Weg 1',
        'ort': '01234 Ort',
        'telefon': '0123',
        'email': 'max@example.org',
      });
      expect(k.felder, [
        'Max Muster',
        'Weg 1',
        '01234 Ort',
        '0123',
        'max@example.org',
      ]);
      expect(Kundendaten.aus(const {}).felder, everyElement(isEmpty));
    });

    test('nur kurze Texte', () {
      expect(
        Kundendaten.aus({'name': 'x' * Kundendaten.hoechstlaenge}).name,
        hasLength(Kundendaten.hoechstlaenge),
      );
      expect(
        () => Kundendaten.aus({'name': 'x' * (Kundendaten.hoechstlaenge + 1)}),
        throwsArgumentError,
      );
      expect(() => Kundendaten.aus({'ort': 3}), throwsArgumentError);
    });
  });
}
