/// Verblendung der Seiten (M7-02, Fachkonzept 4.2): Verblendungsdielen je
/// verblendeter Seite und Blendenhalter aus UK-Holz (R-C05).
library;

import 'dart:math' as math;

import '../artikel/artikel.dart';
import '../artikel/einheiten.dart';
import '../artikel/ukauswahl.dart';
import '../ergebnisse/materialliste.dart';
import '../ergebnisse/stueckliste.dart';
import '../konfiguration/anschlussergebnis.dart';
import '../konfiguration/grundriss.dart';
import '../konfiguration/planungsstand.dart';
import 'anschlussregeln.dart';
import 'regelwerk.dart';
import 'uk_zusatz.dart';

/// Belagstärken, bei denen der Planer eine Verblendung rechnet
/// (Fachkonzept 4.2): 19 bis 23 mm.
const verblendungStaerkeVon = Millimeter(19);
const verblendungStaerkeBis = Millimeter(23);

/// Ob zum [belag] eine Verblendung gerechnet wird: Stärke 19 bis 23 mm.
bool verblendungMoeglich(Artikel belag) => switch (belag.abmessungen.staerke) {
  final s? => s >= verblendungStaerkeVon && s <= verblendungStaerkeBis,
  null => false,
};

/// Material und Meldungen des Terrassenanschlusses einer Fläche (M7):
/// Zuschnitte für die Stückliste, Bedarf für die Materialliste.
final class Anschlussbedarf {
  Anschlussbedarf({
    List<Planstueck> stuecke = const [],
    List<Materialbedarf> bedarf = const [],
    List<Anschlussmeldung> meldungen = const [],
  }) : stuecke = List.unmodifiable(stuecke),
       bedarf = List.unmodifiable(bedarf),
       meldungen = List.unmodifiable(meldungen);

  /// Zuschnitte aus UK-Holz (Blendenhalter) für die Stückliste.
  final List<Planstueck> stuecke;

  /// Bedarf für die Materialliste.
  final List<Materialbedarf> bedarf;

  /// Hinweise zum Anschluss für die App.
  final List<Anschlussmeldung> meldungen;

  /// Beides zusammen, erst dieser, dann [weiterer].
  Anschlussbedarf und(Anschlussbedarf weiterer) => Anschlussbedarf(
    stuecke: [...stuecke, ...weiterer.stuecke],
    bedarf: [...bedarf, ...weiterer.bedarf],
    meldungen: [...meldungen, ...weiterer.meldungen],
  );
}

/// Eine verblendete Strecke: Länge in mm und die Terrassenhöhe dort.
typedef Blendenstrecke = ({double laenge, Millimeter hoehe});

/// Verblendete Strecken der Fläche: je verblendeter Seite ihre Länge und
/// die größere Höhe ihrer Ecken ([hoehen] je Ecke, geprüft); beim Kreis
/// („Fläche verblenden“) der Umfang und die größte Höhe.
List<Blendenstrecke> blendenstrecken(
  Planungsstand stand,
  List<Millimeter> hoehen,
) {
  if (stand.grundriss is KreisGrundriss) {
    return [
      if (stand.anschluss.verblendet.isNotEmpty)
        (laenge: stand.kontur.umfang, hoehe: hoehen.reduce(_hoeher)),
    ];
  }
  final n = stand.seitenzahl;
  return [
    for (final seite in stand.anschluss.verblendet)
      if (seitenstrecke(stand, seite) case (:final von, :final bis))
        (
          laenge: von.abstand(bis),
          hoehe: _hoeher(hoehen[seite], hoehen[(seite + 1) % n]),
        ),
  ];
}

Millimeter _hoeher(Millimeter a, Millimeter b) => a > b ? a : b;

/// Ob alle freien Seiten (nicht an Bauelementen) verblendet sind – dann
/// warnt der Planer vor fehlender Unterlüftung (F37, Fachkonzept 4.2).
bool ohneUnterlueftung(Planungsstand stand) {
  final anschluss = stand.anschluss;
  if (anschluss.verblendet.isEmpty) return false;
  if (stand.grundriss is KreisGrundriss) return true;
  for (var seite = 0; seite < stand.seitenzahl; seite++) {
    if (!anschluss.grenztAn(seite) && !anschluss.verblendetAn(seite)) {
      return false;
    }
  }
  return true;
}

/// Verblendung der Fläche [stand] (M7-02, Fachkonzept 4.2) mit den
/// geprüften Höhen [hoehen] je Ecke:
///
/// - **Verblendungsdielen** (Artikel aus `Beziehung.verblendung` des
///   [belag], nur bei Belagstärke 19–23 mm): je verblendeter Strecke so
///   viele Reihen, wie die Blendenhöhe (Höhe minus Dielenstärke) in
///   Dielenbreiten braucht, jede Reihe so lang wie die Strecke; die
///   Lieferlängen rechnet `lieferstuecke` (F37: 309, 480, 309 cm → 2 ×
///   4000 + 1 × 5000 mm). Sie stehen nur in der Materialliste, mit Zusatz
///   „Verblendung“ (Fachkonzept 08).
/// - **Blendenhalter** (R-C05): kurze Stücke aus UK-Holz ([uk]) in der
///   Terrassenhöhe, je Strecke im UK-Achsabstand [ukAbstand] plus eins
///   (F37: 9 + 13 + 9 = 31 à 8,6 cm), beim Kreis ohne das eine. Ihre
///   Lieferstücke rechnet `anschlussbedarf` mit den übrigen UK-Zuschnitten
///   des Anschlusses.
///
/// Meldungen: Unterlüftung (alle freien Seiten verblendet), Belagstärke
/// außerhalb 19–23 mm, kein Höhenunterschied (Blendenhöhe ≤ 0) und kein
/// Verblendungsartikel in den Artikeldaten.
Anschlussbedarf verblendungsbedarf(
  Planungsstand stand, {
  required List<Millimeter> hoehen,
  Artikel? belag,
  Regelwerk? regelwerk,
  Artikel? uk,
  Millimeter? ukAbstand,
}) {
  final meldungen = [
    if (ohneUnterlueftung(stand)) Anschlussmeldung.unterlueftung,
  ];
  final staerke = belag?.abmessungen.staerke;
  if (stand.anschluss.verblendet.isEmpty || belag == null || staerke == null) {
    return Anschlussbedarf(meldungen: meldungen);
  }
  if (!verblendungMoeglich(belag)) {
    return Anschlussbedarf(
      meldungen: [...meldungen, Anschlussmeldung.belagstaerke],
    );
  }
  final strecken = [
    for (final s in blendenstrecken(stand, hoehen))
      if (s.hoehe > staerke) s,
  ];
  if (strecken.length < stand.anschluss.verblendet.length) {
    meldungen.add(Anschlussmeldung.keinHoehenunterschied);
  }
  final artikel = regelwerk?.datei[belag.nummer] == null
      ? null
      : regelwerk!.moeglich(belag.nummer, Beziehung.verblendung).firstOrNull;
  if (artikel == null) meldungen.add(Anschlussmeldung.ohneVerblendungsartikel);
  final halter = _blendenhalter(stand, strecken, uk, ukAbstand);
  return Anschlussbedarf(
    stuecke: halter,
    bedarf: [if (artikel != null) ..._dielen(artikel, strecken, staerke)],
    meldungen: meldungen,
  );
}

/// Verblendungsdielen der [strecken]: Reihen je Strecke aus der
/// Blendenhöhe, Lieferlängen wie bei der UK; ohne Lieferlängen in lfm.
List<Materialbedarf> _dielen(
  Artikel artikel,
  List<Blendenstrecke> strecken,
  Millimeter staerke,
) {
  final breite = artikel.abmessungen.breite;
  final stuecke = [
    for (final s in strecken)
      for (
        var r = 0;
        r < (breite == null ? 1 : ((s.hoehe - staerke).mm / breite.mm).ceil());
        r++
      )
        Millimeter(s.laenge.round()),
  ];
  final laengen = ukLieferlaengen(artikel);
  if (laengen.isEmpty) {
    final summe = stuecke.fold(0, (a, s) => a + s.mm);
    return [
      Materialbedarf(
        [artikel],
        (summe / 1000).ceil(),
        zusatz: Materialzusatz.verblendung,
      ),
    ];
  }
  return [
    for (final MapEntry(key: laenge, value: anzahl) in lieferstuecke(
      stuecke,
      laengen,
    ).entries)
      Materialbedarf(
        [artikel],
        anzahl,
        laenge: laenge,
        zusatz: Materialzusatz.verblendung,
      ),
  ];
}

/// Blendenhalter der [strecken] aus der [uk]: je Strecke so viele, dass
/// sie höchstens [abstand] auseinander stehen, an beiden Enden einer (beim
/// Kreis schließt sich der Umfang); so lang wie die Terrassenhöhe dort.
List<Planstueck> _blendenhalter(
  Planungsstand stand,
  List<Blendenstrecke> strecken,
  Artikel? uk,
  Millimeter? abstand,
) {
  if (uk == null || abstand == null) return const [];
  final ende = stand.grundriss is KreisGrundriss ? 0 : 1;
  final ganze = ukLieferlaengen(uk);
  return [
    for (final s in strecken)
      for (
        var i = 0;
        i < math.max(1, (s.laenge / abstand.mm - 1e-6).ceil()) + ende;
        i++
      )
        Planstueck(
          uk.nummer,
          uk.titel,
          s.hoehe,
          ganzeLaenge: ganze.isEmpty ? s.hoehe : ganze.last,
        ),
  ];
}
