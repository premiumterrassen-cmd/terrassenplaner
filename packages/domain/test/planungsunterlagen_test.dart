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

    test('Grundriss: Namen außerhalb der Ecken, Kanten in m', () {
      final plan = baustein<Plan>(erzeuge().kapitel[1]);
      expect(plan.linien.single.punkte, rechteck);
      expect(plan.linien.single.staerke, 1);
      expect(plan.linien.single.geschlossen, isTrue);
      expect(plan.texte.first.ort.x, closeTo(2400 - 2400 * 1.06, 1e-9));
      expect(plan.texte.first.ort.y, closeTo(1545 - 1545 * 1.06, 1e-9));
      expect(plan.texte[4].ort, const Punkt(2400, 0));
      expect(plan.texte[7].ort, const Punkt(0, 1545));
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
    ]);
    Berechnung berechnung({
      List<Belagmeldung> meldungen = const [],
      Hoehenpunkte? hoehen,
      List<Auflagermeldung> auflagermeldungen = const [],
    }) => Berechnung(
      umriss: rechteck,
      flaeche: 4800 * 3090,
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
      expect(liste.farben, [Stueckfarbe.blau, Stueckfarbe.gruen]);
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

    test('Belag: Verlegeplan mit Nummern, Dielen nach Nummer, Lieferung und '
        'Zuschnitt', () {
      final u = erzeuge([berechnung()]);
      final k = u.kapitel[4];
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
      expect(baustein<Tabelle>(k, 1).zeilen, [
        ['500', '48'],
      ]);
      expect(baustein<Tabelle>(u.kapitel[5]).zeilen, [
        ['Diele 60 x 21 mm', '500', '48', '480'],
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

    test('Materialliste mit Länge, Freidiele, Preisen und Hinweis', () {
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
      expect(tabelle.zeilen.last.skip(3), ['', '', '25,00', '50,00']);
      expect(tabelle.rechts, {0, 2, 3, 4, 5, 6});
      expect(texte(k).skip(6), [
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
        ),
        auflagermeldungen: Auflagermeldung.values,
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
        '• ${Unterlagentexte.deutsch.belagmeldung(Belagmeldung.laengeNichtLieferbar, const Millimeter(7000))}',
        '• ${Unterlagentexte.deutsch.ukGedreht}',
        '• ${Unterlagentexte.deutsch.hoeheKorrigiert(const Millimeter(63))}',
        '• ${Unterlagentexte.deutsch.auflagermeldung(Auflagermeldung.unterMindesthoehe, const Millimeter(55))}',
        '• ${Unterlagentexte.deutsch.auflagermeldung(Auflagermeldung.ueberHoechsthoehe, const Millimeter(950))}',
      ]);
      expect(baustein<Absatz>(hinweise).fett, isTrue);
      final eine = erzeuge([
        mitMeldung,
      ], planung: Planung([planung.flaechen.last]));
      expect(texte(kapitel(eine, 'Hinweise zur Planung'))[1], startsWith('• '));
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

  test('Eckname A–Z, dann von vorn', () {
    expect(eckname(0), 'A');
    expect(eckname(25), 'Z');
    expect(eckname(26), 'A');
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
