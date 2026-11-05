/// Berechnung der UK-Verlegung (M6-10, Fachkonzept 3.11): Lage der
/// UK-Hölzer quer zu den Dielen, doppelte UK an den Stößen der Dielen,
/// Randabstand, Stöße der UK, Längsverbinder, Farben im Plan, Stückliste
/// und Lieferstücke.
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
import '../konfiguration/ausschnitt.dart';
import '../konfiguration/belagverlegung.dart';
import '../konfiguration/dielenverlegung.dart';
import '../konfiguration/planungsstand.dart';
import 'regelwerk.dart';
import 'uk_zusatz.dart';

/// Ein UK-Holz in der Zeichnung: Achse von [von] bis [bis] in mm und seine
/// Farbe wie in der Stückliste (M9-04).
typedef UkHolz = ({Punkt von, Punkt bis, Stueckfarbe farbe});

/// Eine UK-Linie in der gedrehten Fläche (Dielen längs x): Lage [x] ihrer
/// Achse, die Abschnitte (von, bis) in y, in denen sie unter dem Belag
/// liegt, und die Stöße ihrer Hölzer ([stoesse], y).
typedef UkLinie = ({
  double x,
  List<(double, double)> abschnitte,
  List<double> stoesse,
});

/// UK-Verlegung einer Fläche (M6-10).
final class UkVerlegung {
  UkVerlegung({
    List<UkLinie> linien = const [],
    List<Planstueck> stuecke = const [],
    List<Materialbedarf> bedarf = const [],
    List<UkHolz> hoelzer = const [],
    List<Lieferdiele> zuschnitt = const [],
    this.breite = const Millimeter(0),
    this.winkel = 0,
  }) : linien = List.unmodifiable(linien),
       zuschnitt = List.unmodifiable(zuschnitt),
       stuecke = List.unmodifiable(stuecke),
       bedarf = List.unmodifiable(bedarf),
       hoelzer = List.unmodifiable(hoelzer);

  /// Ohne UK.
  static final keine = UkVerlegung();

  /// Linien in der gedrehten Fläche, nach x aufsteigend.
  final List<UkLinie> linien;

  /// Zuschnitte der UK-Hölzer für die Stückliste: rot in ganzer
  /// Lieferlänge, sonst blau.
  final List<Planstueck> stuecke;

  /// Lieferstücke je Lieferlänge und Längsverbinder für die Materialliste.
  final List<Materialbedarf> bedarf;

  /// Welche Stücke aus welchem Lieferholz kommen (M9-02, `lieferhoelzer`).
  final List<Lieferdiele> zuschnitt;

  /// UK-Hölzer in Planungskoordinaten für die Zeichnung.
  final List<UkHolz> hoelzer;

  /// Breite der UK in der Draufsicht: die schmale Seite, gedreht die
  /// breite (B-034).
  final Millimeter breite;

  /// Winkel der Dielen in Grad: um ihn ist die Fläche der [linien] gedreht.
  final double winkel;

  /// Lage der Linien (x in der gedrehten Fläche) – für Befestigung und
  /// Querstreben.
  List<double> get lagen => [for (final l in linien) l.x];

  /// Anzahl der Stöße aller UK-Linien.
  int get stossanzahl => linien.fold(0, (n, l) => n + l.stoesse.length);
}

/// Legt die UK [uk] für [stand] (M6-10):
///
/// - **Lage:** quer zu den Dielen, höchstens [abstand] (wirksame
///   Feldbreite, M6-09) auseinander und gleichmäßig verteilt; die äußeren
///   Hölzer liegen bündig am Rand (B-096: keine Dielenüberstände, UK bis
///   an den Rand).
/// - **Doppelte UK an den Stößen der Dielen:** wo Dielen einer Reihe
///   aneinanderstoßen ([dielen]), liegt je ein Holz links und rechts des
///   Stoßes – jedes Dielenende liegt auf (wie im alten Planer, Referenzfälle
///   2026-05-03-4381, 2026-07-07-2794). Nahe Stöße (unter dem halben
///   Abstand) teilen sich ein Paar.
/// - **Abschnitte:** jede Linie liegt nur, wo Belag ist – in der Fläche ohne
///   leere Ausschnitte (Fachkonzept 1.4).
/// - **Stöße der UK und Lieferlängen:** ein Abschnitt bekommt Hölzer wie
///   eine Dielenreihe (`lieferlaengenFuer`, R-B10: kürzeste Länge, die ihn
///   abdeckt, längere gestückelt; 1000 cm → 600 + 400 cm wie 2026-07-07);
///   eine erzwungene UK-Länge (3.4, M6-03) gilt. Die Lieferstücke rechnet
///   `lieferhoelzer` (kurze Reste aus gemeinsamen Hölzern).
/// - **Längsverbinder:** je Stoß einer aus den Längsverbindern der UK im
///   [regelwerk] (Spalte „mögliche Längsverbinder“), wenn es welche gibt –
///   Robinien-UK haben keine.
/// - [gedreht]: die UK liegt flach (M6-02, B-034) – in der Draufsicht ist
///   sie dann so breit wie ihre breite Seite.
UkVerlegung ukVerlegung(
  Planungsstand stand,
  Artikel uk, {
  required Millimeter abstand,
  List<Dielenstueck> dielen = const [],
  bool gedreht = false,
  Regelwerk? regelwerk,
}) {
  final (a, b) = (uk.abmessungen.breite, uk.abmessungen.staerke);
  if (a == null || b == null) return UkVerlegung.keine;
  final breite = Millimeter(
    gedreht ? math.max(a.mm, b.mm) : math.min(a.mm, b.mm),
  );
  final winkel = stand.dielenwinkel.toDouble();
  final drehung = -winkel * math.pi / 180;
  List<Punkt> gedrehte(Kontur k) => [
    for (final p in k.vieleck()) p.gedreht(drehung),
  ];
  final flaeche = gedrehte(stand.kontur);
  final aussparungen = [
    for (final s in stand.ausschnitte)
      if (s.funktion == Ausschnittfunktion.leer) gedrehte(s.kontur),
  ];
  final huelle = Huellrechteck.um(flaeche);
  final w = breite.mm.toDouble();
  final lagen = _lagen(
    [
      huelle.min.x,
      ..._dielenstoesse(dielen, drehung, abstand.mm / 2, huelle, w),
      huelle.max.x,
    ],
    w,
    abstand.mm.toDouble(),
  );
  final laengen = ukLieferlaengen(uk);
  final linien = <UkLinie>[];
  final stuecke = <Planstueck>[];
  final hoelzer = <UkHolz>[];
  for (final x in lagen) {
    final abschnitte = _ohne(_schnitte(flaeche, x), [
      for (final s in aussparungen) ..._schnitte(s, x),
    ]);
    final stoesse = <double>[];
    for (final (von, bis) in abschnitte) {
      var y = von;
      final teile = _teile(bis - von, laengen, stand.ukLaenge);
      for (final (i, laenge) in teile.indexed) {
        final stueck = Planstueck(
          uk.nummer,
          uk.titel,
          Millimeter(laenge.round()),
          ganzeLaenge: laengen.isEmpty
              ? Millimeter(laenge.round())
              : laengen.last,
        );
        stuecke.add(stueck);
        hoelzer.add((
          von: Punkt(x, y).gedreht(-drehung),
          bis: Punkt(x, y + laenge).gedreht(-drehung),
          farbe: stueck.farbe,
        ));
        y += laenge;
        if (i < teile.length - 1) stoesse.add(y);
      }
    }
    linien.add((x: x, abschnitte: abschnitte, stoesse: stoesse));
  }
  final stossanzahl = linien.fold(0, (n, l) => n + l.stoesse.length);
  final verbinder = regelwerk?.datei[uk.nummer] == null
      ? const <Artikel>[]
      : regelwerk!.moeglich(uk.nummer, Beziehung.laengsverbinder);
  final zuschnitt = lieferhoelzer(
    [for (final s in stuecke) s.laenge],
    laengen,
    fest: stand.ukLaenge,
  );
  return UkVerlegung(
    linien: linien,
    stuecke: stuecke,
    zuschnitt: zuschnitt,
    bedarf: [
      ...ukBedarf(uk, zuschnitt),
      if (verbinder.isNotEmpty && stossanzahl > 0)
        Materialbedarf(verbinder, stossanzahl),
    ],
    hoelzer: hoelzer,
    breite: breite,
    winkel: winkel,
  );
}

/// Höchstens so viele Felder zwischen zwei Grenzen (Rand oder Stoß):
/// 100 m bei 10 cm Feldbreite.
const hoechsteFelder = 1000;

/// Ein Dielenende und der Anfang der nächsten Diele derselben Reihe liegen
/// höchstens so weit (mm) auseinander: Fuge plus Rundung.
const _stossLuecke = 10.0;

/// Abschnitte unter dieser Länge (mm) bekommen kein Holz – etwa ein
/// Streifen zwischen Rand und Ausschnitt.
const _mindestAbschnitt = 10.0;

/// Stöße der [dielen] in x der gedrehten Fläche: Mitte zwischen dem Ende
/// eines Stücks und dem Anfang des nächsten derselben Reihe. Stöße näher
/// als [naehe] werden zusammengefasst (Mittelwert); Stöße am Rand (näher
/// als die UK-Breite [w]) zählen nicht.
List<double> _dielenstoesse(
  List<Dielenstueck> dielen,
  double drehung,
  double naehe,
  Huellrechteck huelle,
  double w,
) {
  final reihen = <int, List<(double, double)>>{};
  for (final d in dielen) {
    final xs = [for (final p in d.umriss) p.gedreht(drehung).x];
    reihen.putIfAbsent(d.reihe, () => []).add((
      xs.reduce(math.min),
      xs.reduce(math.max),
    ));
  }
  final stoesse = <double>[];
  for (final stuecke in reihen.values) {
    stuecke.sort((a, b) => a.$1.compareTo(b.$1));
    for (var i = 1; i < stuecke.length; i++) {
      final (ende, anfang) = (stuecke[i - 1].$2, stuecke[i].$1);
      final mitte = (ende + anfang) / 2;
      if ((anfang - ende).abs() <= _stossLuecke &&
          mitte > huelle.min.x + w &&
          mitte < huelle.max.x - w) {
        stoesse.add(mitte);
      }
    }
  }
  stoesse.sort();
  final gruppen = <List<double>>[];
  for (final s in stoesse) {
    if (gruppen.isNotEmpty && s - gruppen.last.last < naehe) {
      gruppen.last.add(s);
    } else {
      gruppen.add([s]);
    }
  }
  return [for (final g in gruppen) g.reduce((a, b) => a + b) / g.length];
}

/// Achsen der UK-Hölzer zwischen den [grenzen] (Rand, Stöße, Rand): je Feld
/// bündig an beiden Grenzen (Achse eine halbe Breite [w] innen) und
/// dazwischen gleichmäßig höchstens [abstand] auseinander. Ein Feld ist
/// mindestens den halben Abstand breit (Grundriss ab 50 cm, nahe Stöße
/// zusammengefasst), also breiter als ein Holz.
List<double> _lagen(List<double> grenzen, double w, double abstand) {
  final lagen = <double>[];
  for (var i = 1; i < grenzen.length; i++) {
    final links = grenzen[i - 1] + w / 2;
    final rechts = grenzen[i] - w / 2;
    // feste Obergrenze: ein Fehler im Abstand darf nicht endlos rechnen
    final felder = math.min(
      hoechsteFelder,
      math.max(1, ((rechts - links) / abstand - 1e-6).ceil()),
    );
    for (var k = 0; k <= felder; k++) {
      lagen.add(links + (rechts - links) * k / felder);
    }
  }
  return lagen;
}

/// Abschnitte (von, bis) in y, in denen die senkrechte Linie bei [x] im
/// Vieleck [p] liegt.
List<(double, double)> _schnitte(List<Punkt> p, double x) {
  final ys = [
    for (final (i, a) in p.indexed)
      if (p[(i + 1) % p.length] case final b when (a.x <= x) != (b.x <= x))
        a.y + (x - a.x) * (b.y - a.y) / (b.x - a.x),
  ]..sort();
  // Zählschleife mit i++: ein Mutant „i += 2 → i = 2“ liefe endlos
  // (docs/erkenntnisse/mutation-tests.md)
  return [for (var i = 0; i < ys.length ~/ 2; i++) (ys[2 * i], ys[2 * i + 1])];
}

/// [abschnitte] ohne die [luecken]; zu kurze Reste fallen weg.
List<(double, double)> _ohne(
  List<(double, double)> abschnitte,
  List<(double, double)> luecken,
) {
  var rest = abschnitte;
  for (final (lv, lb) in luecken) {
    rest = [
      for (final (von, bis) in rest)
        if (lb <= von || lv >= bis)
          (von, bis)
        else ...[
          if (lv > von) (von, lv),
          if (lb < bis) (lb, bis),
        ],
    ];
  }
  return [
    for (final (von, bis) in rest)
      if (bis - von >= _mindestAbschnitt) (von, bis),
  ];
}

/// Zuschnitte eines Abschnitts der Länge [laenge]: ganze Lieferlängen und
/// der Rest (`lieferlaengenFuer`, mit erzwungener Länge [fest]); ohne
/// Lieferlängen ein Stück.
List<double> _teile(double laenge, List<Millimeter> laengen, Millimeter? fest) {
  final lieferung = lieferlaengenFuer(
    Millimeter(laenge.round()),
    laengen,
    fest: fest,
  );
  if (lieferung.length < 2) return [laenge];
  final ganze = [
    for (final l in lieferung.take(lieferung.length - 1)) l.mm.toDouble(),
  ];
  return [...ganze, laenge - ganze.fold(0.0, (a, b) => a + b)];
}
