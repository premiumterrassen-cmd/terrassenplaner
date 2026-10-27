import 'dart:math' as math;

import 'punkt.dart';

/// Größte Abweichung eines Sehnenzugs vom Kreisbogen in Millimetern, mit der
/// Bögen für Mengenoperationen und Abstände angenähert werden (M4-01).
const bogenToleranz = 0.1;

/// Kante einer [Kontur]: Strecke oder Kreisbogen von [start] nach [ende].
///
/// [woelbung] = tan(θ/4) mit dem Mittelpunktswinkel θ des Bogens: 0 ist eine
/// Strecke, > 0 ein Bogen gegen den Uhrzeigersinn, < 0 im Uhrzeigersinn,
/// ±1 ein Halbkreis. Auf einer Kontur gegen den Uhrzeigersinn wölbt ein
/// positiver Wert die Kante nach außen.
final class Kante {
  const Kante(this.start, this.ende, [this.woelbung = 0]);

  final Punkt start;
  final Punkt ende;
  final double woelbung;

  bool get istBogen => woelbung != 0;

  Punkt get sehne => ende - start;

  /// Mittelpunktswinkel θ im Bogenmaß, vorzeichenbehaftet (0 bei Strecken).
  double get winkel => 4 * math.atan(woelbung);

  double get radius => sehne.laenge / (2 * math.sin(winkel / 2)).abs();

  Punkt get mittelpunkt =>
      (start + ende) * 0.5 +
      sehne.links.einheit * (sehne.laenge / 2 / math.tan(winkel / 2));

  double get laenge => istBogen ? radius * winkel.abs() : sehne.laenge;

  /// Fläche zwischen Sehne und Bogen, positiv bei Bögen gegen den
  /// Uhrzeigersinn.
  double get segmentflaeche {
    final r = radius;
    return istBogen ? r * r / 2 * (winkel - math.sin(winkel)) : 0;
  }

  /// Fahrtrichtung am Anfang.
  Punkt get richtungAmStart => sehne.gedreht(-winkel / 2);

  /// Fahrtrichtung am Ende.
  Punkt get richtungAmEnde => sehne.gedreht(winkel / 2);

  /// Punkte des Sehnenzugs ab [start] (ohne [ende]), der höchstens um
  /// [toleranz] vom Bogen abweicht; bei Strecken nur [start].
  List<Punkt> zwischenpunkte(double toleranz) {
    if (!istBogen) return [start];
    final r = radius;
    final schritt = 2 * math.acos(math.max(0, 1 - toleranz / r));
    final anzahl = (winkel.abs() / schritt).ceil();
    final mitte = mittelpunkt;
    return [
      for (var i = 0; i < anzahl; i++)
        start.gedreht(winkel * i / anzahl, mitte),
    ];
  }

  /// Kürzester Abstand von [p] zur Kante.
  double abstand(Punkt p) {
    if (istBogen) {
      final mitte = mittelpunkt;
      return _liegtImBogenwinkel(p, mitte)
          ? (p.abstand(mitte) - radius).abs()
          : math.min(p.abstand(start), p.abstand(ende));
    }
    final s = sehne;
    final t = ((p - start).punktprodukt(s) / s.punktprodukt(s)).clamp(0.0, 1.0);
    return p.abstand(start + s * t);
  }

  bool _liegtImBogenwinkel(Punkt p, Punkt mitte) {
    final w = winkel;
    final ab = (p - mitte).richtung - (start - mitte).richtung;
    return (w > 0 ? ab : -ab) % (2 * math.pi) < w.abs();
  }

  /// Liegt [p] im Kreisabschnitt zwischen Sehne und Bogen?
  bool segmentEnthaelt(Punkt p) =>
      istBogen &&
      p.abstand(mittelpunkt) < radius &&
      (sehne.kreuz(p - start) < 0) == (winkel > 0);

  /// Dieselbe Kante in Gegenrichtung.
  Kante get umgekehrt => Kante(ende, start, -woelbung);
}

/// Geschlossener Linienzug aus Strecken und Kreisbögen (M4-01): Grundriss,
/// Ausschnitt, Teilfläche. Kante `i` führt von `punkte[i]` zu
/// `punkte[i + 1]` (die letzte zurück zum ersten Punkt) mit `woelbungen[i]`.
final class Kontur {
  Kontur(List<Punkt> punkte, {List<double>? woelbungen})
    : punkte = List.unmodifiable(punkte),
      woelbungen = List.unmodifiable(
        woelbungen ?? List<double>.filled(punkte.length, 0),
      ) {
    if (this.woelbungen.length != punkte.length) {
      throw ArgumentError.value(
        this.woelbungen.length,
        'woelbungen',
        'braucht genau eine Wölbung je Punkt',
      );
    }
    if (_vorzeichenbehafteteFlaeche.abs() < geometrieToleranz) {
      throw ArgumentError.value(
        punkte.length,
        'punkte',
        'umschließen keine Fläche',
      );
    }
  }

  /// Rechteck mit Punkt A in [ursprung], gegen den Uhrzeigersinn.
  factory Kontur.rechteck(
    double breite,
    double hoehe, [
    Punkt ursprung = Punkt.ursprung,
  ]) => Kontur([
    ursprung,
    ursprung + Punkt(breite, 0),
    ursprung + Punkt(breite, hoehe),
    ursprung + Punkt(0, hoehe),
  ]);

  /// Kreis aus zwei Halbkreisen, gegen den Uhrzeigersinn.
  factory Kontur.kreis(Punkt mitte, double radius) => Kontur(
    [mitte + Punkt(radius, 0), mitte - Punkt(radius, 0)],
    woelbungen: const [1, 1],
  );

  final List<Punkt> punkte;
  final List<double> woelbungen;

  List<Kante> get kanten => [
    for (var i = 0; i < punkte.length; i++)
      Kante(punkte[i], punkte[(i + 1) % punkte.length], woelbungen[i]),
  ];

  double get _vorzeichenbehafteteFlaeche {
    var summe = 0.0;
    for (final k in kanten) {
      summe += k.start.kreuz(k.ende) / 2 + k.segmentflaeche;
    }
    return summe;
  }

  /// Umschlossene Fläche in mm², unabhängig vom Umlaufsinn.
  double get flaeche => _vorzeichenbehafteteFlaeche.abs();

  bool get gegenUhrzeigersinn => _vorzeichenbehafteteFlaeche > 0;

  double get umfang => kanten.fold(0, (s, k) => s + k.laenge);

  /// Innenwinkel je Punkt in Grad (zwischen den Tangenten der anliegenden
  /// Kanten).
  List<double> get innenwinkel {
    final k = kanten;
    final umlauf = gegenUhrzeigersinn ? 1 : -1;
    return [
      for (var i = 0; i < k.length; i++)
        _grad(
          math.pi - umlauf * _drehung(k[(i + k.length - 1) % k.length], k[i]),
        ),
    ];
  }

  static double _drehung(Kante herein, Kante hinaus) {
    final a = herein.richtungAmEnde;
    final b = hinaus.richtungAmStart;
    return math.atan2(a.kreuz(b), a.punktprodukt(b));
  }

  static double _grad(double bogenmass) => bogenmass * 180 / math.pi;

  /// Liegt [p] im Inneren? Für Punkte auf dem Rand ist das Ergebnis
  /// unbestimmt – dafür [abstandZumRand].
  bool enthaelt(Punkt p) {
    var innen = sehnenzugEnthaelt(punkte, p);
    for (final k in kanten) {
      if (k.segmentEnthaelt(p)) innen = !innen;
    }
    return innen;
  }

  double abstandZumRand(Punkt p) =>
      kanten.fold(double.infinity, (m, k) => math.min(m, k.abstand(p)));

  /// Punkte des Sehnenzugs, der höchstens [toleranz] von den Bögen abweicht.
  List<Punkt> vieleck([double toleranz = bogenToleranz]) => [
    for (final k in kanten) ...k.zwischenpunkte(toleranz),
  ];

  Huellrechteck get huellrechteck => Huellrechteck.um(vieleck());

  Kontur verschoben(Punkt v) =>
      Kontur([for (final p in punkte) p + v], woelbungen: woelbungen);

  /// Um [winkel] (Grad, gegen den Uhrzeigersinn) um [mitte] gedreht.
  Kontur gedreht(double winkel, [Punkt mitte = Punkt.ursprung]) => Kontur([
    for (final p in punkte) p.gedreht(winkel * math.pi / 180, mitte),
  ], woelbungen: woelbungen);

  /// Gleiche Form mit umgekehrtem Umlaufsinn.
  Kontur get umgekehrt {
    final n = punkte.length;
    return Kontur(
      punkte.reversed.toList(),
      woelbungen: [
        for (var i = 0; i < n; i++) -woelbungen[(2 * n - 2 - i) % n],
      ],
    );
  }

  /// Ohne Selbstüberschneidung? (Freiform, M4-08)
  bool get istEinfach {
    final p = vieleck();
    final n = p.length;
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        final benachbart = j == i + 1 || (i == 0 && j == n - 1);
        if (!benachbart &&
            streckenBeruehren(p[i], p[(i + 1) % n], p[j], p[(j + 1) % n])) {
          return false;
        }
      }
    }
    return true;
  }
}

/// Gerade-Ungerade-Regel für einen geschlossenen Sehnenzug.
bool sehnenzugEnthaelt(List<Punkt> zug, Punkt p) {
  var innen = false;
  for (var i = 0, j = zug.length - 1; i < zug.length; j = i++) {
    final a = zug[i], b = zug[j];
    if ((a.y > p.y) != (b.y > p.y) &&
        p.x < a.x + (p.y - a.y) * (b.x - a.x) / (b.y - a.y)) {
      innen = !innen;
    }
  }
  return innen;
}

/// Schneiden oder berühren sich die Strecken a1–a2 und b1–b2?
bool streckenBeruehren(Punkt a1, Punkt a2, Punkt b1, Punkt b2) =>
    streckenAbstand(a1, a2, b1, b2) < geometrieToleranz;

/// Kürzester Abstand zweier Strecken.
double streckenAbstand(Punkt a1, Punkt a2, Punkt b1, Punkt b2) {
  final r = a2 - a1, s = b2 - b1;
  final d1 = r.kreuz(b1 - a1), d2 = r.kreuz(b2 - a1);
  final d3 = s.kreuz(a1 - b1), d4 = s.kreuz(a2 - b1);
  // echte Kreuzung: die Enden liegen jeweils auf verschiedenen Seiten
  if ((d1 > 0) != (d2 > 0) && (d3 > 0) != (d4 > 0)) return 0;
  return [
    Kante(a1, a2).abstand(b1),
    Kante(a1, a2).abstand(b2),
    Kante(b1, b2).abstand(a1),
    Kante(b1, b2).abstand(a2),
  ].reduce(math.min);
}
