import '../holzart/holzart.dart';
import 'einheiten.dart';

/// Artikelnummer wie im Shop (B-152) – der fachliche Schlüssel eines
/// Artikels.
extension type const Artikelnummer(String wert) implements Object {
  /// Prüft und normalisiert (ohne Leerraum am Rand); wirft bei leerem Text.
  factory Artikelnummer.pruefe(String text) {
    final wert = text.trim();
    if (wert.isEmpty) {
      throw ArgumentError.value(text, 'text', 'Artikelnummer ist leer');
    }
    return Artikelnummer(wert);
  }
}

/// Bereich eines Artikels im Planer (M2-01).
enum Bereich {
  belag,
  unterkonstruktion,
  befestigung,
  auflager,
  anschluss,
  zubehoer,
}

/// Artikelart – unabhängig von den Typ-Texten des Imports (M2-01).
enum Artikelart {
  diele(Bereich.belag),
  systemdiele(Bereich.belag),
  holzfliese(Bereich.belag),
  unterkonstruktion(Bereich.unterkonstruktion),
  aluUnterkonstruktion(Bereich.unterkonstruktion),
  clip(Bereich.befestigung),
  schraube(Bereich.befestigung),
  stellfuss(Bereich.auflager),
  pad(Bereich.auflager),
  padUnterStellfuss(Bereich.auflager),
  bodenanker(Bereich.auflager),
  laengsverbinder(Bereich.unterkonstruktion),
  querverbinder(Bereich.unterkonstruktion),
  eckverbinder(Bereich.unterkonstruktion),
  variablerVerbinder(Bereich.unterkonstruktion),
  blendenhalter(Bereich.anschluss),
  verblendung(Bereich.anschluss),
  rinne(Bereich.anschluss),
  rinnenzubehoer(Bereich.anschluss),
  gummiband(Bereich.zubehoer),
  pflege(Bereich.zubehoer),
  werkzeug(Bereich.zubehoer),
  dienstleistung(Bereich.zubehoer),
  sonstiges(Bereich.zubehoer);

  const Artikelart(this.bereich);

  final Bereich bereich;

  /// Holzartikel mit Holzart, Serie, Profil und Lieferlängen (M2-08).
  bool get istHolz =>
      this == diele || this == systemdiele || this == unterkonstruktion;
}

/// Oberseite einer Diele.
enum Oberseite { glatt, bombiert }

/// Abmessungen in mm; Längen sind die lieferbaren Längen (aufsteigend, ohne
/// doppelte).
final class Abmessungen {
  Abmessungen({
    this.breite,
    this.staerke,
    Iterable<Millimeter> laengen = const [],
  }) : laengen = List.unmodifiable(
         laengen.toSet().toList()..sort((a, b) => a.mm - b.mm),
       ) {
    for (final (name, wert) in [
      ('breite', breite),
      ('staerke', staerke),
      for (final l in this.laengen) ('laengen', l),
    ]) {
      if (wert != null && wert.mm <= 0) {
        throw ArgumentError.value(wert.mm, name, 'muss größer als 0 sein');
      }
    }
  }

  final Millimeter? breite;
  final Millimeter? staerke;
  final List<Millimeter> laengen;

  /// Längste lieferbare Länge (z. B. für Freidielen, R-B09).
  Millimeter? get laengste => laengen.isEmpty ? null : laengen.last;
}

/// Artikel des Planers (M2-01) – Verkaufsdaten, nie Einstandspreise (B-020).
final class Artikel {
  Artikel({
    required this.nummer,
    required String titel,
    required this.art,
    required this.einheit,
    Abmessungen? abmessungen,
    this.preisBrutto,
    this.gewicht,
    this.holzart,
    this.serie,
    this.profil,
    this.oberseite,
    Iterable<String> bilder = const [],
  }) : titel = titel.trim(),
       abmessungen = abmessungen ?? Abmessungen(),
       bilder = List.unmodifiable(bilder) {
    if (this.titel.isEmpty) {
      throw ArgumentError.value(titel, 'titel', 'Titel ist leer');
    }
    if (this.bilder.length > 3) {
      throw ArgumentError.value(bilder, 'bilder', 'höchstens 3 Abbildungen');
    }
    final holzangaben = [holzart, serie].nonNulls.length;
    if (holzangaben != (art.istHolz ? 2 : 0)) {
      throw ArgumentError.value(
        serie,
        'serie',
        'Holzartikel brauchen Holzart und Serie, andere keine (${art.name})',
      );
    }
    if (serie case final s?) holzart?.serie(s);
  }

  final Artikelnummer nummer;
  final String titel;
  final Artikelart art;
  final Verkaufseinheit einheit;
  final Abmessungen abmessungen;

  /// Bruttopreis je Verkaufseinheit – nur Anzeige (B-055).
  final Cent? preisBrutto;

  /// Gewicht je Verkaufseinheit.
  final Gramm? gewicht;

  /// Holzart und Serie – nur bei Holzartikeln (M2-08).
  final Holzart? holzart;
  final Serie? serie;
  final Profil? profil;
  final Oberseite? oberseite;

  /// Abbildungen 1–3 (Profilansicht, Stirnseite, Profilzeichnung).
  final List<String> bilder;

  @override
  bool operator ==(Object other) => other is Artikel && other.nummer == nummer;

  @override
  int get hashCode => nummer.hashCode;

  @override
  String toString() => '$nummer $titel';
}
