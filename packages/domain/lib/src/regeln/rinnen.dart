/// Entwässerungsrinnen (M7-03, Fachkonzept 4.3) nach den Planungsregeln
/// Alexander (Planungskern v11, 12.11.2026), Abschnitt 13: Entwässerungsrinne
/// RELO V je Kante – Lage, Belagfläche, Stützhölzer und Material.
library;

import 'dart:math' as math;

import '../artikel/artikel.dart';
import '../artikel/einheiten.dart';
import '../ergebnisse/materialliste.dart';
import '../geometrie/kontur.dart';
import '../geometrie/punkt.dart';
import '../konfiguration/anschluss.dart';
import '../konfiguration/anschlussergebnis.dart';
import '../konfiguration/grundriss.dart';
import '../konfiguration/planungsstand.dart';
import 'anschlussregeln.dart';
import 'regelwerk.dart';
import 'verblendung.dart';

/// Breite des Profils RELO V (1200 × 151 × 20 mm, Regel 13.1.2).
const rinnenprofilbreite = Millimeter(151);

/// Fuge zwischen Rinne und Belag (Regel 13.1.1, wie die Dielenfuge).
const rinnenfuge = Millimeter(6);

/// Der Belag endet so weit vor der Kante mit Rinne: Profil plus Fuge
/// (Regel 13.1.1: 15,1 cm + 6 mm = 15,7 cm).
const rinnenabstand = Millimeter(157);

/// Kürzeste Kante mit Rinne (Regel 13.1.1: ab 30 cm).
const rinnenMindestlaenge = Millimeter(300);

/// Länge eines Profils RELO V (Regel 13.1.5: Rinnenlänge / 1,20 m).
const rinnenprofillaenge = Millimeter(1200);

/// Länge eines Auflagerprofils RELO VA (Regel 13.1.5: 2 × Länge / 1,88 m).
const auflagerprofillaenge = Millimeter(1880);

/// Je Rinne liegen zwei Auflagerprofile nebeneinander (Regel 13.1.2).
const auflagerprofileJeRinne = 2;

/// Achsabstand der Stützhölzer unter einer Rinne längs zur UK höchstens
/// (Regel 13.1.2/13.1.4: UK-Achse höchstens 42 cm).
const stuetzholzabstand = Millimeter(420);

/// Erstes und letztes Stützholz liegen so weit von den Enden der Rinne.
const stuetzholzrand = Millimeter(50);

/// Eckverbundwinkel RELO E je Stützholz (Regel 13.1.5).
const eckwinkelJeStuetzholz = 2;

/// Eine Kante gilt bis zu dieser Abweichung (mm) als waagerecht oder
/// senkrecht (wie der Planungskern: 0,5 cm).
const _gerade = 5.0;

/// Ob an der Seite [seite] eine Rinne geplant werden kann (Regel 13.1.1):
/// nur an geraden, waagerechten oder senkrechten Seiten ab
/// [rinnenMindestlaenge] – nicht am Bogen (Stich der Seite); der Kreis hat
/// keine Seiten.
bool rinneMoeglich(Planungsstand stand, int seite) {
  if (seite < 0 || seite >= stand.seitenzahl) return false;
  if (stand.rundungen.seiten.containsKey(seite) ||
      stand.rundungen.radien.containsKey(seite)) {
    return false;
  }
  final (:von, :bis) = seitenstrecke(stand, seite);
  final d = bis - von;
  return (d.x.abs() <= _gerade || d.y.abs() <= _gerade) &&
      d.laenge >= rinnenMindestlaenge.mm;
}

/// Eine geplante Rinne (Regel 13.1): die Seite, ihre Kante im Grundriss
/// ([von]–[bis]) und die Richtung ins Innere der Fläche ([innen],
/// Einheitsvektor). Die Rinne liegt innen an der Kante.
typedef Rinnenkante = ({int seite, Punkt von, Punkt bis, Punkt innen});

/// Länge der Rinne an der Kante [k] in mm.
double rinnenlaenge(Rinnenkante k) => k.von.abstand(k.bis);

/// Rinnen von [stand], die geplant werden ([rinneMoeglich]); mit [geplant]
/// nur die Seiten, für die es einen Rinnenartikel gibt.
List<Rinnenkante> rinnenkanten(
  Planungsstand stand, {
  bool Function(int seite)? geplant,
}) => [
  for (final (:seite, lage: _) in stand.anschluss.rinnen)
    if (rinneMoeglich(stand, seite) && (geplant?.call(seite) ?? true))
      _kante(stand, seite),
];

Rinnenkante _kante(Planungsstand stand, int seite) {
  final (:von, :bis) = seitenstrecke(stand, seite);
  final laengs = (bis - von).einheit;
  return (
    seite: seite,
    von: von,
    bis: bis,
    innen: stand.grundriss.kontur.gegenUhrzeigersinn
        ? laengs.links
        : Punkt(laengs.y, -laengs.x),
  );
}

/// Rinnenartikel für die Lage [lage] am [belag]: die Artikel aus
/// `Beziehung.drainage` in Datenreihenfolge stehen für die Lagen in ihrer
/// Reihenfolge (gesamte Seite, im Element, außerhalb, vor dem Element);
/// fehlt die Variante, gilt die erste (R-D01: die Lage wählt die
/// Artikelvariante). `null` ohne Artikel.
Artikel? rinnenartikel(Regelwerk? regelwerk, Artikel belag, Rinnenlage lage) {
  if (regelwerk?.datei[belag.nummer] == null) return null;
  final varianten = regelwerk!.moeglich(belag.nummer, Beziehung.drainage);
  if (varianten.isEmpty) return null;
  return varianten[math.min(lage.index, varianten.length - 1)];
}

/// Rinnen von [stand] mit Rinnenartikel zum [belag] – nur sie sparen den
/// Belag aus und bekommen Stützhölzer; ohne Belag keine.
List<Rinnenkante> geplanteRinnen(
  Planungsstand stand,
  Artikel? belag,
  Regelwerk? regelwerk,
) => belag == null
    ? const []
    : rinnenkanten(
        stand,
        geplant: (seite) =>
            rinnenartikel(regelwerk, belag, stand.anschluss.rinneAn(seite)!) !=
            null,
      );

/// Artikel einer Rinne (R-D11): [profil] RELO V und [auflagerprofil] RELO
/// VA (`null`, wenn die Artikeldaten keins nennen).
typedef Rinnensatz = ({Artikel profil, Artikel? auflagerprofil});

/// Artikel der Rinne für die Lage [lage] in der Farbe [farbe] (Regel
/// 13.1.5): eloxiert ist der Rinnenartikel der Lage (`rinnenartikel`),
/// anthrazit seine Farbvariante – der erste Zubehör-Verweis der Art Rinne.
/// Das Auflagerprofil ist das Pflichtzubehör oder der erste Zubehör-Verweis
/// der Art Rinnenzubehör des Profils. `null` ohne Profil in dieser Farbe.
Rinnensatz? rinnensatz(
  Regelwerk? regelwerk,
  Artikel belag,
  Rinnenlage lage,
  Rinnenfarbe farbe,
) {
  final grund = rinnenartikel(regelwerk, belag, lage);
  if (grund == null) return null;
  // mit Rinnenartikel gibt es das Regelwerk
  final daten = regelwerk!;
  final profil = farbe == Rinnenfarbe.eloxiert
      ? grund
      : _zubehoer(daten, grund, Artikelart.rinne).firstOrNull;
  if (profil == null) return null;
  return (
    profil: profil,
    auflagerprofil: _zubehoer(
      daten,
      profil,
      Artikelart.rinnenzubehoer,
    ).firstOrNull,
  );
}

/// Pflichtzubehör und Zubehör-Verweise von [artikel] der Art [art].
Iterable<Artikel> _zubehoer(Regelwerk daten, Artikel artikel, Artikelart art) =>
    [
      ...daten.pflichtzubehoer(artikel.nummer).keys,
      ...daten.moeglich(artikel.nummer, Beziehung.zubehoer),
    ].where((a) => a.art == art);

/// Eckverbundwinkel RELO E für die Stützhölzer (Regel 13.1.4): die
/// Eckverbinder der [uk] aus den Artikeldaten, sonst die Zubehör-Verweise
/// der Art Eckverbinder des Rinnenartikels [rinne] – alle Packungen, die
/// Materialliste wählt die günstigste Kombination (VPE 25/50).
List<Artikel> eckwinkel(Regelwerk? regelwerk, Artikel rinne, Artikel? uk) {
  // mit Rinnenartikel gibt es das Regelwerk
  final daten = regelwerk!;
  final verbinder = uk == null || daten.datei[uk.nummer] == null
      ? const <Artikel>[]
      : daten.moeglich(uk.nummer, Beziehung.eckverbinder);
  return verbinder.isNotEmpty
      ? verbinder
      : _zubehoer(daten, rinne, Artikelart.eckverbinder).toList();
}

/// Planungsstand für den Belag: jede Kante mit Rinne ([kanten]) um
/// [rinnenabstand] nach innen versetzt (Regel 13.1.1: F38 480 × 309 →
/// 480 × 293,3 cm). Ohne Rinnen oder wenn der versetzte Umriss nicht
/// gültig ist (zu kurze Seiten, gekreuzt, umgeklappt), bleibt der Stand.
///
/// Ist eine Nachbarseite ein Bogen (Stich oder Radius, Planungskern v12),
/// rutscht die Ecke auf seinem Kreis, und der Bogen bekommt dessen Radius
/// – er bleibt auf demselben Kreis (Kern v23, kein „zweiter Kreis“).
Planungsstand belagstand(Planungsstand stand, List<Rinnenkante> kanten) {
  if (kanten.isEmpty) return stand;
  final boegen = stand.rundungen.seitenboegen(stand.grundriss);
  var ecken = stand.grundriss.ecken;
  for (final k in kanten) {
    ecken = _versetzt(ecken, k, boegen);
  }
  final n = ecken.length;
  var rundungen = stand.rundungen;
  for (final k in kanten) {
    for (final j in [(k.seite + n - 1) % n, (k.seite + 1) % n]) {
      if (boegen[j] case final b?) {
        rundungen = rundungen.mitRadius(
          j,
          Millimeter(b.radius.round()),
          innen: rundungen.stichAn(stand.grundriss, j).mm < 0,
        );
      }
    }
  }
  try {
    final neu = FreiformGrundriss(ecken, geschlossen: true);
    // umgeklappt: die Rinnen sind breiter als die Fläche
    if (neu.kontur.gegenUhrzeigersinn !=
        stand.grundriss.kontur.gegenUhrzeigersinn) {
      return stand;
    }
    final belag = stand.mitGrundriss(neu).mitRundungen(rundungen);
    belag.kontur;
    return belag;
  } on ArgumentError {
    return stand;
  }
}

/// [ecken] mit der Seite der Rinne [k] um [rinnenabstand] nach innen
/// versetzt: ihre beiden Ecken wandern auf den Nachbarseiten mit – auf dem
/// Kreis, wenn die Nachbarseite ein Bogen aus [boegen] ist.
List<Punkt> _versetzt(
  List<Punkt> ecken,
  Rinnenkante k,
  Map<int, Kante> boegen,
) {
  final n = ecken.length;
  final seite = k.seite;
  final a = ecken[seite];
  final b = ecken[(seite + 1) % n];
  final laengs = (b - a).einheit;
  final verschoben = k.innen * rinnenabstand.mm.toDouble();
  Punkt ecke(Punkt nachbar, Punkt alt, int nachbarseite) {
    final gerade = _schnitt(nachbar, alt, alt + verschoben, laengs);
    return switch (boegen[nachbarseite]) {
      final bogen? => _aufKreis(bogen, alt + verschoben, laengs, gerade),
      null => gerade,
    };
  }

  return [
    for (var i = 0; i < n; i++)
      i == seite
          ? ecke(ecken[(seite + n - 1) % n], a, (seite + n - 1) % n)
          : i == (seite + 1) % n
          ? ecke(ecken[(seite + 2) % n], b, (seite + 1) % n)
          : ecken[i],
  ];
}

/// Schnitt der Geraden durch [p] in Richtung [d] (Einheitsvektor) mit dem
/// Kreis des Bogens [bogen] – der Schnittpunkt nächst [naehe]; ohne
/// Schnitt [naehe].
Punkt _aufKreis(Kante bogen, Punkt p, Punkt d, Punkt naehe) {
  final m = bogen.mittelpunkt;
  final r = bogen.radius;
  final v = p - m;
  final halb = d.punktprodukt(v);
  final diskriminante = halb * halb - (v.punktprodukt(v) - r * r);
  if (diskriminante < 0) return naehe;
  final w = math.sqrt(diskriminante);
  final (s1, s2) = (p + d * (-halb + w), p + d * (-halb - w));
  return s1.abstand(naehe) <= s2.abstand(naehe) ? s1 : s2;
}

Punkt _schnitt(Punkt p, Punkt q, Punkt r, Punkt d) {
  final e = q - p;
  final nenner = e.x * d.y - e.y * d.x;
  if (nenner.abs() < 1e-9) return r;
  final t = ((r.x - p.x) * d.y - (r.y - p.y) * d.x) / nenner;
  return p + e * t;
}

/// Planungsstand für den Belag mit den Rinnen, für die es zum [belag]
/// einen Rinnenartikel gibt (`geplanteRinnen`, `belagstand`); ohne Belag
/// der Stand selbst.
Planungsstand rinnenstand(
  Planungsstand stand,
  Artikel? belag,
  Regelwerk? regelwerk,
) => belagstand(stand, geplanteRinnen(stand, belag, regelwerk));

/// Lage der Stützhölzer längs einer Rinne der Länge [laenge] (Regel
/// 13.1.4): das erste und letzte [stuetzholzrand] von den Enden,
/// dazwischen gleichmäßig höchstens [stuetzholzabstand] auseinander
/// (Abstände vom Anfang der Rinne in mm).
List<double> stuetzholzstellen(double laenge) {
  final rand = stuetzholzrand.mm.toDouble();
  final strecke = math.max(0.0, laenge - 2 * rand);
  final felder = math.max(1, (strecke / stuetzholzabstand.mm - 1e-6).ceil());
  return [for (var k = 0; k <= felder; k++) rand + strecke * k / felder];
}

/// Material der Entwässerungsrinnen (Regel 13.1.5, R-D11) je geplanter
/// Rinne über die ganze Kante:
///
/// - **Profil RELO V:** Rinnenlänge / [rinnenprofillaenge] aufgerundet
///   (F38: 480 cm → 4), verpackt wie in den Artikeldaten (VPE 10).
/// - **Auflagerprofil RELO VA:** [auflagerprofileJeRinne] × Länge /
///   [auflagerprofillaenge] aufgerundet (F38: 960 / 188 → 6, VPE 14).
/// - **Eckverbundwinkel RELO E:** [eckwinkelJeStuetzholz] je Stützholz
///   ([stuetzhoelzer] aus der UK-Verlegung, `eckwinkel`).
///
/// Hinweise: `rinneNichtMoeglich` (Seite nicht gerade, schräg oder kürzer
/// als 30 cm), `ohneRinnenartikel`, `rinnenfarbeFehlt` (keine
/// Farbvariante), `eckwinkelFehlt` und – bei jeder geplanten Rinne –
/// `rinnenmontage` (Systemschrauben UNIA 4,2 × 22 mm nicht im Shop,
/// Endkappen RELO VB, Höhenausgleich mit GUMO).
Anschlussbedarf rinnenbedarf(
  Planungsstand stand, {
  Artikel? belag,
  Regelwerk? regelwerk,
  Artikel? uk,
  int stuetzhoelzer = 0,
}) {
  final anschluss = stand.anschluss;
  final bedarf = <Materialbedarf>[];
  final meldungen = <Anschlussmeldung>{};
  if (anschluss.rinnen.any((r) => !rinneMoeglich(stand, r.seite))) {
    meldungen.add(Anschlussmeldung.rinneNichtMoeglich);
  }
  Artikel? erster;
  for (final k in rinnenkanten(stand)) {
    final lage = anschluss.rinneAn(k.seite)!;
    final grund = belag == null ? null : rinnenartikel(regelwerk, belag, lage);
    if (grund == null) {
      meldungen.add(Anschlussmeldung.ohneRinnenartikel);
      continue;
    }
    erster ??= grund;
    final satz = rinnensatz(regelwerk, belag!, lage, anschluss.rinnenfarbe);
    if (satz == null) {
      meldungen.add(Anschlussmeldung.rinnenfarbeFehlt);
      continue;
    }
    final laenge = rinnenlaenge(k);
    bedarf.add(
      Materialbedarf([satz.profil], _stuecke(laenge, rinnenprofillaenge)),
    );
    if (satz.auflagerprofil case final va?) {
      bedarf.add(
        Materialbedarf([
          va,
        ], _stuecke(auflagerprofileJeRinne * laenge, auflagerprofillaenge)),
      );
    }
  }
  if (erster != null) {
    meldungen.add(Anschlussmeldung.rinnenmontage);
    if (stuetzhoelzer > 0) {
      final winkel = eckwinkel(regelwerk, erster, uk);
      if (winkel.isEmpty) {
        meldungen.add(Anschlussmeldung.eckwinkelFehlt);
      } else {
        bedarf.add(
          Materialbedarf(winkel, eckwinkelJeStuetzholz * stuetzhoelzer),
        );
      }
    }
  }
  return Anschlussbedarf(bedarf: bedarf, meldungen: meldungen.toList());
}

/// Stücke der Länge [stueck] für [laenge] mm, aufgerundet.
int _stuecke(double laenge, Millimeter stueck) =>
    (laenge / stueck.mm - 1e-9).ceil();
