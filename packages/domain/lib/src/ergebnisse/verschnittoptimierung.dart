/// Verschnittoptimierung (M9-01, Fachkonzept 7.1): Die Dielenstücke eines
/// Belags werden über alle Teilflächen und Flächen der Planung hinweg auf
/// Lieferlängen verteilt – so wenig geliefert wie möglich (R-B11). Dazu
/// kommen Varianten mit nur einer Lieferlänge, aus denen man wählt.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../artikel/artikel.dart';
import '../artikel/einheiten.dart';
import '../konfiguration/belagverlegung.dart';

/// Verteilt die [stuecke] so auf die [lieferlaengen], dass möglichst wenig
/// geliefert wird (M9-01): die Verteilung [zuschneiden] über alle Stücke
/// zusammen – mit dem Musterverfahren ([Musterregel.dielen], R-B17) füllt sie
/// schon Diele für Diele ([musterZuschnitte]). Ohne ([Musterregel.frei],
/// Holzfliesen, Paritätstests) kommt die Füllung Diele für Diele ohne
/// Einschränkung dazu (Teilsummen auf den Millimeter); es gilt die kürzere
/// ([besteVerteilung]), bei Gleichstand [zuschneiden].
/// Jede Lieferlänge nimmt [ueberlaenge] mehr auf (`dielenUeberlaenge`). Ein
/// Stück, das länger als jede [lieferlaengen] samt Überlänge ist, ist ein
/// Fehler des Aufrufers.
List<Lieferdiele> optimiereZuschnitt(
  Iterable<Millimeter> stuecke,
  List<Millimeter> lieferlaengen, {
  Millimeter ueberlaenge = const Millimeter(0),
  Musterregel muster = Musterregel.frei,
}) {
  final liste = stuecke.toList();
  final verteilt = zuschneiden(
    liste,
    lieferlaengen,
    ueberlaenge: ueberlaenge,
    muster: muster,
  );
  if (muster.hoechstens != null) return verteilt;
  return besteVerteilung([
    verteilt,
    _fuelleDielen(liste, lieferlaengen, ueberlaenge.mm, muster),
  ], mehrlaenge: muster.mehrlaenge);
}

/// Musterverfahren (R-B17, Planungsregeln Alexander (Planungskern v6,
/// 11.11.2026) Regel 1.3) für die [stuecke], zwei Läufe für [zuschneiden]:
///
/// Diele für Diele beginnt das längste offene Stück; für jede Lieferlänge,
/// die es aufnimmt, kommen bis zu zwei weitere Stücke dazu (5 mm
/// Sägeschnitt dazwischen, jedes nur aus einem Rest ab 30 cm) – im ersten
/// Lauf die, die die Diele am vollsten machen, im zweiten das kürzeste
/// offene Stück und dazu das längste, das noch passt (so bleiben am Ende
/// keine kurzen Stücke, die je drei eine ganze Diele brauchen; F04). Gewählt
/// wird die Länge mit dem größten genutzten Anteil, bei Gleichstand die
/// kürzere; sind höchstens [vorschau] Stücke offen, zählt zuerst, was diese
/// Diele plus die Verteilung des Rests ([verteile]) liefert – so bleibt am
/// Ende kein kurzes Stück für eine ganze Diele übrig. Das Muster wird
/// wiederholt, solange die offenen Stücke reichen (die letzte Wiederholung
/// wird neu entschieden) – so bleiben auch viele gleiche Flächen
/// (Häufigkeit, M4-14) schnell. [muster] ist [Musterregel.dielen].
List<List<Lieferdiele>> musterZuschnitte(
  List<Millimeter> stuecke,
  List<Millimeter> lieferlaengen, {
  required Millimeter ueberlaenge,
  required Musterregel muster,
}) => [
  for (final kleinstes in const [false, true])
    _fuelleDielen(
      stuecke,
      lieferlaengen,
      ueberlaenge.mm,
      muster,
      kleinstes: kleinstes,
    ),
];

int _geliefert(List<Lieferdiele> dielen) =>
    dielen.fold(0, (summe, d) => summe + d.laenge.mm);

/// Ab so wenigen offenen Stücken wählt [musterZuschnitte] eine Diele mit
/// Blick auf den Rest (Laufzeit, M9-01).
const vorschau = 60;

/// Füllt Diele für Diele ([musterZuschnitte]); ohne Höchstzahl der Stücke
/// ([Musterregel.frei]) so voll wie möglich mit beliebig vielen Stücken.
List<Lieferdiele> _fuelleDielen(
  List<Millimeter> stuecke,
  List<Millimeter> lieferlaengen,
  int u,
  Musterregel regel, {
  bool kleinstes = false,
}) {
  final laengen = [for (final l in lieferlaengen) l.mm]..sort();
  final gruppen = <int, int>{};
  for (final s in stuecke) {
    gruppen.update(s.mm, (n) => n + 1, ifAbsent: () => 1);
  }
  final sorten = gruppen.keys.toList()..sort((a, b) => b - a);
  final offen = [for (final s in sorten) gruppen[s]!];
  final dielen = <Lieferdiele>[];
  var verbleibend = stuecke.length;
  for (var erste = 0; erste < sorten.length; erste++) {
    final anfang = sorten[erste];
    while (offen[erste] > 0) {
      offen[erste]--;
      final vorrat = regel.hoechstens == null ? null : _Vorrat(sorten, offen);
      ({int laenge, int genutzt, int gesamt, Map<int, int> muster})? beste;
      for (final laenge in laengen) {
        if (laenge + u < anfang) continue;
        final platz = laenge + u - anfang - regel.schnitt.mm;
        final (:summe, :muster) = regel.hoechstens == null
            ? _fuelle(platz, sorten, offen)
            : kleinstes
            ? _mitKleinstem(platz, vorrat!, regel)
            : _fuelleMuster(platz, vorrat!, regel);
        final genutzt = anfang + summe;
        // Vorschau auf den Rest erst gegen Ende: dort entscheidet sie
        final gesamt = verbleibend > vorschau
            ? 0
            : laenge + _rest(sorten, offen, muster, lieferlaengen, u, regel);
        if (beste == null ||
            gesamt < beste.gesamt ||
            gesamt == beste.gesamt &&
                genutzt * beste.laenge > beste.genutzt * laenge) {
          beste = (
            laenge: laenge,
            genutzt: genutzt,
            gesamt: gesamt,
            muster: muster,
          );
        }
      }
      // jedes Stück passt in eine Länge – das prüft schon [zuschneiden]
      final (:muster, laenge: _, genutzt: _, gesamt: _) = beste!;
      offen[erste]++;
      final diele = {...muster, erste: (muster[erste] ?? 0) + 1};
      // die letzte Wiederholung wird neu entschieden (Ende der Stücke)
      final wiederholung = math.max(
        1,
        [for (final MapEntry(key: i, value: n) in diele.entries) offen[i] ~/ n]
                .reduce(math.min) -
            1,
      );
      final schnitte = [
        for (final MapEntry(key: i, value: n) in diele.entries)
          for (var k = 0; k < n; k++) Millimeter(sorten[i]),
      ]..sort((a, b) => b.mm - a.mm);
      // die kürzeste Lieferlänge, aus der die Stücke geschnitten werden können
      final laenge = regel.kuerzeste(laengen, u, [
        for (final s in schnitte) s.mm,
      ]);
      for (final MapEntry(key: i, value: n) in diele.entries) {
        offen[i] -= n * wiederholung;
        verbleibend -= n * wiederholung;
      }
      for (var k = 0; k < wiederholung; k++) {
        dielen.add(Lieferdiele(Millimeter(laenge), schnitte));
      }
    }
  }
  return dielen;
}

/// Was die Verteilung je Teilfläche ([verteile]) für die offenen Stücke
/// ohne [muster] liefert (mm) – die Vorschau, mit der eine Diele gewählt
/// wird.
int _rest(
  List<int> sorten,
  List<int> offen,
  Map<int, int> muster,
  List<Millimeter> lieferlaengen,
  int u,
  Musterregel regel,
) => _geliefert(
  verteile(
    [
      for (final (i, s) in sorten.indexed)
        for (var k = 0; k < offen[i] - (muster[i] ?? 0); k++) Millimeter(s),
    ],
    lieferlaengen,
    ueberlaenge: Millimeter(u),
    muster: regel,
  ),
);

/// Größte Summe aus den offenen Stücken (je Sorte [sorten] höchstens
/// [offen] Stück), die in [platz] mm passt, und wie viele je Sorte sie
/// nutzt. Teilsummen als Bitfeld; mehrfache Stücke einer Sorte werden in
/// Bündel 1, 2, 4 … zerlegt.
({int summe, Map<int, int> muster}) _fuelle(
  int platz,
  List<int> sorten,
  List<int> offen,
) {
  final buendel = <(int sorte, int anzahl)>[];
  for (final (i, s) in sorten.indexed) {
    var rest = offen[i] < platz ~/ s ? offen[i] : platz ~/ s;
    for (var n = 1; rest > 0; n *= 2) {
      final teil = n < rest ? n : rest;
      buendel.add((i, teil));
      rest -= teil;
    }
  }
  final worte = (platz >> 5) + 1;
  // Bitfeld je Stand: vor Bündel 0, nach Bündel 0, … (Rückverfolgung)
  final felder = Uint32List(worte * (buendel.length + 1))..[0] = 1;
  for (final (b, (i, n)) in buendel.indexed) {
    final schritt = sorten[i] * n;
    final (q, r) = (schritt >> 5, schritt & 31);
    final alt = b * worte;
    final neu = alt + worte;
    for (var j = 0; j < worte; j++) {
      var wert = felder[alt + j];
      if (j >= q) {
        wert |= felder[alt + j - q] << r;
        if (r > 0 && j > q) wert |= felder[alt + j - q - 1] >> (32 - r);
      }
      felder[neu + j] = wert;
    }
  }
  bool erreicht(int stand, int summe) =>
      felder[stand * worte + (summe >> 5)] & (1 << (summe & 31)) != 0;
  var summe = platz;
  while (!erreicht(buendel.length, summe)) {
    summe--;
  }
  final muster = <int, int>{};
  var ziel = summe;
  for (var b = buendel.length - 1; b >= 0; b--) {
    if (erreicht(b, ziel)) continue;
    final (i, n) = buendel[b];
    muster.update(i, (m) => m + n, ifAbsent: () => n);
    ziel -= sorten[i] * n;
  }
  return (summe: summe, muster: muster);
}

/// Offene Stücke für die Füllung einer Diele nach dem Musterverfahren
/// ([Musterregel.dielen]: drei Stücke je Diele): die Sorten mit offenen
/// Stücken, absteigend nach Länge.
final class _Vorrat {
  _Vorrat(this.sorten, this.offen)
    : frei = [
        for (var i = 0; i < sorten.length; i++)
          if (offen[i] > 0) i,
      ];

  final List<int> sorten;
  final List<int> offen;

  /// Sorten mit offenen Stücken (Index in [sorten]), absteigend nach Länge.
  final List<int> frei;

  int laenge(int stelle) => sorten[frei[stelle]];

  /// Erste Stelle in [frei] ab [ab] mit höchstens [platz] mm.
  int ersteBis(int platz, [int ab = 0]) {
    var (unten, oben) = (ab, frei.length);
    while (unten < oben) {
      final mitte = (unten + oben) ~/ 2;
      if (laenge(mitte) > platz) {
        unten = mitte + 1;
      } else {
        oben = mitte;
      }
    }
    return unten;
  }

  /// Erste Stelle ab [stelle], die noch ein Stück hat, wenn an [besetzt]
  /// schon eins genommen ist.
  int naechste(int stelle, int besetzt) =>
      stelle == besetzt && offen[frei[stelle]] < 2 ? stelle + 1 : stelle;

  ({int summe, Map<int, int> muster}) wahl(List<int> stellen) {
    final muster = <int, int>{};
    var summe = 0;
    for (final s in stellen) {
      muster.update(frei[s], (n) => n + 1, ifAbsent: () => 1);
      summe += laenge(s);
    }
    return (summe: summe, muster: muster);
  }
}

/// Wie [_fuelle], aber nach dem Musterverfahren [regel] (R-B17): bis zu zwei
/// weitere Stücke (drei je Diele), nach jedem der Sägeschnitt, und ein Stück
/// nur aus einem Rest ab dem Mindestrest. Geschnitten wird absteigend; die
/// Paare sucht ein Zeigerpaar über die offenen Sorten (das zweite Stück wird
/// länger, wenn das erste kürzer wird). Bei gleicher Summe gilt ein Stück
/// vor zweien.
({int summe, Map<int, int> muster}) _fuelleMuster(
  int platz,
  _Vorrat vorrat,
  Musterregel regel,
) {
  final k = regel.schnitt.mm;
  final ab = regel.wiederverwendetAb.mm;
  if (platz < ab) return (summe: 0, muster: const {});
  final eins = vorrat.ersteBis(platz);
  var beste = eins < vorrat.frei.length ? [eins] : const <int>[];
  var summe = beste.isEmpty ? 0 : vorrat.laenge(eins);
  var zweites = vorrat.frei.length;
  for (var i = vorrat.ersteBis(platz - k - ab); i < vorrat.frei.length; i++) {
    final b = vorrat.laenge(i);
    if (2 * b <= summe) break;
    // das zweite Stück: höchstens so lang wie b, passt in den Rest nach b
    while (zweites > i && vorrat.laenge(zweites - 1) <= platz - b - k) {
      zweites--;
    }
    final c = vorrat.naechste(math.max(zweites, i), i);
    if (c < vorrat.frei.length && b + vorrat.laenge(c) > summe) {
      beste = [i, c];
      summe = b + vorrat.laenge(c);
    }
  }
  return vorrat.wahl(beste);
}

/// Füllung für den zweiten Lauf von [musterZuschnitte]: das kürzeste offene
/// Stück und dazu das längste, das davor noch passt (geschnitten wird
/// absteigend, das kürzeste zuletzt aus einem Rest ab dem Mindestrest).
/// Passt das kürzeste nicht, gilt [_fuelleMuster].
({int summe, Map<int, int> muster}) _mitKleinstem(
  int platz,
  _Vorrat vorrat,
  Musterregel regel,
) {
  final k = regel.schnitt.mm;
  final ab = regel.wiederverwendetAb.mm;
  final c = vorrat.frei.length - 1;
  if (c < 0 || platz < ab || vorrat.laenge(c) > platz) {
    return _fuelleMuster(platz, vorrat, regel);
  }
  final grenze = platz - k - math.max<int>(vorrat.laenge(c), ab);
  final b = vorrat.naechste(vorrat.ersteBis(grenze), c);
  return vorrat.wahl(b < vorrat.frei.length ? [b, c] : [c]);
}

/// Stücke eines Belags über die ganze Planung (M9-01): alle Teilflächen
/// aller Flächen mit derselben Auswahl an [laengen], jede Fläche mal ihrer
/// Häufigkeit; [ueberlaenge] der Lieferlängen (`Belagverlegung.ueberlaenge`)
/// und das Musterverfahren [muster] (`Belagverlegung.muster`, R-B17).
typedef Belagstuecke = ({
  Artikelnummer belag,
  List<Millimeter> laengen,
  List<Millimeter> stuecke,
  Millimeter ueberlaenge,
  Musterregel muster,
});

/// Eine Verschnittvariante (M9-01): Lieferdielen je Belag der ganzen
/// Planung.
final class Verschnittvariante {
  Verschnittvariante(Map<Artikelnummer, List<Lieferdiele>> zuschnitt)
    : zuschnitt = Map.unmodifiable({
        for (final MapEntry(:key, :value) in zuschnitt.entries)
          key: List<Lieferdiele>.unmodifiable(value),
      });

  /// Lieferdielen je Belag.
  final Map<Artikelnummer, List<Lieferdiele>> zuschnitt;

  /// Dielenliste je Belag.
  Map<Artikelnummer, Dielenliste> get dielenlisten => {
    for (final MapEntry(:key, :value) in zuschnitt.entries)
      key: Dielenliste.aus(value),
  };

  /// Dielenliste aller Beläge zusammen – für den Verschnitt.
  Dielenliste get summe =>
      dielenlisten.values.fold(Dielenliste.leer, (a, b) => a + b);
}

/// Bis zu [hoechstens] Verschnittvarianten der ganzen Planung (M9-01,
/// Fachkonzept 7.1), die mit dem geringsten Verschnitt zuerst.
///
/// Je Belag (mit seiner Auswahl an Lieferlängen und seinem Musterverfahren)
/// gibt es die optimierte
/// Verteilung über alle Längen ([optimiereZuschnitt]) und je Lieferlänge,
/// die das längste Stück aufnimmt, eine Verteilung nur in dieser Länge –
/// wie die Varianten des alten Planers (F43: 4 % in 500 cm, 12,73 % in
/// 550 cm, 20 % in 600 cm). Gleiche Dielenlisten zählen einmal; zuerst die
/// nach der 1-%-Regel beste ([besteVerteilung], R-B17), dann sortiert nach
/// gelieferter Länge und Anzahl der Dielen. Variante k nimmt je
/// Belag dessen k-te (oder letzte) Verteilung.
List<Verschnittvariante> verschnittvarianten(
  List<Belagstuecke> belaege, {
  int hoechstens = 3,
}) {
  final je = [for (final b in belaege) _verteilungen(b)];
  final anzahl = je.fold(0, (n, v) => math.max(n, v.length));
  return [
    for (var k = 0; k < math.min(anzahl, hoechstens); k++)
      Verschnittvariante(_variante(belaege, je, k)),
  ];
}

/// Je Belag die [k]-te (oder letzte) seiner Verteilungen [je].
Map<Artikelnummer, List<Lieferdiele>> _variante(
  List<Belagstuecke> belaege,
  List<List<List<Lieferdiele>>> je,
  int k,
) {
  final zuschnitt = <Artikelnummer, List<Lieferdiele>>{};
  for (final (i, b) in belaege.indexed) {
    final v = je[i];
    zuschnitt
        .putIfAbsent(b.belag, () => [])
        .addAll(v[math.min(k, v.length - 1)]);
  }
  return zuschnitt;
}

/// Verschiedene Verteilungen der Stücke eines Belags, die beste zuerst.
List<List<Lieferdiele>> _verteilungen(Belagstuecke b) {
  final laengste = b.stuecke.fold(0, (m, s) => s.mm > m ? s.mm : m);
  final u = b.ueberlaenge;
  final kandidaten = [
    optimiereZuschnitt(b.stuecke, b.laengen, ueberlaenge: u, muster: b.muster),
    for (final l in [...b.laengen]..sort((x, y) => x.mm - y.mm))
      if (l.mm + u.mm >= laengste)
        optimiereZuschnitt(b.stuecke, [l], ueberlaenge: u, muster: b.muster),
  ];
  // die nach der 1-%-Regel beste zuerst (R-B17)
  final erste = kandidaten.indexOf(
    besteVerteilung(kandidaten, mehrlaenge: b.muster.mehrlaenge),
  );
  final reihenfolge = [for (var i = 0; i < kandidaten.length; i++) i]
    ..sort((x, y) {
      if (x == erste || y == erste) return x == erste ? -1 : 1;
      final (a, c) = (kandidaten[x], kandidaten[y]);
      final laenge = _geliefert(a) - _geliefert(c);
      if (laenge != 0) return laenge;
      final dielen = a.length - c.length;
      return dielen != 0 ? dielen : x - y;
    });
  final gesehen = <String>{};
  return [
    for (final i in reihenfolge)
      if (gesehen.add(_schluessel(kandidaten[i]))) kandidaten[i],
  ];
}

String _schluessel(List<Lieferdiele> dielen) => [
  for (final MapEntry(:key, :value) in Dielenliste.aus(dielen).anzahl.entries)
    '${key.mm}:$value',
].join(',');
