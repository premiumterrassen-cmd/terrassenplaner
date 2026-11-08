import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

/// Daten des Last- und Leistungstests (M10-02): eine kleine, erfundene
/// Artikeldatei (nur Verkaufsdaten, B-020) und Planungen in typischer und
/// großer Ausprägung.
abstract final class Lastdaten {
  static Artikel _zubehoer(String nummer, Artikelart art, int inhalt) =>
      Artikel(
        nummer: Artikelnummer(nummer),
        titel: 'Artikel $nummer',
        art: art,
        einheit: Verkaufseinheit(Mengeneinheit.karton, inhalt: inhalt),
        preisBrutto: const Cent(2500),
      );

  /// Diele 60 × 21 mm in 4, 5 und 6 m.
  static final diele = Artikel(
    nummer: const Artikelnummer('10-10-073'),
    titel: 'Terrassendiele Robinie 60 x 21 mm, genutet',
    art: Artikelart.diele,
    einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
    preisBrutto: const Cent(449),
    abmessungen: Abmessungen(
      breite: const Millimeter(60),
      staerke: const Millimeter(21),
      laengen: const [Millimeter(4000), Millimeter(5000), Millimeter(6000)],
    ),
    holzart: robinie,
    serie: basic,
    profil: Profil.genutet,
  );

  /// Unterkonstruktion 45 × 60 mm (BASIC).
  static final unterkonstruktion = Artikel(
    nummer: const Artikelnummer('10-10-031'),
    titel: 'Unterkonstruktionsholz Robinie 45 x 60 mm',
    art: Artikelart.unterkonstruktion,
    einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
    preisBrutto: const Cent(979),
    abmessungen: Abmessungen(
      breite: const Millimeter(45),
      staerke: const Millimeter(60),
    ),
    holzart: robinie,
    serie: basic,
  );

  static final _pad = _zubehoer('50-60-005', Artikelart.pad, 70);
  static final _fuss = _zubehoer('60-55-136', Artikelart.stellfuss, 20);

  /// Artikeldatei mit Belag, UK, Unterlegpads und Stellfüßen – genug für
  /// Verlegung, UK, Auflager und Materialliste.
  static final artikeldatei = Artikeldatei(
    quelle: 'lasttest',
    version: 'lasttest-1',
    eintraege: [
      Artikeleintrag(artikel: diele, angaben: const {'Abstand_UK': 400}),
      Artikeleintrag(
        artikel: unterkonstruktion,
        verweise: {
          Beziehung.stellfussPrivat.spalte: [_fuss.nummer],
          Beziehung.unterlegpads.spalte: [_pad.nummer],
        },
        angaben: const {'Abstand_Stelzfuesse': 600},
      ),
      Artikeleintrag(
        artikel: _pad,
        angaben: const {'MinHoehe': 5, 'MaxHoehe': 5},
      ),
      Artikeleintrag(
        artikel: _fuss,
        angaben: const {'MinHoehe': 55, 'MaxHoehe': 95},
      ),
    ],
  );

  /// Typische Planung: drei Flächen (O-Form mit Ausschnitt, L-Form und ein
  /// Rechteck [laenge] × 3 m, zweimal gebaut).
  static Planung typisch([int laenge = 5400]) => Planung([
    Terrassenflaeche(Planungsstand.start.mitForm(Terrassenform.oForm)),
    Terrassenflaeche(Planungsstand.start.mitForm(Terrassenform.lForm)),
    Terrassenflaeche(
      Planungsstand(
        grundriss: RechteckGrundriss(
          Millimeter(laenge),
          const Millimeter(3000),
        ),
      ),
      haeufigkeit: 2,
    ),
  ], aktiv: 2);

  /// Große Freiform 12 × 8 m mit schräger Ecke und Einbuchtung im
  /// Halbverband (wie in den Benchmarks der Verlegung).
  static final freiform = Planungsstand(
    grundriss: FreiformGrundriss(const [
      Punkt(0, 0),
      Punkt(9000, 0),
      Punkt(12000, 2500),
      Punkt(12000, 8000),
      Punkt(7000, 8000),
      Punkt(7000, 6000),
      Punkt(4000, 6000),
      Punkt(4000, 8000),
      Punkt(0, 8000),
    ], geschlossen: true),
  ).mitVerlegeart(Verlegeart.halbverband);

  /// Großes Projekt: [flaechen] große Freiformen, je [haeufigkeit]-mal
  /// gebaut, mit der aufwendigsten Verschnittoptimierung (M9-01) – rund
  /// 8 600 m² Belag bei den Vorgaben (je Freiform 86,25 m²).
  static Planung gross({int flaechen = 10, int haeufigkeit = 10}) => Planung([
    for (var i = 0; i < flaechen; i++)
      Terrassenflaeche(freiform, haeufigkeit: haeufigkeit),
  ], verschnittvariante: Planung.hoechsteVerschnittvariante);
}
