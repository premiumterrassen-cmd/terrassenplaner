/// Gegenstück eines Belags mit dem anderen Profil – Planungsregeln Alexander
/// (Planungskern v6, 11.11.2026) Regel 4.4: die Befestigung „von oben“ ↔
/// „sichtverdeckt“ tauscht die Diele derselben Serie und Breite glattkant ↔
/// genutet. Das Gegenstück liefert auch die Schrauben für die sichtbar
/// verschraubten Anfangs- und Enddielen genuteter Dielen (Regel 4.1).
library;

import '../artikel/artikel.dart';
import 'regelwerk.dart';

/// Diele der Artikeldaten mit gleicher Art, Serie (und damit Holzart) und
/// Breite wie
/// [belag], aber dem anderen Profil (genutet ↔ glattkant). Gibt es mehrere,
/// gewinnt die mit gleicher Stärke, dann die mit gleicher Oberseite, dann
/// die erste in den Daten (B-122). `null` ohne Profil oder ohne Gegenstück.
Artikel? gegenstueck(Regelwerk regelwerk, Artikel belag) {
  final profil = belag.profil;
  if (profil == null) return null;
  final kandidaten = [
    for (final e in regelwerk.datei.eintraege)
      if (e.artikel case final a
          when a.art == belag.art &&
              a.serie == belag.serie &&
              a.abmessungen.breite == belag.abmessungen.breite &&
              a.profil != null &&
              a.profil != profil)
        a,
  ];
  if (kandidaten.isEmpty) return null;
  int punkte(Artikel a) =>
      (a.abmessungen.staerke == belag.abmessungen.staerke ? 2 : 0) +
      (a.oberseite == belag.oberseite ? 1 : 0);
  return kandidaten.reduce((beste, a) => punkte(a) > punkte(beste) ? a : beste);
}
