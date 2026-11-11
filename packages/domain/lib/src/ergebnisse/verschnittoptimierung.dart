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
/// geliefert wird (M9-01).
///
/// Diele für Diele: Das längste noch offene Stück beginnt eine Diele; für
/// jede Lieferlänge, die es aufnimmt, wird der Rest so voll wie möglich mit
/// offenen Stücken gefüllt (Teilsummen auf den Millimeter). Gewählt wird die
/// Länge mit dem größten genutzten Anteil, bei Gleichstand die kürzere; sind
/// höchstens [vorschau] Stücke offen, zählt zuerst, was diese Diele plus die
/// Verteilung des Rests ([zuschneiden]) liefert – so bleibt am Ende kein
/// kurzes Stück für eine ganze Diele übrig. Das Muster wird wiederholt,
/// solange die offenen Stücke reichen (die letzte Wiederholung wird neu
/// entschieden) – so bleiben auch viele gleiche Flächen (Häufigkeit, M4-14)
/// schnell.
///
/// Das Ergebnis ist nie schlechter als die Verteilung je Teilfläche
/// ([zuschneiden], M5-08): Liefert sie weniger (oder gleich viel in weniger
/// Dielen), gilt sie. Gesägt wird ohne Zugabe wie im alten Planer; jede
/// Lieferlänge nimmt [ueberlaenge] mehr auf (`dielenUeberlaenge`). Ein
/// Stück, das länger als jede [lieferlaengen] samt Überlänge ist, ist ein
/// Fehler des Aufrufers.
List<Lieferdiele> optimiereZuschnitt(
  Iterable<Millimeter> stuecke,
  List<Millimeter> lieferlaengen, {
  Millimeter ueberlaenge = const Millimeter(0),
}) {
  final liste = stuecke.toList();
  final regel = zuschneiden(liste, lieferlaengen, ueberlaenge: ueberlaenge);
  final optimiert = _fuelleDielen(liste, lieferlaengen, ueberlaenge.mm);
  return liefertWeniger(optimiert, regel) ? optimiert : regel;
}

int _geliefert(List<Lieferdiele> dielen) =>
    dielen.fold(0, (summe, d) => summe + d.laenge.mm);

/// Ab so wenigen offenen Stücken wählt [optimiereZuschnitt] eine Diele mit
/// Blick auf den Rest (Laufzeit, M9-01).
const vorschau = 60;

List<Lieferdiele> _fuelleDielen(
  List<Millimeter> stuecke,
  List<Millimeter> lieferlaengen,
  int u,
) {
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
      ({int laenge, int genutzt, int gesamt, Map<int, int> muster})? beste;
      for (final laenge in laengen) {
        if (laenge + u < anfang) continue;
        final (:summe, :muster) = _fuelle(laenge + u - anfang, sorten, offen);
        final genutzt = anfang + summe;
        // Vorschau auf den Rest erst gegen Ende: dort entscheidet sie
        final gesamt = verbleibend > vorschau
            ? 0
            : laenge + _rest(sorten, offen, muster, lieferlaengen, u);
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
      final (:laenge, :muster, genutzt: _, gesamt: _) = beste!;
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

/// Was die Verteilung je Teilfläche ([zuschneiden]) für die offenen Stücke
/// ohne [muster] liefert (mm) – die Vorschau, mit der eine Diele gewählt
/// wird.
int _rest(
  List<int> sorten,
  List<int> offen,
  Map<int, int> muster,
  List<Millimeter> lieferlaengen,
  int u,
) => _geliefert(
  zuschneiden(
    [
      for (final (i, s) in sorten.indexed)
        for (var k = 0; k < offen[i] - (muster[i] ?? 0); k++) Millimeter(s),
    ],
    lieferlaengen,
    ueberlaenge: Millimeter(u),
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

/// Stücke eines Belags über die ganze Planung (M9-01): alle Teilflächen
/// aller Flächen mit derselben Auswahl an [laengen], jede Fläche mal ihrer
/// Häufigkeit; [ueberlaenge] der Lieferlängen (`Belagverlegung.ueberlaenge`).
typedef Belagstuecke = ({
  Artikelnummer belag,
  List<Millimeter> laengen,
  List<Millimeter> stuecke,
  Millimeter ueberlaenge,
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
/// Je Belag (mit seiner Auswahl an Lieferlängen) gibt es die optimierte
/// Verteilung über alle Längen ([optimiereZuschnitt]) und je Lieferlänge,
/// die das längste Stück aufnimmt, eine Verteilung nur in dieser Länge –
/// wie die Varianten des alten Planers (F43: 4 % in 500 cm, 12,73 % in
/// 550 cm, 20 % in 600 cm). Gleiche Dielenlisten zählen einmal; sortiert
/// nach gelieferter Länge, dann Anzahl der Dielen. Variante k nimmt je
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
    optimiereZuschnitt(b.stuecke, b.laengen, ueberlaenge: u),
    for (final l in [...b.laengen]..sort((x, y) => x.mm - y.mm))
      if (l.mm + u.mm >= laengste)
        optimiereZuschnitt(b.stuecke, [l], ueberlaenge: u),
  ];
  final reihenfolge = [for (var i = 0; i < kandidaten.length; i++) i]
    ..sort((x, y) {
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
