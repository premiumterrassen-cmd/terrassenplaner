/// Zusätzliches UK-Holz der Konstruktion (M6-05, Fachkonzept 3.6): Rahmen,
/// zweite Lage (Lattenkreuz) und Leiterverband aus Querstreben – je nach Art
/// der Terrassennutzung und Art der Terrasse (Hochterrasse: immer zwei
/// Lagen, Fachkonzept 3.1).
///
/// Die Querstreben liegen zwischen den UK-Hölzern der UK-Verlegung (M6-10,
/// `UkVerlegung.lagen`); ohne sie (keine Dielen) gleichmäßig über die
/// Ausdehnung der Fläche, höchstens im UK-Achsabstand auseinander, die
/// äußeren am Rand. Das Holz hier kommt zu den UK-Hölzern hinzu.
library;

import 'dart:math' as math;

import '../artikel/artikel.dart';
import '../artikel/dielenlaenge.dart';
import '../artikel/einheiten.dart';
import '../artikel/ukauswahl.dart';
import '../ergebnisse/materialliste.dart';
import '../ergebnisse/stueckliste.dart';
import '../geometrie/kontur.dart';
import '../geometrie/punkt.dart';
import '../holzart/holzart.dart';
import '../konfiguration/planungsstand.dart';
import 'planungsregeln.dart';

/// Eine Querstrebe in der Zeichnung: von [von] bis [bis] in mm.
typedef Strebe = ({Punkt von, Punkt bis});

/// Zusätzliches UK-Holz einer Fläche: Zuschnitte für die Stückliste (M9-04),
/// Lieferstücke für die Materialliste (M9-03) und die Querstreben für die
/// Zeichnung.
final class Ukzusatz {
  Ukzusatz({
    List<Planstueck> stuecke = const [],
    List<Materialbedarf> bedarf = const [],
    List<Strebe> streben = const [],
    this.reihen = 0,
  }) : stuecke = List.unmodifiable(stuecke),
       bedarf = List.unmodifiable(bedarf),
       streben = List.unmodifiable(streben);

  /// Ohne zusätzliches Holz (schwimmende Verlegung).
  static final keiner = Ukzusatz();

  /// Zuschnitte: Rahmen und zweite Lage längs, Querstreben quer (grün).
  final List<Planstueck> stuecke;

  /// Lieferstücke der UK je Lieferlänge.
  final List<Materialbedarf> bedarf;

  /// Querstreben in Planungskoordinaten.
  final List<Strebe> streben;

  /// Reihen der Querstreben (`strebenreihen`); 0 ohne.
  final int reihen;
}

/// Reihen der Querstreben bei einer Ausdehnung [laenge] quer zu den
/// Dielen (längs der UK-Linien):
///
/// - mit zusätzlichen Querstreben (3.7, M6-06) die eingegebene Anzahl der
///   Quertraversen oder automatisch so viele, dass sie höchstens
///   [querstrebenAbstand] (60 cm, R-C03) auseinander liegen – sie ersetzen
///   dann die Reihen der Versteifung;
/// - sonst bei Versteifung (3.6, M6-05) höchstens [versteifungsAbstand];
/// - jeweils mindestens eine Reihe, ohne beides keine.
int strebenreihen(Planungsstand stand, Millimeter laenge) {
  final abstand = stand.querstreben
      ? querstrebenAbstand
      : stand.wirksameNutzungsart?.versteift ?? false
      ? versteifungsAbstand
      : null;
  if (abstand == null) return 0;
  if (stand.querstreben && stand.querstrebenReihen != null) {
    return stand.querstrebenReihen!;
  }
  return math.max(1, _felder(laenge.mm.toDouble(), abstand) - 1);
}

/// Zusätzliches Holz der UK [uk] für [stand] mit dem UK-Achsabstand
/// [ukAbstand]:
///
/// - **Rahmen** (Rahmen, Versteifung mit Rahmen): je Kante der Fläche, die
///   nicht parallel zu den UK-Linien läuft, ein Rahmenholz in ihrer Länge –
///   beim Rechteck 480 × 309 cm zwei à 480 cm (F32: 2 × 5000 mm). Kanten
///   parallel zu den UK-Linien deckt die äußere UK-Linie.
/// - **Zweite Lage** (doppelte UK, Hochterrasse): Hölzer parallel zu den
///   Dielen unter der ersten Lage im selben Achsabstand (F34, F28: 9 × 480
///   cm → 9 × 5000 mm).
/// - **Leiterverband** (Versteifung, `strebenreihen`): Querstreben zwischen
///   benachbarten UK-Linien in Reihen quer zu ihnen; eine Strebe ist so lang
///   wie der lichte Abstand der Linien (Achsabstand minus der schmalen Seite
///   der hochkant stehenden UK).
///
/// Die Lieferlängen rechnet `lieferstuecke`; eine erzwungene UK-Länge (3.4)
/// gilt auch hier. [linien] sind die Lagen der UK-Hölzer in der gedrehten
/// Fläche (M6-10); zwischen den beiden Hölzern einer doppelten UK am Stoß
/// (lichter Abstand unter [mindestStrebe]) gibt es keine Strebe.
Ukzusatz ukZusatz(
  Planungsstand stand,
  Artikel uk, {
  required Millimeter ukAbstand,
  List<double>? linien,
}) {
  final (breite, staerke) = (uk.abmessungen.breite, uk.abmessungen.staerke);
  final rahmen = stand.wirksameNutzungsart?.mitRahmen ?? false;
  if (breite == null || staerke == null) return Ukzusatz.keiner;
  final drehung = -stand.dielenwinkel * math.pi / 180;
  final flaeche = [for (final p in stand.kontur.vieleck()) p.gedreht(drehung)];
  final huelle = Huellrechteck.um(flaeche);
  final reihen = strebenreihen(stand, Millimeter(huelle.hoehe.round()));
  if (!rahmen && !stand.doppelteUk && reihen == 0) return Ukzusatz.keiner;
  final laengs = [
    if (rahmen)
      for (final (a, b) in _kanten(flaeche))
        if ((b.x - a.x).abs() > _parallel) a.abstand(b),
    if (stand.doppelteUk)
      for (final y in _linien(huelle.min.y, huelle.max.y, ukAbstand))
        ..._abschnitte(
          flaeche,
          y.clamp(huelle.min.y + _innen, huelle.max.y - _innen),
        ),
  ];
  final streben = _streben(
    flaeche,
    huelle,
    linien ?? _linien(huelle.min.x, huelle.max.x, ukAbstand),
    math.min(breite.mm, staerke.mm).toDouble(),
    reihen,
  );
  final laengen = ukLieferlaengen(uk);
  Planstueck stueck(double laenge, Stuecklage lage) => Planstueck(
    uk.nummer,
    uk.titel,
    Millimeter(laenge.round()),
    ganzeLaenge: laengen.last,
    lage: lage,
  );
  final stuecke = [
    for (final l in laengs) stueck(l, Stuecklage.laengs),
    for (final s in streben) stueck(s.von.abstand(s.bis), Stuecklage.quer),
  ];
  final lieferung = lieferstuecke(
    [for (final s in stuecke) s.laenge],
    laengen,
    fest: stand.ukLaenge,
  );
  return Ukzusatz(
    stuecke: stuecke,
    bedarf: [
      for (final MapEntry(key: laenge, value: anzahl) in lieferung.entries)
        Materialbedarf([uk], anzahl, laenge: laenge),
    ],
    streben: [
      for (final s in streben)
        (von: s.von.gedreht(-drehung), bis: s.bis.gedreht(-drehung)),
    ],
    reihen: reihen,
  );
}

/// Lieferstücke für die Zuschnitte [stuecke] aus den Lieferlängen
/// [laengen] (aufsteigend), Anzahl je Länge aufsteigend sortiert.
///
/// - Lange Stücke (ab der halben kürzesten Lieferlänge) bekommen eigene
///   Hölzer wie eine Dielenreihe (R-B10, `lieferlaengenFuer`): 480 cm →
///   5000 mm.
/// - Kurze Stücke (Querstreben) werden der Größe nach aus gemeinsamen
///   Hölzern geschnitten: zuerst in ein angeschnittenes Holz, in das sie
///   passen; sonst in ein neues, das so lang ist wie der Rest aller kurzen
///   Stücke (höchstens die längste Lieferlänge) – so wenig Verschnitt wie
///   möglich (R-B11).
///
/// Liefert die UK die Wunschlänge [fest], wird nur sie verwendet.
Map<Millimeter, int> lieferstuecke(
  List<Millimeter> stuecke,
  List<Millimeter> laengen, {
  Millimeter? fest,
}) {
  final moeglich = laengen.contains(fest) ? [fest!] : laengen;
  final anzahl = <Millimeter, int>{};
  void liefere(Millimeter l) =>
      anzahl.update(l, (n) => n + 1, ifAbsent: () => 1);
  if (moeglich.isEmpty) return anzahl;
  final grenze = moeglich.first.mm / 2;
  final kurz = [
    for (final s in stuecke)
      if (s.mm < grenze) s.mm,
  ]..sort((a, b) => b.compareTo(a));
  for (final s in stuecke) {
    if (s.mm >= grenze) lieferlaengenFuer(s, moeglich).forEach(liefere);
  }
  final reste = <int>[];
  var offen = kurz.fold(0, (a, b) => a + b);
  for (final s in kurz) {
    final i = reste.indexWhere((r) => r >= s);
    if (i >= 0) {
      reste[i] -= s;
    } else {
      final ziel = math.min(offen, moeglich.last.mm);
      final holz = moeglich.firstWhere((l) => l.mm >= ziel);
      liefere(holz);
      reste.add(holz.mm - s);
    }
    offen -= s;
  }
  return Map.fromEntries(
    anzahl.entries.toList()..sort((a, b) => a.key.mm.compareTo(b.key.mm)),
  );
}

/// Lieferstücke für weitere kurze Zuschnitte [kurz] (z. B. Blendenhalter,
/// M7-02), die zuerst aus den Resten der Hölzer schon verlegter Zuschnitte
/// [vorhanden] geschnitten werden (R-B11, F37: 31 Blendenhalter à 8,6 cm
/// aus den Resten von 13 × 4000 mm für 309 cm). Reste haben nur lange
/// Zuschnitte mit eigenem Holz (`lieferstuecke`); was nicht hineinpasst,
/// bekommt neue Hölzer wie bei `lieferstuecke`.
Map<Millimeter, int> zusaetzlicheLieferstuecke(
  List<Millimeter> kurz,
  List<Millimeter> vorhanden,
  List<Millimeter> laengen, {
  Millimeter? fest,
}) {
  final moeglich = laengen.contains(fest) ? [fest!] : laengen;
  final reste = [
    for (final s in vorhanden)
      if (moeglich.isNotEmpty && s.mm >= moeglich.first.mm / 2)
        if (lieferlaengenFuer(s, moeglich) case [final holz]) holz.mm - s.mm,
  ];
  final uebrig = <Millimeter>[];
  for (final s in [...kurz]..sort((a, b) => b.mm.compareTo(a.mm))) {
    final i = reste.indexWhere((r) => r >= s.mm);
    if (i >= 0) {
      reste[i] -= s.mm;
    } else {
      uebrig.add(s);
    }
  }
  return lieferstuecke(uebrig, laengen, fest: fest);
}

/// UK-Achsabstand für einen Belag der [holzart]: der des Belags laut
/// Artikeldaten ([artikel]), höchstens der der Holzart (R-C01).
Millimeter ukAbstandFuer(Holzart holzart, Millimeter? artikel) =>
    artikel != null && artikel < holzart.ukAchsabstandMax
    ? artikel
    : holzart.ukAchsabstandMax;

/// Kürzeste Querstrebe: darunter liegen zwei UK-Hölzer als doppelte UK am
/// Stoß der Dielen nebeneinander (M6-10).
const mindestStrebe = Millimeter(100);

/// Kanten mit weniger Versatz quer (mm) gelten als parallel zu den UK-Linien.
const _parallel = 1.0;

/// Linien am Rand der Fläche werden so weit nach innen gelegt (mm), damit
/// sie die Fläche sicher schneiden.
const _innen = 0.5;

int _felder(double laenge, Millimeter abstand) =>
    math.max(1, (laenge / abstand.mm - 1e-6).ceil());

/// Lage der Linien von [von] bis [bis], höchstens [abstand] auseinander, die
/// äußeren am Rand.
List<double> _linien(double von, double bis, Millimeter abstand) {
  final felder = _felder(bis - von, abstand);
  return [for (var k = 0; k <= felder; k++) von + (bis - von) * k / felder];
}

/// Kanten des geschlossenen Linienzugs [p], jede vom Punkt zum nächsten.
List<(Punkt, Punkt)> _kanten(List<Punkt> p) => [
  for (final (i, a) in p.indexed) (a, i + 1 < p.length ? p[i + 1] : p.first),
];

/// Längen der Abschnitte, in denen die waagrechte Linie bei [y] in der
/// [flaeche] liegt.
List<double> _abschnitte(List<Punkt> flaeche, double y) {
  final xs = [
    for (final (a, b) in _kanten(flaeche))
      if ((a.y <= y) != (b.y <= y)) a.x + (y - a.y) * (b.x - a.x) / (b.y - a.y),
  ]..sort();
  // Zählschleife mit i++: ein Mutant „i += 2 → i = 2“ liefe endlos
  // (docs/erkenntnisse/mutation-tests.md)
  return [for (var i = 0; i < xs.length ~/ 2; i++) xs[2 * i + 1] - xs[2 * i]];
}

/// Querstreben in [reihen] gleichmäßig verteilten Reihen zwischen den
/// UK-Linien [linien] (in der gedrehten [flaeche]); eine Strebe gibt es nur,
/// wo ihre Mitte in der Fläche liegt. [uk] ist die Breite der UK in der
/// Draufsicht.
List<Strebe> _streben(
  List<Punkt> flaeche,
  Huellrechteck huelle,
  List<double> linien,
  double uk,
  int reihen,
) => [
  for (var r = 1; r <= reihen; r++)
    for (var i = 1; i < linien.length; i++)
      if (huelle.min.y + huelle.hoehe * r / (reihen + 1) case final y
          when linien[i] - linien[i - 1] - uk >= mindestStrebe.mm &&
              sehnenzugEnthaelt(
                flaeche,
                Punkt((linien[i - 1] + linien[i]) / 2, y),
              ))
        (
          von: Punkt(linien[i - 1] + uk / 2, y),
          bis: Punkt(linien[i] - uk / 2, y),
        ),
];
