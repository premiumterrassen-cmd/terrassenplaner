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
import '../konfiguration/planungsstand.dart';
import '../konfiguration/terrassenart.dart';
import 'auflager.dart';
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
  }) : punkte = List.unmodifiable(punkte),
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
}

/// Höhe von Oberkante Belag bis Boden über der Fläche aus den Höhenpunkten
/// (M6-11): je Eckpunkt die geprüfte Höhe, dazwischen linear über Dreiecke
/// der Ecken (Ohrenschnitt) – eine geneigte Ebene (F30) wird exakt
/// wiedergegeben, an jedem Eckpunkt gilt seine Höhe. Ohne Gefälle, mit nur
/// einem Punkt (Kreis) oder ohne passende Ecken überall die erste Höhe.
///
/// Weitere Höhenreferenzpunkte (M7-04, [weitere], ihre Höhen folgen in
/// [hoehen] auf die der Ecken) teilen die Dreiecke, in denen sie liegen –
/// auch auf einer Kante –, in Dreiecke zu ihnen; dort gilt ihre Höhe (ein
/// Ablauf als tiefster Punkt). Punkte außerhalb der Fläche wirken nicht.
final class Hoehenflaeche {
  Hoehenflaeche(
    List<Punkt> ecken,
    List<Millimeter> hoehen, [
    List<Punkt> weitere = const [],
  ]) : _ecken = [...ecken, ...weitere],
       _hoehen = [for (final h in hoehen) h.mm.toDouble()],
       _dreiecke =
           ecken.length >= 3 &&
               ecken.length + weitere.length == hoehen.length &&
               hoehen.toSet().length > 1
           ? _mitPunkten(_ohrenschnitt(ecken), [
               ...ecken,
               ...weitere,
             ], ecken.length)
           : const [];

  final List<Punkt> _ecken;
  final List<double> _hoehen;
  final List<(int, int, int)> _dreiecke;

  /// Höhe am Punkt [p] in mm (auf ganze mm gerundet).
  Millimeter bei(Punkt p) {
    if (_dreiecke.isEmpty) return Millimeter(_hoehen.first.round());
    // das Dreieck, in dem p am tiefsten liegt (größtes kleinstes Gewicht)
    (double, double, double)? bestes;
    var guete = double.negativeInfinity;
    (int, int, int)? wahl;
    for (final d in _dreiecke) {
      final g = _gewichte(_ecken, p, d);
      final kleinstes = math.min(g.$1, math.min(g.$2, g.$3));
      if (kleinstes > guete) {
        guete = kleinstes;
        bestes = g;
        wahl = d;
      }
    }
    final (g1, g2, g3) = bestes!;
    final (i, j, k) = wahl!;
    return Millimeter(
      (g1 * _hoehen[i] + g2 * _hoehen[j] + g3 * _hoehen[k]).round(),
    );
  }
}

/// Baryzentrische Gewichte von [p] im Dreieck [d] der [punkte].
(double, double, double) _gewichte(
  List<Punkt> punkte,
  Punkt p,
  (int, int, int) d,
) {
  final (a, b, c) = (punkte[d.$1], punkte[d.$2], punkte[d.$3]);
  final flaeche = (b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y);
  final wb = ((p.x - a.x) * (c.y - a.y) - (c.x - a.x) * (p.y - a.y)) / flaeche;
  final wc = ((b.x - a.x) * (p.y - a.y) - (p.x - a.x) * (b.y - a.y)) / flaeche;
  return (1 - wb - wc, wb, wc);
}

/// [dreiecke] der [punkte], geteilt an jedem Punkt ab [ab] (M7-04): ein
/// Dreieck, in dem oder auf dessen Rand der Punkt liegt, wird zu drei
/// Dreiecken mit dem Punkt als Spitze; flache Dreiecke (Punkt auf einer
/// Kante) fallen weg.
List<(int, int, int)> _mitPunkten(
  List<(int, int, int)> dreiecke,
  List<Punkt> punkte,
  int ab,
) {
  var ergebnis = dreiecke;
  for (var m = ab; m < punkte.length; m++) {
    ergebnis = [for (final d in ergebnis) ..._geteilt(punkte, d, m)];
  }
  return ergebnis;
}

/// Das Dreieck [d] geteilt am Punkt [m], wenn er in ihm oder auf seinem
/// Rand liegt (ohne flache Teile); sonst [d] selbst.
List<(int, int, int)> _geteilt(List<Punkt> punkte, (int, int, int) d, int m) {
  final (g1, g2, g3) = _gewichte(punkte, punkte[m], d);
  if (math.min(g1, math.min(g2, g3)) < -_rand) return [d];
  return [
    for (final t in [(d.$1, d.$2, m), (d.$2, d.$3, m), (d.$3, d.$1, m)])
      if (_doppelteFlaeche(punkte, t).abs() > _flach) t,
  ];
}

/// Toleranz der Gewichte für Punkte auf dem Rand eines Dreiecks.
const _rand = 1e-9;

/// Dreiecke mit weniger doppelter Fläche (mm²) gelten als flach.
const _flach = 1e-6;

double _doppelteFlaeche(List<Punkt> p, (int, int, int) d) =>
    (p[d.$2].x - p[d.$1].x) * (p[d.$3].y - p[d.$1].y) -
    (p[d.$3].x - p[d.$1].x) * (p[d.$2].y - p[d.$1].y);

/// Zerlegt das einfache Vieleck [p] in Dreiecke (Ohrenschnitt); die Ecken
/// werden dazu gegen den Uhrzeigersinn umlaufen (positive Fläche).
List<(int, int, int)> _ohrenschnitt(List<Punkt> p) {
  double kreuz(int a, int b, int c) =>
      (p[b].x - p[a].x) * (p[c].y - p[a].y) -
      (p[c].x - p[a].x) * (p[b].y - p[a].y);
  final flaeche = [for (var i = 1; i < p.length - 1; i++) kreuz(0, i, i + 1)]
      .fold(0.0, (a, b) => a + b);
  final rest = [for (var i = 0; i < p.length; i++) i];
  final umlauf = flaeche > 0 ? rest : rest.reversed.toList();
  // auf oder links jeder Kante des Dreiecks (a, b, c)
  bool innen(int q, int a, int b, int c) =>
      kreuz(a, b, q) >= 0 && kreuz(b, c, q) >= 0 && kreuz(c, a, q) >= 0;
  final dreiecke = <(int, int, int)>[];
  // feste Obergrenze: jede Runde schneidet ein Ohr ab (ein einfaches
  // Vieleck hat immer eins)
  for (var runde = 0; runde < p.length && umlauf.length > 3; runde++) {
    final n = umlauf.length;
    final ohr = [
      for (var i = 0; i < n; i++)
        if ((umlauf[(i + n - 1) % n], umlauf[i], umlauf[(i + 1) % n])
            case (final a, final b, final c)
            when kreuz(a, b, c) > 0 &&
                !umlauf.any(
                  (q) => q != a && q != b && q != c && innen(q, a, b, c),
                ))
          (i, (a, b, c)),
    ].firstOrNull;
    if (ohr case (final i, final dreieck)?) {
      dreiecke.add(dreieck);
      umlauf.removeAt(i);
    }
  }
  if (umlauf.length == 3) dreiecke.add((umlauf[0], umlauf[1], umlauf[2]));
  return dreiecke;
}

/// Auflager der UK-Verlegung [verlegung] (M6-11):
///
/// - **Lage:** längs jedes UK-Holzes von Ende zu Ende höchstens [abstand]
///   (`auflagerabstand`, M6-08) auseinander, gleichmäßig verteilt, und an
///   jedem Stoß der UK eins, auf dem beide Enden liegen – F01: 13 Linien à
///   309 cm mit 60 cm → je 7 (91; F28: 91 Bodenanker wie im alten Planer).
/// - **Höhe:** [flaeche] am Auflager minus [aufbauhoehe] ist der Spalt
///   zwischen UK und Boden.
/// - **Normale Terrasse:** je Spalt das Auflager aus den [bereiche]n
///   (`auflagerFuer`, M6-08); die Höhenzuordnung zählt je Bereich, die
///   Materialliste verpackt über die Packungen des Bereichs.
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
  final orte = [
    for (final l in verlegung.linien)
      for (final y in _stellen(l, abstand.mm.toDouble()))
        Punkt(l.x, y).gedreht(drehung),
  ];
  if (orte.isEmpty) return Auflagerbedarf.keiner;
  final spalte = [for (final o in orte) flaeche.bei(o) - aufbauhoehe];
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

/// Stellen der Auflager auf der Linie [l] (y): je Holz zwischen den Enden
/// bzw. Stößen gleichmäßig höchstens [abstand] auseinander, gemeinsame
/// Stellen nur einmal.
List<double> _stellen(UkLinie l, double abstand) {
  final stellen = <double>[];
  for (final (von, bis) in l.abschnitte) {
    final grenzen = [
      von,
      for (final s in l.stoesse)
        if (s > von && s < bis) s,
      bis,
    ];
    stellen.add(von);
    for (var i = 1; i < grenzen.length; i++) {
      final (a, b) = (grenzen[i - 1], grenzen[i]);
      // feste Obergrenze wie bei den Hölzern (`hoechsteFelder`)
      final felder = math.min(
        hoechsteFelder,
        math.max(1, ((b - a) / abstand - 1e-6).ceil()),
      );
      for (var k = 1; k <= felder; k++) {
        stellen.add(a + (b - a) * k / felder);
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
  final wahl = [for (final s in spalte) auflagerFuer(s, bereiche)];
  final zeilen = <Auflagerbereich>[
    for (final b in bereiche)
      if (wahl.contains(b)) b,
  ];
  return Auflagerbedarf(
    punkte: [
      for (final (i, o) in orte.indexed)
        (
          ort: o,
          spalt: spalte[i],
          zeile: switch (wahl[i]) {
            final b? => zeilen.indexOf(b),
            null => null,
          },
        ),
    ],
    zeilen: [
      for (final b in zeilen)
        if ([
              for (final (i, w) in wahl.indexed)
                if (w == b) spalte[i],
            ]
            case final s)
          (titel: b.titel, anzahl: s.length, von: _min(s), bis: _max(s)),
    ],
    bedarf: [
      for (final b in zeilen)
        Materialbedarf(b.einheiten, wahl.where((w) => w == b).length),
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
  return Auflagerbedarf(
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
      for (final MapEntry(key: laenge, value: anzahl) in lieferstuecke(
        [for (final s in stuecke) s.laenge],
        laengen,
        fest: stand.ukLaenge,
      ).entries)
        Materialbedarf([uk], anzahl, laenge: laenge),
      if (anker != null) Materialbedarf([anker], orte.length),
    ],
    stuecke: stuecke,
  );
}

Millimeter _min(List<Millimeter> werte) =>
    Millimeter(werte.map((w) => w.mm).reduce(math.min));

Millimeter _max(List<Millimeter> werte) =>
    Millimeter(werte.map((w) => w.mm).reduce(math.max));
