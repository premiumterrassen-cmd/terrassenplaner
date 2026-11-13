/// Grenzwerte und Meldungen zum Belag (M5-10, Fachkonzept 2.8): was der
/// Server zur Wahl des Belags, der Länge und der Befestigung meldet, statt
/// still auf eine Vorgabe zu wechseln oder nichts zu verlegen. Die Texte
/// stehen in der App (Deutsch/Englisch); hier steht nur, wann eine Meldung
/// gilt und unter welchem Unterpunkt sie erscheint.
///
/// Die Sortimentsgrenzen der Beläge selbst (Breite × Stärke je Serie und
/// Profil B-030/B-032/B-036, Lieferlängen je Serie B-035, keine einseitig
/// genuteten Dielen B-033) prüft der Import (M2-03): ein Belag außerhalb
/// kommt gar nicht erst in die Auswahl.
library;

import '../artikel/artikel.dart';
import '../artikel/dielenlaenge.dart';
import '../artikel/einheiten.dart';
import '../konfiguration/ausschnitt.dart';
import '../konfiguration/belagverlegung.dart';
import '../konfiguration/dielenverlegung.dart';
import '../konfiguration/planungsstand.dart';
import '../konfiguration/verlegeart.dart';
import 'befestigungsbedarf.dart';
import 'planungsregeln.dart';
import 'regelwerk.dart';

/// Eine Meldung zum Belag. [unterpunkt] ist der Index im Schritt
/// Terrassenbelag (0 = 2.1 Belag, 1 = 2.2 Dielenlänge, 5 = 2.6
/// Befestigungsart) – dort, wo die Eingabe passiert. [warnung] = das
/// Ergebnis ist fachlich fraglich; sonst ein Hinweis, was der Planer statt
/// der Wahl tut.
enum Belagmeldung {
  /// Der Belag des Planungsstands ist nicht mehr in den Artikeldaten; es
  /// gilt der Vorgabebelag (M5-01).
  belagErsetzt(0, unterpunkt: 0, warnung: false),

  /// Dem Belag fehlen Breite oder Lieferlängen – er wird nicht verlegt.
  belagOhneMasse(1, unterpunkt: 0, warnung: true),

  /// MASSIV-Systemdielen liegen im Längenmix (B-036, B-232, Planungskern
  /// Regel 1a.3/1a.4): Stöße versetzt mittig auf einer UK; Verlegemuster und
  /// Dielenlänge gelten nicht (R-B18, R-B19).
  systemdieleLaengenmix(2, unterpunkt: 0, warnung: false),

  /// Eine Teilfläche ist kleiner als eine Diele oder Fliese: schmaler als
  /// eine Dielenreihe bzw. ohne eine ganze Fliese.
  flaecheKleinerAlsBelag(3, unterpunkt: 0, warnung: true),

  /// Holzfliesen in einer Fläche mit spitzen Ecken (unter 90°): jede Fliese
  /// dort wird schräg zugeschnitten.
  fliesenSpitzeWinkel(4, unterpunkt: 0, warnung: true),

  /// Glatte Diele ab 80 mm Breite: bombiert wird empfohlen (R-B03).
  bombierungEmpfohlen(5, unterpunkt: 0, warnung: false),

  /// Die erzwungene Dielenlänge liefert der Belag nicht; die Länge wird
  /// automatisch ermittelt (M5-02, B-035).
  laengeNichtLieferbar(6, unterpunkt: 1, warnung: false),

  /// Keine Lieferlänge des Belags erfüllt die Vorgabe Dielenlänge
  /// höchstens/mindestens; geplant wird mit allen Lagerlängen (Planungskern
  /// v9 Regel 11.1, R-B19).
  laengenvorgabeNichtErfuellbar(10, unterpunkt: 1, warnung: false),

  /// Vorgabe „Stoßlinie durch Eckpunkt“ (Planungskern v13 Regel 15, R-B20):
  /// Zwischen den festen Stoßlinien wären Stücke länger als die
  /// Lieferlänge; die Planung setzt gleichmäßig verteilte zusätzliche Stöße
  /// (Anzahl: `Berechnung.zusatzstoesse`).
  stosslinieZusatzstoesse(11, unterpunkt: 2, warnung: false),

  /// Die feste Stoßlinie gilt nicht bei MASSIV (Längenmix), im Verband
  /// (R-B18) und bei Holzfliesen (R-B20).
  stosslinieNichtImMuster(12, unterpunkt: 2, warnung: false),

  /// Keine gewählte Ecke ergibt eine Stoßlinie: sie liegt am Anfang oder
  /// Ende der Fläche in Verlegerichtung, an keiner gewählten Teilfläche,
  /// oder die Fläche passt in eine Diele (R-B20).
  stosslinieOhneWirkung(13, unterpunkt: 2, warnung: false),

  /// Die gewählte Verschraubung passt nicht zu genuteten Dielen; sie werden
  /// mit Clips befestigt (B-094, M5-09).
  befestigungsartNichtMoeglich(7, unterpunkt: 5, warnung: false),

  /// Zum Belag sind keine passenden Clips oder Schrauben hinterlegt – die
  /// Befestigung fehlt in der Materialliste.
  befestigungOhneArtikel(8, unterpunkt: 5, warnung: true),

  /// Keine hinterlegte Schraube hat die doppelte Dielenstärke; gerechnet
  /// wird mit der längsten (Fachkonzept 2.6).
  schraubeZuKurz(9, unterpunkt: 5, warnung: true);

  const Belagmeldung(
    this.nummer, {
    required this.unterpunkt,
    required this.warnung,
  });

  /// Nummer im Transportformat (Berechnung).
  final int nummer;

  /// Index des Unterpunkts im Schritt Terrassenbelag.
  final int unterpunkt;

  /// Warnung (fachlich fraglich) statt Hinweis.
  final bool warnung;

  /// Meldung zur [nummer] aus dem Transportformat.
  static Belagmeldung ausNummer(int nummer) => values.firstWhere(
    (m) => m.nummer == nummer,
    orElse: () => throw FormatException('unbekannte Belagmeldung $nummer'),
  );
}

/// Spitzer als das ist eine Ecke (Grad): 90° mit Spielraum für gerundete
/// Eingaben der Freiform.
const spitzerWinkel = 89.5;

/// Ab dieser Breite empfiehlt der Planer bombierte Dielen (R-B03,
/// Montagehinweise Regel 7).
const bombiertAb = Millimeter(80);

/// Meldungen zum Belag der Fläche [stand] (M5-10), in der Reihenfolge von
/// [Belagmeldung]. [belag] ist der Belag, mit dem der Server rechnet (bei
/// unbekannter Nummer die Vorgabe), [verlegung] seine Verlegung
/// (`verlegeBelag`), [regelwerk] liefert die Befestigungsartikel. Ohne Belag
/// gibt es keine Meldung.
List<Belagmeldung> belagmeldungen(
  Planungsstand stand,
  Artikel? belag,
  Belagverlegung? verlegung, {
  Regelwerk? regelwerk,
}) {
  if (belag == null) return const [];
  final masse = belag.abmessungen;
  final breite = masse.breite;
  final fliese = belag.art == Artikelart.holzfliese;
  final fest = stand.dielenlaenge;
  final meldungen = {
    if (stand.belag case final nummer? when nummer != belag.nummer)
      Belagmeldung.belagErsetzt,
    if ((belag.art == Artikelart.diele || fliese) &&
        (breite == null || masse.laengen.isEmpty))
      Belagmeldung.belagOhneMasse,
    if (belag.art == Artikelart.systemdiele) Belagmeldung.systemdieleLaengenmix,
    if (verlegung != null &&
        verlegung.teile.any(
          (t) => !t.stuecke.any((s) => _ganz(s, belag, fliese: fliese)),
        ))
      Belagmeldung.flaecheKleinerAlsBelag,
    if (fliese && _spitzeEcken(stand)) Belagmeldung.fliesenSpitzeWinkel,
    if (belag.art == Artikelart.diele &&
        belag.oberseite == Oberseite.glatt &&
        breite != null &&
        breite >= bombiertAb)
      Belagmeldung.bombierungEmpfohlen,
    if (belag.art == Artikelart.diele &&
        fest != null &&
        masse.laengen.isNotEmpty &&
        !masse.laengen.contains(fest))
      Belagmeldung.laengeNichtLieferbar,
    if (!masse.laengen.contains(fest) &&
        laengenvorgabeNichtErfuellbar(
          belag,
          masse.laengen,
          hoechstens: stand.dielenlaengeHoechstens,
          mindestens: stand.dielenlaengeMindestens,
        ))
      Belagmeldung.laengenvorgabeNichtErfuellbar,
    if (verlegung != null && verlegung.zusatzstoesse > 0)
      Belagmeldung.stosslinieZusatzstoesse,
    if (stand.stossecken.isNotEmpty &&
        (belag.art != Artikelart.diele ||
            stand.verlegeart != Verlegeart.fugenschnitt))
      Belagmeldung.stosslinieNichtImMuster
    else if (stand.stossecken.isNotEmpty &&
        verlegung != null &&
        verlegung.festeStoesse == 0)
      Belagmeldung.stosslinieOhneWirkung,
    if (verlegung != null && regelwerk?.datei[belag.nummer] != null)
      ...befestigungsmeldungen(regelwerk!, belag, stand.befestigungsart),
  };
  return [
    for (final m in Belagmeldung.values)
      if (meldungen.contains(m)) m,
  ];
}

/// Ob [s] eine ganze Diele oder Fliese ist: volle Reihenbreite (Breite plus
/// Fuge, 1 mm Spielraum für die Rundung), bei Fliesen auch die volle
/// Kantenlänge. Dielen werden in der Länge immer zugeschnitten.
bool _ganz(Dielenstueck s, Artikel belag, {required bool fliese}) {
  final masse = belag.abmessungen;
  final reihe = (masse.breite! + fuge).mm - 1;
  return s.breite >= reihe && (!fliese || s.laenge >= masse.laengen.last);
}

/// Ob die Fläche oder eine Teilfläche mit anderem Belag eine Ecke unter 90°
/// hat (Freiform, Dreieck als Ausschnitt).
bool _spitzeEcken(Planungsstand stand) => [
  stand.kontur,
  for (final a in stand.ausschnitte)
    if (a.funktion == Ausschnittfunktion.andererBelag) a.kontur,
].any((k) => k.innenwinkel.any((w) => w < spitzerWinkel));
