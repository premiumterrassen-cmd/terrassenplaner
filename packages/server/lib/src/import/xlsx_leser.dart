import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Ein gelesenes Tabellenblatt: Kopfzeile und Datenzeilen (Spaltenname →
/// Zellwert als Text). Zeilennummern wie in Excel (Kopfzeile = 1).
final class Blatt {
  Blatt(this.kopf, this.zeilen, {required this.formelnOhneWert});

  final List<String> kopf;
  final List<({int nummer, Map<String, String> werte})> zeilen;

  /// Formelzellen ohne gespeicherten Wert (z. B. Blatt „Import
  /// Terrassenplaner“ direkt in der Master-Artikelliste).
  final int formelnOhneWert;
}

/// Liest ein Blatt einer xlsx-Datei (M2-02) – ohne Formeln auszuwerten:
/// gespeicherte Werte, gemeinsame und Inline-Texte. Wirft [FormatException],
/// wenn Datei oder Blatt fehlen.
Blatt leseBlatt(List<int> bytes, String blattname) {
  // Ungültige Bytes ergeben ein leeres Archiv (kein Fehler des Decoders).
  final archiv = ZipDecoder().decodeBytes(bytes);
  if (archiv.isEmpty) throw const FormatException('keine xlsx-Datei');
  String text(String pfad) {
    final datei = archiv.findFile(pfad);
    if (datei == null) throw FormatException('$pfad fehlt in der xlsx-Datei');
    return utf8.decode(datei.content);
  }

  final mappe = XmlDocument.parse(text('xl/workbook.xml'));
  final blatt = mappe
      .findAllElements('sheet')
      .where((e) => e.getAttribute('name') == blattname);
  if (blatt.isEmpty) throw FormatException('Blatt „$blattname“ fehlt');
  final rid = blatt.first.attributes
      .firstWhere((a) => a.name.local == 'id')
      .value;
  final beziehung = XmlDocument.parse(text('xl/_rels/workbook.xml.rels'))
      .findAllElements('Relationship')
      .firstWhere((e) => e.getAttribute('Id') == rid);
  var ziel = beziehung.getAttribute('Target')!;
  ziel = ziel.startsWith('/') ? ziel.substring(1) : 'xl/$ziel';

  final gemeinsam = archiv.findFile('xl/sharedStrings.xml') == null
      ? const <String>[]
      : [
          for (final si in XmlDocument.parse(
            text('xl/sharedStrings.xml'),
          ).findAllElements('si'))
            si.findAllElements('t').map((t) => t.innerText).join(),
        ];

  var ohneWert = 0;
  final roh = <(int, Map<String, String>)>[];
  for (final zeile in XmlDocument.parse(text(ziel)).findAllElements('row')) {
    final werte = <String, String>{};
    for (final zelle in zeile.findElements('c')) {
      final spalte = _spalte(zelle.getAttribute('r')!);
      final typ = zelle.getAttribute('t');
      final v = zelle.getElement('v')?.innerText;
      final String? wert;
      if (typ == 'inlineStr') {
        wert = zelle.findAllElements('t').map((t) => t.innerText).join();
      } else if (typ == 's' && v != null) {
        wert = gemeinsam[int.parse(v)];
      } else {
        wert = v;
      }
      if (wert == null && zelle.getElement('f') != null) ohneWert++;
      if (wert != null) werte[spalte] = wert;
    }
    roh.add((int.parse(zeile.getAttribute('r')!), werte));
  }
  if (roh.isEmpty) throw FormatException('Blatt „$blattname“ ist leer');

  final (_, kopfZellen) = roh.first;
  final spalten = kopfZellen.keys.toList()..sort(_spaltenfolge);
  final kopf = [for (final s in spalten) kopfZellen[s]!.trim()];
  return Blatt(kopf, [
    for (final (nummer, werte) in roh.skip(1))
      if (werte.values.any((w) => w.trim().isNotEmpty))
        (
          nummer: nummer,
          werte: {
            for (final (i, s) in spalten.indexed)
              if (werte[s] != null) kopf[i]: werte[s]!.trim(),
          },
        ),
  ], formelnOhneWert: ohneWert);
}

/// Spaltenbuchstaben einer Zellreferenz, z. B. „AB“ aus „AB12“.
String _spalte(String referenz) => RegExp('^[A-Z]+').stringMatch(referenz)!;

/// Reihenfolge der Spalten wie in Excel: A … Z, AA …
int _spaltenfolge(String a, String b) =>
    a.length != b.length ? a.length.compareTo(b.length) : a.compareTo(b);
