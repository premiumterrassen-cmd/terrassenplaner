import 'dart:math' as math;

import '../artikel/einheiten.dart';

/// Verlegeart des Belags (Fachkonzept 2.3, M5-04; Verlegemuster nach den
/// Planungsregeln Alexander (Planungskern v7, 11.11.2026) Regel 9.3,
/// R-B18): wo die Stöße der Dielenreihen liegen. Die Stoßlinien laufen quer
/// zur Verlegerichtung; jede Reihe wird an ihnen geschnitten
/// (`reihenstuecke`).
///
/// Raster ist die Dielenlänge, mit der verlegt wird ([stossraster]). Im
/// Fugenschnitt liegen alle Stöße auf denselben Linien. In den Verbänden
/// sind die Linien jeder Reihe um einen Teil der Stoßweite versetzt
/// ([teilung]: ½, ⅓, ¼); welche Linien eine Reihe bekommt, wählt
/// [Verbandwahl].
enum Verlegeart {
  /// „Auf Fuge geschnitten“: alle Stöße in einer Linie (Vorgabe).
  fugenschnitt(0, 1),

  /// Reihe für Reihe um eine halbe Stoßweite versetzt.
  halbverband(1, 2),

  /// Reihe für Reihe um ein Drittel der Stoßweite versetzt.
  drittelverband(2, 3),

  /// Reihe für Reihe um ein Viertel der Stoßweite versetzt (neu mit dem
  /// Planungskern v7).
  viertelverband(4, 4),

  /// Unregelmäßig: je Reihe einer der Viertel-Versätze, nie derselbe wie in
  /// den beiden Reihen davor (Planungskern v7, Regel 9.3).
  wechselverband(3, 4);

  const Verlegeart(this.nummer, this.teilung);

  /// Nummer im Transportformat (FlatBuffer des Planungsstands).
  final int nummer;

  /// In so viele gleiche Teile ist die Stoßweite für die Versätze geteilt
  /// (Fugenschnitt 1: kein Versatz).
  final int teilung;

  /// Stoßlinien mit dem Versatz [versatz] (in Teilen der Stoßweite; negativ
  /// zurück – so liegt das Raster von der Gegenseite aus) im Bereich von
  /// [von] bis [bis] in Verlegerichtung, aufsteigend und nur im Inneren.
  ///
  /// Das Raster beginnt am [ausgang] (Vorgabe: [von]); liegt er mitten in
  /// der Fläche, läuft eine Linie ohne Versatz durch ihn (135°, F04, M5-05).
  List<Millimeter> linien(
    int versatz,
    Millimeter von,
    Millimeter bis,
    Millimeter raster, {
    Millimeter? ausgang,
  }) {
    final r = raster.mm;
    if (r <= 0) return const [];
    // auf ganze mm gerundet: 404 cm im Drittelverband 134,7 + 269,3 cm
    // wie im alten Planer (Referenzfall 2026-05-03-4381, M5-08)
    final basis = (ausgang ?? von).mm + (r * versatz / teilung).round();
    // erste Linie hinter [von]; Dart rechnet % auch bei negativer Basis ≥ 0
    var erste = von.mm + (basis - von.mm) % r;
    if (erste == von.mm) erste += r;
    final anzahl = erste < bis.mm ? (bis.mm - erste - 1) ~/ r + 1 : 0;
    return [for (var k = 0; k < anzahl; k++) Millimeter(erste + k * r)];
  }
}

/// Raster der Stoßlinien: die längste erlaubte Lieferlänge [laengste] (bei
/// erzwungener Länge diese), höchstens aber die [ausdehnung] der Fläche in
/// Verlegerichtung – passt eine Reihe in eine Diele (samt [ueberlaenge],
/// `dielenUeberlaenge`: 603 cm in eine 6-m-Diele), gibt es keinen Stoß.
Millimeter stossraster(
  Millimeter ausdehnung,
  Millimeter laengste, {
  Millimeter ueberlaenge = const Millimeter(0),
}) => ausdehnung <= laengste + ueberlaenge ? ausdehnung : laengste;

/// Kürzestes Dielenstück im Verband (Planungsregeln Alexander (Planungskern
/// v7, 11.11.2026) Regel 9.3, R-B18): 40 cm.
const verbandMindeststueck = Millimeter(400);

/// Stöße benachbarter Reihen liegen im Verband mindestens so weit
/// auseinander, sofern die Fläche es zulässt (R-B18): 30 cm, bei großem
/// Versatz die Hälfte des Versatzes.
const verbandMindestabstand = Millimeter(300);

/// Wählt Reihe für Reihe die Stoßlinien der [art] (R-B18, Planungsregeln
/// Alexander (Planungskern v7, 11.11.2026) Regel 9.3).
///
/// Die Reihen werden in ihrer Reihenfolge ([stoesse] Reihe für Reihe
/// aufrufen) über die Fläche von [von] bis [bis] (Verlegerichtung) gelegt:
///
/// - Nur wenn die Fläche länger als eine Diele ist ([hoechstlaenge]:
///   längste Lieferlänge plus Überlänge), gibt es Stöße; ein Abschnitt einer
///   Reihe, der in eine Diele passt, bleibt ganz.
/// - **Fugenschnitt:** alle Reihen an den Linien ohne Versatz (unverändert
///   seit M5-04).
/// - **Halb-, Drittel-, Viertelverband:** Reihe n bevorzugt den Versatz
///   n mod [Verlegeart.teilung]; **Wechselverband:** je Reihe einer der
///   vier Viertel-Versätze, nie derselbe wie in den beiden Reihen davor
///   (feste Zufallsfolge – gleiche Fläche, gleiche Planung).
/// - Je Abschnitt gelten nur Linien, mit denen jedes Stück mindestens
///   [mindeststueck] (40 cm) und höchstens [hoechstlaenge] lang ist. Geprüft
///   werden der bevorzugte Versatz, dann die übrigen, je vom Ausgangspunkt
///   und gespiegelt von der Gegenseite; gewählt wird die erste Lage, deren
///   Stöße nicht neben denen der Reihe davor liegen (Drittel/Viertel: der
///   Reihen davor, so viele wie Versätze minus eins; Wechsel: der beiden
///   Reihen davor) –
///   mindestens [verbandMindestabstand], höchstens der halbe Versatz –,
///   sonst die erste gültige. Gibt es keine, wird der Abschnitt in gleich
///   lange Stücke geteilt.
///
/// Jeder Stoß bekommt in der UK zwei Hölzer (`ukVerlegung`, Regel 2.1).
final class Verbandwahl {
  Verbandwahl(
    this.art, {
    required this.von,
    required this.bis,
    required this.raster,
    required this.hoechstlaenge,
    this.ausgang = const Millimeter(0),
    this.mindeststueck = verbandMindeststueck,
  });

  final Verlegeart art;
  final Millimeter von;
  final Millimeter bis;
  final Millimeter raster;
  final Millimeter hoechstlaenge;
  final Millimeter ausgang;
  final Millimeter mindeststueck;

  final _vorher = <List<int>>[];
  var _zug = 1;
  final _versaetze = <int>[];

  /// Ob die Fläche überhaupt Stöße bekommt.
  bool get _mitStoessen => bis - von > hoechstlaenge;

  /// Stöße der Reihe [reihe] je Abschnitt in [abschnitte] (von, bis in
  /// Verlegerichtung), in derselben Reihenfolge.
  List<List<Millimeter>> stoesse(
    int reihe,
    List<(Millimeter, Millimeter)> abschnitte,
  ) {
    if (art == Verlegeart.fugenschnitt) {
      final alle = art.linien(0, von, bis, raster, ausgang: ausgang);
      return [for (final _ in abschnitte) alle];
    }
    if (!_mitStoessen) return [for (final _ in abschnitte) const []];
    final versatz = _versatz(reihe);
    final ergebnis = [
      for (final (a, b) in abschnitte)
        if (b - a <= hoechstlaenge)
          const <Millimeter>[]
        else
          _abschnitt(versatz, a.mm, b.mm),
    ];
    _vorher.add([
      for (final s in ergebnis)
        for (final m in s) m.mm,
    ]);
    return ergebnis;
  }

  /// Bevorzugter Versatz der Reihe [reihe].
  int _versatz(int reihe) {
    if (art != Verlegeart.wechselverband) return reihe % art.teilung;
    final frei = [
      for (var v = 0; v < art.teilung; v++)
        if (!_versaetze.reversed.take(2).contains(v)) v,
    ];
    // feste Zufallsfolge (lineare Kongruenz, klein genug für jede Plattform)
    _zug = (_zug * 75 + 74) % 65537;
    final v = frei[_zug % frei.length];
    _versaetze.add(v);
    return v;
  }

  /// Stöße im Abschnitt [a] bis [b] (mm): die erste gültige Lage, die
  /// nicht neben den Vorreihen liegt, sonst die erste gültige.
  List<Millimeter> _abschnitt(int versatz, int a, int b) {
    List<Millimeter>? ersteGueltige;
    for (var k = 0; k < art.teilung; k++) {
      final v = (versatz + k) % art.teilung;
      // vom Ausgangspunkt, dann gespiegelt von der Gegenseite
      for (final (anker, richtung) in [(ausgang, 1), (bis, -1)]) {
        final js = art.linien(
          richtung * v,
          Millimeter(a),
          Millimeter(b),
          raster,
          ausgang: anker,
        );
        if (!_gueltig(js, a, b)) continue;
        if (!_nebenVorreihen(js)) return js;
        ersteGueltige ??= js;
      }
    }
    return ersteGueltige ?? _gleichmaessig(a, b);
  }

  /// Ob mit den Stößen [js] jedes Stück von [a] bis [b] mindestens
  /// [mindeststueck] und höchstens [hoechstlaenge] lang ist.
  bool _gueltig(List<Millimeter> js, int a, int b) {
    var anfang = a;
    for (var i = 0; i <= js.length; i++) {
      final ende = i < js.length ? js[i].mm : b;
      final stueck = ende - anfang;
      if (stueck < mindeststueck.mm || stueck > hoechstlaenge.mm) return false;
      anfang = ende;
    }
    return true;
  }

  /// Ob ein Stoß aus [js] näher als der Mindestabstand an einem Stoß der
  /// Vorreihen liegt.
  bool _nebenVorreihen(List<Millimeter> js) {
    final abstand = math.max(
      verbandMindestabstand.mm,
      raster.mm ~/ (2 * art.teilung),
    );
    // Wechsel: die beiden Reihen davor (Regel 9.3), sonst so viele Reihen,
    // wie es weitere Versätze gibt (Halb 1, Drittel 2, Viertel 3)
    final reihen = art == Verlegeart.wechselverband ? 2 : art.teilung - 1;
    for (final vor in _vorher.reversed.take(reihen)) {
      for (final j in js) {
        for (final k in vor) {
          if ((k - j.mm).abs() < abstand) return true;
        }
      }
    }
    return false;
  }

  /// Notlösung: [a] bis [b] in gleich lange Stücke von höchstens
  /// [hoechstlaenge].
  List<Millimeter> _gleichmaessig(int a, int b) {
    final n = ((b - a) / hoechstlaenge.mm).ceil();
    return [
      for (var k = 1; k < n; k++) Millimeter(a + ((b - a) * k / n).round()),
    ];
  }
}
