/// Berechnung der Auflager mit Höhenzuordnung (M6-11, Fachkonzept 3.9):
/// Lage und Höhe jedes Stelzfußes bzw. Pads längs der UK-Hölzer, Tabelle
/// der Höhenzuordnung und Mengen für die Materialliste.
library;

import 'dart:math' as math;

import '../artikel/artikel.dart';
import '../artikel/einheiten.dart';
import '../artikel/ukauswahl.dart';
import '../ergebnisse/materialliste.dart';
import '../ergebnisse/stueckliste.dart';
import '../geometrie/punkt.dart';
import '../konfiguration/belagverlegung.dart';
import '../konfiguration/planungsstand.dart';
import '../konfiguration/terrassenart.dart';
import 'auflager.dart';
import 'planungsregeln.dart';
import 'regelwerk.dart';
import 'uk_verlegung.dart';
import 'uk_zusatz.dart';

/// Ein Auflager: Ort in mm, Spalt zwischen UK und Boden und die Zeile der
/// Höhenzuordnung (`null`: kein passendes Auflager, siehe Meldungen).
typedef Auflagerpunkt = ({Punkt ort, Millimeter spalt, int? zeile});

/// Zeile der Höhenzuordnung: so viele Auflager dieser Art für Spalte von
/// [von] bis [bis].
typedef Auflagerzeile = ({
  String titel,
  int anzahl,
  Millimeter von,
  Millimeter bis,
});

/// Auflager einer Fläche (M6-11).
final class Auflagerbedarf {
  Auflagerbedarf({
    List<Auflagerpunkt> punkte = const [],
    List<Auflagerzeile> zeilen = const [],
    List<Materialbedarf> bedarf = const [],
    List<Planstueck> stuecke = const [],
    List<Lieferdiele> zuschnitt = const [],
  }) : punkte = List.unmodifiable(punkte),
       zuschnitt = List.unmodifiable(zuschnitt),
       zeilen = List.unmodifiable(zeilen),
       bedarf = List.unmodifiable(bedarf),
       stuecke = List.unmodifiable(stuecke);

  static final keiner = Auflagerbedarf();

  /// Auflager in Planungskoordinaten mit Spalt und Zeile.
  final List<Auflagerpunkt> punkte;

  /// Tabelle der Höhenzuordnung in der Reihenfolge der Bereiche.
  final List<Auflagerzeile> zeilen;

  /// Stelzfüße, Pads und Bodenanker in Stück (verpackt wird über alle
  /// Flächen), Stützen als UK-Lieferstücke.
  final List<Materialbedarf> bedarf;

  /// Stützen aus UK-Holz für die Stückliste (Hochterrasse, grün).
  final List<Planstueck> stuecke;

  /// Aus welchem Lieferholz die Stützen geschnitten werden (M9-02).
  final List<Lieferdiele> zuschnitt;
}

/// Höhe von Oberkante Belag bis Boden über der Fläche aus Höhenpunkten
/// (M6-11, Planungsregeln Alexander (Planungskern v7, 12.11.2026), Regel
/// 9.1, R-C18): je Eckpunkt die geprüfte Höhe, dazu die weiteren
/// Höhenreferenzpunkte (M7-04, [weitere], ihre Höhen folgen in [hoehen] auf
/// die der Ecken; Punkte außerhalb der Fläche wirken nicht, ein Punkt auf
/// einer Ecke ersetzt deren Höhe).
///
/// - **ein Punkt:** überall gleich;
/// - **zwei Punkte:** Verlauf entlang ihrer Verbindung, quer dazu gleich;
/// - **ab drei Punkten** die Ausgleichsebene (kleinste Quadrate); liegen
///   alle auf einer Linie, der Verlauf zwischen den äußeren.
///
/// Liegen die Punkte nicht in dieser Ebene (Untergrund verwunden, Ablauf),
/// wird die Abweichung je Punkt nach Abstand verteilt (Gewicht 1 / Abstand²)
/// – jeder angegebene Punkt stimmt genau, eine geneigte Ebene (F30) bleibt
/// exakt. Passen Ecken und Höhen nicht zusammen, gilt überall die erste
/// Höhe.
final class Hoehenflaeche {
  factory Hoehenflaeche(
    List<Punkt> ecken,
    List<Millimeter> hoehen, [
    List<Punkt> weitere = const [],
  ]) {
    final werte = [for (final h in hoehen) h.mm.toDouble()];
    if (ecken.length + weitere.length != hoehen.length || ecken.isEmpty) {
      return Hoehenflaeche._([(Punkt.ursprung, werte.first)]);
    }
    final punkte = [for (final (i, e) in ecken.indexed) (e, werte[i])];
    for (final (i, p) in weitere.indexed) {
      if (ecken.length >= 3 && !_inFlaeche(ecken, p)) continue;
      final h = werte[ecken.length + i];
      final gleich = punkte.indexWhere((q) => q.$1.abstand(p) < _gleichBis);
      if (gleich >= 0) {
        punkte[gleich] = (p, h);
      } else {
        punkte.add((p, h));
      }
    }
    return Hoehenflaeche._(punkte);
  }

  Hoehenflaeche._(List<(Punkt, double)> punkte)
    : _punkte = punkte,
      _gefaelle = _ausgleichsgefaelle(punkte) {
    _rest = [for (final (p, h) in punkte) h - _gefaelle.bei(p)];
  }

  final List<(Punkt, double)> _punkte;
  final _Gefaelle _gefaelle;
  late final List<double> _rest;

  /// Höhe am Punkt [p] in mm (auf ganze mm gerundet): das Gefälle der
  /// Ausgleichsebene plus die Abweichungen der Punkte nach Abstand – die
  /// Höhenlage der Ebene steckt in den Abweichungen (bei ebenen Punkten
  /// sind alle gleich).
  Millimeter bei(Punkt p) {
    var summe = 0.0;
    var gewichte = 0.0;
    for (final (i, (q, hq)) in _punkte.indexed) {
      final abstand = p.abstand(q);
      if (abstand < _gleichBis) return Millimeter(hq.round());
      final gewicht = 1 / (abstand * abstand);
      gewichte += gewicht;
      summe += _rest[i] * gewicht;
    }
    return Millimeter((_gefaelle.bei(p) + summe / gewichte).round());
  }
}

/// Punkte näher als dies (mm) gelten als derselbe Punkt.
const _gleichBis = 1.0;

/// Gefälle einer Ebene: Höhe a·x + b·y bis auf die Höhenlage.
typedef _Gefaelle = ({double a, double b});

extension on _Gefaelle {
  double bei(Punkt p) => a * p.x + b * p.y;
}

const _Gefaelle _flach = (a: 0, b: 0);

/// Gefälle der Ausgleichsebene der [punkte] (Regel 9.1): einer flach, zwei
/// als Verlauf entlang ihrer Verbindung, ab drei kleinste Quadrate – liegen
/// sie auf einer Linie, der Verlauf zwischen den beiden äußeren.
_Gefaelle _ausgleichsgefaelle(List<(Punkt, double)> punkte) {
  final n = punkte.length;
  if (n == 1) return _flach;
  if (n == 2) return _verlauf(punkte);
  var (mx, my) = (0.0, 0.0);
  for (final (p, _) in punkte) {
    mx += p.x / n;
    my += p.y / n;
  }
  var (sxx, sxy, syy, sxh, syh) = (0.0, 0.0, 0.0, 0.0, 0.0);
  for (final (p, h) in punkte) {
    final (x, y) = (p.x - mx, p.y - my);
    sxx += x * x;
    sxy += x * y;
    syy += y * y;
    sxh += x * h;
    syh += y * h;
  }
  final det = sxx * syy - sxy * sxy;
  if (det.abs() > 1e-6 * math.max(1, sxx * syy)) {
    return (a: (sxh * syy - syh * sxy) / det, b: (syh * sxx - sxh * sxy) / det);
  }
  // alle auf einer Linie: die beiden am weitesten auseinander
  var paar = [punkte.first, punkte.last];
  for (final u in punkte) {
    for (final w in punkte) {
      if (u.$1.abstand(w.$1) > paar.first.$1.abstand(paar.last.$1)) {
        paar = [u, w];
      }
    }
  }
  return _verlauf(paar);
}

/// Verlauf zwischen dem ersten und letzten der [paar]: das Gefälle entlang
/// ihrer Verbindung, quer dazu flach; liegen sie aufeinander, flach.
_Gefaelle _verlauf(List<(Punkt, double)> paar) {
  final (von, hv) = paar.first;
  final (bis, hb) = paar.last;
  final d = bis - von;
  if (d.laenge < _gleichBis) return _flach;
  final g = (hb - hv) / d.punktprodukt(d);
  return (a: g * d.x, b: g * d.y);
}

/// Ob [p] in dem Vieleck der [ecken] oder auf seinem Rand liegt.
bool _inFlaeche(List<Punkt> ecken, Punkt p) {
  var innen = false;
  var a = ecken.last;
  for (final b in ecken) {
    if (_streckenabstand(a, b, p) < _gleichBis) return true;
    if ((a.y > p.y) != (b.y > p.y) &&
        p.x < a.x + (p.y - a.y) * (b.x - a.x) / (b.y - a.y)) {
      innen = !innen;
    }
    a = b;
  }
  return innen;
}

double _streckenabstand(Punkt a, Punkt b, Punkt p) {
  final d = b - a;
  final t = ((p - a).punktprodukt(d) / d.punktprodukt(d)).clamp(0.0, 1.0);
  return (a + d * t).abstand(p);
}

/// Auflager der UK-Verlegung [verlegung] (M6-11):
///
/// - **Lage** (`_stellen`, Planungsregeln Alexander (Planungskern v6,
///   11.11.2026), Regel 3.6): das erste und letzte Auflager 5 cm vom Ende
///   der UK, dazwischen gleichmäßig höchstens [abstand]
///   (`auflagerabstand`, M6-08) auseinander, an jedem Stoß der UK eins, auf
///   dem beide Enden liegen; eine UK bis 12 cm hat eins in der Mitte – F01:
///   13 Linien à 309 cm mit 60 cm → je 7 (91; F28: 91 Bodenanker wie im
///   alten Planer).
///   Die Rand-UK (Planungsregeln 3.3) trägt ihre Auflager genauso; ein
///   Stützholz unter der Rinne hat eins in der Mitte (Planungskern v11,
///   Regel 13.1.4).
/// - **Höhe:** [flaeche] am Auflager minus [aufbauhoehe] und
///   [gummiband] ist der Spalt zwischen UK und Boden (Ausgleichshöhe,
///   Planungsregeln Alexander (Planungskern v6, 11.11.2026), Regel 3a.2.1).
/// - **Normale Terrasse:** je Spalt das Auflager aus den [bereiche]n
///   (`auflagerFuer`, M6-08, Regel 3a.2: bis 17 mm ein oder zwei Pads,
///   darüber Stelzfüße); die Höhenzuordnung zählt je Auflager (zwei Pads
///   übereinander sind eine Zeile), die Materialliste je Bereich über
///   seine Packungen.
/// - **Hochterrasse:** je Auflager eine Stütze aus UK-Holz in Spaltlänge
///   (Stückliste grün, Lieferstücke wie kurze Stücke) und ein Bodenanker.
/// - **Vorhandene UK:** je Auflager (Abstand = Spannweite) ein Bodenanker
///   auf dem vorhandenen Träger (F29: 13 × 5 = 65).
///
/// Bodenanker: der erste Artikel der Art Bodenanker im [regelwerk] – die
/// Upload-Datei verweist von der UK nicht auf sie.
Auflagerbedarf auflagerbedarf(
  Planungsstand stand,
  UkVerlegung verlegung, {
  required Artikel uk,
  required Millimeter abstand,
  required Hoehenflaeche flaeche,
  required Millimeter aufbauhoehe,
  List<Auflagerbereich> bereiche = const [],
  Regelwerk? regelwerk,
}) {
  final drehung = verlegung.winkel * math.pi / 180;
  final a = abstand.mm.toDouble();
  final orte = [
    for (final l in verlegung.linien)
      for (final y in _stellen(l.abschnitte, l.stoesse, a))
        Punkt(l.x, y).gedreht(drehung),
    for (final r in verlegung.rand)
      for (final s in _stellen([(0, r.von.abstand(r.bis))], r.stoesse, a))
        (r.von + (r.bis - r.von).einheit * s).gedreht(drehung),
    for (final s in verlegung.stuetzen)
      ((s.von + s.bis) * 0.5).gedreht(drehung),
  ];
  if (orte.isEmpty) return Auflagerbedarf.keiner;
  final spalte = [
    for (final o in orte) flaeche.bei(o) - aufbauhoehe - gummiband,
  ];
  final anker = regelwerk?.datei.eintraege
      .map((e) => e.artikel)
      .where((a) => a.art == Artikelart.bodenanker)
      .firstOrNull;
  return switch (stand.terrassenart) {
    Terrassenart.normal => _stelzfuesse(orte, spalte, bereiche),
    Terrassenart.hochterrasse => _stuetzen(stand, orte, spalte, uk, anker),
    Terrassenart.vorhandeneUk => Auflagerbedarf(
      punkte: [
        for (final (i, o) in orte.indexed)
          (ort: o, spalt: spalte[i], zeile: anker == null ? null : 0),
      ],
      zeilen: [
        if (anker != null)
          (
            titel: anker.titel,
            anzahl: orte.length,
            von: _min(spalte),
            bis: _max(spalte),
          ),
      ],
      bedarf: [
        if (anker != null) Materialbedarf([anker], orte.length),
      ],
    ),
  };
}

/// Stellen der Auflager auf den [abschnitte]n einer Linie oder Rand-UK
/// (y bzw. Abstand vom Anfang) mit den [stoesse]n (Planungsregeln Alexander
/// (Planungskern v6, 11.11.2026), Regel 3.5/3.6): das erste und das letzte
/// [auflagerRandabstand] vom Ende der UK, an jedem Stoß eins für beide
/// Enden, dazwischen je Holz gleichmäßig höchstens [abstand] auseinander –
/// die Anzahl je Holz richtet sich nach seiner ganzen Länge. Ein Abschnitt
/// bis [auflagerEinzelnBis] bekommt eins in der Mitte.
List<double> _stellen(
  List<(double, double)> abschnitte,
  List<double> stoesse,
  double abstand,
) {
  final rand = auflagerRandabstand.mm.toDouble();
  final stellen = <double>[];
  for (final (von, bis) in abschnitte) {
    if (bis - von <= auflagerEinzelnBis.mm) {
      stellen.add((von + bis) / 2);
      continue;
    }
    final grenzen = [
      von,
      for (final s in stoesse)
        if (s > von && s < bis) s,
      bis,
    ];
    stellen.add(von + rand);
    for (var i = 1; i < grenzen.length; i++) {
      final (a, b) = (grenzen[i - 1], grenzen[i]);
      // feste Obergrenze wie bei den Hölzern (`hoechsteFelder`)
      final felder = math.min(
        hoechsteFelder,
        math.max(1, ((b - a) / abstand - 1e-6).ceil()),
      );
      final anfang = i == 1 ? von + rand : a;
      final ende = i == grenzen.length - 1 ? bis - rand : b;
      for (var k = 1; k <= felder; k++) {
        stellen.add(anfang + (ende - anfang) * k / felder);
      }
    }
  }
  return stellen;
}

Auflagerbedarf _stelzfuesse(
  List<Punkt> orte,
  List<Millimeter> spalte,
  List<Auflagerbereich> bereiche,
) {
  final wahlen = auflagerwahlen(bereiche);
  final wahl = [for (final s in spalte) auflagerFuer(s, wahlen)];
  // Spalte je Lage, in der Reihenfolge der Punkte
  final spalteJe = <Auflagerwahl, List<Millimeter>>{};
  for (final (i, w) in wahl.indexed) {
    if (w != null) spalteJe.putIfAbsent(w, () => []).add(spalte[i]);
  }
  final zeilen = [
    for (final w in wahlen)
      if (spalteJe.containsKey(w)) w,
  ];
  final index = {for (final (i, w) in zeilen.indexed) w: i};
  final stueck = <Auflagerbereich, int>{};
  for (final MapEntry(key: w, value: s) in spalteJe.entries) {
    for (final t in w.teile) {
      stueck[t] = (stueck[t] ?? 0) + s.length;
    }
  }
  return Auflagerbedarf(
    punkte: [
      for (final (i, o) in orte.indexed)
        (ort: o, spalt: spalte[i], zeile: index[wahl[i]]),
    ],
    zeilen: [
      for (final w in zeilen)
        if (spalteJe[w]! case final s)
          (titel: w.titel, anzahl: s.length, von: _min(s), bis: _max(s)),
    ],
    bedarf: [
      for (final b in bereiche)
        if (stueck[b] case final n?) Materialbedarf(b.einheiten, n),
    ],
  );
}

Auflagerbedarf _stuetzen(
  Planungsstand stand,
  List<Punkt> orte,
  List<Millimeter> spalte,
  Artikel uk,
  Artikel? anker,
) {
  final laengen = ukLieferlaengen(uk);
  final stuecke = [
    for (final s in spalte)
      if (s.mm > 0)
        Planstueck(
          uk.nummer,
          uk.titel,
          s,
          ganzeLaenge: laengen.last,
          lage: Stuecklage.quer,
        ),
  ];
  final zuschnitt = lieferhoelzer(
    [for (final s in stuecke) s.laenge],
    laengen,
    fest: stand.ukLaenge,
  );
  return Auflagerbedarf(
    zuschnitt: zuschnitt,
    punkte: [
      for (final (i, o) in orte.indexed) (ort: o, spalt: spalte[i], zeile: 0),
    ],
    zeilen: [
      (
        titel: uk.titel,
        anzahl: orte.length,
        von: _min(spalte),
        bis: _max(spalte),
      ),
      if (anker != null)
        (
          titel: anker.titel,
          anzahl: orte.length,
          von: _min(spalte),
          bis: _max(spalte),
        ),
    ],
    bedarf: [
      ...ukBedarf(uk, zuschnitt),
      if (anker != null) Materialbedarf([anker], orte.length),
    ],
    stuecke: stuecke,
  );
}

Millimeter _min(List<Millimeter> werte) =>
    Millimeter(werte.map((w) => w.mm).reduce(math.min));

Millimeter _max(List<Millimeter> werte) =>
    Millimeter(werte.map((w) => w.mm).reduce(math.max));
