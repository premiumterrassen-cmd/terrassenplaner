import 'dart:collection';
import 'dart:math' as math;

import '../artikel/artikel.dart';
import '../artikel/einheiten.dart';
import '../ergebnisse/verschnittoptimierung.dart';
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

/// Regeln des Musterverfahrens für den Zuschnitt (R-B17, Planungsregeln
/// Alexander (Planungskern v6, 11.11.2026) Regeln 1.3 und 1.4): zwischen
/// zwei Stücken einer Diele ein [schnitt], höchstens [hoechstens] Stücke je
/// Diele, ein Rest nur ab [wiederverwendetAb] für weitere Stücke.
final class Musterregel {
  const Musterregel._({
    this.schnitt = const Millimeter(0),
    this.hoechstens,
    this.wiederverwendetAb = const Millimeter(0),
    this.mehrlaenge = 0,
  });

  /// Ohne Einschränkung, wie im alten Planer: Holzfliesen und die
  /// Paritätstests des Rechenwegs (gesägt ohne Zugabe, beliebig viele
  /// Stücke, jeder Rest; es gilt die kürzeste Verteilung).
  static const frei = Musterregel._();

  /// Dielen (R-B17): 5 mm Sägeschnitt, höchstens 3 Stücke, Reste ab 30 cm,
  /// 1-%-Regel.
  static const dielen = Musterregel._(
    schnitt: saegeschnitt,
    hoechstens: stueckeJeDiele,
    wiederverwendetAb: mindestrest,
    mehrlaenge: mehrlaengeFuerWenigerDielen,
  );

  /// Sägeschnitt zwischen zwei Stücken einer Diele.
  final Millimeter schnitt;

  /// Höchstens so viele Stücke je Diele; `null` = beliebig viele.
  final int? hoechstens;

  /// Kürzester Rest, aus dem noch ein Stück geschnitten wird.
  final Millimeter wiederverwendetAb;

  /// So viel Mehrlänge (Anteil) nimmt die Wahl der Verteilung für weniger
  /// Dielen in Kauf ([besteVerteilung]); frei 0: die kürzeste gilt.
  final double mehrlaenge;

  /// Ob eine Diele mit [stuecke] Stücken und [rest] mm Rest (nach dem
  /// Sägeschnitt) noch ein Stück aufnimmt.
  bool nimmtAuf(int stuecke, int rest) =>
      rest >= wiederverwendetAb.mm &&
      (hoechstens == null || stuecke < hoechstens!);

  /// Ob die [schnitte] (absteigend, in mm) nach dieser Regel aus [platz] mm
  /// (Lieferlänge plus Überlänge) geschnitten werden können.
  bool passt(int platz, List<int> schnitte) {
    var rest = platz;
    for (final (i, s) in schnitte.indexed) {
      if (s > rest || i > 0 && !nimmtAuf(i, rest)) return false;
      rest -= s + schnitt.mm;
    }
    return true;
  }

  /// Die kürzeste der aufsteigenden [laengen] (mm), aus der die [schnitte]
  /// samt [ueberlaenge] nach dieser Regel geschnitten werden können.
  int kuerzeste(List<int> laengen, int ueberlaenge, List<int> schnitte) =>
      laengen.firstWhere((l) => passt(l + ueberlaenge, schnitte));
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
/// die ihre Stücke noch aufnimmt. Eine Lieferlänge nimmt Stücke bis zu
/// ihrer Länge plus [ueberlaenge] auf (`dielenUeberlaenge`, Planungsregeln
/// Alexander (Planungskern v6, 11.11.2026)): 603 cm aus einer 6-m-Diele.
/// Das [muster] (R-B17) begrenzt die Stücke je Diele, rechnet den
/// Sägeschnitt zwischen zwei Stücken (2 × 300 cm + 5 mm aus 6 m samt
/// Überlänge) und verwendet nur Reste ab 30 cm weiter; ohne ([Musterregel.frei])
/// wird gesägt wie im alten Planer: zwei Stücke von 200 cm passen in
/// 4000 mm.
///
/// Mit Musterverfahren wird außerdem je Lieferlänge, die jedes Stück
/// aufnimmt, nur mit dieser verteilt und Diele für Diele gefüllt
/// ([musterZuschnitte]); es gilt die Verteilung nach der 1-%-Regel
/// ([besteVerteilung], R-B17): bei höchstens 1 % Mehrlänge die mit den
/// wenigsten Dielen. Ohne ([Musterregel.frei]) ist die Überlänge nur ein
/// Angebot: Liefert die Verteilung ohne sie weniger, gilt diese.
///
/// Das ist eine Verteilung je Teilfläche, keine Optimierung über
/// Varianten, Flächen und Belagwechsel hinweg – die folgt mit der
/// Verschnittoptimierung (M9-01). Ein Stück, das länger als jede
/// [lieferlaengen] (samt Überlänge) ist, ist ein Fehler des Aufrufers.
List<Lieferdiele> zuschneiden(
  Iterable<Millimeter> stuecke,
  List<Millimeter> lieferlaengen, {
  Millimeter ueberlaenge = const Millimeter(0),
  Musterregel muster = Musterregel.frei,
}) {
  final liste = stuecke.toList();
  final laengste = liste.fold(0, (m, s) => s.mm > m ? s.mm : m);
  final mit = verteile(
    liste,
    lieferlaengen,
    ueberlaenge: ueberlaenge,
    muster: muster,
  );
  return besteVerteilung(
    muster.hoechstens == null
        ? [
            mit,
            // ohne Überlänge nur, wo jedes Stück auch ohne sie passt
            if (ueberlaenge.mm > 0 &&
                lieferlaengen.any((l) => l.mm >= laengste))
              verteile(liste, lieferlaengen),
          ]
        : [
            mit,
            if (lieferlaengen.length > 1)
              for (final l in lieferlaengen)
                if (l.mm + ueberlaenge.mm >= laengste)
                  _gekuerzt(
                    verteile(
                      liste,
                      [l],
                      ueberlaenge: ueberlaenge,
                      muster: muster,
                    ),
                    lieferlaengen,
                    ueberlaenge.mm,
                    muster,
                  ),
            ...musterZuschnitte(
              liste,
              lieferlaengen,
              ueberlaenge: ueberlaenge,
              muster: muster,
            ),
          ],
    mehrlaenge: muster.mehrlaenge,
  );
}

/// Die [dielen] je in der kürzesten der [lieferlaengen], aus der ihre
/// Stücke samt Überlänge [u] nach dem [muster] geschnitten werden können.
List<Lieferdiele> _gekuerzt(
  List<Lieferdiele> dielen,
  List<Millimeter> lieferlaengen,
  int u,
  Musterregel muster,
) {
  final laengen = [for (final l in lieferlaengen) l.mm]..sort();
  return [
    for (final d in dielen)
      Lieferdiele(
        Millimeter(muster.kuerzeste(laengen, u, _mm(d.schnitte))),
        d.schnitte,
      ),
  ];
}

List<int> _mm(List<Millimeter> werte) => [for (final w in werte) w.mm];

/// Die Verteilung, die gilt (R-B17, Planungsregeln Alexander (Planungskern
/// v6, 11.11.2026) Regel 1.3): Unter den [kandidaten], die höchstens
/// [mehrlaenge] (Musterverfahren: [mehrlaengeFuerWenigerDielen], 1 %) mehr
/// liefern als die kürzeste, die mit den wenigsten Dielen, dann die
/// kürzeste, dann die erste. Mit 0 gilt die kürzeste (bei gleicher Länge
/// die mit weniger Dielen) wie im alten Planer.
List<Lieferdiele> besteVerteilung(
  List<List<Lieferdiele>> kandidaten, {
  double mehrlaenge = mehrlaengeFuerWenigerDielen,
}) {
  final laengen = [for (final k in kandidaten) _geliefert(k)];
  final grenze = laengen.reduce(math.min) * (1 + mehrlaenge);
  var beste = 0;
  for (var i = 1; i < kandidaten.length; i++) {
    if (laengen[i] > grenze) continue;
    final (n, m) = (kandidaten[i].length, kandidaten[beste].length);
    if (laengen[beste] > grenze ||
        n < m ||
        n == m && laengen[i] < laengen[beste]) {
      beste = i;
    }
  }
  return kandidaten[beste];
}

int _geliefert(List<Lieferdiele> dielen) =>
    dielen.fold(0, (summe, d) => summe + d.laenge.mm);

/// Eine Verteilung wie [zuschneiden], aber nur mit der [ueberlaenge] und
/// allen [lieferlaengen] (ohne den Vergleich) – für schnelle Vorschauen
/// (Verschnittoptimierung).
List<Lieferdiele> verteile(
  Iterable<Millimeter> stuecke,
  List<Millimeter> lieferlaengen, {
  Millimeter ueberlaenge = const Millimeter(0),
  Musterregel muster = Musterregel.frei,
}) {
  final u = ueberlaenge.mm;
  final k = muster.schnitt.mm;
  final folge = [for (final s in stuecke) s.mm]..sort((a, b) => b - a);
  final laengen = [for (final l in lieferlaengen) l.mm]..sort();
  final gruppen = _Gruppen(folge);
  // Schnitte je angefangener Diele
  final offen = <List<int>>[];
  // Rest je Diele nach dem Sägeschnitt hinter dem letzten Stück
  final reste = <int>[];
  // Dielen je Rest, jeweils aufsteigend nach Nummer: der kleinste passende
  // Rest in O(log n), bei Gleichstand die zuerst begonnene Diele
  final nachRest = SplayTreeMap<int, List<int>>();
  void merke(int j) {
    if (!muster.nimmtAuf(offen[j].length, reste[j])) return;
    final ziel = nachRest.putIfAbsent(reste[j], () => []);
    ziel.insert(_einfuegestelle(ziel, j), j);
  }

  for (var i = 0; i < folge.length; i++) {
    final stueck = folge[i];
    final passend = nachRest.firstKeyAfter(stueck - 1);
    if (passend == null) {
      final laenge = _neueLaenge(stueck, gruppen, i + 1, laengen, u, muster);
      offen.add([stueck]);
      reste.add(laenge + u - stueck - k);
      merke(reste.length - 1);
    } else {
      final dielen = nachRest[passend]!;
      final beste = dielen.removeAt(0);
      if (dielen.isEmpty) nachRest.remove(passend);
      offen[beste].add(stueck);
      reste[beste] -= stueck + k;
      merke(beste);
    }
  }
  return [
    for (final schnitte in offen)
      Lieferdiele(Millimeter(muster.kuerzeste(laengen, u, schnitte)), [
        for (final s in schnitte) Millimeter(s),
      ]),
  ];
}

/// Stelle, an der [wert] in die aufsteigende [liste] gehört.
int _einfuegestelle(List<int> liste, int wert) {
  var (unten, oben) = (0, liste.length);
  while (unten < oben) {
    final mitte = (unten + oben) ~/ 2;
    if (liste[mitte] < wert) {
      unten = mitte + 1;
    } else {
      oben = mitte;
    }
  }
  return unten;
}

/// Gleich lange Stücke einer absteigenden Folge als Gruppen (Länge, Ende),
/// damit das Auffüllen einer Diele je Länge statt je Stück rechnet.
final class _Gruppen {
  _Gruppen(List<int> folge) : kleinstes = folge.isEmpty ? 0 : folge.last {
    for (var i = 0; i < folge.length; i++) {
      if (i == 0 || folge[i] != folge[i - 1]) {
        laengen.add(folge[i]);
        anfaenge.add(i);
        enden.add(i);
      }
      enden.last = i + 1;
      gruppe.add(laengen.length - 1);
    }
  }

  final int kleinstes;
  final laengen = <int>[];
  final anfaenge = <int>[];
  final enden = <int>[];

  /// Gruppe je Stück.
  final gruppe = <int>[];
}

/// Lieferlänge für eine neue Diele, die mit [stueck] beginnt: kleinster Rest
/// nach dem Auffüllen mit den Stücken ab [ab] (absteigend, je Länge so viele
/// wie passen und das [muster] erlaubt) aus [gruppen], bei Gleichstand die
/// kürzere; jede Länge nimmt [u] mm Überlänge mehr auf.
int _neueLaenge(
  int stueck,
  _Gruppen gruppen,
  int ab,
  List<int> laengen,
  int u,
  Musterregel muster,
) {
  final k = muster.schnitt.mm;
  int? beste;
  var besterRest = 0;
  for (final laenge in laengen) {
    if (laenge + u < stueck) continue;
    var rest = laenge + u - stueck - k;
    var anzahl = 1;
    if (ab < gruppen.gruppe.length) {
      for (
        var g = gruppen.gruppe[ab];
        g < gruppen.laengen.length &&
            rest >= gruppen.kleinstes &&
            muster.nimmtAuf(anzahl, rest);
        g++
      ) {
        final schritt = gruppen.laengen[g] + k;
        final vorrat =
            gruppen.enden[g] - math.max<int>(ab, gruppen.anfaenge[g]);
        // jedes weitere Stück nur aus einem Rest ab dem Mindestrest
        final nimm = math.min(
          math.min(vorrat, (rest + k) ~/ schritt),
          math.min(
            (rest - muster.wiederverwendetAb.mm) ~/ schritt + 1,
            (muster.hoechstens ?? vorrat + anzahl) - anzahl,
          ),
        );
        rest -= schritt * nimm;
        anzahl += nimm;
      }
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
  /// den [lieferlaengen] samt [ueberlaenge] nach dem [muster] zu
  /// ([zuschneiden]); die
  /// zugeschnittene Breite ist die Breite des Stücks ohne die [fuge], mit der
  /// verlegt wurde.
  factory Teilverlegung(
    List<Dielenstueck> stuecke, {
    required List<Millimeter> lieferlaengen,
    Millimeter ueberlaenge = const Millimeter(0),
    Musterregel muster = Musterregel.frei,
    String? bezeichnung,
    Millimeter fuge = fuge,
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
        muster: muster,
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
    this.muster,
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

  /// Musterverfahren des Zuschnitts (R-B17; Holzfliesen frei) – auch für
  /// die Verschnittoptimierung.
  final Musterregel muster;
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
/// Belag sie liefert, M5-02), [fuge] 6 mm (R-B06, Planungsregeln Alexander
/// (Planungskern v6, 11.11.2026) Regel 1.2; Paritätstests rechnen mit den
/// 5 mm des alten Planers), 3 cm Überlänge (`dielenUeberlaenge`,
/// Planungsregeln Alexander (Planungskern v6, 11.11.2026)): eine Reihe bis
/// 603 cm liegt ohne Stoß auf einer 6-m-Diele; zugeschnitten nach dem
/// Musterverfahren [dielenmuster] ([Musterregel.dielen], R-B17;
/// Paritätstests des Rechenwegs: [Musterregel.frei]). Holzfliesen (606 × 606 mm)
/// liegen wie Dielen in Reihen aus Kantenlänge plus Fuge und werden längs
/// ohne Fuge gestoßen – wie im alten Planer (F25: 7 × 60,6 + 55,8 cm je
/// Reihe; Referenzfall 2026-08-17-1838: Randreihe 25,1 cm), ohne Überlänge
/// und ohne Musterverfahren ([Musterregel.frei]); kurze Stücke
/// werden nie verbunden, eine Fliese über eine Rasterlinie gibt es nicht.
///
/// Die Hauptfläche spart alle Ausschnitte aus (leere Fläche: kein Material,
/// Fachkonzept 1.4). Ein Ausschnitt mit anderem Terrassenbelag ist eine
/// eigene Teilfläche, verlegt ab seiner Ecke oben links – bis er einen
/// eigenen Belag bekommt, mit dem Belag der Fläche (F22).
Belagverlegung? verlegeBelag(
  Planungsstand stand,
  Artikel? belag, {
  Millimeter fuge = fuge,
  Musterregel dielenmuster = Musterregel.dielen,
}) {
  if (stand.grundriss case FreiformGrundriss(geschlossen: false)) return null;
  final masse = belag?.abmessungen;
  final breite = masse?.breite;
  if (breite == null || masse!.laengen.isEmpty) return null;
  final fest = stand.dielenlaenge;
  final (
    List<Millimeter> lieferlaengen,
    bool verbinden,
    Millimeter ueber,
    Musterregel muster,
  )
  art;
  switch (belag!.art) {
    case Artikelart.diele:
      art = (
        masse.laengen.contains(fest) ? [fest!] : masse.laengen,
        stand.kurzeStueckeVerbinden,
        dielenUeberlaenge,
        dielenmuster,
      );
    case Artikelart.holzfliese:
      art = (masse.laengen, false, const Millimeter(0), Musterregel.frei);
    default:
      return null;
  }
  final (lieferlaengen, verbinden, ueberlaenge, muster) = art;
  final kontur = stand.kontur;
  final winkel = stand.dielenwinkel.toDouble();
  final laengste = lieferlaengen.last;
  final grenzen = verschiebungsgrenzen(
    kontur,
    winkel: winkel,
    dielenbreite: breite,
    laengste: laengste,
    ueberlaenge: ueberlaenge,
    fuge: fuge,
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
      fuge: fuge,
    ),
    lieferlaengen: lieferlaengen,
    ueberlaenge: ueberlaenge,
    muster: muster,
    bezeichnung: bezeichnung,
    fuge: fuge,
  );
  return Belagverlegung._(
    ausgangspunkt,
    grenzen,
    lieferlaengen,
    ueberlaenge,
    muster,
    [
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
    ],
  );
}

double _begrenzt(Millimeter wert, Millimeter grenze) =>
    wert.mm.clamp(-grenze.mm, grenze.mm).toDouble();
