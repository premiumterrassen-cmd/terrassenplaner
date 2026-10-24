import 'dart:io';

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

/// Was für die Artikelbilder zu tun ist (M2-07): je Zieldatei die Quelle,
/// dazu Bilder ohne Quelle (die App zeigt dort den Platzhalter).
final class Bildplan {
  Bildplan({
    required Map<String, String> quellen,
    required List<String> fehlend,
    required List<String> mehrdeutig,
  }) : quellen = Map.unmodifiable(quellen),
       fehlend = List.unmodifiable(fehlend),
       mehrdeutig = List.unmodifiable(mehrdeutig);

  /// Zieldatei (`artikelbildDatei`) → Pfad der Quelldatei.
  final Map<String, String> quellen;

  /// Bildnamen aus den Artikeldaten, die in keinem Quellordner liegen.
  final List<String> fehlend;

  /// Verschiedene Bildnamen mit derselben Zieldatei (z. B. `a.jpg`, `a.webp`);
  /// übernommen wird der zuerst genannte.
  final List<String> mehrdeutig;
}

/// Sucht jedes Bild der [datei] in den [ordner]n (der erste Treffer gilt).
Bildplan planeArtikelbilder(Artikeldatei datei, List<String> ordner) {
  final quellen = <String, String>{};
  final name = <String, String>{};
  final fehlend = <String>{};
  final mehrdeutig = <String>{};
  for (final bild in {for (final e in datei.eintraege) ...e.artikel.bilder}) {
    final ziel = artikelbildDatei(bild);
    final vorher = name[ziel];
    if (vorher != null) {
      mehrdeutig.add('$vorher / $bild');
      continue;
    }
    final quelle = ordner
        .map((o) => '$o${Platform.pathSeparator}$bild')
        .where((pfad) => File(pfad).existsSync())
        .firstOrNull;
    if (quelle == null) {
      fehlend.add(bild);
    } else {
      name[ziel] = bild;
      quellen[ziel] = quelle;
    }
  }
  return Bildplan(
    quellen: quellen,
    fehlend: fehlend.toList(),
    mehrdeutig: mehrdeutig.toList(),
  );
}

/// Größte Breite der aufbereiteten Bilder in Pixeln (Ansicht im Planer).
const artikelbildBreite = 800;

/// Argumente für `cwebp`: WebP, Qualität 80, nur verkleinern.
List<String> cwebpArgumente(String quelle, String ziel) => [
  '-quiet',
  '-q',
  '80',
  '-resize',
  '$artikelbildBreite',
  '0',
  '-resize_mode',
  'down_only',
  '-metadata',
  'none',
  quelle,
  '-o',
  ziel,
];
