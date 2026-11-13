/// Seitenblende (M7-02, Fachkonzept 4.2) nach den Planungsregeln Alexander
/// (Planungskern v6, 11.11.2026), Abschnitt 4a: Blenden aus der Serie des
/// Belags je verblendeter Seite, senkrechte Träger aus UK-Holz (R-C05) und
/// ihre Schrauben.
library;

import 'dart:math' as math;

import '../artikel/artikel.dart';
import '../artikel/einheiten.dart';
import '../artikel/ukauswahl.dart';
import '../ergebnisse/materialliste.dart';
import '../ergebnisse/stueckliste.dart';
import '../geometrie/punkt.dart';
import '../holzart/holzart.dart';
import '../konfiguration/anschlussergebnis.dart';
import '../konfiguration/grundriss.dart';
import '../konfiguration/planungsstand.dart';
import 'anschlussregeln.dart';
import 'auflagerbedarf.dart';
import 'regelwerk.dart';
import 'uk_zusatz.dart';

/// Breiteste Blende in einer Reihe (Planungskern v6, 4a.2: bei 12,5 cm
/// Höhe 100 mm).
const blendeBreiteMax = Millimeter(100);

/// Über dieser Höhe zwei Blenden mit Zwischenraum (4a.3: über ca. 13 cm,
/// Stellfüße oder größere Höhe) …
const blendeZweiReihenUeber = Millimeter(130);

/// … je 60 mm breit (4a.3).
const blendeZweiReihenBreite = Millimeter(60);

/// Zugabe je Kante für die Ecken auf Gehrung im Zuschnitt (4a.5).
const blendeGehrungszugabe = Millimeter(50);

/// Größter Abstand der senkrechten Träger (4a.6).
const blendentraegerAbstandMax = Millimeter(400);

/// Abstand der Träger zum Boden (4a.6: Länge = Höhe − 2 cm − Dielenstärke).
const blendentraegerBodenabstand = Millimeter(20);

/// Schrauben je Träger (4a.6).
const blendentraegerSchrauben = 2;

/// Mögliche Blenden zum [belag] aus [artikel] (4a.1): Dielen derselben
/// Holzart und Serie, glattkant, in der Stärke des Belags, mit Breite.
List<Artikel> blendenZumBelag(Artikel belag, Iterable<Artikel> artikel) => [
  for (final a in artikel)
    if (a.art == Artikelart.diele &&
        a.profil == Profil.glattkant &&
        a.holzart?.id == belag.holzart?.id &&
        a.serie == belag.serie &&
        a.abmessungen.staerke == belag.abmessungen.staerke &&
        a.abmessungen.breite != null)
      a,
];

/// Blendenreihen für die Höhe [hoehe] aus den [blenden] (4a.2–4a.4):
/// über 13 cm zwei Blenden à 60 mm, sonst eine in der breitesten Breite
/// unter der Höhe (die Blende steht nicht auf dem Boden auf), höchstens
/// 100 mm – 90 mm gibt es nicht, dann 80 mm. `null`, wenn die Serie die
/// nötige Breite nicht hat: dann fragt der Planer nach, statt zu raten.
List<Artikel>? blendenreihen(Millimeter hoehe, List<Artikel> blenden) {
  if (hoehe > blendeZweiReihenUeber) {
    final schmal = blenden
        .where((b) => b.abmessungen.breite == blendeZweiReihenBreite)
        .firstOrNull;
    return schmal == null ? null : [schmal, schmal];
  }
  Artikel? beste;
  for (final b in blenden) {
    final breite = b.abmessungen.breite!;
    if (breite < hoehe &&
        breite <= blendeBreiteMax &&
        (beste == null || breite > beste.abmessungen.breite!)) {
      beste = b;
    }
  }
  return beste == null ? null : [beste];
}

/// Material und Meldungen des Terrassenanschlusses einer Fläche (M7):
/// Zuschnitte für die Stückliste, Bedarf für die Materialliste.
final class Anschlussbedarf {
  Anschlussbedarf({
    List<Planstueck> stuecke = const [],
    List<Materialbedarf> bedarf = const [],
    List<Anschlussmeldung> meldungen = const [],
    List<(Artikel, Millimeter)> blenden = const [],
  }) : stuecke = List.unmodifiable(stuecke),
       bedarf = List.unmodifiable(bedarf),
       meldungen = List.unmodifiable(meldungen),
       blenden = List.unmodifiable(blenden);

  /// Zuschnitte aus UK-Holz (Blendenträger, Treppe) für die Stückliste.
  final List<Planstueck> stuecke;

  /// Zuschnitte der Seitenblende je Reihe (Artikel, Länge samt
  /// Gehrungszugabe) – für die Ölfläche (R-D10).
  final List<(Artikel, Millimeter)> blenden;

  /// Bedarf für die Materialliste.
  final List<Materialbedarf> bedarf;

  /// Hinweise zum Anschluss für die App.
  final List<Anschlussmeldung> meldungen;

  /// Beides zusammen, erst dieser, dann [weiterer].
  Anschlussbedarf und(Anschlussbedarf weiterer) => Anschlussbedarf(
    stuecke: [...stuecke, ...weiterer.stuecke],
    bedarf: [...bedarf, ...weiterer.bedarf],
    meldungen: [...meldungen, ...weiterer.meldungen],
    blenden: [...blenden, ...weiterer.blenden],
  );
}

/// Eine verblendete Strecke: Länge in mm, die Höhe der Blende dort und ob
/// sie an einer Ecke der Seite beginnt oder endet (dort Gehrung, 4a.5).
typedef Blendenstrecke = ({double laenge, Millimeter hoehe, bool ecke});

/// Verblendete Strecken der Fläche (Planungsregeln Alexander
/// (Planungskern v7, 12.11.2026), Regel 9.4, R-D30): je verblendeter Seite
/// die ganze Seite oder ihre Teilstücke (`Anschluss.teileAn`, auf die Seite
/// gekürzt). Die Höhe ist die eigene Blendenhöhe der Seite
/// (`Anschluss.blendenhoeheAn`), sonst die niedrigste Stelle der Strecke
/// über der Höhenfläche aus den geprüften [hoehen] (Ecken, dann die
/// wirksamen Höhenreferenzpunkte) – dort darf die Blende nicht auf dem
/// Boden aufstehen (4a.2), an höheren Stellen bleibt unten Luft. Beim Kreis
/// („Fläche verblenden“) der Umfang und die kleinste Höhe.
List<Blendenstrecke> blendenstrecken(
  Planungsstand stand,
  List<Millimeter> hoehen,
) {
  final anschluss = stand.anschluss;
  if (stand.grundriss is KreisGrundriss) {
    return [
      if (anschluss.verblendet.isNotEmpty)
        (
          laenge: stand.kontur.umfang,
          hoehe: anschluss.blendenhoeheAn(0) ?? hoehen.reduce(_niedriger),
          ecke: false,
        ),
    ];
  }
  final ecken = stand.grundriss.ecken;
  final flaeche = Hoehenflaeche(ecken, hoehen, [
    if (hoehen.length > ecken.length)
      for (final p in stand.wirksameHoehenpunkte) stand.ortVon(p),
  ]);
  return [
    for (final seite in anschluss.verblendet)
      for (final (:von, :bis, :ecke) in blendenstuecke(stand, seite))
        (
          laenge: von.abstand(bis),
          hoehe: anschluss.blendenhoeheAn(seite) ?? _tiefste(flaeche, von, bis),
          ecke: ecke,
        ),
  ];
}

/// Niedrigste Höhe der [flaeche] auf der Strecke [von]–[bis], abgetastet
/// alle [blendeAbtastung].
Millimeter _tiefste(Hoehenflaeche flaeche, Punkt von, Punkt bis) {
  final n = math.max(1, (von.abstand(bis) / blendeAbtastung.mm).ceil());
  var tiefste = flaeche.bei(von);
  for (var k = 1; k <= n; k++) {
    tiefste = _niedriger(tiefste, flaeche.bei(von + (bis - von) * (k / n)));
  }
  return tiefste;
}

/// Abstand, in dem die Höhe längs einer Blende abgetastet wird.
const blendeAbtastung = Millimeter(100);

Millimeter _niedriger(Millimeter a, Millimeter b) => a < b ? a : b;

/// Ob alle freien Seiten (nicht an Bauelementen) verblendet sind – dann
/// warnt der Planer vor fehlender Unterlüftung (F37, Fachkonzept 4.2).
/// „Blende an allen Kanten“ heißt alle Kanten außer der Hauswand
/// (Planungskern v6, 4a.7): angrenzende Seiten sind nie verblendet.
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

/// Seitenblende der Fläche [stand] (M7-02) mit den geprüften Höhen
/// [hoehen] je Ecke nach den Planungsregeln Alexander (Planungskern v6,
/// 11.11.2026), Abschnitt 4a:
///
/// - **Blenden** (4a.1–4a.4): glattkante Dielen der Serie des [belag] in
///   seiner Stärke aus dem [regelwerk] (`blendenZumBelag`), Reihen je
///   verblendeter Strecke nach `blendenreihen`. Jede Reihe ist so lang wie
///   die Strecke plus 5 cm je Kante für die Gehrung (4a.5, beim Kreis ohne
///   Ecken keine, ein Teilstück nur, wenn es an einer Ecke liegt); die Lieferlängen rechnet `lieferstuecke` (F37: 314, 485,
///   314 cm → 2 × 4000 + 1 × 5000 mm). Sie stehen nur in der Materialliste,
///   mit Zusatz „Verblendung“ (Fachkonzept 08).
/// - **Träger** (4a.6, R-C05): senkrechte Stücke aus UK-Holz ([uk], aus
///   der Serie wie die UK), je Strecke höchstens 40 cm auseinander und an
///   beiden Enden einer (beim Kreis schließt sich der Umfang), so lang wie
///   Höhe − 2 cm − Dielenstärke (F37: 9 + 13 + 9 = 31 à 4,5 cm); ohne [uk]
///   (keine UK-Verlegung) keine. Ihre Lieferstücke rechnet
///   `anschlussbedarf` mit den übrigen UK-Zuschnitten des Anschlusses.
/// - **Schrauben** (4a.6): 2 je Träger, aus dem Befestigungsverweis der
///   ersten Blende (glattkant: Terrassenschrauben).
///
/// Meldungen: Unterlüftung (alle freien Seiten verblendet), kein
/// Höhenunterschied (Höhe ≤ Dielenstärke) und Rückfrage, wenn die Serie
/// die nötige Blende nicht hat (4a.4) – an dieser Seite dann kein Material.
Anschlussbedarf verblendungsbedarf(
  Planungsstand stand, {
  required List<Millimeter> hoehen,
  Artikel? belag,
  Regelwerk? regelwerk,
  Artikel? uk,
}) {
  final meldungen = [
    if (ohneUnterlueftung(stand)) Anschlussmeldung.unterlueftung,
  ];
  if (stand.anschluss.verblendet.isEmpty || belag == null) {
    return Anschlussbedarf(meldungen: meldungen);
  }
  final staerke = belag.abmessungen.staerke ?? const Millimeter(0);
  final alle = blendenstrecken(stand, hoehen);
  final strecken = [
    for (final s in alle)
      if (s.hoehe > staerke) s,
  ];
  if (strecken.length < alle.length) {
    meldungen.add(Anschlussmeldung.keinHoehenunterschied);
  }
  final blenden = blendenZumBelag(
    belag,
    regelwerk?.imBereich(Bereich.belag) ?? const [],
  );
  final reihen = <Artikel, List<Millimeter>>{};
  final traeger = <Planstueck>[];
  var fehlt = false;
  for (final s in strecken) {
    final auswahl = blendenreihen(s.hoehe, blenden);
    if (auswahl == null) {
      fehlt = true;
      continue;
    }
    for (final blende in auswahl) {
      (reihen[blende] ??= []).add(
        Millimeter(s.laenge.round()) +
            (s.ecke ? blendeGehrungszugabe : const Millimeter(0)),
      );
    }
    if (uk != null) traeger.addAll(_traeger(stand, s, uk, staerke));
  }
  if (fehlt) meldungen.add(Anschlussmeldung.blendeFehlt);
  return Anschlussbedarf(
    stuecke: traeger,
    bedarf: [
      for (final MapEntry(key: blende, value: stuecke) in reihen.entries)
        ..._blenden(stand, blende, stuecke),
      if (regelwerk != null && traeger.isNotEmpty)
        ..._schrauben(regelwerk, reihen.keys.first, traeger.length),
    ],
    meldungen: meldungen,
    blenden: [
      for (final MapEntry(key: blende, value: stuecke) in reihen.entries)
        for (final laenge in stuecke) (blende, laenge),
    ],
  );
}

/// Blenden [artikel] für die Reihen [stuecke] in den Lieferlängen der
/// Serie wie bei der UK (lange Reihen eigene Bretter, kurze zusammen),
/// begrenzt durch die Vorgabe Dielenlänge des [stand]s (R-B19).
List<Materialbedarf> _blenden(
  Planungsstand stand,
  Artikel artikel,
  List<Millimeter> stuecke,
) => [
  for (final MapEntry(key: laenge, value: anzahl) in lieferstuecke(
    stuecke,
    stand.vorgabelaengen(artikel, ukLieferlaengen(artikel)),
  ).entries)
    Materialbedarf(
      [artikel],
      anzahl,
      laenge: laenge,
      zusatz: Materialzusatz.verblendung,
    ),
];

/// Träger der Strecke [s] aus der [uk] (4a.6): höchstens 40 cm
/// auseinander, an beiden Enden einer (beim Kreis schließt sich der
/// Umfang); Länge = Höhe − 2 cm − Dielenstärke [staerke].
List<Planstueck> _traeger(
  Planungsstand stand,
  Blendenstrecke s,
  Artikel uk,
  Millimeter staerke,
) {
  final ende = stand.grundriss is KreisGrundriss ? 0 : 1;
  final felder = math.max(
    1,
    (s.laenge / blendentraegerAbstandMax.mm - 1e-6).ceil(),
  );
  final laenge = s.hoehe - blendentraegerBodenabstand - staerke;
  return [
    for (var i = 0; i < felder + ende; i++)
      Planstueck(
        uk.nummer,
        uk.titel,
        laenge,
        ganzeLaenge: ukLieferlaengen(uk).last,
      ),
  ];
}

/// Schrauben für [traeger] Träger (4a.6: 2 je Träger) aus dem
/// Befestigungsverweis der [blende]: die erste Schraube in
/// Datenreihenfolge mit allen Verpackungseinheiten ihrer Länge; ohne
/// Schraube kein Bedarf.
List<Materialbedarf> _schrauben(
  Regelwerk regelwerk,
  Artikel blende,
  int traeger,
) {
  final schrauben = [
    for (final a in regelwerk.moeglich(blende.nummer, Beziehung.befestigung))
      if (a.art == Artikelart.schraube) a,
  ];
  if (schrauben.isEmpty) return const [];
  final laenge = schrauben.first.abmessungen.laengste;
  return [
    Materialbedarf([
      for (final s in schrauben)
        if (s.abmessungen.laengste == laenge) s,
    ], traeger * blendentraegerSchrauben),
  ];
}
