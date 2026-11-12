/// Auflager der Unterkonstruktion (M6-08, Fachkonzept 3.9): Stelzfüße und
/// Pads aus dem Regelwerk der UK, ihre Höhenbereiche, der Abstand der
/// Auflager längs der UK und die Höhengrenzen mit Meldung.
library;

import 'dart:math' as math;

import '../artikel/artikel.dart';
import '../artikel/einheiten.dart';
import '../konfiguration/auflagen.dart';
import '../konfiguration/planungsstand.dart';
import '../konfiguration/terrassenart.dart';
import 'hoehenpunkte.dart';
import 'planungsregeln.dart';
import 'regelwerk.dart';

/// Ein Höhenbereich der Auflager: alle Artikel mit derselben Min- und
/// Max-Höhe laut Artikeldaten – dieselben Füße in verschiedenen Packungen
/// (ROBI-LIFT 35–55 mm zu 10, 30 und 125 Stück) sind ein Bereich, verpackt
/// wird über alle (`verpackt`). Pads haben eine feste Dicke ([von] = [bis]).
final class Auflagerbereich {
  Auflagerbereich({
    required List<Artikel> einheiten,
    required this.von,
    required this.bis,
    required this.pad,
  }) : einheiten = List.unmodifiable(einheiten);

  /// Artikel des Bereichs in Datenreihenfolge (mindestens einer).
  final List<Artikel> einheiten;

  /// Niedrigste und höchste Höhe des Auflagers (Spalt unter der UK).
  final Millimeter von;
  final Millimeter bis;

  /// Ob es ein Pad ist (Unterlegpad unter der UK).
  final bool pad;

  /// Titel des ersten Artikels für die Anzeige.
  String get titel => einheiten.first.titel;

  /// Angabe für die App (Transportformat).
  Auflagerangabe get angabe => (titel: titel, von: von, bis: bis, pad: pad);
}

/// Höhenbereich eines Auflagers für die Anzeige (M6-08).
typedef Auflagerangabe = ({
  String titel,
  Millimeter von,
  Millimeter bis,
  bool pad,
});

/// Meldung zu den Höhengrenzen der Auflager (M6-08).
enum Auflagermeldung {
  /// Ein Höhenpunkt liegt unter der niedrigsten Höhe mit Stelzfüßen (nur
  /// ohne Pads möglich).
  unterMindesthoehe(0),

  /// Ein Höhenpunkt liegt über der höchsten Höhe mit Stelzfüßen.
  ueberHoechsthoehe(1);

  const Auflagermeldung(this.nummer);

  /// Nummer im Transportformat.
  final int nummer;

  /// Meldung zur [nummer]; unbekannte sind ein Formatfehler.
  static Auflagermeldung ausNummer(int nummer) => values.firstWhere(
    (m) => m.nummer == nummer,
    orElse: () => throw FormatException('unbekannte Auflagermeldung $nummer'),
  );
}

/// Höhenbereiche der Auflager für die UK [uk] (M6-08): die Stellfüße der
/// Nutzung ([gewerblich], `Regelwerk.stellfuesse`, M6-07) und – mit
/// [auflagen] „Stelzfüße und Pads“ – die Unterlegpads der UK (Spalte
/// „mögliche Unterlegpads“, nur Artikel der Art Pad). Artikel ohne Min-
/// oder Max-Höhe in den Artikeldaten bleiben weg. Reihenfolge: Pads, dann
/// Stelzfüße, je in Datenreihenfolge – nichts fest verdrahtet (B-122).
List<Auflagerbereich> auflagerbereiche(
  Regelwerk regelwerk,
  Artikel uk, {
  required bool gewerblich,
  required Auflagen auflagen,
}) {
  final artikel = <Artikel>{
    if (auflagen.mitPads)
      for (final a in regelwerk.moeglich(uk.nummer, Beziehung.unterlegpads))
        if (a.art == Artikelart.pad) a,
    ...regelwerk.stellfuesse(uk.nummer, gewerblich: gewerblich),
  };
  final bereiche = <(bool, int, int), List<Artikel>>{};
  for (final a in artikel) {
    final abstaende = regelwerk.abstaende(a.nummer);
    final (von, bis) = (abstaende.minHoehe, abstaende.maxHoehe);
    if (von == null || bis == null) continue;
    bereiche
        .putIfAbsent((a.art == Artikelart.pad, von.mm, bis.mm), () => [])
        .add(a);
  }
  return [
    for (final MapEntry(key: (pad, von, bis), value: einheiten)
        in bereiche.entries)
      Auflagerbereich(
        einheiten: einheiten,
        von: Millimeter(von),
        bis: Millimeter(bis),
        pad: pad,
      ),
  ];
}

/// Auflager an einer Stelle (Planungsregeln Alexander (Planungskern v6,
/// 11.11.2026), Regel 3a.2): ein Stelzfuß, ein Pad oder zwei Pads
/// übereinander ([teile], das dickere zuerst).
final class Auflagerwahl {
  Auflagerwahl(List<Auflagerbereich> teile)
    : teile = List.unmodifiable(teile),
      _pad = teile.first.pad,
      _hoehe = teile.fold(0, (s, t) => s + t.bis.mm);

  /// Die Bereiche, aus denen das Auflager besteht (mindestens einer).
  final List<Auflagerbereich> teile;

  /// Titel für die Höhenzuordnung: „Unterleger 8 mm + Unterleger 5 mm“,
  /// zwei gleiche als „2 × Unterleger 5 mm“.
  String get titel => teile.length > 1 && teile.first == teile.last
      ? '${teile.length} × ${teile.first.titel}'
      : teile.map((t) => t.titel).join(' + ');

  /// Ob es Pads sind (sonst ein Stelzfuß).
  final bool _pad;

  /// Höhe der Pads zusammen.
  final int _hoehe;
}

/// Mögliche Auflager aus den [bereiche]n in der Reihenfolge der Tabelle:
/// zuerst die Pads einzeln und zu zweit übereinander (Planungsregeln
/// Alexander (Planungskern v6, 11.11.2026), Regel 3a.2.2: 2, 2 + 2, 5,
/// 5 + 2, 8, 5 + 5, 8 + 5, 8 + 8 mm – nach der Höhe, bei gleicher Höhe
/// erst eins, dann das ausgeglichenere Paar: 10 mm = 5 + 5, nicht 8 + 2),
/// dann die Stelzfüße in Datenreihenfolge.
List<Auflagerwahl> auflagerwahlen(List<Auflagerbereich> bereiche) {
  final pads = [
    for (final b in bereiche)
      if (b.pad) b,
  ]..sort((a, b) => b.bis.mm.compareTo(a.bis.mm));
  final stapel = [
    for (final (i, a) in pads.indexed) ...[
      Auflagerwahl([a]),
      for (final b in pads.skip(i)) Auflagerwahl([a, b]),
    ],
  ]..sort(_stapelfolge);
  return [
    ...stapel,
    for (final b in bereiche)
      if (!b.pad) Auflagerwahl([b]),
  ];
}

/// Pads nach Höhe, dann Anzahl, dann dem dünneren Teil (größer zuerst).
int _stapelfolge(Auflagerwahl a, Auflagerwahl b) {
  final hoehe = a._hoehe.compareTo(b._hoehe);
  if (hoehe != 0) return hoehe;
  final anzahl = a.teile.length.compareTo(b.teile.length);
  if (anzahl != 0) return anzahl;
  return b.teile.last.bis.mm.compareTo(a.teile.last.bis.mm);
}

/// Auflager für einen [spalt] (Ausgleichshöhe) zwischen UK und Boden aus
/// den [wahlen] (`auflagerwahlen`, M6-08/M6-11, Planungsregeln Alexander
/// (Planungskern v6, 11.11.2026), Regel 3a.2):
///
/// - **Pads** bis [padAusgleichBis] (17 mm): die niedrigste Lage aus einem
///   oder zwei Pads, die mindestens so hoch ist wie der Spalt (F30: 2 mm →
///   Unterleger 2 mm, 4 mm → 2 + 2 mm); reicht keine, die höchste (17 mm →
///   8 + 8 mm). Liegt die UK genau auf Höhe, das dünnste Pad (Gummi unter
///   der UK, R-C04).
/// - sonst (ab 18 mm, oder ohne Pads) der erste **Stelzfuß** in
///   Datenreihenfolge, dessen Bereich den Spalt enthält;
/// - sonst (Lücke zwischen zwei Bereichen) der nächstgelegene Stelzfuß –
///   die Abweichung gleicht man mit Pads oder Keilen aus;
/// - `null` ohne Auflager, unter dem niedrigsten Stelzfuß ohne Pads und
///   über dem höchsten ([auflagermeldungen] meldet das).
Auflagerwahl? auflagerFuer(Millimeter spalt, List<Auflagerwahl> wahlen) {
  // je Auflager gerufen: ohne Zwischenlisten (Benchmark Auflager)
  if (spalt <= padAusgleichBis) {
    Auflagerwahl? hoechste;
    for (final w in wahlen) {
      if (!w._pad) continue;
      if (w._hoehe >= spalt.mm) return w;
      hoechste = w;
    }
    if (hoechste != null) return hoechste;
  }
  // Lücke: der nächste Fuß – nicht über dem höchsten, ohne Pads nicht
  // unter dem niedrigsten (wie `_grenzen`)
  Auflagerwahl? naechster;
  var mitPads = false;
  var darunter = true;
  var darueber = true;
  for (final w in wahlen) {
    if (w._pad) {
      mitPads = true;
      continue;
    }
    final abstand = _entfernung(spalt, w);
    if (abstand <= 0) return w;
    darunter = darunter && spalt < w.teile.first.von;
    darueber = darueber && spalt > w.teile.first.bis;
    if (naechster == null || abstand < _entfernung(spalt, naechster)) {
      naechster = w;
    }
  }
  return darueber || (darunter && !mitPads) ? null : naechster;
}

int _entfernung(Millimeter spalt, Auflagerwahl w) =>
    math.max(w.teile.first.von.mm - spalt.mm, spalt.mm - w.teile.first.bis.mm);

/// Niedrigster und höchster Spalt, den die [bereiche] tragen – mit Pads
/// ab 0 und mindestens bis [padAusgleichBis] (zwei Pads übereinander,
/// Regel 3a.2.2); `null` ohne Bereiche.
({Millimeter von, Millimeter bis})? _grenzen(List<Auflagerbereich> bereiche) {
  if (bereiche.isEmpty) return null;
  final mitPads = bereiche.any((b) => b.pad);
  return (
    von: mitPads
        ? const Millimeter(0)
        : Millimeter(bereiche.map((b) => b.von.mm).reduce(math.min)),
    bis: Millimeter(
      bereiche
          .map((b) => b.bis.mm)
          .fold(mitPads ? padAusgleichBis.mm : 0, math.max),
    ),
  );
}

/// Höhengrenzen der Auflager für die Anzeige: niedrigste und höchste Höhe
/// von Oberkante Belag bis Boden bei der [aufbauhoehe] und dem
/// [gummiband] (Regel 3a.2.1: Ausgleichshöhe = Höhe − Aufbauhöhe − 1 mm);
/// mit Pads ab der Aufbauhöhe selbst (das dünnste Pad liegt immer unter
/// der UK); `null` ohne Bereiche.
({Millimeter von, Millimeter bis})? auflagergrenzen(
  List<Auflagerbereich> bereiche,
  Millimeter aufbauhoehe,
) => switch (_grenzen(bereiche)) {
  final g? => (
    von: g.von.mm > 0 ? aufbauhoehe + gummiband + g.von : aufbauhoehe,
    bis: aufbauhoehe + gummiband + g.bis,
  ),
  null => null,
};

/// Meldungen zu den Höhengrenzen (M6-08, Abnahme „Höhengrenzen mit
/// Meldung“): liegt ein Höhenpunkt ([hoehen], geprüft mit der
/// [aufbauhoehe]) unter oder über dem, was die [bereiche] tragen. Die Höhe
/// dazwischen ist linear (M6-11), die Grenzen liegen also an den
/// Eckpunkten. Ohne Bereiche keine Meldung – dann fehlen Artikeldaten.
List<Auflagermeldung> auflagermeldungen(
  List<Millimeter> hoehen,
  Millimeter aufbauhoehe,
  List<Auflagerbereich> bereiche,
) {
  final grenzen = auflagergrenzen(bereiche, aufbauhoehe);
  if (grenzen == null) return const [];
  return [
    if (hoehen.any((h) => h < grenzen.von)) Auflagermeldung.unterMindesthoehe,
    if (hoehen.any((h) => h > grenzen.bis)) Auflagermeldung.ueberHoechsthoehe,
  ];
}

/// Höchster Abstand der Auflager längs der UK (M6-08, Abnahme „Abstände
/// aus dem Regelwerk“):
///
/// - bei vorhandener UK die Spannweite der vorhandenen Träger (F29);
/// - sonst der Abstand der Stelzfüße der UK laut Artikeldaten
///   ([artikel], Spalte `Abstand_Stelzfuesse`), ohne Angabe
///   [auflagerAbstandVorgabe];
/// - bei gewerblicher Nutzung zwei Drittel davon: anderthalbmal so viele
///   Auflager wie im alten Planer (F35: Gummi unter der UK 2 → 3 Rollen,
///   R-C09) – der UK-Achsabstand bleibt.
Millimeter auflagerabstand(Planungsstand stand, Millimeter? artikel) {
  if (stand.terrassenart == Terrassenart.vorhandeneUk) return stand.spannweite;
  final abstand = artikel ?? auflagerAbstandVorgabe;
  return stand.gewerblich ? Millimeter(abstand.mm * 2 ~/ 3) : abstand;
}

/// Steht die Fläche auf Stellfüßen (Planungsregeln Alexander (Planungskern
/// v6, 11.11.2026), Regel 3.11, im Kern je Fläche)? Bei der normalen
/// Terrasse mit Aufbauhöhe: ohne Pads immer, sonst wenn an einem der
/// geprüften [hoehen] die Ausgleichshöhe über [padAusgleichBis] liegt (ab
/// 18 mm Stellfüße, Regel 3a.2.3) – dann gilt der Wandabstand an der
/// Hauswand (`ukVerlegung`).
bool mitStellfuessen(Planungsstand stand, Hoehenpunkte hoehen) {
  final aufbau = hoehen.aufbauhoehe;
  if (stand.terrassenart != Terrassenart.normal || aufbau == null) {
    return false;
  }
  return !stand.auflagen.mitPads ||
      hoehen.hoehen.any((h) => h - aufbau - gummiband > padAusgleichBis);
}
