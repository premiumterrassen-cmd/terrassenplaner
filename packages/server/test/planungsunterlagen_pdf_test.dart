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
          farben: [Stueckfarbe.rot],
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
        farben: [Stueckfarbe.blau],
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
  });
}
