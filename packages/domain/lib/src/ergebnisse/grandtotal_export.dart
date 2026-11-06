/// Export für GrandTotal (M9-08, Fachkonzept 08): die Materialliste als
/// Importdatei im Aufbau des alten Planers – eine Zeile je Artikel, Länge
/// und Zusatz mit 17 Spalten. Lfm-Ware (Dielen, UK) steht mit Stückzahl und
/// Länge in mm darin; das GrandTotal-Plugin „ImportZuLaufmeter“ rechnet sie
/// in lfm um und zieht die Katalogpreise (GrandTotal ist führend, B-055).
///
/// Nur Verkaufsdaten: Titel und Artikelnummern wie im Shop (B-152),
/// Preise aus den Verkaufspreisen – nie Einstandspreise, Lieferanten oder
/// Werksbezeichnungen (B-020, B-021, B-023).
library;

import '../artikel/artikel.dart';
import '../artikel/artikelbild.dart';
import '../artikel/einheiten.dart';
import '../konfiguration/konfigurationsnummer.dart';
import 'materialliste.dart';

/// Artikel zur Nummer aus den aktuellen Artikeldaten; `null` = unbekannt.
typedef Artikelsuche = Artikel? Function(Artikelnummer nummer);

/// Spaltenköpfe der Importdatei in ihrer Reihenfolge (17 Spalten wie der
/// „CSV-Download“ des alten Planers).
const grandTotalSpalten = [
  'Bezeichnung',
  'Nomenklatur',
  'Body HTML',
  'Anzahl',
  'Breite',
  'Stärke',
  'Länge',
  'Artikelnummer',
  'Nettopreis',
  'Bruttopreis',
  'Link zum Bild',
  'Volumen',
  'Gewicht',
  'Quadratmeter',
  'Gesamtlaufmeter',
  'Artikeltyp',
  'Einheit',
];

/// Eine Zeile der Importdatei. Maße in mm, Preise je Einheit der Zeile
/// (bei Lfm-Ware je lfm), Volumen und Quadratmeter je Stück, Gewicht und
/// Gesamtlaufmeter für die ganze Zeile – wie die bisherigen Importdateien.
final class GrandTotalZeile {
  const GrandTotalZeile({
    required this.bezeichnung,
    required this.nomenklatur,
    required this.artikelnummer,
    required this.anzahl,
    required this.artikeltyp,
    required this.einheit,
    this.beschreibung = '',
    this.breite,
    this.staerke,
    this.laenge,
    this.brutto,
    this.bildLink,
    this.volumen,
    this.gewicht,
    this.quadratmeter,
    this.gesamtlaenge,
  });

  /// Titel wie im Shop, bei Lfm-Ware mit „ - Länge: 5000 mm“ und ggf.
  /// „ - Freidiele“.
  final String bezeichnung;

  /// Kurzbezeichnung – der Titel wie im Shop (keine Werks-Nomenklatur,
  /// B-021).
  final String nomenklatur;

  /// Beschreibungstext („Body HTML“); leer, solange die Artikeldaten keinen
  /// führen.
  final String beschreibung;
  final int anzahl;
  final Millimeter? breite;
  final Millimeter? staerke;
  final Millimeter? laenge;
  final Artikelnummer artikelnummer;

  /// Bruttopreis je Einheit der Zeile (bei Lfm-Ware je lfm); Freidielen 0.
  final Cent? brutto;
  final Uri? bildLink;

  /// Holzvolumen eines Stücks in m³.
  final double? volumen;

  /// Gewicht der ganzen Zeile.
  final Gramm? gewicht;

  /// Fläche eines Stücks (Breite × Länge) in m².
  final double? quadratmeter;

  /// Gesamtlänge der Zeile (Anzahl × Länge).
  final Millimeter? gesamtlaenge;

  /// Warengruppe in GrandTotal (z. B. „Deckbelag“, „Unterkonstruktion“,
  /// „BefestigungDeck,Zubehoer“).
  final String artikeltyp;

  /// Einheit der Zeile: „lfm“ bei Lfm-Ware, sonst die Verkaufseinheit.
  final String einheit;

  /// Nettopreis je Einheit: Brutto ohne die enthaltene Mehrwertsteuer
  /// ([mehrwertsteuerSatz]), ungerundet in Euro.
  double? get netto => switch (brutto) {
    final b? => b.cent / (100 + mehrwertsteuerSatz),
    null => null,
  };

  /// Die 17 Felder als Text in der Reihenfolge von [grandTotalSpalten];
  /// Zahlen mit Punkt, Preise netto auf 4 und brutto auf 2 Nachkommastellen,
  /// Volumen, Gewicht (kg), m² und lfm auf höchstens 4.
  List<String> get felder => [
    bezeichnung,
    nomenklatur,
    beschreibung,
    '$anzahl',
    _text(breite?.mm),
    _text(staerke?.mm),
    _text(laenge?.mm),
    artikelnummer.wert,
    netto?.toStringAsFixed(4) ?? '',
    brutto?.euro.toStringAsFixed(2) ?? '',
    bildLink?.toString() ?? '',
    _zahl(volumen),
    _zahl(gewicht?.kg),
    _zahl(quadratmeter),
    _zahl(gesamtlaenge?.m),
    artikeltyp,
    einheit,
  ];

  @override
  String toString() => felder.join(';');
}

/// Zeilen der Importdatei aus der [liste] (Reihenfolge der Materialliste,
/// abgewählte Positionen mit Menge 0 entfallen). [artikel] liefert Maße,
/// Art, Holzart und Gewicht; [bilder] ist die Adresse der Web-App, neben
/// der die Artikelbilder liegen (M2-07) – ohne sie bleibt der Bild-Link
/// leer.
List<GrandTotalZeile> grandTotalZeilen(
  Materialliste liste,
  Artikelsuche artikel, {
  Uri? bilder,
}) => [
  for (final p in liste.positionen)
    if (p.anzahl > 0) _zeile(p, artikel(p.nummer), bilder),
];

/// Importdatei aus [zeilen]: Spaltenköpfe und Zeilen, getrennt durch `;`,
/// Zeilenende CRLF, UTF-8-Text. Felder mit `;`, `"` oder Zeilenumbruch
/// stehen in Anführungszeichen (`"` verdoppelt).
String grandTotalCsv(Iterable<GrandTotalZeile> zeilen) => [
  grandTotalSpalten,
  for (final z in zeilen) z.felder,
].map((felder) => '${felder.map(_feld).join(';')}\r\n').join();

/// Dateiname der Importdatei: mit gespeicherter Konfiguration deren Nummer
/// und Version (ohne Prüfcode, M9-05b), sonst ohne.
String grandTotalDateiname([KonfigurationsStand? stand]) => switch (stand) {
  final s? => 'GrandTotal_Import_${s.nummer.wert}_v${s.version}.csv',
  null => 'GrandTotal_Import.csv',
};

/// Warengruppe in GrandTotal je Artikelart – Holz wie im alten Planer
/// („Deckbelag“, „Unterkonstruktion“), damit „ImportZuLaufmeter“ es als
/// Lfm-Ware erkennt.
String grandTotalArtikeltyp(Artikelart art) => switch (art) {
  Artikelart.diele || Artikelart.systemdiele => 'Deckbelag',
  Artikelart.holzfliese => 'Deckbelag,Zubehoer',
  Artikelart.unterkonstruktion ||
  Artikelart.aluUnterkonstruktion => 'Unterkonstruktion',
  Artikelart.laengsverbinder ||
  Artikelart.querverbinder ||
  Artikelart.eckverbinder ||
  Artikelart.variablerVerbinder => 'Verbinder,Zubehoer',
  Artikelart.clip || Artikelart.schraube => 'BefestigungDeck,Zubehoer',
  Artikelart.stellfuss => 'Stellfuss,Zubehoer',
  Artikelart.pad || Artikelart.padUnterStellfuss => 'Unterlegpads,Zubehoer',
  Artikelart.bodenanker => 'Bodenanker',
  Artikelart.blendenhalter || Artikelart.verblendung => 'Verblendung,Zubehoer',
  Artikelart.rinne => 'Drainage',
  Artikelart.rinnenzubehoer => 'DrainageZubehoer',
  Artikelart.gummiband => 'EPDM-Band,Zubehoer',
  Artikelart.dienstleistung => 'Dienstleistung',
  Artikelart.pflege ||
  Artikelart.werkzeug ||
  Artikelart.sonstiges => 'Zubehoer',
};

GrandTotalZeile _zeile(Materialzeile p, Artikel? artikel, Uri? bilder) {
  final art = artikel?.art;
  final laenge = p.laenge;
  final masse = artikel?.abmessungen;
  final (breite, staerke) = (masse?.breite, masse?.staerke);
  final volumen = switch ((breite, staerke, laenge)) {
    (final b?, final s?, final l?) => b.m * s.m * l.m,
    _ => null,
  };
  return GrandTotalZeile(
    bezeichnung: [
      p.titel,
      if (laenge != null) 'Länge: ${laenge.mm} mm',
      if (p.zusatz == Materialzusatz.freidiele) 'Freidiele',
    ].join(' - '),
    nomenklatur: p.titel,
    artikelnummer: p.nummer,
    anzahl: p.anzahl,
    breite: breite,
    staerke: staerke,
    laenge: laenge,
    brutto: laenge == null ? p.einzelpreis : p.preisJeLfm,
    bildLink: switch ((bilder, p.bild)) {
      (final basis?, final bild?) => basis.resolve(artikelbildAdresse(bild)),
      _ => null,
    },
    volumen: volumen,
    gewicht: _gewicht(artikel, p.anzahl, breite, staerke, laenge),
    quadratmeter: switch ((breite, laenge)) {
      (final b?, final l?) => b.m * l.m,
      _ => null,
    },
    gesamtlaenge: p.gesamtlaenge,
    artikeltyp: art == null ? '' : grandTotalArtikeltyp(art),
    einheit: laenge == null
        ? p.einheit.anzeige
        : Mengeneinheit.laufmeter.anzeige,
  );
}

/// Gewicht der Zeile: Holz aus Querschnitt, Länge und Rohdichte der
/// Holzart (R-A12), sonst Gewicht je Verkaufseinheit mal Anzahl; `null`,
/// wenn beides fehlt.
Gramm? _gewicht(
  Artikel? artikel,
  int anzahl,
  Millimeter? breite,
  Millimeter? staerke,
  Millimeter? laenge,
) => switch ((artikel?.holzart, breite, staerke, laenge, artikel?.gewicht)) {
  (final h?, final b?, final s?, final l?, _) => h.gewicht(b, s, l) * anzahl,
  (_, _, _, _, final g?) => g * anzahl,
  _ => null,
};

String _text(int? wert) => wert == null ? '' : '$wert';

/// Zahl mit Punkt, auf 4 Nachkommastellen gerundet, ohne Nullen am Ende
/// („0.0066“, „240“, „2.4“).
String _zahl(double? wert) {
  if (wert == null) return '';
  final text = wert.toStringAsFixed(4);
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}

String _feld(String wert) => wert.contains(RegExp('[;"\r\n]'))
    ? '"${wert.replaceAll('"', '""')}"'
    : wert;
