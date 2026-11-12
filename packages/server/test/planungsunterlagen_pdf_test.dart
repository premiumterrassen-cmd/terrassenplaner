import 'dart:convert';
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

void main() {
  final rechteck = [
    const Punkt(0, 0),
    const Punkt(4000, 0),
    const Punkt(4000, 2000),
    const Punkt(0, 2000),
  ];
  final unterlagen = Planungsunterlagen(
    texte: Unterlagentexte.deutsch,
    kopfzeile: 'Kopfzeile Folgeseite',
    kapitel: [
      Kapitel('Erstes', [
        const Absatz('Fett gedruckt', fett: true),
        Wertepaare([('Fläche', '12 m²')]),
      ]),
      Kapitel('Zweites', [
        Tabelle(
          ['Artikel', 'Preis'],
          [
            ['Diele – „Test“', '2.066,57 €'],
          ],
          farben: [Stueckfarbe.rot.argb],
          rechts: {1},
        ),
        Plan(
          [
            Planlinie(rechteck, argb: 0xFF000000),
            Planlinie(rechteck, argb: 0xFF1976D2, gefuellt: true),
          ],
          [(ort: const Punkt(0, 0), text: 'A')],
        ),
      ]),
      Kapitel('Drittes', [const Absatz('auf Seite zwei')], neueSeite: false),
    ],
  );

  Future<String> roh(Planungsunterlagen u) async =>
      latin1.decode(await planungsunterlagenPdf(u, komprimiert: false));

  test('Briefkopf nur auf dem Deckblatt, Kopfzeile auf den Folgeseiten, '
      'Seitenangabe im Fuß', () async {
    final pdf = await roh(unterlagen);
    expect(pdf, startsWith('%PDF'));
    expect(RegExp(r'/Type\s*/Page\b').allMatches(pdf), hasLength(2));
    expect(RegExp(r'\(RobinienWelt\)').allMatches(pdf), hasLength(1));
    expect(RegExp(r'\(Folgeseite\)').allMatches(pdf), hasLength(1));
    expect(pdf, contains('(ERSTES)'));
    expect(pdf, contains('(ZWEITES)'));
    expect(pdf, contains('(DRITTES)'));
    for (final seite in ['(1)', '(2)']) {
      expect(pdf, contains(seite));
    }
    // Ersatz für die Standardschrift: kein Zeichen außerhalb von Latin-1
    expect(pdf, contains('(EUR)'));
    expect(pdf, contains('("Test")'));
    expect(pdf, contains('/Helvetica-Bold'));
  });

  // Der Satz als Ganzes (Ränder, Schriftgrößen, Abstände, Farben) gegen
  // eine Referenzdatei – ohne Zeitstempel und Dokumentkennung. Nach einer
  // gewollten Änderung am Satz neu schreiben mit
  // PLANER_PDF_REFERENZ_SCHREIBEN=1 dart test test/planungsunterlagen_pdf_test.dart
  test('Satz unverändert gegenüber der Referenz', () async {
    final pdf = (await roh(unterlagen))
        .replaceAll(RegExp(r'/CreationDate\([^)]*\)'), '')
        .replaceAll(RegExp(r'/ID\[[^\]]*\]'), '');
    final referenz = File('test/daten/planungsunterlagen_referenz.pdf');
    if (Platform.environment['PLANER_PDF_REFERENZ_SCHREIBEN'] == '1') {
      referenz.writeAsStringSync(pdf, encoding: latin1);
    }
    expect(pdf, referenz.readAsStringSync(encoding: latin1));
  });

  test('komprimiert kleiner als roh', () async {
    final klein = await planungsunterlagenPdf(unterlagen);
    final gross = await planungsunterlagenPdf(unterlagen, komprimiert: false);
    expect(klein.length, lessThan(gross.length));
  });

  test('Latin-1: typografische Zeichen ersetzt, Rest „?“', () {
    expect(
      latin1Text('2,50 € – „a“ ‚b‘ ’c — • …'),
      '2,50 EUR - "a" \'b\' \'c - - ...',
    );
    expect(latin1Text('Größe 12 m² × 90° ½'), 'Größe 12 m² × 90° ½');
    expect(latin1Text('✓ 中'), '? ?');
  });

  test('Spaltenbreiten nach Inhalt zwischen 3 und 40, Farbfeld fest', () {
    final breiten = spaltenbreiten(
      Tabelle(
        ['Nr.', 'Ausgangslänge in cm', 'Artikel'],
        [
          ['1', '5', 'x' * 60],
        ],
        farben: [Stueckfarbe.blau.argb],
      ),
    );
    expect(breiten, hasLength(4));
    expect((breiten[0]! as pw.FlexColumnWidth).flex, 3);
    expect((breiten[1]! as pw.FlexColumnWidth).flex, 13);
    expect((breiten[2]! as pw.FlexColumnWidth).flex, 40);
    expect((breiten[3]! as pw.FixedColumnWidth).width, 22);
    expect(
      spaltenbreiten(
        Tabelle(
          ['a'],
          [
            ['12345'],
          ],
        ),
      ),
      hasLength(1),
    );
  });

  group('Maßstab der Zeichnung', () {
    test('so groß wie möglich, y nach oben', () {
      final m = Planmassstab.fuer(Plan([Planlinie(rechteck, argb: 0)]));
      final faktor = (satzbreite - 2 * planrand) / 4000;
      expect(m.faktor, faktor);
      expect(m.breite, closeTo(4000 * faktor, 1e-9));
      expect(m.hoehe, closeTo(2000 * faktor, 1e-9));
      final p = m.abbild(const Punkt(1000, 500));
      expect(p.x, closeTo(1000 * faktor, 1e-9));
      expect(p.y, closeTo(1500 * faktor, 1e-9));
    });

    test('hohe Zeichnung nach der Höhe; Beschriftungen zählen mit', () {
      final m = Planmassstab.fuer(
        Plan(
          [
            Planlinie(const [Punkt(0, 0), Punkt(0, 10000)], argb: 0),
          ],
          [(ort: const Punkt(-100, 20000), text: 'x')],
        ),
      );
      expect(m.faktor, planhoehe / 20000);
      expect(m.breite, closeTo(100 * planhoehe / 20000, 1e-9));
      expect(m.abbild(const Punkt(-100, 20000)).y, 0);
    });

    test('Nebentexte zählen mit', () {
      final m = Planmassstab.fuer(
        Plan(
          [
            Planlinie(const [Punkt(0, 0), Punkt(1000, 0)], argb: 0),
          ],
          const [],
          [
            (
              ort: const Punkt(0, 1000),
              richtung: Punkt.ursprung,
              abstand: 0,
              text: '1',
            ),
          ],
        ),
      );
      expect(m.faktor, planhoehe / 1000);
    });

    test('ein Punkt: Ausdehnung mindestens 1 mm; ohne Punkte leer', () {
      final punkt = Planmassstab.fuer(
        Plan([
          Planlinie(const [Punkt(5, 5)], argb: 0),
        ]),
      );
      expect(punkt.faktor, planhoehe);
      expect(punkt.breite, 0);
      final leer = Planmassstab.fuer(Plan(const []));
      expect([leer.faktor, leer.breite, leer.hoehe], [0, 0, 0]);
    });
  });

  group('Nebentexte weiß hinterlegt neben dem Bauteil (Planungskern v8 '
      'Regel 10.1.3, v10 Regel 12.1)', () {
    final m = Planmassstab.fuer(Plan([Planlinie(rechteck, argb: 0)]));
    final p = m.abbild(const Punkt(1000, 500));
    Nebentext neben(Punkt richtung, String text, {double abstand = 0}) => (
      ort: const Punkt(1000, 500),
      richtung: richtung,
      abstand: abstand,
      text: text,
    );
    test('rechts neben dem Punkt: linke Kante 1 pt daneben, mittig in y', () {
      final lage = nebentextLage(neben(const Punkt(1, 0), '4,5'), m);
      expect(lage.breite, closeTo(3 * 5.5 * 0.55 + 1, 1e-9));
      expect(lage.hoehe, 7.5);
      expect(lage.links, closeTo(p.x + 1, 1e-9));
      expect(lage.unten, closeTo(p.y - 3.75, 1e-9));
    });
    test('Abstand vom Bauteil in mm, im Maßstab', () {
      final lage = nebentextLage(
        neben(const Punkt(1, 0), '4,5', abstand: 100),
        m,
      );
      expect(lage.links, closeTo(p.x + 100 * m.faktor + 1, 1e-9));
      final gegen = nebentextLage(
        neben(const Punkt(1, 0), '4,5', abstand: 100),
        m,
        const Punkt(-1, 0),
      );
      expect(
        gegen.links + gegen.breite,
        closeTo(p.x - 100 * m.faktor - 1, 1e-9),
      );
    });
    test('über dem Punkt (y nach unten in mm, nach oben im PDF)', () {
      final lage = nebentextLage(neben(const Punkt(0, -1), '12'), m);
      expect(lage.unten, closeTo(p.y + 1, 1e-9));
      expect(lage.links, closeTo(p.x - lage.breite / 2, 1e-9));
    });
    test('links und unter dem Punkt', () {
      final links = nebentextLage(neben(const Punkt(-1, 0), '1'), m);
      expect(links.links + links.breite, closeTo(p.x - 1, 1e-9));
      final unten = nebentextLage(neben(const Punkt(0, 1), '1'), m);
      expect(unten.unten + unten.hoehe, closeTo(p.y - 1, 1e-9));
    });
    test('ohne Richtung mittig', () {
      final lage = nebentextLage(neben(Punkt.ursprung, 'Stufe 1'), m);
      expect(lage.links + lage.breite / 2, closeTo(p.x, 1e-9));
      expect(lage.unten + lage.hoehe / 2, closeTo(p.y, 1e-9));
    });

    test('Feld berührt Vieleck: Trennachse des Felds und der Kanten', () {
      const f = (links: 0.0, unten: 0.0, breite: 10.0, hoehe: 10.0);
      List<PdfPoint> quadrat(double x, double y, double a) => [
        PdfPoint(x, y),
        PdfPoint(x + a, y),
        PdfPoint(x + a, y + a),
        PdfPoint(x, y + a),
      ];
      expect(feldBeruehrt(f, quadrat(5, 5, 10)), isTrue);
      expect(feldBeruehrt(f, quadrat(2, 2, 2)), isTrue);
      // nur berühren an der Kante zählt nicht
      expect(feldBeruehrt(f, quadrat(10, 0, 5)), isFalse);
      expect(feldBeruehrt(f, quadrat(-5, 0, 5)), isFalse);
      expect(feldBeruehrt(f, quadrat(0, 10, 5)), isFalse);
      expect(feldBeruehrt(f, quadrat(0, -5, 5)), isFalse);
      // schräges Holz: Hüllrechtecke überlappen, die Kante trennt
      const raute = [
        PdfPoint(14, 7),
        PdfPoint(21, 14),
        PdfPoint(14, 21),
        PdfPoint(7, 14),
      ];
      expect(feldBeruehrt(f, raute), isFalse);
      expect(
        feldBeruehrt(f, const [
          PdfPoint(9, 5),
          PdfPoint(16, 12),
          PdfPoint(9, 19),
          PdfPoint(2, 12),
        ]),
        isTrue,
      );
    });

    test('Platz: eigene Richtung, sonst Gegenrichtung, sonst entfällt; nie '
        'über Holz, Beschriftung oder einem anderen Nebentext', () {
      // Hölzer senkrecht bei x = 1000 und 1240 (40 mm breit)
      List<Punkt> holz(double x) => [
        Punkt(x, 0),
        Punkt(x + 40, 0),
        Punkt(x + 40, 2000),
        Punkt(x, 2000),
      ];
      Nebentext an(double x, double y, {Punkt richtung = const Punkt(1, 0)}) =>
          (ort: Punkt(x, y), richtung: richtung, abstand: 20, text: '12,5');
      final plan = Plan(
        [
          Planlinie(rechteck, argb: 0),
          Planlinie(holz(1000), argb: 0, gefuellt: true),
          Planlinie(holz(1240), argb: 0, gefuellt: true),
          // nicht gefüllt: kein Hindernis
          Planlinie(holz(860), argb: 0),
        ],
        [(ort: const Punkt(1100, 1500), text: 'B')],
        [
          an(1020, 500),
          // derselbe Platz ist belegt: links
          an(1020, 500),
          // dritter am selben Ort: kein Platz mehr
          an(1020, 500),
          // Beschriftung „B“ rechts im Weg: links
          an(1020, 1500),
          // links vom zweiten Holz liegt schon der erste: rechts
          an(1260, 500, richtung: const Punkt(-1, 0)),
          // ohne Richtung auf dem Holz: entfällt
          an(1020, 1000, richtung: Punkt.ursprung),
        ],
      );
      final m = Planmassstab.fuer(plan);
      final felder = nebentextFelder(plan, m);
      expect(
        [for (final (n, _) in felder) n.ort],
        const [
          Punkt(1020, 500),
          Punkt(1020, 500),
          Punkt(1020, 1500),
          Punkt(1260, 500),
        ],
      );
      double x(double mm) => m.abbild(Punkt(mm, 0)).x;
      expect(felder[0].$2.links, closeTo(x(1040) + 1, 1e-9));
      expect(
        felder[1].$2.links + felder[1].$2.breite,
        closeTo(x(1000) - 1, 1e-9),
      );
      expect(
        felder[2].$2.links + felder[2].$2.breite,
        closeTo(x(1000) - 1, 1e-9),
      );
      expect(felder[3].$2.links, closeTo(x(1280) + 1, 1e-9));
    });

    test('im PDF weiß hinterlegt in 5,5 pt', () async {
      final pdf = await roh(
        Planungsunterlagen(
          texte: Unterlagentexte.deutsch,
          kopfzeile: '',
          kapitel: [
            Kapitel('Plan', [
              Plan(
                [Planlinie(rechteck, argb: 0xFF000000)],
                const [],
                [
                  (
                    ort: const Punkt(100, 100),
                    richtung: const Punkt(1, 0),
                    abstand: 0,
                    text: '8,6',
                  ),
                ],
              ),
            ]),
          ],
        ),
      );
      expect(pdf, contains('(8,6)'));
      expect(pdf, contains('1 1 1 rg'));
      expect(pdf, contains(RegExp(r'/F\d+ 5.5 Tf')));
    });
  });

  test('Zeichnen: Linien gestrichen, Flächen gefüllt, ein Punkt nichts', () {
    final puffer = PdfStream();
    final leinwand = PdfGraphics(PdfPage(PdfDocument()), puffer);
    final plan = Plan([
      Planlinie(
        const [Punkt(0, 0), Punkt(1000, 0)],
        argb: 0xFFFF0000,
        geschlossen: false,
        staerke: 1.5,
      ),
      Planlinie(rechteck, argb: 0xFF0000FF, gefuellt: true),
      Planlinie(const [Punkt(7, 7)], argb: 0xFF00FF00),
    ]);
    zeichne(leinwand, plan, Planmassstab.fuer(plan));
    final inhalt = puffer.output();
    final text = latin1.decode(inhalt);
    expect(RegExp(r' m\b').allMatches(text), hasLength(2));
    expect(RegExp(r' l\b').allMatches(text), hasLength(4));
    expect(RegExp(r'\bh\b').allMatches(text), hasLength(1));
    expect(text, contains('1 0 0 RG'));
    expect(text, contains('1.5 w'));
    expect(RegExp(r'\bS\b').allMatches(text), hasLength(1));
    expect(text, contains('0 0 1 rg'));
    expect(RegExp(r'\bf\b').allMatches(text), hasLength(1));
    expect(text, isNot(contains('0 1 0')));
    expect(text, isNot(contains(' d')));
  });

  test('Zeichnen: gestrichelte Linie (Stoßlinie, R-E01), danach '
      'wieder durchgezogen', () {
    final puffer = PdfStream();
    final leinwand = PdfGraphics(PdfPage(PdfDocument()), puffer);
    final plan = Plan([
      Planlinie(
        const [Punkt(0, 0), Punkt(0, 1000)],
        argb: stossfarbe,
        geschlossen: false,
        gestrichelt: true,
      ),
      Planlinie(const [Punkt(0, 0), Punkt(1000, 0)], argb: 0),
    ]);
    zeichne(leinwand, plan, Planmassstab.fuer(plan));
    final text = latin1.decode(puffer.output());
    expect(
      text.indexOf('[4 2] 0 d'),
      allOf(greaterThan(-1), lessThan(text.indexOf(' S'))),
    );
    expect(text.indexOf('[] 0 d'), greaterThan(text.indexOf(' S')));
    expect(text.indexOf('[] 0 d'), lessThan(text.lastIndexOf(' S')));
    expect(RegExp(r'\bd\b').allMatches(text), hasLength(2));
  });
}
