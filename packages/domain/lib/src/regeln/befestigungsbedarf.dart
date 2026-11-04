/// Befestigungsartikel und Mengen des Belags (M5-09, Fachkonzept 2.6) nach
/// dem Regelwerk der Artikeldaten und den Firmenregeln der Holzart (R-B01,
/// R-B02: B-094, B-150, B-074, B-090).
library;

import 'dart:math' as math;

import '../artikel/artikel.dart';
import '../artikel/einheiten.dart';
import '../ergebnisse/materialliste.dart';
import '../holzart/holzart.dart';
import '../konfiguration/befestigungsart.dart';
import '../konfiguration/dielenverlegung.dart';
import 'belagmeldungen.dart';
import 'regelwerk.dart';

/// Eine Position der Befestigung: Artikel und Anzahl Verkaufseinheiten
/// (z. B. 2 × CLIP-FIXX VPE 250).
final class Befestigungsposition {
  const Befestigungsposition(this.nummer, this.titel, this.anzahl);

  final Artikelnummer nummer;
  final String titel;

  /// Anzahl Verkaufseinheiten.
  final int anzahl;

  @override
  bool operator ==(Object other) =>
      other is Befestigungsposition &&
      other.nummer == nummer &&
      other.titel == titel &&
      other.anzahl == anzahl;

  @override
  int get hashCode => Object.hash(nummer, titel, anzahl);

  @override
  String toString() => '$anzahl × $nummer $titel';
}

/// Befestigungspunkte der Verlegung: jede Kreuzung eines Dielenstücks mit
/// einer UK-Linie ([punkte]) und davon die Punkte der äußeren Reihe
/// ([randpunkte]), deren freie Längskante einen eigenen Clip braucht.
typedef Befestigungspunkte = ({int punkte, int randpunkte});

/// Lage eines Dielenstücks quer gedreht: von [anfang] bis [ende] in
/// Verlegerichtung, von [unten] bis [oben] quer dazu (mm).
typedef Uklage = ({double anfang, double ende, double unten, double oben});

/// Übergangs-Unterkonstruktion, solange die Unterkonstruktion fehlt (M6):
/// Die UK-Linien liegen quer zur Verlegerichtung gleichmäßig über die
/// Ausdehnung der Verlegung, höchstens [ukAbstand] auseinander, die äußeren
/// am Rand (keine Überstände, B-096) – 480 cm mit 40 cm: 13 Linien wie in
/// F01. [lagen] parallel zu den [stuecke]n, [linien] als Lage in
/// Verlegerichtung. Grundlage für Befestigung (M5-09) und Zubehör (M8-02).
({List<Uklage> lagen, List<double> linien}) uebergangsUk(
  List<Dielenstueck> stuecke, {
  required double winkel,
  required Millimeter ukAbstand,
}) {
  if (stuecke.isEmpty) return (lagen: const [], linien: const []);
  final drehung = -winkel * math.pi / 180;
  final lagen = [
    for (final s in stuecke)
      () {
        final p = [for (final q in s.umriss) q.gedreht(drehung)];
        final x = p.map((q) => q.x);
        final y = p.map((q) => q.y);
        return (
          anfang: x.reduce(math.min),
          ende: x.reduce(math.max),
          unten: y.reduce(math.min),
          oben: y.reduce(math.max),
        );
      }(),
  ];
  final von = lagen.map((l) => l.anfang).reduce(math.min);
  final bis = lagen.map((l) => l.ende).reduce(math.max);
  final felder = math.max(1, ((bis - von) / ukAbstand.mm - 1e-6).ceil());
  return (
    lagen: lagen,
    linien: [for (var k = 0; k <= felder; k++) von + (bis - von) * k / felder],
  );
}

/// Zählt die Befestigungspunkte der [stuecke] (M5-09) auf der
/// Übergangs-UK ([uebergangsUk]). Jedes Dielenstück liegt an beiden Enden
/// auf (am Stoß zwei UK nebeneinander, F09: 22 statt 21 Linien) und
/// dazwischen auf jeder Linie, die es überdeckt.
Befestigungspunkte befestigungspunkte(
  List<Dielenstueck> stuecke, {
  required double winkel,
  required Millimeter ukAbstand,
}) {
  if (stuecke.isEmpty) return (punkte: 0, randpunkte: 0);
  final (:lagen, :linien) = uebergangsUk(
    stuecke,
    winkel: winkel,
    ukAbstand: ukAbstand,
  );
  final randreihe = stuecke.map((s) => s.reihe).reduce(math.max);
  var punkte = 0;
  var randpunkte = 0;
  for (final (i, s) in stuecke.indexed) {
    final anfang = lagen[i].anfang + _toleranz;
    final ende = lagen[i].ende - _toleranz;
    final auflagen = 2 + linien.where((x) => x > anfang && x < ende).length;
    punkte += auflagen;
    if (s.reihe == randreihe) randpunkte += auflagen;
  }
  return (punkte: punkte, randpunkte: randpunkte);
}

/// Eine UK-Linie unter dem Ende eines Stücks zählt nicht doppelt.
const _toleranz = 1.0;

/// Verkaufseinheiten für [stueck] Stück aus den [einheiten] (z. B. VPE 50,
/// 100, 250): so wenig Überhang wie möglich, dann so wenig Packungen wie
/// möglich (F01: 637 Clips → 2 × 250 + 100 + 50). Ergebnis in der
/// Reihenfolge der [einheiten], ohne Einheiten mit Anzahl 0. [inhalt]
/// liefert den Inhalt einer Einheit, wenn er nicht der Inhalt der
/// Verkaufseinheit ist (Öl in Zentilitern, M8-02).
List<(Artikel, int)> verpackt(
  int stueck,
  List<Artikel> einheiten, {
  int Function(Artikel)? inhalt,
}) {
  if (stueck <= 0 || einheiten.isEmpty) return const [];
  final inhalte = [
    for (final e in einheiten) inhalt?.call(e) ?? e.einheit.inhalt.ceil(),
  ];
  // jeder Bereich so lang wie die größte Packung enthält ein Vielfaches davon
  final grenze = stueck + inhalte.reduce(math.max);
  final packungen = List<int?>.filled(grenze, null)..[0] = 0;
  final letzte = List.filled(grenze, 0);
  for (var t = 1; t < grenze; t++) {
    for (final (i, inhalt) in inhalte.indexed) {
      if (inhalt > t) continue;
      final vorher = packungen[t - inhalt];
      if (vorher == null) continue;
      if (packungen[t] case final bisher? when bisher <= vorher + 1) continue;
      packungen[t] = vorher + 1;
      letzte[t] = i;
    }
  }
  var t = stueck;
  while (packungen[t] == null) {
    t++;
  }
  final anzahl = List.filled(einheiten.length, 0);
  while (t > 0) {
    anzahl[letzte[t]]++;
    t -= inhalte[letzte[t]];
  }
  return [
    for (final (i, e) in einheiten.indexed)
      if (anzahl[i] > 0) (e, anzahl[i]),
  ];
}

/// Befestigung einer Verlegung: wählbare Arten, die wirksame Art, die
/// Befestigungspunkte und die Artikel mit Anzahl.
final class Befestigungsbedarf {
  Befestigungsbedarf({
    this.arten = const [],
    this.art,
    this.punkte = 0,
    List<Befestigungsposition> mittel = const [],
    List<Materialbedarf> bedarf = const [],
  }) : mittel = List.unmodifiable(mittel),
       bedarf = List.unmodifiable(bedarf);

  /// Ohne Befestigung (Holzfliese, kein Holzbelag).
  static final keiner = Befestigungsbedarf();

  /// Wählbare Befestigungsarten des Belags (`Befestigungsart.fuer`).
  final List<Befestigungsart> arten;

  /// Wirksame Befestigungsart; `null` ohne wählbare Art.
  final Befestigungsart? art;

  /// Befestigungspunkte (Kreuzungen Diele–UK).
  final int punkte;

  /// Befestigungsartikel mit Anzahl Verkaufseinheiten.
  final List<Befestigungsposition> mittel;

  /// Bedarf in Stück für die Materialliste (M9-03): Über mehrere Flächen
  /// wird erst die Summe verpackt, nicht jede Fläche für sich.
  final List<Materialbedarf> bedarf;
}

/// Befestigung des [belag] für die verlegten [stuecke] mit der gewählten
/// Art [gewaehlt] (M5-09).
///
/// - **Clips** (genutet, B-094/R-B01): ein Clip je Befestigungspunkt, dazu
///   einer je Punkt der äußeren Reihe; CLIP-FIXX unter 100 mm, DUO-CLIP-FIXX
///   für genutete PREMIUM SELECT ab 100 mm. Die Clipschrauben sind im
///   Lieferumfang (B-074, B-150) und keine eigene Position.
/// - **Verschraubt** (glattkant, B-090/R-B02): je Punkt eine Schraube, ab
///   100 mm zwei; Schraubenlänge mindestens doppelte Dielenstärke.
/// - **Mit Abstandshaltern:** zusätzlich eine Packung Montagehilfe
///   (wiederverwendbare Abstandshalter für die Fuge von 5 mm – die Clips
///   geben sie sonst selbst vor; Alexander 04.11.2026). Einweg-Abstandshalter
///   (4/7 mm) passen nicht zur Fuge und werden nicht gewählt.
///
/// Die Artikel kommen aus den Befestigungsverweisen des Belags; Preise und
/// Verkaufseinheiten unverändert aus den Artikeldaten (B-153). Abstand der
/// UK: der des Belags laut Artikeldaten, höchstens der der Holzart (R-C01).
Befestigungsbedarf befestigungsbedarf(
  Regelwerk regelwerk,
  Artikel belag,
  Befestigungsart gewaehlt,
  List<Dielenstueck> stuecke, {
  required double winkel,
}) {
  final (holzart, serie, profil, breite) = (
    belag.holzart,
    belag.serie,
    belag.profil,
    belag.abmessungen.breite,
  );
  final art = gewaehlt.wirksam(profil);
  if (holzart == null ||
      serie == null ||
      profil == null ||
      breite == null ||
      art == null) {
    return Befestigungsbedarf.keiner;
  }
  final (:punkte, :randpunkte) = befestigungspunkte(
    stuecke,
    winkel: winkel,
    ukAbstand: ukAbstandFuer(regelwerk, belag, holzart),
  );
  final moeglich = regelwerk.moeglich(belag.nummer, Beziehung.befestigung);
  final bedarf = [
    for (final (einheiten, stueck, jePlanung) in switch (art) {
      Befestigungsart.clips => [
        (
          _clips(moeglich, holzart.serie(serie).befestigung(profil, breite)),
          punkte + randpunkte,
          false,
        ),
      ],
      _ => [
        (
          _schrauben(moeglich, belag.abmessungen.staerke),
          punkte * holzart.schraubenJePunkt(serie, profil, breite),
          false,
        ),
        if (art == Befestigungsart.verschraubtMitAbstandshaltern)
          ([?_montagehilfe(regelwerk)], 1, true),
      ],
    })
      if (einheiten.isNotEmpty)
        Materialbedarf(einheiten, stueck, jePlanung: jePlanung),
  ];
  return Befestigungsbedarf(
    arten: Befestigungsart.fuer(profil),
    art: art,
    punkte: punkte,
    mittel: [
      for (final b in bedarf)
        for (final (a, anzahl) in verpackt(b.stueck, b.einheiten))
          Befestigungsposition(a.nummer, a.titel, anzahl),
    ],
    bedarf: bedarf,
  );
}

/// UK-Achsabstand für den [belag]: der Abstand laut Artikeldaten, höchstens
/// der der [holzart] (R-C01).
Millimeter ukAbstandFuer(Regelwerk regelwerk, Artikel belag, Holzart holzart) {
  final ukArtikel = regelwerk.abstaende(belag.nummer).uk;
  return ukArtikel != null && ukArtikel < holzart.ukAchsabstandMax
      ? ukArtikel
      : holzart.ukAchsabstandMax;
}

/// Meldungen zur Befestigung des [belag] mit der gewählten Art [gewaehlt]
/// (M5-10): eine Verschraubung, die bei genuteten Dielen nicht gilt (dann
/// Clips, B-094; die Vorgabe Clips bei glattkanten Dielen meldet nichts),
/// fehlende Clips oder Schrauben in den Befestigungsverweisen (B-122) und
/// eine Schraube unter der doppelten Dielenstärke. Ohne Holzart, Serie,
/// Profil oder Breite (Holzfliese) keine Meldung.
List<Belagmeldung> befestigungsmeldungen(
  Regelwerk regelwerk,
  Artikel belag,
  Befestigungsart gewaehlt,
) {
  final (holzart, serie, profil, breite) = (
    belag.holzart,
    belag.serie,
    belag.profil,
    belag.abmessungen.breite,
  );
  if (holzart == null || serie == null || profil == null || breite == null) {
    return const [];
  }
  // mit Profil gibt es immer eine wählbare Art
  final art = gewaehlt.wirksam(profil)!;
  final moeglich = regelwerk.moeglich(belag.nummer, Beziehung.befestigung);
  final schrauben = [
    for (final a in moeglich)
      if (a.art == Artikelart.schraube) a.abmessungen.laengste?.mm ?? 0,
  ];
  final staerke = belag.abmessungen.staerke;
  final geschraubt = art != Befestigungsart.clips;
  return [
    if (art != gewaehlt && gewaehlt != Befestigungsart.clips)
      Belagmeldung.befestigungsartNichtMoeglich,
    if (geschraubt
        ? schrauben.isEmpty
        : _clips(
            moeglich,
            holzart.serie(serie).befestigung(profil, breite),
          ).isEmpty)
      Belagmeldung.befestigungOhneArtikel,
    if (geschraubt &&
        schrauben.isNotEmpty &&
        staerke != null &&
        schrauben.reduce(math.max) < 2 * staerke.mm)
      Belagmeldung.schraubeZuKurz,
  ];
}

/// Clips aus [moeglich], die zur [regel] passen: DUO-CLIP-FIXX nur für
/// DUO-CLIP-FIXX (B-094, B-150).
List<Artikel> _clips(List<Artikel> moeglich, Befestigung regel) => [
  for (final a in moeglich)
    if (a.art == Artikelart.clip &&
        _istDuoClip(a) == (regel == Befestigung.duoClipFixx))
      a,
];

/// DUO-CLIP-FIXX und CLIP-FIXX sind beide Clips; unterscheiden lassen sie
/// sich nur am Titel, der wie im Shop lautet (B-152).
bool _istDuoClip(Artikel a) => a.titel.contains('DUO');

/// Schrauben einer Länge aus [moeglich]: die kürzeste, die mindestens die
/// doppelte Dielenstärke hat (21–25 mm → 50 mm), sonst die längste.
List<Artikel> _schrauben(List<Artikel> moeglich, Millimeter? staerke) {
  final schrauben = [
    for (final a in moeglich)
      if (a.art == Artikelart.schraube) a,
  ];
  final laengen = {
    for (final s in schrauben) s.abmessungen.laengste?.mm ?? 0,
  }.toList()..sort();
  if (laengen.isEmpty) return const [];
  final mindest = 2 * (staerke?.mm ?? 0);
  final laenge = laengen.firstWhere(
    (l) => l >= mindest,
    orElse: () => laengen.last,
  );
  return [
    for (final s in schrauben)
      if ((s.abmessungen.laengste?.mm ?? 0) == laenge) s,
  ];
}

/// Montagehilfe aus den Artikeldaten: der erste Artikel, dessen Titel
/// „Montagehilfe Abstandshalter“ enthält – die Upload-Datei kennt keine
/// Beziehung Belag → Abstandshalter (Fachkonzept 2.6).
Artikel? _montagehilfe(Regelwerk regelwerk) => regelwerk.datei.eintraege
    .map((e) => e.artikel)
    .where((a) => a.titel.contains('Montagehilfe Abstandshalter'))
    .firstOrNull;
