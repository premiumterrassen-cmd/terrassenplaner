import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:terrassenplaner_server/terrassenplaner_server.dart';

/// Importiert die Upload-Datei des Planers (xlsx, Blatt „Import
/// Terrassenplaner“) in eine geprüfte Artikeldatei (M2-02):
///
///     dart run bin/artikel_importieren.dart <upload.xlsx> <artikel.json>
///
/// Die Artikeldatei gehört nicht ins Repository (Artikelnummern der
/// Fremdartikel sind EANs, B-155).
Future<void> main(List<String> argumente) async {
  if (argumente.length != 2) {
    stderr.writeln('Aufruf: artikel_importieren <upload.xlsx> <artikel.json>');
    exitCode = 64;
    return;
  }
  final ergebnis = importiereArtikel(
    await File(argumente[0]).readAsBytes(),
    quelle: p.basename(argumente[0]),
  );
  for (final befund in ergebnis.befunde) {
    stdout.writeln(befund);
  }
  final datei = ergebnis.datei;
  if (datei == null) {
    stderr.writeln('Import abgebrochen – kritische Befunde.');
    exitCode = 1;
    return;
  }
  await File(
    argumente[1],
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(datei.alsJson()));
  stdout.writeln(
    '${datei.eintraege.length} Artikel, Version ${datei.version} → '
    '${argumente[1]}',
  );
}
