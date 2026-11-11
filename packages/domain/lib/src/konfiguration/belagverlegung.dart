import 'dart:math' as math;

import '../artikel/artikel.dart';
import '../artikel/einheiten.dart';
import '../geometrie/kontur.dart';
import '../geometrie/punkt.dart';
import '../regeln/planungsregeln.dart';
import 'ausschnitt.dart';
import 'dielenverlegung.dart';
import 'grundriss.dart';
import 'planungsstand.dart';

/// Eine Lieferdiele des Zuschnitts (M5-08): in welcher Lieferlänge sie
/// bestellt wird und welche Stücke aus ihr geschnitten werden.
final class Lieferdiele {
  Lieferdiele(this.laenge, List<Millimeter> schnitte)
    : schnitte = List.unmodifiable(schnitte);

  final Millimeter laenge;

  /// Längen der Stücke, längstes zuerst.
  final List<Millimeter> schnitte;

  /// Summe der Schnitte: so viel der Diele wird verlegt.
  Millimeter get genutzt =>
      schnitte.fold(const Millimeter(0), (summe, s) => summe + s);
}

/// Ordnet jedes Stück einer Lieferdiele zu (M5-08, R-B10, R-B11) und
/// verteilt Reststücke auf weitere Reihen – etwa eine 4000-mm-Diele für
/// zwei Reihen mit je 200 cm Rest (F09).
///
/// Die Stücke werden absteigend nach Länge verteilt: Jedes kommt in den
/// kleinsten Rest einer schon angefangenen Diele, in den es passt. Sonst
/// beginnt eine neue Diele in der Lieferlänge, deren Rest nach dem
/// Auffüllen mit den folgenden Stücken am kleinsten ist – bei gleichem Rest
/// die kürzere. Zum Schluss bekommt jede Diele die kürzeste Lieferlänge,
/// die ihre Stücke noch aufnimmt. Gesägt wird ohne Zugabe: zwei Stücke von
/// 200 cm passen in 4000 mm wie im alten Planer. Eine Lieferlänge nimmt
/// Stücke bis zu ihrer Länge plus [ueberlaenge] auf (`dielenUeberlaenge`,
/// Planungsregeln Alexander (Planungskern v6, 11.11.2026)): 603 cm aus einer
/// 6-m-Diele, 2 × 301 cm ebenso. Die Überlänge ist nur ein Angebot: Liefert
/// die Verteilung ohne sie weniger (die Verteilung ist nicht optimal), gilt
/// diese – Überlänge macht den Zuschnitt nie schlechter.
///
/// Das ist eine Verteilung je Teilfläche, keine Optimierung über
/// Varianten, Flächen und Belagwechsel hinweg – die folgt mit der
/// Verschnittoptimierung (M9-01). Ein Stück, das länger als jede
/// [lieferlaengen] (samt Überlänge) ist, ist ein Fehler des Aufrufers.
List<Lieferdiele> zuschneiden(
  Iterable<Millimeter> stuecke,
  List<Millimeter> lieferlaengen, {
  Millimeter ueberlaenge = const Millimeter(0),
}) {
  final folge = [for (final s in stuecke) s.mm]..sort((a, b) => b - a);
  final laengen = [for (final l in lieferlaengen) l.mm]..sort();
  final mit = _verteile(folge, laengen, ueberlaenge.mm);
  if (ueberlaenge.mm == 0 || folge.isEmpty || folge.first > laengen.last) {
    return mit;
  }
  final ohne = _verteile(folge, laengen, 0);
  return liefertWeniger(ohne, mit) ? ohne : mit;
}

/// Ob [a] weniger liefert als [b] – bei gleicher Länge in weniger Dielen.
bool liefertWeniger(List<Lieferdiele> a, List<Lieferdiele> b) {
  final (la, lb) = (_geliefert(a), _geliefert(b));
  return la < lb || la == lb && a.length < b.length;
}

int _geliefert(List<Lieferdiele> dielen) =>
    dielen.fold(0, (summe, d) => summe + d.laenge.mm);

/// [zuschneiden] der Stücke [folge] (absteigend) auf die [laengen]
/// (aufsteigend), jede mit [u] mm Überlänge.
List<Lieferdiele> _verteile(List<int> folge, List<int> laengen, int u) {
  final offen = <({int laenge, List<int> schnitte})>[];
  final reste = <int>[];
  for (var i = 0; i < folge.length; i++) {
    final stueck = folge[i];
    var beste = -1;
    for (var j = 0; j < reste.length; j++) {
      if (reste[j] >= stueck && (beste < 0 || reste[j] < reste[beste])) {
        beste = j;
      }
    }
    if (beste < 0) {
      final laenge = _neueLaenge(stueck, folge, i + 1, laengen, u);
      offen.add((laenge: laenge, schnitte: [stueck]));
      reste.add(laenge + u - stueck);
    } else {
      offen[beste].schnitte.add(stueck);
      reste[beste] -= stueck;
    }
  }
  return [
    for (final (j, (:laenge, :schnitte)) in offen.indexed)
      Lieferdiele(
        Millimeter(laengen.firstWhere((l) => l >= laenge - reste[j])),
        [for (final s in schnitte) Millimeter(s)],
      ),
  ];
}

/// Lieferlänge für eine neue Diele, die mit [stueck] beginnt: kleinster Rest
/// nach dem Auffüllen mit den Stücken ab [ab] aus [folge] (absteigend),
/// bei Gleichstand die kürzere; jede Länge nimmt [u] mm Überlänge mehr auf.
int _neueLaenge(int stueck, List<int> folge, int ab, List<int> laengen, int u) {
  int? beste;
  var besterRest = 0;
  for (final laenge in laengen) {
    if (laenge + u < stueck) continue;
    var rest = laenge + u - stueck;
    for (var k = ab; k < folge.length && rest >= folge.last; k++) {
      if (folge[k] <= rest) rest -= folge[k];
    }
    if (beste == null || rest < besterRest) {
      beste = laenge;
      besterRest = rest;
    }
  }
  if (beste == null) {
    throw ArgumentError.value(stueck, 'stuecke', 'länger als jede Lieferlänge');
  }
  return beste;
}

/// Zeile „Dielen/Platten nach Nummer“ der Planungsunterlage (M5-08): gleich
/// lange und gleich breite Stücke einer Teilfläche tragen dieselbe Nummer.
final class Dielensorte {
  const Dielensorte(this.nummer, this.laenge, this.breite, this.stueck);

  /// Ab 1, in der Reihenfolge der Verlegung.
  final int nummer;
  final Millimeter laenge;

  /// Zugeschnittene Breite: Reihenbreite ohne Fuge (Randreihe schmaler).
  final Millimeter breite;
  final int stueck;
}

/// Verlegung einer Teilfläche (M5-08): die Hauptfläche oder ein Ausschnitt
/// mit anderem Terrassenbelag. Jede Teilfläche wird für sich nummeriert und
/// zugeschnitten wie im alten Planer (eigene Nummern je Ausschnitt).
final class Teilverlegung {
  /// Nummeriert die [stuecke] in Verlegereihenfolge und schneidet sie aus
  /// den [lieferlaengen] samt [ueberlaenge] zu ([zuschneiden]).
  factory Teilverlegung(
    List<Dielenstueck> stuecke, {
    required List<Millimeter> lieferlaengen,
    Millimeter ueberlaenge = const Millimeter(0),
    String? bezeichnung,
  }) {
    final index = <(int, int), int>{};
    final anzahl = <int>[];
    final sorten = <(int, int)>[];
    final nummern = <int>[];
    for (final s in stuecke) {
      final schluessel = (s.laenge.mm, (s.breite - fuge.mm).round());
      final i = index.putIfAbsent(schluessel, () {
        sorten.add(schluessel);
        anzahl.add(0);
        return sorten.length - 1;
      });
      anzahl[i]++;
      nummern.add(i + 1);
    }
    return Teilverlegung._(
      bezeichnung,
      stuecke,
      nummern,
      [
        for (final (i, (laenge, breite)) in sorten.indexed)
          Dielensorte(i + 1, Millimeter(laenge), Millimeter(breite), anzahl[i]),
      ],
      zuschneiden(
        [for (final s in stuecke) s.laenge],
        lieferlaengen,
        ueberlaenge: ueberlaenge,
      ),
    );
  }

  Teilverlegung._(
    this.bezeichnung,
    List<Dielenstueck> stuecke,
    List<int> nummern,
    List<Dielensorte> sorten,
    List<Lieferdiele> zuschnitt,
  ) : stuecke = List.unmodifiable(stuecke),
      nummern = List.unmodifiable(nummern),
      sorten = List.unmodifiable(sorten),
      zuschnitt = List.unmodifiable(zuschnitt);

  /// `null` = Hauptfläche, sonst die Bezeichnung des Ausschnitts („A1“).
  final String? bezeichnung;
  final List<Dielenstueck> stuecke;

  /// Nummer je Stück (parallel zu [stuecke]) für die Zeichnung.
  final List<int> nummern;

  /// „Dielen nach Nummer“.
  final List<Dielensorte> sorten;
  final List<Lieferdiele> zuschnitt;
}

/// Dielenliste (M5-08): wie viele Dielen je Lieferlänge geliefert werden,
/// dazu geplante und gelieferte Länge für den Verschnitt (R-B11).
final class Dielenliste {
  Dielenliste(
    Map<Millimeter, int> anzahl, {
    required this.geplant,
    required this.geliefert,
  }) : anzahl = Map.unmodifiable(
         Map.fromEntries(
           anzahl.entries.toList()..sort((a, b) => a.key.mm - b.key.mm),
         ),
       );

  /// Zählt die Lieferdielen eines Zuschnitts.
  factory Dielenliste.aus(Iterable<Lieferdiele> zuschnitt) {
    final anzahl = <Millimeter, int>{};
    var geplant = 0, geliefert = 0;
    for (final d in zuschnitt) {
      anzahl.update(d.laenge, (n) => n + 1, ifAbsent: () => 1);
      // die Überlänge zählt nicht als geliefert: höchstens die Lieferlänge
      geplant += math.min(d.genutzt.mm, d.laenge.mm);
      geliefert += d.laenge.mm;
    }
    return Dielenliste(
      anzahl,
      geplant: Millimeter(geplant),
      geliefert: Millimeter(geliefert),
    );
  }

  static final leer = Dielenliste(
    const {},
    geplant: const Millimeter(0),
    geliefert: const Millimeter(0),
  );

  /// Anzahl je Lieferlänge, aufsteigend nach Länge.
  final Map<Millimeter, int> anzahl;

  /// Summe der verlegten Stücke.
  final Millimeter geplant;

  /// Summe der Lieferlängen.
  final Millimeter geliefert;

  /// Verschnitt = (geliefert − geplant) ÷ geliefert (R-B11) – wie im alten
  /// Planer über die Längen: F01 4 % (48 × 4800 in 5000 mm), F02 22,75 %,
  /// F20 10 %, Holzfliese F25 0,99 %. 0 ohne Dielen.
  double get verschnitt =>
      geliefert.mm == 0 ? 0 : (geliefert - geplant).mm / geliefert.mm;

  /// Beide Listen zusammen (mehrere Teilflächen und Flächen, M4-14).
  Dielenliste operator +(Dielenliste andere) {
    final summe = {...anzahl};
    andere.anzahl.forEach(
      (l, n) => summe.update(l, (m) => m + n, ifAbsent: () => n),
    );
    return Dielenliste(
      summe,
      geplant: geplant + andere.geplant,
      geliefert: geliefert + andere.geliefert,
    );
  }

  /// Für eine Fläche, die [haeufigkeit]-mal gebaut wird (M4-14): jede
  /// Fläche wird für sich zugeschnitten.
  Dielenliste operator *(int haeufigkeit) => Dielenliste(
    anzahl.map((l, n) => MapEntry(l, n * haeufigkeit)),
    geplant: geplant * haeufigkeit,
    geliefert: geliefert * haeufigkeit,
  );
}

/// Verlegung des Belags einer Fläche (M5-08): Ausgangspunkt und Grenzen der
/// Verschiebung (M5-07) und die Teilflächen – zuerst die Hauptfläche ohne
/// alle Ausschnitte, dann je Ausschnitt mit anderem Terrassenbelag eine
/// eigene.
final class Belagverlegung {
  Belagverlegung._(
    this.ausgangspunkt,
    this.grenzen,
    List<Millimeter> lieferlaengen,
    this.ueberlaenge,
    List<Teilverlegung> teile,
  ) : lieferlaengen = List.unmodifiable(lieferlaengen),
      teile = List.unmodifiable(teile);

  /// Gewählte Ecke plus (begrenzte) Verschiebung.
  final Punkt ausgangspunkt;

  /// Größte Verschiebung je Bildschirmachse (`verschiebungsgrenzen`).
  final ({Millimeter x, Millimeter y}) grenzen;

  /// Lieferlängen, aus denen zugeschnitten wird: die erzwungene Länge oder
  /// alle des Belags (aufsteigend) – auch für die Verschnittoptimierung
  /// (M9-01).
  final List<Millimeter> lieferlaengen;

  /// Längste Lieferlänge, in der verlegt wird (erzwungene Länge oder die
  /// längste des Belags): ein Stück dieser Länge ist ungeschnitten
  /// (Stückliste, M9-04).
  Millimeter get laengste => lieferlaengen.last;

  /// Überlänge der Lieferlängen (`dielenUeberlaenge`; Holzfliesen 0) – auch
  /// für die Verschnittoptimierung.
  final Millimeter ueberlaenge;
  final List<Teilverlegung> teile;

  /// Dielenliste aller Teilflächen.
  Dielenliste get dielenliste => teile.fold(
    Dielenliste.leer,
    (summe, t) => summe + Dielenliste.aus(t.zuschnitt),
  );

  /// Ob ein Stück kürzer oder eine Randreihe schmaler als 5 cm ist (M5-07).
  bool get kurzeZuschnitte =>
      teile.any((t) => t.stuecke.any((s) => s.kurzerZuschnitt));
}

/// Verlegt den [belag] auf der Fläche [stand] (M5-08); `null`, wenn nichts
/// zu verlegen ist: offene Freiform, kein Belag, Systemdielen (Längenmix,
/// Endlosverlegung) oder unvollständige Abmessungen.
///
/// Dielen: Breite und Lieferlängen des Belags (erzwungene Länge, solange der
/// Belag sie liefert, M5-02), Fuge 5 mm (R-B06), 3 cm Überlänge
/// (`dielenUeberlaenge`, Planungsregeln Alexander (Planungskern v6,
/// 11.11.2026)): eine Reihe bis 603 cm liegt ohne Stoß auf einer 6-m-Diele. Holzfliesen (606 × 606 mm)
/// liegen wie Dielen in Reihen aus Kantenlänge plus Fuge und werden längs
/// ohne Fuge gestoßen – wie im alten Planer (F25: 7 × 60,6 + 55,8 cm je
/// Reihe; Referenzfall 2026-08-17-1838: Randreihe 25,1 cm); kurze Stücke
/// werden nie verbunden, eine Fliese über eine Rasterlinie gibt es nicht.
///
/// Die Hauptfläche spart alle Ausschnitte aus (leere Fläche: kein Material,
/// Fachkonzept 1.4). Ein Ausschnitt mit anderem Terrassenbelag ist eine
/// eigene Teilfläche, verlegt ab seiner Ecke oben links – bis er einen
/// eigenen Belag bekommt, mit dem Belag der Fläche (F22).
Belagverlegung? verlegeBelag(Planungsstand stand, Artikel? belag) {
  if (stand.grundriss case FreiformGrundriss(geschlossen: false)) return null;
  final masse = belag?.abmessungen;
  final breite = masse?.breite;
  if (breite == null || masse!.laengen.isEmpty) return null;
  final fest = stand.dielenlaenge;
  final (List<Millimeter> lieferlaengen, bool verbinden, Millimeter ueber) art;
  switch (belag!.art) {
    case Artikelart.diele:
      art = (
        masse.laengen.contains(fest) ? [fest!] : masse.laengen,
        stand.kurzeStueckeVerbinden,
        dielenUeberlaenge,
      );
    case Artikelart.holzfliese:
      art = (masse.laengen, false, const Millimeter(0));
    default:
      return null;
  }
  final (lieferlaengen, verbinden, ueberlaenge) = art;
  final kontur = stand.kontur;
  final winkel = stand.dielenwinkel.toDouble();
  final laengste = lieferlaengen.last;
  final grenzen = verschiebungsgrenzen(
    kontur,
    winkel: winkel,
    dielenbreite: breite,
    laengste: laengste,
    ueberlaenge: ueberlaenge,
  );
  final ausgangspunkt =
      stand.ausgangspunkt +
      Punkt(
        _begrenzt(stand.verschiebungX, grenzen.x),
        _begrenzt(stand.verschiebungY, grenzen.y),
      );
  Teilverlegung teil(
    Kontur flaeche,
    Punkt ab, {
    List<Kontur> aussparungen = const [],
    String? bezeichnung,
  }) => Teilverlegung(
    verlegeDielen(
      flaeche,
      winkel: winkel,
      ausgangspunkt: ab,
      dielenbreite: breite,
      verlegeart: stand.verlegeart,
      laengste: laengste,
      verbinden: verbinden,
      ueberlaenge: ueberlaenge,
      aussparungen: aussparungen,
    ),
    lieferlaengen: lieferlaengen,
    ueberlaenge: ueberlaenge,
    bezeichnung: bezeichnung,
  );
  return Belagverlegung._(ausgangspunkt, grenzen, lieferlaengen, ueberlaenge, [
    teil(
      kontur,
      ausgangspunkt,
      aussparungen: [for (final a in stand.ausschnitte) a.kontur],
    ),
    for (final a in stand.ausschnitte)
      if (a.funktion == Ausschnittfunktion.andererBelag)
        teil(
          a.kontur,
          Punkt(a.x.mm.toDouble(), a.y.mm.toDouble()),
          bezeichnung: a.bezeichnung,
        ),
  ]);
}

double _begrenzt(Millimeter wert, Millimeter grenze) =>
    wert.mm.clamp(-grenze.mm, grenze.mm).toDouble();
