/// Rand-UK an den Kanten, an denen Dielen enden (Planungsregeln Alexander
/// (Planungskern v6, 11.11.2026), Regel 3.3 und 3.4; Antwort auf die offene
/// Frage 19, Fachkonzept 3.11).
///
/// Gerechnet wird in der gedrehten Fläche wie bei der UK-Verlegung: Dielen
/// längs x, UK-Linien quer dazu (x fest).
library;

import 'dart:math' as math;

import '../geometrie/kontur.dart';
import '../geometrie/punkt.dart';
import 'uk_verlegung.dart';

/// Eine Kante des Umrisses oder eines leeren Ausschnitts in der gedrehten
/// Fläche: von [von] nach [bis], [innen] ist die Einheitsnormale zur
/// Belagseite (bei Ausschnitten die Terrassenseite, nicht das Loch).
typedef Randkante = ({Punkt von, Punkt bis, Punkt innen});

/// Eine Kante mit Rand-UK; [ergaenzt]: erst die Selbstkontrolle (Regel 3.4)
/// hat sie gefunden.
typedef Randbelegung = ({Randkante kante, bool ergaenzt});

/// Kanten der [vielecke] (Umriss und leere Ausschnitte in der gedrehten
/// Fläche), soweit sie an Belag grenzen: geteilt an den Ecken und Schnitten
/// der anderen Vielecke; ein Stück zählt, wenn eine UK-Breite [w] neben
/// seiner Mitte Belag liegt ([aufBelag]) – auf dieser Seite liegt die
/// Rand-UK. Stücke ohne Belag daneben (etwa wo ein Ausschnitt den Umriss
/// berührt) fallen weg, benachbarte Stücke einer Kante mit derselben
/// Belagseite bleiben eins.
List<Randkante> randkanten(
  List<List<Punkt>> vielecke,
  bool Function(Punkt) aufBelag,
  double w,
) => [
  for (final p in vielecke)
    for (final (i, a) in p.indexed)
      if (p[(i + 1) % p.length] case final b)
        ..._anBelag(a, b, _teilung(a, b, vielecke), aufBelag, w),
];

/// Ecken anderer Vielecke gelten höchstens so weit (mm) neben einer Kante
/// als auf ihr.
const _aufKante = 0.5;

/// Teilungen (Anteil 0 bis 1) der Kante [a]–[b]: ihre Enden, die Ecken der
/// [vielecke] auf ihr und die Schnitte mit deren Kanten, aufsteigend.
List<double> _teilung(Punkt a, Punkt b, List<List<Punkt>> vielecke) {
  final d = b - a;
  final teile = <double>{0, 1};
  for (final p in vielecke) {
    for (final (i, c) in p.indexed) {
      final f = p[(i + 1) % p.length] - c;
      final t = (c - a).punktprodukt(d) / d.punktprodukt(d);
      if (t > 0 && t < 1 && (a + d * t).abstand(c) <= _aufKante) teile.add(t);
      final nenner = d.kreuz(f);
      if (nenner == 0) continue;
      final s = (c - a).kreuz(f) / nenner;
      final u = (c - a).kreuz(d) / nenner;
      if (s > 0 && s < 1 && u >= 0 && u <= 1) teile.add(s);
    }
  }
  return teile.toList()..sort();
}

/// Die Stücke der Kante [a]–[b] zwischen den [teilungen], neben denen Belag
/// liegt, mit der Normalen zur Belagseite.
List<Randkante> _anBelag(
  Punkt a,
  Punkt b,
  List<double> teilungen,
  bool Function(Punkt) aufBelag,
  double w,
) {
  final d = b - a;
  final normale = d.einheit.links;
  final stuecke = <Randkante>[];
  for (var i = 1; i < teilungen.length; i++) {
    final (von, bis) = (a + d * teilungen[i - 1], a + d * teilungen[i]);
    final mitte = (von + bis) * 0.5;
    final innen = aufBelag(mitte + normale * w)
        ? normale
        : aufBelag(mitte - normale * w)
        ? normale * -1
        : null;
    if (innen == null) continue;
    if (stuecke.lastOrNull case final letzte?
        when letzte.bis == von && letzte.innen == innen) {
      stuecke.last = (von: letzte.von, bis: bis, innen: innen);
    } else {
      stuecke.add((von: von, bis: bis, innen: innen));
    }
  }
  return stuecke;
}

/// Eine Kante weicht mehr als so viele Grad von der Richtung der UK ab,
/// dann ist sie schräg und bekommt eine Rand-UK (Regel 3.3).
const randWinkel = 12.0;

/// Eine Kante reicht quer zu den Dielen weiter als so viele mm, dann enden
/// an ihr Dielen und sie bekommt nach Regel 3.3 eine Rand-UK.
const randAusdehnung = 80.0;

/// Die Selbstkontrolle (Regel 3.4) prüft alle Kanten, die quer zu den
/// Dielen mindestens so weit (mm) reichen – flachere laufen mit der Diele,
/// dort endet keine.
const pruefAusdehnung = 10.0;

/// Prüfpunkte der Selbstkontrolle: alle 10 cm entlang der Kante, ab 5 cm
/// vom Anfang bis höchstens 5 cm vor dem Ende.
const pruefAbstand = 100.0;
const _pruefRand = 50.0;

/// Ein Prüfpunkt ist belegt, wenn eine UK höchstens so weit (mm) entfernt
/// liegt.
const pruefToleranz = 60.0;

/// Fehlt die UK an mehr als diesem Anteil der Prüfpunkte einer Kante, wird
/// die Rand-UK ergänzt.
const fehlAnteil = 0.1;

/// Kanten mit Rand-UK (Regel 3.3) und von der Selbstkontrolle ergänzte
/// (Regel 3.4), in dieser Reihenfolge:
///
/// - **Regel 3.3:** an jeder Kante, an der Dielen enden (quer zu den Dielen
///   über [randAusdehnung]), liegt eine UK – ist die Kante schräg (über
///   [randWinkel] zur UK) oder liegt keine der [linien] an ihr (etwa die
///   Innenkante einer L-Form oder die Kante eines Ausschnitts), eine Rand-UK
///   entlang der Kante. Kanten parallel zu den Dielen bekommen keine.
/// - **Regel 3.4 (Selbstkontrolle):** Prüfpunkte alle [pruefAbstand] auf
///   jeder Kante ab [pruefAusdehnung] quer zu den Dielen; liegt an mehr als
///   [fehlAnteil] von ihnen keine UK (Linie oder Rand-UK) innerhalb
///   [pruefToleranz], wird die Rand-UK ergänzt und gemeldet.
List<Randbelegung> randbelegung(List<Randkante> kanten, List<UkLinie> linien) {
  final rand = <Randbelegung>[];
  bool belegt(Randkante k) =>
      _belegt(k, linien, [for (final r in rand) r.kante]);
  for (final k in kanten) {
    if (_quer(k) > randAusdehnung && (_schraeg(k) || !belegt(k))) {
      rand.add((kante: k, ergaenzt: false));
    }
  }
  for (final k in kanten) {
    if (_quer(k) >= pruefAusdehnung && !belegt(k)) {
      rand.add((kante: k, ergaenzt: true));
    }
  }
  return rand;
}

/// Ausdehnung der Kante [k] quer zu den Dielen (y).
double _quer(Randkante k) => (k.bis.y - k.von.y).abs();

/// Weicht die Kante [k] mehr als [randWinkel] von der UK-Richtung (y) ab?
bool _schraeg(Randkante k) =>
    math.atan2((k.bis.x - k.von.x).abs(), _quer(k)) * 180 / math.pi >=
    randWinkel;

/// Liegt an höchstens [fehlAnteil] der Prüfpunkte von [k] keine UK?
bool _belegt(Randkante k, List<UkLinie> linien, List<Randkante> rand) {
  final laenge = k.von.abstand(k.bis);
  final richtung = (k.bis - k.von).einheit;
  final anzahl = math.max(
    0,
    ((laenge - 2 * _pruefRand) / pruefAbstand).floor() + 1,
  );
  var fehlend = 0;
  // Zählschleife mit i++ (docs/erkenntnisse/mutation-tests.md)
  for (var i = 0; i < anzahl; i++) {
    final q = k.von + richtung * (_pruefRand + i * pruefAbstand);
    if (!_gedeckt(q, linien, rand)) fehlend++;
  }
  return fehlend <= anzahl * fehlAnteil;
}

/// Liegt eine UK-Linie oder Rand-UK höchstens [pruefToleranz] von [q]?
bool _gedeckt(Punkt q, List<UkLinie> linien, List<Randkante> rand) =>
    linien.any(
      (l) =>
          (l.x - q.x).abs() <= pruefToleranz &&
          l.abschnitte.any(
            (a) => q.y >= a.$1 - pruefToleranz && q.y <= a.$2 + pruefToleranz,
          ),
    ) ||
    rand.any((r) => Kante(r.von, r.bis).abstand(q) <= pruefToleranz);
