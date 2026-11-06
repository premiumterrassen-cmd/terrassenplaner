/// Entwässerungsrinnen (M7-03, Fachkonzept 4.3): Lage, Belagfläche und
/// Material.
library;

import 'dart:math' as math;

import '../artikel/artikel.dart';
import '../artikel/dielenlaenge.dart';
import '../artikel/einheiten.dart';
import '../ergebnisse/materialliste.dart';
import '../geometrie/punkt.dart';
import '../konfiguration/anschluss.dart';
import '../konfiguration/anschlussergebnis.dart';
import '../konfiguration/grundriss.dart';
import '../konfiguration/planungsstand.dart';
import 'anschlussregeln.dart';
import 'regelwerk.dart';
import 'verblendung.dart';

/// Rinnenartikel für die Lage [lage] am [belag]: die Artikel aus
/// `Beziehung.drainage` in Datenreihenfolge stehen für die Lagen in ihrer
/// Reihenfolge (gesamte Seite, im Element, außerhalb, vor dem Element);
/// fehlt die Variante, gilt die erste (R-D01: die Lage wählt die
/// Artikelvariante). `null` ohne Artikel.
Artikel? rinnenartikel(Regelwerk? regelwerk, Artikel belag, Rinnenlage lage) {
  if (regelwerk?.datei[belag.nummer] == null) return null;
  final varianten = regelwerk!.moeglich(belag.nummer, Beziehung.drainage);
  if (varianten.isEmpty) return null;
  return varianten[math.min(lage.index, varianten.length - 1)];
}

/// Planungsstand für den Belag: jede Seite mit Rinne um die Breite ihres
/// Artikels nach innen versetzt (F38: 480 × 309 → 480 × 297 cm). Die UK
/// bleibt an der Seite (R-C08), sie rechnet mit dem ganzen Grundriss. Ohne
/// Rinnen mit Breite oder wenn der versetzte Umriss nicht gültig ist (zu
/// kurze Seiten, gekreuzt, umgeklappt), bleibt der Stand.
Planungsstand belagstand(
  Planungsstand stand,
  Millimeter? Function(int seite) breite,
) {
  var ecken = stand.grundriss.ecken;
  var versetzt = false;
  for (final (:seite, lage: _) in stand.anschluss.rinnen) {
    final b = breite(seite);
    if (b == null || b.mm <= 0) continue;
    ecken = _versetzt(ecken, seite, b.mm.toDouble(), stand);
    versetzt = true;
  }
  if (!versetzt) return stand;
  try {
    final neu = FreiformGrundriss(ecken, geschlossen: true);
    // umgeklappt: die Rinnen sind breiter als die Fläche
    if (neu.kontur.gegenUhrzeigersinn !=
        stand.grundriss.kontur.gegenUhrzeigersinn) {
      return stand;
    }
    return stand.mitGrundriss(neu);
  } on ArgumentError {
    return stand;
  }
}

/// [ecken] mit der Seite [seite] um [abstand] nach innen versetzt: ihre
/// beiden Ecken wandern auf den Nachbarseiten mit.
List<Punkt> _versetzt(
  List<Punkt> ecken,
  int seite,
  double abstand,
  Planungsstand stand,
) {
  final n = ecken.length;
  final a = ecken[seite];
  final b = ecken[(seite + 1) % n];
  final laengs = (b - a) * (1 / a.abstand(b));
  final innen = stand.grundriss.kontur.gegenUhrzeigersinn
      ? Punkt(-laengs.y, laengs.x)
      : Punkt(laengs.y, -laengs.x);
  final verschoben = innen * abstand;
  final vorher = ecken[(seite + n - 1) % n];
  final nachher = ecken[(seite + 2) % n];
  return [
    for (var i = 0; i < n; i++)
      i == seite
          ? _schnitt(vorher, a, a + verschoben, laengs)
          : i == (seite + 1) % n
          ? _schnitt(nachher, b, b + verschoben, laengs)
          : ecken[i],
  ];
}

/// Schnitt der Geraden durch [p] und [q] mit der Geraden durch [r] in
/// Richtung [d]; parallel: [r].
Punkt _schnitt(Punkt p, Punkt q, Punkt r, Punkt d) {
  final e = q - p;
  final nenner = e.x * d.y - e.y * d.x;
  if (nenner.abs() < 1e-9) return r;
  final t = ((r.x - p.x) * d.y - (r.y - p.y) * d.x) / nenner;
  return p + e * t;
}

/// Planungsstand für den Belag mit den Rinnenartikeln der Lagen
/// (`rinnenartikel`, `belagstand`); ohne Belag der Stand selbst.
Planungsstand rinnenstand(
  Planungsstand stand,
  Artikel? belag,
  Regelwerk? regelwerk,
) {
  if (belag == null) return stand;
  return belagstand(
    stand,
    (seite) => rinnenartikel(
      regelwerk,
      belag,
      stand.anschluss.rinneAn(seite)!,
    )?.abmessungen.breite,
  );
}

/// Material der Entwässerungsrinnen (M7-03, Fachkonzept 4.3) je Seite mit
/// Rinne, über die ganze Seite (Eckpunkt zu Eckpunkt):
///
/// - **Rinne** (`rinnenartikel`): mit Lieferlängen je Seite so viele Stücke
///   wie `lieferlaengenFuer` (F38: 480 cm aus 1200 mm → 4), ohne in lfm.
/// - **Pflichtzubehör der Rinne** (Artikeldaten, z. B. Auflagerprofile):
///   mit „Abstand_Stelzfuesse“ der Rinne im Abstand plus eins je Seite
///   (F38: 480 cm, 100 cm → 6), sonst je Rinnenstück; mal der Anzahl aus
///   den Artikeldaten.
///
/// Ohne Rinnenartikel kommt der Hinweis `ohneRinnenartikel`.
Anschlussbedarf rinnenbedarf(
  Planungsstand stand, {
  Artikel? belag,
  Regelwerk? regelwerk,
}) {
  final bedarf = <Materialbedarf>[];
  var ohneArtikel = false;
  for (final (:seite, :lage) in stand.anschluss.rinnen) {
    final rinne = belag == null ? null : rinnenartikel(regelwerk, belag, lage);
    if (rinne == null) {
      ohneArtikel = true;
      continue;
    }
    final (:von, :bis) = seitenstrecke(stand, seite);
    final laenge = Millimeter(von.abstand(bis).round());
    final laengen = rinne.abmessungen.laengen;
    final stuecke = laengen.isEmpty
        ? const <Millimeter>[]
        : lieferlaengenFuer(laenge, laengen);
    bedarf.addAll(
      laengen.isEmpty
          ? [
              Materialbedarf([rinne], (laenge.mm / 1000).ceil()),
            ]
          : [
              for (final l in stuecke.toSet())
                Materialbedarf(
                  [rinne],
                  stuecke.where((s) => s == l).length,
                  laenge: l,
                ),
            ],
    );
    // regelwerk ist da, sonst gäbe es keinen Rinnenartikel
    final daten = regelwerk!;
    final abstand = daten.abstaende(rinne.nummer).stelzfuesse;
    final je = abstand == null
        ? math.max(1, stuecke.length)
        : math.max(1, (laenge.mm / abstand.mm - 1e-6).ceil()) + 1;
    for (final MapEntry(key: zubehoer, value: anzahl)
        in daten.pflichtzubehoer(rinne.nummer).entries) {
      bedarf.add(Materialbedarf([zubehoer], je * anzahl));
    }
  }
  return Anschlussbedarf(
    bedarf: bedarf,
    meldungen: [if (ohneArtikel) Anschlussmeldung.ohneRinnenartikel],
  );
}
