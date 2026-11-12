import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

/// Setzt die Planungsunterlagen (M9-06) als PDF im Format A4: Briefkopf auf
/// dem Deckblatt, Konfigurationsnummer im Kopf jeder weiteren Seite,
/// „Seite x von y“ im Fuß. Was darin steht, kommt fertig aus der Domäne
/// (`planungsunterlagen`) – hier wird nur gesetzt.
///
/// Schrift sind die Standardschriften des PDF (Helvetica, ohne
/// eingebettete Datei); Zeichen außerhalb von Latin-1 ersetzt [latin1Text]
/// (z. B. € → EUR).
Future<Uint8List> planungsunterlagenPdf(
  Planungsunterlagen u, {
  bool komprimiert = true,
}) {
  final dokument = pw.Document(
    title: u.texte.titel,
    creator: 'Terrassenplaner',
    compress: komprimiert,
  );
  dokument.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ).copyWith(defaultTextStyle: const pw.TextStyle(fontSize: 9)),
      header: (kontext) =>
          kontext.pageNumber == 1 ? _briefkopf(u.texte) : _kopf(u.kopfzeile),
      footer: (kontext) => pw.Container(
        alignment: pw.Alignment.centerRight,
        child: _text(
          u.texte.seitenangabe(kontext.pageNumber, kontext.pagesCount),
          groesse: 8,
        ),
      ),
      build: (_) => [
        for (final (i, k) in u.kapitel.indexed) ..._kapitel(k, erstes: i == 0),
      ],
    ),
  );
  return dokument.save();
}

/// Breite des Satzspiegels in Punkt (A4 minus Ränder).
final satzbreite = PdfPageFormat.a4.width - 80;

/// Größte Höhe einer Zeichnung in Punkt.
const planhoehe = 420.0;

/// Rand um eine Zeichnung für Beschriftungen an ihrem Rand, in Punkt.
const planrand = 25.0;

/// Strich und Lücke gestrichelter Linien in Punkt (Stoßlinien, R-E01).
const strichmuster = [4, 2];

/// [text] in Latin-1 – mehr kennen die Standardschriften des PDF nicht:
/// typografische Zeichen werden ersetzt, alles andere wird „?“.
String latin1Text(String text) {
  final ersetzt = text
      .replaceAll('€', 'EUR')
      .replaceAll(RegExp('[–—]'), '-')
      .replaceAll(RegExp('[„“”]'), '"')
      .replaceAll(RegExp('[‚‘’]'), "'")
      .replaceAll('•', '-')
      .replaceAll('…', '...');
  return String.fromCharCodes([
    for (final c in ersetzt.runes) c > 0xFF ? 0x3F : c,
  ]);
}

pw.Widget _text(
  String text, {
  double groesse = 9,
  bool fett = false,
  PdfColor? farbe,
}) => pw.Text(
  latin1Text(text),
  style: pw.TextStyle(
    fontSize: groesse,
    fontWeight: fett ? pw.FontWeight.bold : pw.FontWeight.normal,
    color: farbe,
  ),
);

pw.Widget _briefkopf(Unterlagentexte t) => pw.Container(
  margin: const pw.EdgeInsets.only(bottom: 16),
  padding: const pw.EdgeInsets.only(bottom: 6),
  decoration: const pw.BoxDecoration(
    border: pw.Border(bottom: pw.BorderSide(color: _gruen, width: 2)),
  ),
  child: pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      _text('RobinienWelt', groesse: 20, fett: true, farbe: _gruen),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [for (final z in t.absender.skip(1)) _text(z, groesse: 8)],
      ),
    ],
  ),
);

const _gruen = PdfColor.fromInt(0xFF2E7D32);

pw.Widget _kopf(String zeile) => pw.Container(
  margin: const pw.EdgeInsets.only(bottom: 12),
  padding: const pw.EdgeInsets.only(bottom: 4),
  decoration: const pw.BoxDecoration(
    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey, width: 0.5)),
  ),
  child: _text(zeile, groesse: 8),
);

List<pw.Widget> _kapitel(Kapitel k, {required bool erstes}) => [
  if (k.neueSeite && !erstes) pw.NewPage(),
  pw.Padding(
    padding: const pw.EdgeInsets.only(top: 6, bottom: 8),
    child: _text(k.titel.toUpperCase(), groesse: 13, fett: true),
  ),
  // Tabellen laufen über Seiten – darum Abstand daneben statt Padding
  // drumherum (Padding bricht nicht um).
  for (final b in k.inhalt) ...[_baustein(b), pw.SizedBox(height: 8)],
];

pw.Widget _baustein(Baustein b) => switch (b) {
  Absatz(:final text, :final fett) => _text(text, fett: fett),
  Wertepaare(:final zeilen) => pw.Table(
    columnWidths: const {0: pw.FixedColumnWidth(170), 1: pw.FlexColumnWidth()},
    children: [
      for (final (name, wert) in zeilen)
        pw.TableRow(children: [_zelle(_text('$name:')), _zelle(_text(wert))]),
    ],
  ),
  final Tabelle t => _tabelle(t),
  final Plan p => _plan(p),
};

pw.Widget _zelle(pw.Widget kind, {bool rechts = false}) => pw.Container(
  padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
  alignment: rechts ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
  child: kind,
);

pw.Widget _tabelle(Tabelle t) {
  final farbig = t.farben.isNotEmpty;
  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
    columnWidths: spaltenbreiten(t),
    children: [
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          for (final (i, k) in t.kopf.indexed)
            _zelle(_text(k, fett: true), rechts: t.rechts.contains(i)),
          if (farbig) pw.SizedBox(),
        ],
      ),
      for (final (z, zeile) in t.zeilen.indexed)
        pw.TableRow(
          children: [
            for (final (i, wert) in zeile.indexed)
              _zelle(_text(wert), rechts: t.rechts.contains(i)),
            if (farbig) _farbfeld(t.farben[z]),
          ],
        ),
    ],
  );
}

pw.Widget _farbfeld(int argb) =>
    _zelle(pw.Container(width: 14, height: 8, color: PdfColor.fromInt(argb)));

/// Anteil jeder Spalte an der Breite nach ihrem längsten Inhalt (Kopf
/// nur nach dem längsten Wort, er darf umbrechen), zwischen 3 und 40
/// Zeichen; das Farbfeld ist fest.
Map<int, pw.TableColumnWidth> spaltenbreiten(Tabelle t) => {
  for (final (i, kopf) in t.kopf.indexed)
    i: pw.FlexColumnWidth(
      [
        for (final wort in kopf.split(' ')) wort.length,
        for (final z in t.zeilen) z[i].length,
      ].reduce(math.max).clamp(3, 40).toDouble(),
    ),
  if (t.farben.isNotEmpty) t.kopf.length: const pw.FixedColumnWidth(22),
};

/// Maßstab, Größe und Abbildung einer Zeichnung auf die Seite: so groß wie
/// möglich in [satzbreite] × [planhoehe], y nach oben wie im PDF.
final class Planmassstab {
  Planmassstab._(this._min, this.faktor, this.breite, this.hoehe, this._maxY);

  /// Um alle Punkte und Beschriftungen von [plan]; ohne Punkte leer.
  factory Planmassstab.fuer(Plan plan) {
    final punkte = [
      for (final l in plan.linien) ...l.punkte,
      for (final t in plan.texte) t.ort,
    ];
    if (punkte.isEmpty) return Planmassstab._(Punkt.ursprung, 0, 0, 0, 0);
    final huelle = Huellrechteck.um(punkte);
    final faktor = math.min(
      (satzbreite - 2 * planrand) / math.max(huelle.breite, 1),
      planhoehe / math.max(huelle.hoehe, 1),
    );
    return Planmassstab._(
      huelle.min,
      faktor,
      huelle.breite * faktor,
      huelle.hoehe * faktor,
      huelle.max.y,
    );
  }

  final Punkt _min;
  final double _maxY;
  final double faktor;
  final double breite;
  final double hoehe;

  /// Punkt [p] (mm, y nach unten) in Punkt auf dem Papier (y nach oben).
  PdfPoint abbild(Punkt p) =>
      PdfPoint((p.x - _min.x) * faktor, (_maxY - p.y) * faktor);
}

pw.Widget _plan(Plan plan) {
  final m = Planmassstab.fuer(plan);
  return pw.Center(
    child: pw.SizedBox(
      width: m.breite + 2 * planrand,
      height: m.hoehe + 2 * planrand,
      child: pw.Stack(
        children: [
          pw.Positioned(
            left: planrand,
            bottom: planrand,
            child: pw.CustomPaint(
              size: PdfPoint(m.breite, m.hoehe),
              painter: (leinwand, _) => zeichne(leinwand, plan, m),
            ),
          ),
          for (final t in plan.texte)
            pw.Positioned(
              left: m.abbild(t.ort).x + planrand - 20,
              bottom: m.abbild(t.ort).y + planrand - 4,
              child: pw.SizedBox(
                width: 40,
                child: pw.Center(child: _text(t.text, groesse: 7)),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Zeichnet die Linien von [plan] im Maßstab [m] auf die [leinwand].
void zeichne(PdfGraphics leinwand, Plan plan, Planmassstab m) {
  for (final l in plan.linien) {
    // ein Punkt ist keine Linie (z. B. eine eben begonnene Freiform)
    if (l.punkte.length < 2) continue;
    final [erster, ...rest] = [for (final p in l.punkte) m.abbild(p)];
    leinwand.moveTo(erster.x, erster.y);
    for (final p in rest) {
      leinwand.lineTo(p.x, p.y);
    }
    if (l.geschlossen) leinwand.closePath();
    final farbe = PdfColor.fromInt(l.argb);
    if (l.gefuellt) {
      leinwand
        ..setFillColor(farbe)
        ..fillPath();
    } else {
      leinwand
        ..setStrokeColor(farbe)
        ..setLineWidth(l.staerke);
      // gestrichelt (Stoßlinien, R-E01), danach wieder durchgezogen
      if (l.gestrichelt) leinwand.setLineDashPattern(strichmuster);
      leinwand.strokePath();
      if (l.gestrichelt) leinwand.setLineDashPattern();
    }
  }
}
