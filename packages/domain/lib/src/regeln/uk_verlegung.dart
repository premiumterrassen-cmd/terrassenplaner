/// Berechnung der UK-Verlegung (M6-10, Fachkonzept 3.11): Lage der
/// UK-Hölzer quer zu den Dielen, doppelte UK an den Stößen der Dielen,
/// Randabstand, Rand-UK an den Kanten mit Dielenenden, Stöße der UK,
/// Längsverbinder, Farben im Plan, Stückliste und Lieferstücke.
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
import 'planungsregeln.dart';
import 'rand_uk.dart';
import 'regelwerk.dart';
import 'rinnen.dart';
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

/// Eine Rand-UK (Planungsregeln Alexander (Planungskern v6, 11.11.2026),
/// Regel 3.3/3.4) in der gedrehten Fläche: Achse von [von] bis [bis] – eine
/// halbe UK-Breite innen, also bündig an der Kante –, die Stöße ihrer
/// Hölzer ([stoesse], Abstand von [von]) und ob die Selbstkontrolle sie
/// [ergaenzt] hat.
typedef UkRand = ({Punkt von, Punkt bis, List<double> stoesse, bool ergaenzt});

/// Ein Stützholz unter einer Rinne quer zur Kante (Planungsregeln
/// Alexander, Planungskern v11, Regel 13.1.4) in der gedrehten Fläche: von
/// der Belagkante (an der letzten UK) bis zur Kante der Fläche.
typedef UkStuetze = ({Punkt von, Punkt bis});

/// UK-Verlegung einer Fläche (M6-10).
final class UkVerlegung {
  UkVerlegung({
    List<UkLinie> linien = const [],
    List<UkRand> rand = const [],
    List<UkStuetze> stuetzen = const [],
    List<Planstueck> stuecke = const [],
    List<Materialbedarf> bedarf = const [],
    List<UkHolz> hoelzer = const [],
    List<Lieferdiele> zuschnitt = const [],
    this.breite = const Millimeter(0),
    this.winkel = 0,
  }) : linien = List.unmodifiable(linien),
       rand = List.unmodifiable(rand),
       stuetzen = List.unmodifiable(stuetzen),
       zuschnitt = List.unmodifiable(zuschnitt),
       stuecke = List.unmodifiable(stuecke),
       bedarf = List.unmodifiable(bedarf),
       hoelzer = List.unmodifiable(hoelzer);

  /// Ohne UK.
  static final keine = UkVerlegung();

  /// Linien in der gedrehten Fläche, nach x aufsteigend.
  final List<UkLinie> linien;

  /// Rand-UK an den Kanten mit Dielenenden (Regel 3.3), danach die von der
  /// Selbstkontrolle ergänzten (Regel 3.4).
  final List<UkRand> rand;

  /// Stützhölzer unter den Rinnen längs zur UK (Regel 13.1.4), je eins mit
  /// einem Auflager in der Mitte und zwei Eckverbundwinkeln.
  final List<UkStuetze> stuetzen;

  /// Zuschnitte der UK-Hölzer für die Stückliste: rot in ganzer
  /// Lieferlänge, sonst blau.
  final List<Planstueck> stuecke;

  /// Lieferstücke je Lieferlänge und Längsverbinder für die Materialliste.
  final List<Materialbedarf> bedarf;

  /// Welche Stücke aus welchem Lieferholz kommen (M9-02, `lieferhoelzer`).
  final List<Lieferdiele> zuschnitt;

  /// UK-Hölzer in Planungskoordinaten für die Zeichnung – Linien und
  /// Rand-UK.
  final List<UkHolz> hoelzer;

  /// Breite der UK in der Draufsicht: die schmale Seite, gedreht die
  /// breite (B-034).
  final Millimeter breite;

  /// Winkel der Dielen in Grad: um ihn ist die Fläche der [linien] gedreht.
  final double winkel;

  /// Lage der Linien (x in der gedrehten Fläche) – für Befestigung und
  /// Querstreben.
  List<double> get lagen => [for (final l in linien) l.x];

  /// Länge aller UK-Hölzer in mm – die Abschnitte der Linien, so wie die UK
  /// unter dem Belag liegt, die Rand-UK und die Stützhölzer (Gummiband,
  /// M8-02).
  double get laenge =>
      [for (final r in rand) (von: r.von, bis: r.bis), ...stuetzen].fold(
        linien.fold(
          0.0,
          (summe, l) => l.abschnitte.fold(summe, (s, a) => s + a.$2 - a.$1),
        ),
        (summe, r) => summe + r.von.abstand(r.bis),
      );

  /// Anzahl der Stöße aller UK-Linien und Rand-UK.
  int get stossanzahl => _stossanzahl(linien, rand);

  /// Längen der Rand-UK, die die Selbstkontrolle ergänzt hat (Regel 3.4) –
  /// für die Hinweise.
  List<Millimeter> get ergaenzt => [
    for (final r in rand)
      if (r.ergaenzt) Millimeter(r.von.abstand(r.bis).round()),
  ];
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
///   leere Ausschnitte (Fachkonzept 1.4). Endet sie an einer Kante mit
///   Rand-UK, ist sie dort um die UK-Breite kürzer und läuft nicht über die
///   Rand-UK (`_vorRandUk`).
/// - **Rand-UK** (Planungsregeln Alexander (Planungskern v6, 11.11.2026),
///   Regel 3.3/3.4, `randbelegung`): an jeder Kante, an der Dielen enden und
///   keine Linie liegt – schräge Ränder, Kanten leerer Ausschnitte (auf der
///   Terrassenseite), Innenecken, Bogenstücke, Kanten bei diagonaler
///   Verlegung – ein Holz bündig entlang der Kante; Bögen in Sehnen, die
///   höchstens [randBogenToleranz] vom Bogen abweichen, je Sehne eine.
/// - **Stöße der UK und Lieferlängen:** ein Abschnitt über der längsten
///   Lieferlänge wird gestückelt (`ukStueckelung`, 1000 cm → 600 + 400 cm
///   wie 2026-07-07), das Reststück ist mindestens 50 cm (Planungsregeln
///   Alexander (Planungskern v6, 11.11.2026), Regel 3.5: 610 cm → 560 +
///   50 cm); eine erzwungene UK-Länge (3.4, M6-03) gilt. Die Lieferstücke rechnet
///   `lieferhoelzer` (kurze Reste aus gemeinsamen Hölzern).
/// - **Längsverbinder:** je Stoß einer aus den Längsverbindern der UK im
///   [regelwerk] (Spalte „mögliche Längsverbinder“), wenn es welche gibt –
///   Robinien-UK haben keine.
/// - [gedreht]: die UK liegt flach (M6-02, B-034) – in der Draufsicht ist
///   sie dann so breit wie ihre breite Seite.
/// - **Stellfüße an der Hauswand** ([stellfuesse], Planungsregeln Alexander
///   (Planungskern v6, 11.11.2026), Regel 3.11): Hauswand sind die Seiten
///   an Bauelementen (`Anschluss.angrenzend`, 4.1). Eine UK-Linie, die auf
///   die Wand zuläuft, endet [wandabstandBeiStellfuessen] (1 cm) vor ihr –
///   der erste Fuß steht 5 cm vom UK-Ende, also 6 cm von der Wand; eine UK
///   parallel zur Wand (äußere Linie oder Rand-UK) liegt mit der Achse
///   [wandachseBeiStellfuessen] (6 cm) von ihr, Linien enden dann vor ihr;
///   eine Rand-UK, die an die Wand stößt, endet ebenfalls 1 cm davor. Freie
///   Kanten bleiben bündig.
/// - **Entwässerungsrinnen** ([rinnen], Planungsregeln Alexander,
///   Planungskern v11, Regel 13.1.3/13.1.4, R-C19): die UK liegt unter dem
///   Belag des [belagstand] (Kanten mit Rinne 15,7 cm nach innen versetzt).
///   An einer Rinne längs der Dielen (quer zur UK) laufen die Linien unter
///   der Rinne bis an die Kante der Fläche durch (Frage 14: UK bis zur
///   Hauswand); an jeder anderen Rinne liegen Stützhölzer quer unter der
///   Rinne von der letzten UK bis zur Kante, das erste und letzte 5 cm von
///   den Enden, dazwischen höchstens 42 cm auseinander
///   (`stuetzholzstellen`).
UkVerlegung ukVerlegung(
  Planungsstand stand,
  Artikel uk, {
  required Millimeter abstand,
  List<Dielenstueck> dielen = const [],
  bool gedreht = false,
  bool stellfuesse = false,
  Regelwerk? regelwerk,
  Planungsstand? belagstand,
  List<Rinnenkante> rinnen = const [],
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
  final belag = belagstand ?? stand;
  final flaeche = gedrehte(belag.kontur);
  final gedrehteRinnen = [
    for (final r in rinnen)
      (
        von: r.von.gedreht(drehung),
        bis: r.bis.gedreht(drehung),
        innen: r.innen.gedreht(drehung),
      ),
  ];
  final laengs = [
    for (final r in gedrehteRinnen)
      if ((r.von.y - r.bis.y).abs() <= _amRand) r,
  ];
  final aussparungen = [for (final s in _leere(stand)) gedrehte(s)];
  final huelle = Huellrechteck.um(flaeche);
  final w = breite.mm.toDouble();
  final wand = stellfuesse ? _wand(stand, drehung) : const <Kante>[];
  double randachse(double x) =>
      wand.any((k) => _senkrechtBei(k, x)) ? _wandachse : w / 2;
  final lagen = _lagen(
    [
      huelle.min.x,
      ..._dielenstoesse(dielen, drehung, abstand.mm / 2, huelle, w),
      huelle.max.x,
    ],
    w,
    abstand.mm.toDouble(),
    (randachse(huelle.min.x), randachse(huelle.max.x)),
  );
  final roh = <UkLinie>[
    for (final x in lagen)
      (
        x: x,
        abschnitte: _bisZurKante(
          x,
          _ohne(_schnitte(flaeche, x), [
            for (final s in aussparungen) ..._schnitte(s, x),
          ]),
          laengs,
        ),
        stoesse: const [],
      ),
  ];
  final belegung = randbelegung(_randkanten(belag, drehung, w), roh);
  final randkanten = [for (final r in belegung) r.kante];
  // Achse einer Rand-UK von ihrer Kante: an der Wand 6 cm, sonst bündig
  double achse(Randkante k) =>
      wand.any((h) => _aufKante(k, h)) ? _wandachse : w / 2;
  final laengen = ukLieferlaengen(uk);
  final holz = _Holzleger(uk, laengen, stand.ukLaenge, drehung);
  final linien = <UkLinie>[];
  for (final l in roh) {
    final abschnitte = _vorRandUk(
      l.x,
      l.abschnitte,
      [for (final k in randkanten) (kante: k, achse: achse(k))],
      wand,
      w,
    );
    final stoesse = [
      for (final (von, bis) in abschnitte)
        for (final s in holz.lege(Punkt(l.x, von), Punkt(l.x, bis))) von + s,
    ];
    linien.add((x: l.x, abschnitte: abschnitte, stoesse: stoesse));
  }
  UkRand randholz(Randbelegung r) {
    // bündig: die Achse eine halbe Breite auf der Belagseite (an der Wand
    // 6 cm); stößt sie an die Wand, endet sie 1 cm davor
    final anWand = wand.any((h) => _aufKante(r.kante, h));
    final innen = r.kante.innen * (anWand ? _wandachse : w / 2);
    final richtung = (r.kante.bis - r.kante.von).einheit;
    double kuerzung(Punkt ende) =>
        !anWand && wand.any((h) => h.abstand(ende) <= _amRand)
        ? _wandabstand
        : 0;
    final von = r.kante.von + innen + richtung * kuerzung(r.kante.von);
    final bis = r.kante.bis + innen - richtung * kuerzung(r.kante.bis);
    return (
      von: von,
      bis: bis,
      stoesse: holz.lege(von, bis),
      ergaenzt: r.ergaenzt,
    );
  }

  final rand = [for (final r in belegung) randholz(r)];
  final stuetzen = <UkStuetze>[
    for (final r in gedrehteRinnen)
      if (!laengs.contains(r))
        for (final s in stuetzholzstellen(r.von.abstand(r.bis)))
          if (r.von + (r.bis - r.von).einheit * s case final p)
            (von: p + r.innen * rinnenabstand.mm.toDouble(), bis: p),
  ];
  for (final s in stuetzen) {
    holz.lege(s.von, s.bis);
  }
  final stossanzahl = _stossanzahl(linien, rand);
  final verbinder = regelwerk?.datei[uk.nummer] == null
      ? const <Artikel>[]
      : regelwerk!.moeglich(uk.nummer, Beziehung.laengsverbinder);
  final zuschnitt = lieferhoelzer(
    [for (final s in holz.stuecke) s.laenge],
    laengen,
    fest: stand.ukLaenge,
  );
  return UkVerlegung(
    linien: linien,
    rand: rand,
    stuetzen: stuetzen,
    stuecke: holz.stuecke,
    zuschnitt: zuschnitt,
    bedarf: [
      ...ukBedarf(uk, zuschnitt),
      if (verbinder.isNotEmpty && stossanzahl > 0)
        Materialbedarf(verbinder, stossanzahl),
    ],
    hoelzer: holz.hoelzer,
    breite: breite,
    winkel: winkel,
  );
}

/// Höchstens so viele Felder zwischen zwei Grenzen (Rand oder Stoß):
/// 100 m bei 10 cm Feldbreite.
const hoechsteFelder = 1000;

/// Bögen werden für die Rand-UK in Sehnen zerlegt, die höchstens so weit
/// (mm) vom Bogen abweichen – je Sehne eine Rand-UK.
const randBogenToleranz = 5.0;

/// Ein Dielenende und der Anfang der nächsten Diele derselben Reihe liegen
/// höchstens so weit (mm) auseinander: Fuge plus Rundung.
const _stossLuecke = 10.0;

/// Abschnitte unter dieser Länge (mm) bekommen kein Holz – etwa ein
/// Streifen zwischen Rand und Ausschnitt.
const _mindestAbschnitt = 10.0;

/// Legt die Hölzer einer UK-Linie oder Rand-UK: Zuschnitte für die
/// Stückliste und Hölzer für die Zeichnung (in Planungskoordinaten).
final class _Holzleger {
  _Holzleger(this.uk, this.laengen, this.fest, this.drehung);

  final Artikel uk;
  final List<Millimeter> laengen;
  final Millimeter? fest;
  final double drehung;
  final stuecke = <Planstueck>[];
  final hoelzer = <UkHolz>[];

  /// Hölzer von [von] bis [bis] (gedrehte Fläche); liefert die Stöße als
  /// Abstand von [von].
  List<double> lege(Punkt von, Punkt bis) {
    final richtung = (bis - von).einheit;
    final teile = _teile(von.abstand(bis), laengen, fest);
    final stoesse = <double>[];
    var s = 0.0;
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
        von: (von + richtung * s).gedreht(-drehung),
        bis: (von + richtung * (s + laenge)).gedreht(-drehung),
        farbe: stueck.farbe,
      ));
      s += laenge;
      if (i < teile.length - 1) stoesse.add(s);
    }
    return stoesse;
  }
}

/// Anzahl der Stöße aller [linien] und Rand-UK [rand].
int _stossanzahl(List<UkLinie> linien, List<UkRand> rand) => [
  for (final l in linien) ...l.stoesse,
  for (final r in rand) ...r.stoesse,
].length;

/// Konturen der leeren Ausschnitte von [stand] – nur dort fehlt der Belag.
List<Kontur> _leere(Planungsstand stand) => [
  for (final s in stand.ausschnitte)
    if (s.funktion == Ausschnittfunktion.leer) s.kontur,
];

/// Hauswand in der gedrehten Fläche: die Seiten des Grundrisses an
/// Bauelementen (`Anschluss.angrenzend`, Fachkonzept 4.1) – Regel 3.11.
List<Kante> _wand(Planungsstand stand, double drehung) {
  final ecken = stand.grundriss.ecken;
  return [
    for (final i in stand.anschluss.angrenzend)
      if (i < ecken.length)
        Kante(
          ecken[i].gedreht(drehung),
          ecken[(i + 1) % ecken.length].gedreht(drehung),
        ),
  ];
}

/// Achse einer UK parallel zur Hauswand ([wandachseBeiStellfuessen]) und
/// Abstand der UK-Enden von ihr ([wandabstandBeiStellfuessen]) in mm.
final _wandachse = wandachseBeiStellfuessen.mm.toDouble();
final _wandabstand = wandabstandBeiStellfuessen.mm.toDouble();

/// Läuft die Wandkante [k] senkrecht (quer zu den Dielen) bei [x]?
bool _senkrechtBei(Kante k, double x) =>
    (k.start.x - x).abs() <= _amRand && (k.ende.x - x).abs() <= _amRand;

/// Liegt die Randkante [k] auf der Wandkante [h]?
bool _aufKante(Randkante k, Kante h) =>
    h.abstand(k.von) <= _amRand && h.abstand(k.bis) <= _amRand;

/// Kanten des Umrisses und der leeren Ausschnitte in der gedrehten Fläche,
/// die an Belag grenzen (`randkanten`); Bögen als Sehnen
/// ([randBogenToleranz]).
List<Randkante> _randkanten(Planungsstand stand, double drehung, double w) {
  final leere = _leere(stand);
  return randkanten(
    [
      for (final kontur in [stand.kontur, ...leere])
        [for (final q in kontur.vieleck(randBogenToleranz)) q.gedreht(drehung)],
    ],
    (p) {
      final q = p.gedreht(-drehung);
      return stand.kontur.enthaelt(q) && !leere.any((k) => k.enthaelt(q));
    },
    w,
  );
}

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
/// dazwischen gleichmäßig höchstens [abstand] auseinander; am ersten und
/// letzten Rand liegt die Achse [rand] innen (an der Hauswand bei
/// Stellfüßen 6 cm, Regel 3.11.2). Ein Feld ist mindestens den halben
/// Abstand breit (Grundriss ab 50 cm, nahe Stöße zusammengefasst), also
/// breiter als ein Holz.
List<double> _lagen(
  List<double> grenzen,
  double w,
  double abstand,
  (double, double) rand,
) {
  final lagen = <double>[];
  for (var i = 1; i < grenzen.length; i++) {
    final links = grenzen[i - 1] + (i == 1 ? rand.$1 : w / 2);
    final rechts = grenzen[i] - (i == grenzen.length - 1 ? rand.$2 : w / 2);
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

/// Ein Ende einer Linie liegt höchstens so weit (mm) von einer Kante mit
/// Rand-UK entfernt, dann endet die Linie an ihr – Bögen sind für die
/// Rand-UK in Sehnen zerlegt ([randBogenToleranz]).
const _amRand = randBogenToleranz + 1;

/// [abschnitte] der Linie bei [x] ohne die Rand-UK: endet ein Abschnitt an
/// einer der [randkanten], wird er dort bis vor die Rand-UK gekürzt – um
/// ihre Achse (bündig eine halbe UK-Breite [w], an der Hauswand 6 cm) plus
/// eine halbe Breite; die Linie läuft nicht über die Rand-UK (Planungsregeln
/// Alexander (Planungskern v6, 11.11.2026), Regel 3.3; Zuschnitt und Längen
/// stimmen). Endet er sonst an der [wand], endet er 1 cm davor (Regel
/// 3.11.1). Zu kurze Reste fallen weg.
List<(double, double)> _vorRandUk(
  double x,
  List<(double, double)> abschnitte,
  List<({Randkante kante, double achse})> randkanten,
  List<Kante> wand,
  double w,
) {
  double kuerzung(double y) {
    final p = Punkt(x, y);
    for (final (:kante, :achse) in randkanten) {
      if (Kante(kante.von, kante.bis).abstand(p) <= _amRand) {
        return achse + w / 2;
      }
    }
    return wand.any((k) => k.abstand(p) <= _amRand) ? _wandabstand : 0;
  }

  return [
    for (final (von, bis) in abschnitte)
      if ((von + kuerzung(von), bis - kuerzung(bis)) case (final a, final b)
          when b - a >= _mindestAbschnitt)
        (a, b),
  ];
}

/// [abschnitte] der Linie bei [x], die an der Belagkante einer Rinne
/// längs der Dielen ([laengs], gedrehte Fläche) enden, laufen unter der
/// Rinne bis an ihre Kante (Regel 13.1.3).
List<(double, double)> _bisZurKante(
  double x,
  List<(double, double)> abschnitte,
  List<({Punkt von, Punkt bis, Punkt innen})> laengs,
) {
  double kante(double y) {
    for (final r in laengs) {
      final belagkante = r.von.y + r.innen.y * rinnenabstand.mm;
      if (x >= math.min(r.von.x, r.bis.x) - _amRand &&
          x <= math.max(r.von.x, r.bis.x) + _amRand &&
          (y - belagkante).abs() <= _amRand) {
        return r.von.y;
      }
    }
    return y;
  }

  return [for (final (von, bis) in abschnitte) (kante(von), kante(bis))];
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

/// Zuschnitte eines Abschnitts der Länge [laenge] (`ukStueckelung`,
/// Regel 3.5: Reststück mindestens 50 cm, mit erzwungener Länge [fest]);
/// ohne Lieferlängen ein Stück.
List<double> _teile(double laenge, List<Millimeter> laengen, Millimeter? fest) {
  final stuecke = ukStueckelung(
    Millimeter(laenge.round()),
    laengen,
    fest: fest,
  );
  if (stuecke.length < 2) return [laenge];
  final ganze = [
    for (final l in stuecke.take(stuecke.length - 1)) l.mm.toDouble(),
  ];
  return [...ganze, laenge - ganze.fold(0.0, (a, b) => a + b)];
}
