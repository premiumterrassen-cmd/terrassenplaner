/// Treppen (M7-05, Fachkonzept 5.1): Teile, Zeichnung und Material.
library;

import 'dart:math' as math;

import '../artikel/artikel.dart';
import '../artikel/einheiten.dart';
import '../artikel/ukauswahl.dart';
import '../ergebnisse/materialliste.dart';
import '../ergebnisse/stueckliste.dart';
import '../geometrie/punkt.dart';
import '../konfiguration/anschlussergebnis.dart';
import '../konfiguration/planungsstand.dart';
import '../konfiguration/treppe.dart';
import 'anschlussregeln.dart';
import 'planungsregeln.dart';
import 'uk_zusatz.dart';
import 'verblendung.dart';

/// Ein Teil der Treppe – das Podest oder eine Stufe – in
/// Treppenkoordinaten (x längs der Seite ab dem Treppenanfang, y nach
/// außen, mm):
///
/// - [umriss] für die Zeichnung,
/// - [auftritte]: Streifen des Auftritts als (Länge, Tiefe); die Dielen
///   laufen längs des Streifens,
/// - [stirnkanten]: Längen der sichtbaren Vorderkanten, dort sitzt die
///   Setzstufe,
/// - [steigung]: Höhe der Setzstufe, [oberkante]: Höhe des Auftritts über
///   dem Boden.
typedef Treppenteil = ({
  List<Punkt> umriss,
  List<(double, double)> auftritte,
  List<double> stirnkanten,
  Millimeter steigung,
  Millimeter oberkante,
});

/// Teile der Treppe [t] von oben nach unten: bei der Fächertreppe zuerst
/// das Podest, dann die Stufen; die reguläre hat nur Stufen. Die Stufen
/// der Fächertreppe laufen als L (2-teilig) oder U (3-teilig) um das
/// Podest (F41, F42).
List<Treppenteil> treppenteile(Treppe t) {
  final masse = t.stufenmasse;
  final (laenge: _, breite: _, hoehe: gesamt) = t.masse;
  // Tiefe bis vor Stufe k (k = 0 … anzahl)
  final bis = [0.0];
  for (final m in masse) {
    bis.add(bis.last + m.tiefe.mm);
  }
  // Oberkante der Stufe k
  var oben = t.art.mitPodest ? gesamt - t.podest.hoehe : gesamt;
  final oberkanten = <Millimeter>[];
  for (final m in masse) {
    oberkanten.add(oben);
    oben = oben - m.hoehe;
  }
  final (pt, pb) = (
    t.podest.tiefe.mm.toDouble(),
    t.podest.breite.mm.toDouble(),
  );
  final s = bis.last;
  Punkt p(double x, double y) => Punkt(x, y);
  return switch (t.art) {
    Treppenart.regulaer => [
      for (var k = 0; k < masse.length; k++)
        (
          umriss: _rechteck(0, bis[k], t.breite.mm.toDouble(), bis[k + 1]),
          auftritte: [(t.breite.mm.toDouble(), masse[k].tiefe.mm.toDouble())],
          stirnkanten: [t.breite.mm.toDouble()],
          steigung: masse[k].hoehe,
          oberkante: oberkanten[k],
        ),
    ],
    Treppenart.zweiteilig => [
      (
        umriss: _rechteck(0, 0, pt, pb),
        auftritte: [(pt, pb)],
        stirnkanten: [pt, pb],
        steigung: t.podest.hoehe,
        oberkante: gesamt,
      ),
      for (var k = 0; k < masse.length; k++)
        (
          umriss: [
            p(0, pb + bis[k]),
            p(pt + bis[k], pb + bis[k]),
            p(pt + bis[k], 0),
            p(pt + bis[k + 1], 0),
            p(pt + bis[k + 1], pb + bis[k + 1]),
            p(0, pb + bis[k + 1]),
          ],
          auftritte: [
            (pt + bis[k + 1], masse[k].tiefe.mm.toDouble()),
            (pb + bis[k], masse[k].tiefe.mm.toDouble()),
          ],
          stirnkanten: [pt + bis[k + 1], pb + bis[k + 1]],
          steigung: masse[k].hoehe,
          oberkante: oberkanten[k],
        ),
    ],
    Treppenart.dreiteilig => [
      (
        umriss: _rechteck(s, 0, s + pt, pb),
        auftritte: [(pt, pb)],
        stirnkanten: [pt, pb, pb],
        steigung: t.podest.hoehe,
        oberkante: gesamt,
      ),
      for (var k = 0; k < masse.length; k++)
        (
          umriss: [
            p(s - bis[k + 1], 0),
            p(s - bis[k], 0),
            p(s - bis[k], pb + bis[k]),
            p(s + pt + bis[k], pb + bis[k]),
            p(s + pt + bis[k], 0),
            p(s + pt + bis[k + 1], 0),
            p(s + pt + bis[k + 1], pb + bis[k + 1]),
            p(s - bis[k + 1], pb + bis[k + 1]),
          ],
          auftritte: [
            (pt + 2 * bis[k + 1], masse[k].tiefe.mm.toDouble()),
            (pb + bis[k], masse[k].tiefe.mm.toDouble()),
            (pb + bis[k], masse[k].tiefe.mm.toDouble()),
          ],
          stirnkanten: [pt + 2 * bis[k + 1], pb + bis[k + 1], pb + bis[k + 1]],
          steigung: masse[k].hoehe,
          oberkante: oberkanten[k],
        ),
    ],
  };
}

List<Punkt> _rechteck(double x0, double y0, double x1, double y1) => [
  Punkt(x0, y0),
  Punkt(x1, y0),
  Punkt(x1, y1),
  Punkt(x0, y1),
];

/// Umrisse der Teile von [t] in Planungskoordinaten: die Treppe beginnt
/// [Treppe.abstand] nach der Ecke ihrer Seite und liegt außen vor ihr.
List<List<Punkt>> treppenumrisse(Planungsstand stand, Treppe t) {
  final (:von, :bis) = seitenstrecke(stand, t.seite);
  final laengs = (bis - von) * (1 / von.abstand(bis));
  final aussen = _aussen(stand, laengs);
  final anfang = von + laengs * t.abstand.mm.toDouble();
  return [
    for (final teil in treppenteile(t))
      [for (final q in teil.umriss) anfang + laengs * q.x + aussen * q.y],
  ];
}

/// Einheitsnormale zur Richtung [laengs], die aus der Fläche zeigt.
Punkt _aussen(Planungsstand stand, Punkt laengs) {
  final links = Punkt(-laengs.y, laengs.x);
  return stand.grundriss.kontur.gegenUhrzeigersinn ? links * -1 : links;
}

/// Ob die Treppe [t] an ihrer Seite liegen darf: nur an freien Seiten –
/// nicht an Bauelementen, nicht mit Rinne; verblendete sind erlaubt
/// (Fachkonzept 5.1).
bool treppeErlaubt(Planungsstand stand, Treppe t) =>
    t.seite < stand.seitenzahl &&
    !stand.anschluss.grenztAn(t.seite) &&
    stand.anschluss.rinneAn(t.seite) == null;

/// Zuschnitte der Treppe [t] (M7-05):
///
/// - **Dielen** des [belag]: je Auftrittsstreifen so viele Reihen in
///   Streifenlänge, wie Dielen samt Fuge die Tiefe brauchen (27 cm, 60 mm →
///   5), je Stirnkante so viele, wie die Steigung in Dielenbreiten braucht
///   (15,6 cm → 3) – F39: 2 × 8 Stück à 100 cm wie im alten Planer.
/// - **UK** ([uk]) unter jedem Auftrittsstreifen quer zu den Dielen im
///   Achsabstand [ukAbstand], an beiden Enden eine, so lang wie die Tiefe;
///   bei der Konstruktion dazu unter jedem UK-Holz eine Stütze an der
///   Vorderkante bis zum Boden (Oberkante minus Dielenstärke minus UK
///   hochkant). Beim Fundament liegt die UK auf der Betontreppe (R-D02).
List<Planstueck> treppenstuecke(
  Treppe t, {
  required Artikel belag,
  Artikel? uk,
  Millimeter? ukAbstand,
}) {
  final (breite, staerke) = (
    belag.abmessungen.breite,
    belag.abmessungen.staerke,
  );
  if (breite == null || staerke == null) return const [];
  final ganzeDiele = belag.abmessungen.laengen.lastOrNull;
  final ukMasse = (uk?.abmessungen.breite, uk?.abmessungen.staerke);
  final ukHoehe = switch (ukMasse) {
    (final a?, final b?) => a > b ? a : b,
    _ => null,
  };
  Planstueck diele(double laenge) {
    final mm = Millimeter(laenge.round());
    return Planstueck(
      belag.nummer,
      belag.titel,
      mm,
      ganzeLaenge: ganzeDiele ?? mm,
    );
  }

  final stuecke = <Planstueck>[];
  for (final teil in treppenteile(t)) {
    for (final (laenge, tiefe) in teil.auftritte) {
      final reihen = ((tiefe + fuge.mm) / (breite + fuge).mm - 1e-9).ceil();
      stuecke.addAll(List.filled(reihen, diele(laenge)));
      if (uk != null && ukAbstand != null && ukHoehe != null) {
        stuecke.addAll(
          _unterbau(t, teil, uk, ukAbstand, laenge, tiefe, staerke + ukHoehe),
        );
      }
    }
    final reihen = (teil.steigung.mm / breite.mm - 1e-9).ceil();
    for (final kante in teil.stirnkanten) {
      stuecke.addAll(List.filled(reihen, diele(kante)));
    }
  }
  return stuecke;
}

/// UK unter einem Auftrittsstreifen [laenge] × [tiefe] des Teils [teil]:
/// Hölzer quer zu den Dielen, bei der Konstruktion je Holz eine Stütze bis
/// zum Boden ([aufbau] = Dielenstärke plus UK hochkant).
List<Planstueck> _unterbau(
  Treppe t,
  Treppenteil teil,
  Artikel uk,
  Millimeter abstand,
  double laenge,
  double tiefe,
  Millimeter aufbau,
) {
  final ganze = ukLieferlaengen(uk);
  Planstueck holz(Millimeter mm) => Planstueck(
    uk.nummer,
    uk.titel,
    mm,
    ganzeLaenge: ganze.isEmpty ? mm : ganze.last,
  );
  final linien = math.max(1, (laenge / abstand.mm - 1e-6).ceil()) + 1;
  final stuetze = teil.oberkante - aufbau;
  return [
    ...List.filled(linien, holz(Millimeter(tiefe.round()))),
    if (t.bau == Treppenbau.konstruktion && stuetze.mm > 0)
      ...List.filled(linien, holz(stuetze)),
  ];
}

/// Treppen der Fläche für Zeichnung und Anzeige (M7-05).
List<Treppenbild> treppenbilder(Planungsstand stand) => [
  for (final t in stand.treppen)
    (
      teile: treppenumrisse(stand, t),
      masse: t.masse,
      frei: treppeErlaubt(stand, t),
    ),
];

/// Material der Treppen an freien Seiten (M7-05, `treppenstuecke`): die
/// Dielen als Lieferstücke des Belags (`lieferstuecke`, eine erzwungene
/// Dielenlänge gilt), die UK-Zuschnitte für `anschlussbedarf`. Treppen an
/// Seiten am Bauelement oder mit Rinne zählen nicht (Hinweis).
Anschlussbedarf treppenbedarf(
  Planungsstand stand, {
  Artikel? belag,
  Artikel? uk,
  Millimeter? ukAbstand,
}) {
  final frei = [
    for (final t in stand.treppen)
      if (treppeErlaubt(stand, t)) t,
  ];
  final meldungen = [
    if (frei.length < stand.treppen.length) Anschlussmeldung.treppeNichtFrei,
  ];
  if (belag == null) return Anschlussbedarf(meldungen: meldungen);
  final stuecke = [
    for (final t in frei)
      ...treppenstuecke(t, belag: belag, uk: uk, ukAbstand: ukAbstand),
  ];
  final dielen = [
    for (final s in stuecke)
      if (s.nummer == belag.nummer) s.laenge,
  ];
  return Anschlussbedarf(
    stuecke: stuecke,
    bedarf: [
      for (final MapEntry(key: laenge, value: anzahl) in lieferstuecke(
        dielen,
        belag.abmessungen.laengen,
        fest: stand.dielenlaenge,
      ).entries)
        Materialbedarf([belag], anzahl, laenge: laenge),
    ],
    meldungen: meldungen,
  );
}
