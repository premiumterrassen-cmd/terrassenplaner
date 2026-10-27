import 'dart:math' as math;

import 'flaeche.dart';
import 'kontur.dart';
import 'punkt.dart';

/// Mengenoperation zweier Flächengruppen (M4-01).
enum Verknuepfung {
  vereinigung,
  schnitt,
  differenz;

  bool _gilt(bool inA, bool inB) => switch (this) {
    vereinigung => inA || inB,
    schnitt => inA && inB,
    differenz => inA && !inB,
  };
}

/// Abstand der Prüfpunkte links und rechts einer Kante in mm.
const _pruefabstand = 1e-3;

/// Abstand, unter dem Schnittpunkte zu einem Punkt verschmelzen, in mm.
const _verschmelzen = 1e-5;

/// Verknüpft die Flächen [a] mit [b] (M4-01). Bögen werden als Sehnenzug
/// ([bogenToleranz]) gerechnet, das Ergebnis besteht aus geraden Kanten.
///
/// Verfahren: Alle Ränder werden an ihren Schnittpunkten geteilt. Jedes
/// Teilstück gehört zum Ergebnisrand, wenn das Ergebnis auf genau einer
/// Seite liegt; es wird so ausgerichtet, dass das Ergebnis links liegt.
/// Die Teilstücke werden zu Ringen verkettet – gegen den Uhrzeigersinn sind
/// es Außenränder, im Uhrzeigersinn Löcher. Deckungsgleiche Kanten beider
/// Seiten sind dabei kein Sonderfall.
List<Flaeche> verknuepfe(
  List<Flaeche> a,
  List<Flaeche> b,
  Verknuepfung verknuepfung,
) {
  final ringeA = [for (final f in a) ..._Ring.alle(f)];
  final ringeB = [for (final f in b) ..._Ring.alle(f)];
  final register = _Punktregister();
  final kanten = _geteilteKanten(ringeA, ringeB, register);
  final gerichtet = <(int, int)>[];
  kanten.forEach((kante, rand) {
    final (von, nach) = kante;
    final p = register.punkte[von], q = register.punkte[nach];
    final links = (p + q) * 0.5 + (q - p).links.einheit * _pruefabstand;
    final inA = _Ring.enthalten(ringeA, links);
    final inB = _Ring.enthalten(ringeB, links);
    // rechts der Kante: über jeden Rand hinweg wechselt die Zugehörigkeit
    final ergebnisLinks = verknuepfung._gilt(inA, inB);
    final ergebnisRechts = verknuepfung._gilt(inA != rand.a, inB != rand.b);
    if (ergebnisLinks != ergebnisRechts) {
      gerichtet.add(ergebnisLinks ? (von, nach) : (nach, von));
    }
  });
  return _flaechen(_ringe(gerichtet, register.punkte));
}

/// Rand einer Fläche als Sehnenzug mit umschließendem Rechteck.
final class _Ring {
  _Ring(this.punkte) : huellrechteck = Huellrechteck.um(punkte);

  static Iterable<_Ring> alle(Flaeche f) => f.sehnenzuege.map(_Ring.new);

  /// Gerade-Ungerade-Regel über alle [ringe].
  static bool enthalten(List<_Ring> ringe, Punkt p) {
    final stelle = Huellrechteck(p, p);
    return ringe
        .where(
          (r) =>
              r.huellrechteck.beruehrt(stelle) &&
              sehnenzugEnthaelt(r.punkte, p),
        )
        .length
        .isOdd;
  }

  final List<Punkt> punkte;
  final Huellrechteck huellrechteck;
}

/// Auf welchen Rändern ein Teilstück liegt (ungerade oft = ja).
typedef _Rand = ({bool a, bool b});

/// Führt nahe beieinanderliegende Punkte auf eine Nummer zusammen.
final class _Punktregister {
  final punkte = <Punkt>[];

  final _exakt = <Punkt, int>{};

  int nummer(Punkt p) {
    final gleich = _exakt[p];
    if (gleich != null) return gleich;
    var nummer = punkte.indexWhere((x) => x.abstand(p) < _verschmelzen);
    if (nummer < 0) {
      punkte.add(p);
      nummer = punkte.length - 1;
    }
    _exakt[p] = nummer;
    return nummer;
  }
}

/// Alle Randstücke, an den gegenseitigen Schnittpunkten geteilt; ungerichtet
/// gleiche Stücke werden zusammengefasst und merken, auf welchen Rändern sie
/// liegen.
Map<(int, int), _Rand> _geteilteKanten(
  List<_Ring> ringeA,
  List<_Ring> ringeB,
  _Punktregister register,
) {
  final strecken = [
    for (final (ringe, ausA) in [(ringeA, true), (ringeB, false)])
      for (final ring in ringe)
        for (
          var i = 0, vor = ring.punkte.length - 1;
          i < ring.punkte.length;
          vor = i++
        )
          (ring.punkte[vor], ring.punkte[i], ausA),
  ];
  final teilungen = [
    for (final _ in strecken) <double>[0, 1],
  ];
  final huellrechtecke = [
    for (final (p, q, _) in strecken) Huellrechteck.um([p, q]),
  ];
  for (var i = 0; i < strecken.length; i++) {
    for (var j = i + 1; j < strecken.length; j++) {
      if (huellrechtecke[i].beruehrt(huellrechtecke[j])) {
        _teile(strecken[i], strecken[j], teilungen[i], teilungen[j]);
      }
    }
  }
  final ergebnis = <(int, int), _Rand>{};
  for (var i = 0; i < strecken.length; i++) {
    final (p, q, ausA) = strecken[i];
    final t = teilungen[i]..sort();
    var vorher = register.nummer(p);
    for (final wert in t.skip(1)) {
      final aktuell = register.nummer(p + (q - p) * wert);
      if (aktuell != vorher) {
        final kante = vorher < aktuell ? (vorher, aktuell) : (aktuell, vorher);
        final bisher = ergebnis[kante] ?? (a: false, b: false);
        ergebnis[kante] = (a: bisher.a != ausA, b: bisher.b == ausA);
      }
      vorher = aktuell;
    }
  }
  return ergebnis;
}

/// Trägt die Schnitt- und Berührpunkte zweier Strecken als Parameter
/// (0 … 1) in [ta] und [tb] ein.
void _teile(
  (Punkt, Punkt, bool) a,
  (Punkt, Punkt, bool) b,
  List<double> ta,
  List<double> tb,
) {
  final (p, p2, _) = a;
  final (q, q2, _) = b;
  final r = p2 - p, s = q2 - q;
  if (_aufGerade(q, p, r) && _aufGerade(q2, p, r)) {
    // deckungsgleich: die Enden der einen Strecke teilen die andere
    _teileBei(ta, [q, q2], p, r);
    _teileBei(tb, [p, p2], q, s);
    return;
  }
  // parallele Strecken ergeben hier ±∞ oder NaN und fallen heraus
  final nenner = r.kreuz(s);
  final t = (q - p).kreuz(s) / nenner, u = (q - p).kreuz(r) / nenner;
  // nur echte Schnittpunkte: auf beiden Strecken, nicht nur auf den Geraden
  if (_aufStrecke(t, r) && _aufStrecke(u, s)) {
    ta.add(t);
    tb.add(u);
  }
}

bool _aufGerade(Punkt x, Punkt p, Punkt richtung) =>
    richtung.kreuz(x - p).abs() < geometrieToleranz * richtung.laenge;

void _teileBei(List<double> teilungen, List<Punkt> punkte, Punkt p, Punkt r) {
  for (final x in punkte) {
    final t = (x - p).punktprodukt(r) / r.punktprodukt(r);
    if (_aufStrecke(t, r)) teilungen.add(t);
  }
}

/// Liegt der Punkt zum Parameter [t] auf der Strecke (Enden eingeschlossen)?
/// Werte knapp außerhalb verschmelzen später mit dem Endpunkt.
bool _aufStrecke(double t, Punkt richtung) {
  final rand = _verschmelzen / richtung.laenge;
  return t > -rand && t < 1 + rand;
}

/// Verkettet gerichtete Kanten zu geschlossenen Ringen. Treffen sich mehrere
/// Kanten in einem Punkt, wird die am stärksten links abbiegende gewählt –
/// so bleiben sich berührende Teile getrennte Ringe.
List<List<Punkt>> _ringe(List<(int, int)> kanten, List<Punkt> punkte) {
  final abgehend = <int, List<int>>{};
  for (var i = 0; i < kanten.length; i++) {
    abgehend.putIfAbsent(kanten[i].$1, () => []).add(i);
  }
  final benutzt = List.filled(kanten.length, false);
  final ringe = <List<Punkt>>[];
  for (var start = 0; start < kanten.length; start++) {
    if (benutzt[start]) continue;
    final ring = <int>[];
    var aktuell = start;
    while (!benutzt[aktuell]) {
      benutzt[aktuell] = true;
      final (von, nach) = kanten[aktuell];
      ring.add(von);
      if (nach == kanten[start].$1) break;
      final zurueck = punkte[von] - punkte[nach];
      aktuell = _linksteKante(
        abgehend[nach]!.where((k) => !benutzt[k]),
        zurueck,
        (k) => punkte[kanten[k].$2] - punkte[nach],
      );
    }
    ringe.add(_ohneGeradeZwischenpunkte([for (final i in ring) punkte[i]]));
  }
  return ringe;
}

/// Die Kante mit dem kleinsten Winkel im Uhrzeigersinn ab [zurueck].
int _linksteKante(
  Iterable<int> kandidaten,
  Punkt zurueck,
  Punkt Function(int) richtung,
) {
  double winkel(int k) {
    final d = richtung(k);
    return math.atan2(d.kreuz(zurueck), d.punktprodukt(zurueck)) %
        (2 * math.pi);
  }

  var beste = kandidaten.first;
  for (final k in kandidaten) {
    if (winkel(k) < winkel(beste)) beste = k;
  }
  return beste;
}

/// Entfernt Punkte, an denen der Ring geradeaus weiterläuft.
List<Punkt> _ohneGeradeZwischenpunkte(List<Punkt> ring) {
  final ergebnis = <Punkt>[];
  for (var i = 0, vor = ring.length - 1; i < ring.length; vor = i++) {
    final a = ring[i] - ring[vor], b = ring[(i + 1) % ring.length] - ring[i];
    final knick = a.kreuz(b).abs() / (a.laenge * b.laenge) > geometrieToleranz;
    if (knick || a.punktprodukt(b) < 0) ergebnis.add(ring[i]);
  }
  return ergebnis;
}

/// Ordnet jedes Loch (Uhrzeigersinn) dem kleinsten Außenrand zu, in dem es
/// liegt.
List<Flaeche> _flaechen(List<List<Punkt>> ringe) {
  final aussen = <Kontur>[], loecher = <Kontur>[];
  for (final ring in ringe) {
    final umlauf = _doppelteFlaeche(ring);
    if (umlauf.abs() < geometrieToleranz) continue;
    (umlauf > 0 ? aussen : loecher).add(Kontur(ring));
  }
  aussen.sort((x, y) => x.flaeche.compareTo(y.flaeche));
  final zugeordnet = [for (final _ in aussen) <Kontur>[]];
  for (final loch in loecher) {
    // Kantenmitte: liegt im Inneren des Außenrands, zu dem das Loch gehört
    final k = loch.kanten.first;
    final i = aussen.indexWhere((a) => a.enthaelt((k.start + k.ende) * 0.5));
    zugeordnet[i].add(loch);
  }
  return [
    for (var i = 0; i < aussen.length; i++) Flaeche(aussen[i], zugeordnet[i]),
  ];
}

/// Doppelte Fläche mit Vorzeichen: > 0 gegen den Uhrzeigersinn.
double _doppelteFlaeche(List<Punkt> ring) {
  var summe = 0.0;
  for (var i = 0, vor = ring.length - 1; i < ring.length; vor = i++) {
    summe += ring[vor].kreuz(ring[i]);
  }
  return summe;
}
