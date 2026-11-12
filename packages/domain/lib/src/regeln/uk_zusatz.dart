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
import '../geometrie/punkt.dart';
import '../holzart/holzart.dart';
import '../konfiguration/belagverlegung.dart';
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
    List<Lieferdiele> zuschnitt = const [],
  }) : stuecke = List.unmodifiable(stuecke),
       zuschnitt = List.unmodifiable(zuschnitt),
       bedarf = List.unmodifiable(bedarf),
       streben = List.unmodifiable(streben);

  /// Ohne zusätzliches Holz (schwimmende Verlegung).
  static final keiner = Ukzusatz();

  /// Zuschnitte: Rahmen und zweite Lage längs, Querstreben quer (grün).
  final List<Planstueck> stuecke;

  /// Lieferstücke der UK je Lieferlänge.
  final List<Materialbedarf> bedarf;

  /// Welche Schnitte aus welchem Lieferholz kommen (M9-02, `lieferhoelzer`).
  final List<Lieferdiele> zuschnitt;

  /// Querstreben in Planungskoordinaten.
  final List<Strebe> streben;

  /// Reihen der Querstreben (`strebenreihen`); 0 ohne.
  final int reihen;
}

/// Reihen der Querstreben bei einer Ausdehnung [laenge] quer zu den
/// Dielen (längs der UK-Linien) – so viele Querhölzer hat ein Feld zwischen
/// zwei UK-Linien:
///
/// - mit zusätzlichen Querstreben (3.7, M6-06, Aussteifung) die eingegebene
///   Anzahl der Quertraversen oder automatisch so viele, wie in das Raster
///   [querstrebenAbstand] (75 cm, R-C03) passen – sie ersetzen dann die
///   Reihen der Versteifung;
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

/// Raster der Querhölzer längs der UK-Linien bei einer Ausdehnung [laenge]
/// (Planungsregeln Alexander (Planungskern v6, 11.11.2026), Regel 3.7):
/// automatische Querstreben im festen Raster [querstrebenAbstand] (75 cm),
/// eine eingegebene Anzahl und die Versteifung teilen die Ausdehnung durch
/// ihre [strebenreihen]; ohne beides `null`.
double? strebenraster(Planungsstand stand, Millimeter laenge) {
  final reihen = strebenreihen(stand, laenge);
  if (reihen == 0) return null;
  return stand.querstreben && stand.querstrebenReihen == null
      ? querstrebenAbstand.mm.toDouble()
      : laenge.mm / reihen;
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
/// - **Leiterverband** (Aussteifung, `strebenraster`): Querhölzer zwischen
///   benachbarten UK-Linien im Raster längs der Linien, von Feld zu Feld
///   versetzt (`_streben`); ein Querholz ist so lang wie der lichte Abstand
///   der Linien (Achsabstand minus der schmalen Seite der hochkant stehenden
///   UK).
///
/// Die Lieferhölzer rechnet `lieferhoelzer`; eine erzwungene UK-Länge (3.4)
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
  final hoehe = Millimeter(huelle.hoehe.round());
  final reihen = strebenreihen(stand, hoehe);
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
  final raster = strebenraster(stand, hoehe);
  final streben = raster == null
      ? const <Strebe>[]
      : _streben(
          flaeche,
          linien ?? _linien(huelle.min.x, huelle.max.x, ukAbstand),
          math.min(breite.mm, staerke.mm).toDouble(),
          raster,
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
  final zuschnitt = lieferhoelzer(
    [for (final s in stuecke) s.laenge],
    laengen,
    fest: stand.ukLaenge,
  );
  return Ukzusatz(
    stuecke: stuecke,
    zuschnitt: zuschnitt,
    bedarf: ukBedarf(uk, zuschnitt),
    streben: [
      for (final s in streben)
        (von: s.von.gedreht(-drehung), bis: s.bis.gedreht(-drehung)),
    ],
    reihen: reihen,
  );
}

/// Materialbedarf der Lieferhölzer [zuschnitt] der UK [uk] je Lieferlänge
/// (aufsteigend).
List<Materialbedarf> ukBedarf(Artikel uk, List<Lieferdiele> zuschnitt) => [
  for (final MapEntry(key: laenge, value: anzahl) in Dielenliste.aus(
    zuschnitt,
  ).anzahl.entries)
    Materialbedarf([uk], anzahl, laenge: laenge),
];

/// Lieferstücke für die Zuschnitte [stuecke] aus den Lieferlängen
/// [laengen] (aufsteigend), Anzahl je Länge aufsteigend – gezählt aus
/// [lieferhoelzer] (Treppen, Verblendung und Rest-Hölzer, M7).
Map<Millimeter, int> lieferstuecke(
  List<Millimeter> stuecke,
  List<Millimeter> laengen, {
  Millimeter? fest,
}) => Dielenliste.aus(lieferhoelzer(stuecke, laengen, fest: fest)).anzahl;

/// Welche Lieferhölzer für die Zuschnitte [stuecke] aus den Lieferlängen
/// [laengen] (aufsteigend) geschnitten werden (M9-02, UK-Zuschnittplan):
///
/// - Ein Stück über der längsten Lieferlänge wird zuerst gestückelt
///   (`ukStueckelung`, Regel 3.5: ganze Hölzer, Reststück mindestens
///   50 cm).
/// - Lange Stücke (ab der halben kürzesten Lieferlänge) bekommen eigene
///   Hölzer in der kürzesten Lieferlänge, die sie aufnimmt (R-B10): 480 cm
///   → 5000 mm.
/// - Kurze Stücke (Querstreben, Stützen) werden der Größe nach aus
///   gemeinsamen Hölzern geschnitten: zuerst in den Rest eines langen
///   Stücks oder ein angeschnittenes Holz, in das sie passen (wie im alten
///   Planer: F28 309 + 39,9 + 39,9 cm aus 400 cm; Paritätsnachweis M10-01);
///   sonst in ein neues, das so lang ist wie der Rest aller kurzen
///   Stücke (höchstens die längste Lieferlänge) – so wenig Verschnitt wie
///   möglich (R-B11).
///
/// Liefert die UK die Wunschlänge [fest], wird nur sie verwendet. Ohne
/// Lieferlängen keine Hölzer.
List<Lieferdiele> lieferhoelzer(
  List<Millimeter> stuecke,
  List<Millimeter> laengen, {
  Millimeter? fest,
}) {
  final moeglich = laengen.contains(fest) ? [fest!] : laengen;
  if (moeglich.isEmpty) return const [];
  final grenze = moeglich.first.mm / 2;
  final teile = [for (final s in stuecke) ...ukStueckelung(s, moeglich)];
  // lange Stücke zuerst, ihre Reste nehmen kurze auf (M10-01)
  final offen = <({int laenge, List<Millimeter> schnitte, int rest})>[
    for (final s in teile)
      if (s.mm >= grenze)
        if (moeglich.firstWhere((l) => l >= s).mm case final holz)
          (laenge: holz, schnitte: [s], rest: holz - s.mm),
  ];
  final kurz = [
    for (final s in teile)
      if (s.mm < grenze) s.mm,
  ]..sort((a, b) => b.compareTo(a));
  var summe = kurz.fold(0, (a, b) => a + b);
  for (final s in kurz) {
    final i = offen.indexWhere((h) => h.rest >= s);
    if (i >= 0) {
      final h = offen[i];
      offen[i] = (
        laenge: h.laenge,
        schnitte: [...h.schnitte, Millimeter(s)],
        rest: h.rest - s,
      );
    } else {
      final ziel = math.min(summe, moeglich.last.mm);
      final holz = moeglich.firstWhere((l) => l.mm >= ziel).mm;
      offen.add((laenge: holz, schnitte: [Millimeter(s)], rest: holz - s));
    }
    summe -= s;
  }
  return [for (final h in offen) Lieferdiele(Millimeter(h.laenge), h.schnitte)];
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

/// Querhölzer zwischen den UK-Linien [linien] (in der gedrehten
/// [flaeche]) als Leiter im [raster] längs der Linien, von Feld zu Feld
/// versetzt (Planungsregeln Alexander (Planungskern v6, 11.11.2026), Regel
/// 3.7): Je Feld – der Abschnitt der Fläche auf der Mitte zwischen zwei
/// Linien – liegt das erste Querholz ein Viertel Raster (gerade Felder,
/// das erste ist Feld 0) bzw. ein halbes Raster (ungerade) vom Anfang,
/// die weiteren je ein Raster dahinter, das letzte mehr als
/// [_strebeVorEnde] vor dem Ende. Felder unter [_strebeFeld] Länge und die
/// zwei Hölzer einer doppelten UK am Stoß (lichter Abstand unter
/// [mindestStrebe]) bekommen keine. [uk] ist die Breite der UK in der
/// Draufsicht.
List<Strebe> _streben(
  List<Punkt> flaeche,
  List<double> linien,
  double uk,
  double raster,
) => [
  for (var i = 1; i < linien.length; i++)
    if (linien[i] - linien[i - 1] - uk >= mindestStrebe.mm)
      for (final (von, bis) in _spalte(
        flaeche,
        (linien[i - 1] + linien[i]) / 2,
      ))
        if (bis - von >= _strebeFeld)
          for (final y in _rasterstellen(
            von + raster / (i.isOdd ? 4 : 2),
            bis - _strebeVorEnde,
            raster,
          ))
            (
              von: Punkt(linien[i - 1] + uk / 2, y),
              bis: Punkt(linien[i] - uk / 2, y),
            ),
];

/// Stellen ab [anfang] je [raster] auseinander, alle vor [ende].
List<double> _rasterstellen(double anfang, double ende, double raster) {
  final anzahl = math.max(0, ((ende - anfang) / raster).ceil());
  // Zählschleife mit k++ (docs/erkenntnisse/mutation-tests.md)
  return [for (var k = 0; k < anzahl; k++) anfang + k * raster];
}

/// Felder, die kürzer sind (mm), bekommen kein Querholz (Planungskern).
const _strebeFeld = 400.0;

/// Das letzte Querholz eines Felds liegt mehr als so weit (mm) vor seinem
/// Ende (Planungskern).
const _strebeVorEnde = 100.0;

/// Abschnitte (von, bis) in y, in denen die senkrechte Linie bei [x] in der
/// [flaeche] liegt.
List<(double, double)> _spalte(List<Punkt> flaeche, double x) {
  final ys = [
    for (final (a, b) in _kanten(flaeche))
      if ((a.x <= x) != (b.x <= x)) a.y + (x - a.x) * (b.y - a.y) / (b.x - a.x),
  ]..sort();
  // Zählschleife mit i++ (docs/erkenntnisse/mutation-tests.md)
  return [for (var i = 0; i < ys.length ~/ 2; i++) (ys[2 * i], ys[2 * i + 1])];
}
