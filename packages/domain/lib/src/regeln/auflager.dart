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

/// Auflager für einen [spalt] zwischen UK und Boden (M6-08/M6-11):
///
/// - **Pads** zuerst: das dünnste Pad, das mindestens so dick ist wie der
///   Spalt – F30: 4 mm → GUMO 5 mm wie im alten Planer; liegt die UK genau
///   auf Höhe, das dünnste Pad (Gummi unter der UK, R-C04).
/// - sonst der erste **Stelzfuß** in Datenreihenfolge, dessen Bereich den
///   Spalt enthält;
/// - sonst (Lücke zwischen zwei Bereichen) der nächstgelegene Bereich – die
///   Abweichung gleicht man mit Pads oder Keilen aus;
/// - `null` ohne Bereiche, unter dem niedrigsten Stelzfuß ohne Pads und
///   über dem höchsten Bereich ([auflagermeldungen] meldet das).
Auflagerbereich? auflagerFuer(
  Millimeter spalt,
  List<Auflagerbereich> bereiche,
) {
  final pads = [
    for (final b in bereiche)
      if (b.pad) b,
  ]..sort((a, b) => a.bis.mm.compareTo(b.bis.mm));
  for (final p in pads) {
    if (spalt <= p.bis) return p;
  }
  for (final b in bereiche) {
    if (b.von <= spalt && spalt <= b.bis) return b;
  }
  final grenzen = _grenzen(bereiche);
  if (grenzen == null || spalt < grenzen.von || spalt > grenzen.bis) {
    return null;
  }
  return bereiche.reduce(
    (a, b) => _entfernung(spalt, b) < _entfernung(spalt, a) ? b : a,
  );
}

int _entfernung(Millimeter spalt, Auflagerbereich b) =>
    math.max(b.von.mm - spalt.mm, spalt.mm - b.bis.mm);

/// Niedrigster und höchster Spalt, den die [bereiche] tragen – mit Pads
/// ab 0; `null` ohne Bereiche.
({Millimeter von, Millimeter bis})? _grenzen(List<Auflagerbereich> bereiche) {
  if (bereiche.isEmpty) return null;
  final mitPads = bereiche.any((b) => b.pad);
  return (
    von: mitPads
        ? const Millimeter(0)
        : Millimeter(bereiche.map((b) => b.von.mm).reduce(math.min)),
    bis: Millimeter(bereiche.map((b) => b.bis.mm).reduce(math.max)),
  );
}

/// Höhengrenzen der Auflager für die Anzeige: niedrigste und höchste Höhe
/// von Oberkante Belag bis Boden bei der [aufbauhoehe]; `null` ohne
/// Bereiche.
({Millimeter von, Millimeter bis})? auflagergrenzen(
  List<Auflagerbereich> bereiche,
  Millimeter aufbauhoehe,
) => switch (_grenzen(bereiche)) {
  final g? => (von: aufbauhoehe + g.von, bis: aufbauhoehe + g.bis),
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
