/// MASSIV-Systemdielen im Längenmix (Planungsregeln Alexander
/// (Planungskern v3–v13), Abschnitt 1a, B-036, B-232): Endlosverlegung aus
/// 0,8 / 1,2 / 1,6 / 2,0 m, jeder Stoß mittig auf einer UK im Raster ab dem
/// Rand.
library;

import '../artikel/einheiten.dart';

/// UK-Raster der MASSIV-Systemdielen ab dem Rand (B-232, Regel 1a.4): Rand-UK
/// bündig, dann alle 40 cm vom Rand gemessen (erstes Achsmaß 38 cm bei
/// 40 mm UK) – jeder Stoß liegt mittig auf einer dieser UK.
const laengenmixRaster = Millimeter(400);

/// Raster der Stöße und UK für eine gewählte Feldbreite (M6-09): die
/// [feldbreite], wenn sie kleiner als [laengenmixRaster] ist, sonst 40 cm
/// (Frage 102 in Fachkonzept 10).
Millimeter laengenmixRasterFuer(Millimeter? feldbreite) =>
    feldbreite != null && feldbreite < laengenmixRaster
    ? feldbreite
    : laengenmixRaster;

/// Kürzestes Stück am Anfang und am Ende einer Reihe (Regel 1a.3: das
/// letzte Stück je Reihe mindestens 30 cm).
const laengenmixMindeststueck = Millimeter(300);

/// So viel länger als seine Lieferlänge darf das letzte Stück einer Reihe
/// sein (Kern: Lieferlänge ≥ Stück − 0,5 cm) – auch die Toleranz, mit der
/// eine Reihe als „passt in ein Stück“ gilt.
const laengenmixToleranz = Millimeter(5);

/// Reihenfolge, in der der Längenmix die Lieferlängen bei Gleichstand
/// anbietet (Kern v13: 2,0 / 1,2 / 1,6 / 0,8 m).
const laengenmixFolge = [
  Millimeter(2000),
  Millimeter(1200),
  Millimeter(1600),
  Millimeter(800),
];

/// Längenmix einer Verlegung: die [laengen] des Mixes, das [raster] und
/// der Anfang des Rasters in Verlegerichtung (`null` = Rand der Fläche).
typedef Laengenmix = ({
  List<Millimeter> laengen,
  Millimeter raster,
  double? anfang,
});

/// Wählt die Stöße der Dielenreihen – im Verband (`Verbandwahl`) oder im
/// Längenmix ([Laengenmixwahl]). Die Reihen werden in ihrer Reihenfolge
/// abgefragt.
abstract interface class Stosswahl {
  /// Stöße der Reihe [reihe] je Abschnitt in [abschnitte] (von, bis in
  /// Verlegerichtung), in derselben Reihenfolge.
  List<List<Millimeter>> stoesse(
    int reihe,
    List<(Millimeter, Millimeter)> abschnitte,
  );
}

/// Längenmix einer Teilfläche (Regel 1a.3, B-232; Kern `flaecheRechnen`,
/// `diele.mix`):
///
/// - Jede Reihe wird vom Anfang ihres Abschnitts aus belegt. Passt der Rest
///   in die längste Lieferlänge (samt [laengenmixToleranz]), ist er das
///   letzte Stück.
/// - Sonst endet das Stück auf der Rasterlinie ([raster] ab [anfang], dem
///   Rand der Fläche) bei oder vor Anfang plus einer Lieferlänge. Die Länge
///   wählt ein fairer Mix: die bisher am wenigsten gelegte zuerst, mit einer
///   festen Zufallsfolge (gleiche Fläche, gleiche Planung) und bei
///   Gleichstand in der Folge [laengenmixFolge].
/// - Das Stück und der Rest der Reihe sind mindestens
///   [laengenmixMindeststueck] lang; der Stoß liegt nicht neben einem Stoß
///   der Vorreihe und möglichst auch nicht der Reihe davor (erst beide
///   Reihen, dann nur die Vorreihe, dann ohne).
final class Laengenmixwahl implements Stosswahl {
  Laengenmixwahl(
    List<Millimeter> laengen, {
    required this.anfang,
    this.raster = laengenmixRaster,
  }) : laengen = [
         for (final l in laengenmixFolge)
           if (laengen.contains(l)) l.mm,
       ],
       laengste = laengen.fold(0, (m, l) => l.mm > m ? l.mm : m) {
    for (final l in this.laengen) {
      _gelegt[l] = 0;
    }
  }

  /// Lieferlängen des Mixes in der Folge [laengenmixFolge] (mm).
  final List<int> laengen;

  /// Längste Lieferlänge (mm).
  final int laengste;

  /// Anfang des Rasters in Verlegerichtung: der Rand der Fläche.
  final Millimeter anfang;

  /// Abstand der Rasterlinien ([laengenmixRasterFuer]).
  final Millimeter raster;

  final _gelegt = <int, int>{};
  var _vorreihe = <int>{};
  var _davor = <int>{};
  var _zug = 7;

  @override
  List<List<Millimeter>> stoesse(
    int reihe,
    List<(Millimeter, Millimeter)> abschnitte,
  ) {
    final jetzt = <int>{};
    final ergebnis = [
      for (final (a, b) in abschnitte) _abschnitt(a.mm, b.mm, jetzt),
    ];
    _davor = _vorreihe;
    _vorreihe = jetzt;
    return ergebnis;
  }

  List<Millimeter> _abschnitt(int a, int b, Set<int> jetzt) {
    final stoesse = <Millimeter>[];
    var pos = a;
    while (b - pos > laengste + laengenmixToleranz.mm) {
      final stoss = _naechster(pos, b);
      stoesse.add(Millimeter(stoss));
      jetzt.add(stoss);
      pos = stoss;
    }
    return stoesse;
  }

  /// Stoß hinter [pos] im Abschnitt bis [b] nach dem fairen Mix.
  int _naechster(int pos, int b) {
    final folge = [for (final l in laengen) (l, _gelegt[l]! + _zufall() * 3)]
      ..sort((x, y) => x.$2.compareTo(y.$2));
    final mindest = laengenmixMindeststueck.mm;
    for (final strenge in const [2, 1, 0]) {
      for (final (l, _) in folge) {
        final stoss = _linie(pos + l);
        if (stoss < pos + mindest || b - stoss < mindest) continue;
        if (_vorreihe.contains(stoss) && strenge > 0) continue;
        if (_davor.contains(stoss) && strenge > 1) continue;
        _gelegt[l] = _gelegt[l]! + 1;
        return stoss;
      }
    }
    // die kürzeste Länge passt bei einem Raster bis 50 cm immer
    throw StateError('kein Stoß im Raster ${raster.mm} mm');
  }

  /// Rasterlinie bei oder vor [u].
  int _linie(int u) =>
      anfang.mm + ((u - anfang.mm) / raster.mm + 1e-6).floor() * raster.mm;

  static const _modul = 2147483647;

  /// Feste Zufallsfolge (lineare Kongruenz wie im Kern, Startwert 7).
  double _zufall() {
    _zug = (_zug * 16807) % _modul;
    return _zug / _modul;
  }
}

/// Die Lieferlänge eines Längenmix-Stücks der Länge [stueck]: die kürzeste
/// aus [laengen] (aufsteigend), die es samt [laengenmixToleranz] aufnimmt,
/// sonst die längste.
Millimeter laengenmixLieferlaenge(
  Millimeter stueck,
  List<Millimeter> laengen,
) => laengen.firstWhere(
  (l) => l + laengenmixToleranz >= stueck,
  orElse: () => laengen.last,
);
