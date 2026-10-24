import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';

/// Bereitet die Bilder einer Artikeldatei für den Planer auf (M2-07): sucht
/// jedes Bild in den Quellordnern und schreibt es als WebP (höchstens
/// 800 px breit) in den Zielordner. Braucht `cwebp` (libwebp ≥ 1.5).
///
///     dart run bin/artikelbilder_aufbereiten.dart <artikel.json> <ziel> <quelle>...
Future<void> main(List<String> argumente) async {
  if (argumente.length < 3) {
    stderr.writeln(
      'Aufruf: artikelbilder_aufbereiten <artikel.json> <ziel> <quelle>...',
    );
    exitCode = 64;
    return;
  }
  final datei = Artikeldatei.ausJson(
    jsonDecode(await File(argumente[0]).readAsString()) as Map<String, Object?>,
    [robinie],
  );
  final ziel = Directory(argumente[1])..createSync(recursive: true);
  final plan = planeArtikelbilder(datei, argumente.sublist(2));
  var neu = 0;
  for (final MapEntry(key: name, value: quelle) in plan.quellen.entries) {
    final aus = File(p.join(ziel.path, name));
    if (aus.existsSync() &&
        aus.lastModifiedSync().isAfter(File(quelle).lastModifiedSync())) {
      continue;
    }
    final lauf = await Process.run('cwebp', cwebpArgumente(quelle, aus.path));
    if (lauf.exitCode != 0) {
      stderr.writeln('FEHLER $quelle: ${lauf.stderr}');
      exitCode = 1;
      continue;
    }
    neu++;
  }
  for (final bild in plan.fehlend) {
    stdout.writeln('Hinweis: $bild fehlt – Platzhalter');
  }
  for (final paar in plan.mehrdeutig) {
    stdout.writeln('Hinweis: mehrdeutig $paar – der erste gilt');
  }
  stdout.writeln(
    '${plan.quellen.length} Bilder (davon $neu neu), '
    '${plan.fehlend.length} fehlen → ${ziel.path}',
  );
}
