/// Schutzband auf der UK und Unterleger unter der UK nach Lieferland
/// (Planungsregeln Alexander (Planungskern v14, 13.11.2026), Regel 16.2,
/// R-C70/R-C71): außer in die Schweiz KOPPLEX-1 (75 × 1 mm, Rollen 20 und
/// 10 m) statt GUMO K auf allen UK-Oberseiten und KOPPLEX-3 (40 × 3 mm,
/// Rolle 10 m, je Auflagepunkt 8 cm) statt der dünnen GUMO-L-Unterleger
/// (2 und 5 mm); GUMO L 8 mm bleibt für den Höhenausgleich, die Schweiz
/// bleibt unverändert.
///
/// Die Artikel kommen aus den Artikeldaten (B-122), erkannt am Titel. Fehlen
/// sie dort, bleibt alles wie bisher (GUMO K, GUMO L).
library;

import '../artikel/artikel.dart';
import '../artikel/einheiten.dart';
import 'regelwerk.dart';

/// Land, in das geliefert wird – es bestimmt Schutzband und Unterleger
/// (Regel 16.2).
enum Lieferland {
  deutschland,
  oesterreich,
  schweiz;

  /// Ob KOPPLEX statt GUMO K und GUMO L 2/5 mm geplant wird (R-C70).
  bool get mitKopplex => this != schweiz;
}

/// Lieferland, solange die Planung keines kennt: der Planer rechnet mit dem
/// Shop Deutschland (Preise mit 19 % MwSt.).
const standardLieferland = Lieferland.deutschland;

/// KOPPLEX-3 je Auflagepunkt (Regel 16.2): 8 cm vom Band.
const unterlegbandJeAuflager = Millimeter(80);

/// Pads unter dieser Dicke ersetzt KOPPLEX-3 (Regel 16.2: GUMO L 2 und
/// 5 mm); ab ihr (GUMO L 8 mm) bleibt das Pad für den Höhenausgleich.
const unterlegbandStattPadsUnter = Millimeter(8);

/// Bandlänge je Verkaufseinheit in mm: Rollenlänge (längste Länge der
/// Artikeldaten, sonst „10m-Rolle“ im Titel) mal Rollen im Karton laut
/// Titel („10 Rollen à 10 m“); ohne Rollenlänge `null`.
int? bandlaenge(Artikel band) {
  final rolle =
      band.abmessungen.laengste?.mm ??
      switch (RegExp(r'(\d+)\s*m-Rolle').firstMatch(band.titel)) {
        final t? => int.parse(t.group(1)!) * 1000,
        null => null,
      };
  if (rolle == null) return null;
  final rollen = RegExp(r'(\d+)\s*Rollen').firstMatch(band.titel);
  return rolle * (rollen == null ? 1 : int.parse(rollen.group(1)!));
}

/// Schutzband KOPPLEX-1 für das [lieferland] (R-C70): alle Bänder mit
/// „KOPPLEX-1“ im Titel und Rollenlänge in Datenreihenfolge – leer für die
/// Schweiz oder wenn die Artikeldaten keins haben.
List<Artikel> schutzbandKopplex(Regelwerk regelwerk, Lieferland lieferland) =>
    _mitTitel(regelwerk, lieferland, 'KOPPLEX-1');

/// Unterlegband KOPPLEX-3 für das [lieferland] (R-C71): das erste Band mit
/// „KOPPLEX-3“ im Titel und Rollenlänge; `null` für die Schweiz oder wenn
/// die Artikeldaten keins haben.
Artikel? unterlegband(Regelwerk regelwerk, Lieferland lieferland) =>
    _mitTitel(regelwerk, lieferland, 'KOPPLEX-3').firstOrNull;

List<Artikel> _mitTitel(
  Regelwerk regelwerk,
  Lieferland lieferland,
  String name,
) => [
  if (lieferland.mitKopplex)
    for (final e in regelwerk.datei.eintraege)
      if (e.artikel case final a
          when (a.art == Artikelart.gummiband || a.art == Artikelart.pad) &&
              a.titel.contains(name) &&
              bandlaenge(a) != null)
        a,
];

/// Verkaufseinheiten KOPPLEX-3 für [auflager] Auflagepunkte (R-C71):
/// je Punkt [unterlegbandJeAuflager], aufgerundet auf ganze Einheiten des
/// [band]s.
int unterlegbandEinheiten(int auflager, Artikel band) {
  final je = bandlaenge(band)!;
  return (auflager * unterlegbandJeAuflager.mm + je - 1) ~/ je;
}
