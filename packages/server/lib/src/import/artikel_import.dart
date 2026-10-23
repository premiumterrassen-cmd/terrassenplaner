import 'dart:convert';

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'datenpruefung.dart';
import 'xlsx_leser.dart';

/// Blatt der Upload-Datei für den Planer (Master-Artikelliste, B-156/B-218).
const importBlatt = 'Import Terrassenplaner';

/// Befund beim Import (Zeile wie in Excel, Spalte, Text); kritische Befunde
/// verhindern die Artikeldatei.
final class Befund {
  const Befund(this.zeile, this.feld, this.text, {this.kritisch = true});

  final int zeile;
  final String feld;
  final String text;
  final bool kritisch;

  @override
  String toString() =>
      '${kritisch ? 'FEHLER' : 'Hinweis'} Zeile $zeile, $feld: $text';
}

/// Ergebnis eines Imports: Artikeldatei (nur ohne kritische Befunde) und
/// Prüfbericht.
final class ImportErgebnis {
  ImportErgebnis(this.datei, Iterable<Befund> befunde)
    : befunde = List.unmodifiable(befunde);

  final Artikeldatei? datei;
  final List<Befund> befunde;

  bool get erfolgreich => datei != null;
}

/// Spalten, die der Importer liest – **nur diese** (Whitelist). Alles andere,
/// z. B. Einkaufspreise oder die Spalte `marke` (Fertiger der Eigenmarken,
/// B-023), wird nie gelesen (B-020).
const gelesenenSpalten = {
  'Artikelnummer',
  'Artikelbezeichnung',
  'ArtikelbezeichnungKonfi',
  'Artikeltyp',
  'Zubehoergruppe',
  'Materialobergruppe',
  'VPE',
  'Inhalt_pro_Einheit',
  'Preis_pro_Einheit',
  'Breite_cm',
  'Staerke_cm',
  'Laenge_cm',
  'Abbildung_1',
  'Abbildung_2',
  'Abbildung_3',
  ...verweisSpalten,
  ...angabenSpalten,
  ...schalterSpalten,
  'benoetigtesZubehoer',
  'benoetigtesZubehoer_anzahl',
};

/// Spalten mit Verweisen auf andere Artikel (Grundlage für M2-04).
const verweisSpalten = [
  'moeglicheBefestigungDeck',
  'moeglichesZubehoer',
  'moeglicherStellfussPrivat',
  'moeglicherStellfussGewerblich',
  'moeglicheUnterlegpads',
  'moeglicheLaengsverbinder',
  'moeglicheQuerverbinder',
  'moeglicheVerblendung',
  'moeglicheDrainage',
  'moeglicheStartEndClip',
  'moeglicheEckverbinder',
  'moeglicheVariableverbinder',
];

/// Planer-Angaben in mm (Abstände, Höhen).
const angabenSpalten = [
  'Abstand_Stelzfuesse',
  'Abstand_UK',
  'UK_Abstand_vom_Rand',
  'MinHoehe',
  'MaxHoehe',
];

/// Ja/Nein-Angaben (`true` → 1, sonst 0).
const schalterSpalten = ['Reichweite'];

/// Importiert die Upload-Datei (xlsx) in eine Artikeldatei (M2-02).
/// Hinweis: Die Maßspalten heißen `_cm`, enthalten aber Millimeter.
ImportErgebnis importiereArtikel(
  List<int> xlsx, {
  required String quelle,
  Iterable<Holzart> holzarten = const [],
}) {
  final Blatt blatt;
  try {
    blatt = leseBlatt(xlsx, importBlatt);
  } on FormatException catch (e) {
    return ImportErgebnis(null, [Befund(0, 'Datei', e.message)]);
  }
  final befunde = <Befund>[];
  if (blatt.formelnOhneWert > 0) {
    befunde.add(
      Befund(
        0,
        'Datei',
        '${blatt.formelnOhneWert} Formeln ohne gespeicherten Wert – bitte die '
            'Upload-Datei (Werte) verwenden, nicht die Master-Artikelliste',
      ),
    );
  }
  for (final spalte in ['Artikelnummer', 'Artikelbezeichnung', 'Artikeltyp']) {
    if (!blatt.kopf.contains(spalte)) {
      befunde.add(Befund(1, spalte, 'Pflichtspalte fehlt'));
    }
  }
  if (befunde.isNotEmpty) return ImportErgebnis(null, befunde);

  final holz = holzarten.isEmpty ? [robinie] : holzarten.toList();
  final liste = <({int zeile, Artikeleintrag eintrag})>[];
  for (final zeile in blatt.zeilen) {
    final werte = {
      for (final MapEntry(:key, :value) in zeile.werte.entries)
        if (gelesenenSpalten.contains(key)) key: value,
    };
    final eintrag = _eintrag(zeile.nummer, werte, holz, befunde);
    if (eintrag != null) liste.add((zeile: zeile.nummer, eintrag: eintrag));
  }
  befunde
    ..addAll(pruefeArtikel(liste))
    ..sort((a, b) => a.zeile - b.zeile);
  final eintraege = [for (final (:eintrag, zeile: _) in liste) eintrag];
  if (befunde.any((b) => b.kritisch)) return ImportErgebnis(null, befunde);
  final ohneVersion = Artikeldatei(
    quelle: quelle,
    version: '',
    eintraege: eintraege,
  );
  return ImportErgebnis(
    Artikeldatei(
      quelle: quelle,
      version: _pruefsumme(jsonEncode(ohneVersion.alsJson()['artikel'])),
      eintraege: eintraege,
    ),
    befunde,
  );
}

Artikeleintrag? _eintrag(
  int zeile,
  Map<String, String> w,
  List<Holzart> holzarten,
  List<Befund> befunde,
) {
  int kritische() => befunde.where((b) => b.kritisch).length;
  final kritischVorher = kritische();
  void fehler(String feld, String text) =>
      befunde.add(Befund(zeile, feld, text));
  String text(String feld) => w[feld] ?? '';

  num? zahl(String feld) {
    final t = text(feld).replaceAll(',', '.');
    if (t.isEmpty) return null;
    final n = num.tryParse(t);
    if (n == null) fehler(feld, 'keine Zahl: „${text(feld)}“');
    return n;
  }

  Millimeter? mm(String feld) {
    final n = zahl(feld);
    if (n == null || n == 0) return null;
    if (n.round() == 0) {
      befunde.add(
        Befund(
          zeile,
          feld,
          'unter 1 mm ($n) – nicht übernommen',
          kritisch: false,
        ),
      );
      return null;
    }
    return Millimeter(n.round());
  }

  final nummer = text('Artikelnummer');
  // Name wie im Planer; „Artikelbezeichnung“ enthält oft eine Beschreibung.
  final titel = text('ArtikelbezeichnungKonfi').isNotEmpty
      ? text('ArtikelbezeichnungKonfi')
      : text('Artikelbezeichnung');
  if (nummer.isEmpty) fehler('Artikelnummer', 'fehlt');
  if (titel.isEmpty) fehler('Artikelbezeichnung', 'fehlt');
  final art = artikelartFuer(text('Artikeltyp'), titel, text('Zubehoergruppe'));
  if (art == null) fehler('Artikeltyp', 'unbekannt: „${text('Artikeltyp')}“');
  final einheit = Mengeneinheit.lies(text('VPE'));
  if (einheit == null) fehler('VPE', 'unbekannte Einheit: „${text('VPE')}“');
  final inhalt = zahl('Inhalt_pro_Einheit') ?? 1;
  final preis = zahl('Preis_pro_Einheit');
  final breite = mm('Breite_cm');
  final staerke = mm('Staerke_cm');
  final laenge = mm('Laenge_cm');

  Holzart? holzart;
  Serie? serie;
  if (art != null && art.istHolz) {
    holzart = holzarten.where((h) => titel.contains(h.name)).firstOrNull;
    serie = holzart?.serien.keys
        .where((s) => titel.contains(s.name))
        .firstOrNull;
    if (holzart == null) fehler('Artikelbezeichnung', 'Holzart nicht erkannt');
    if (holzart != null && serie == null) {
      fehler('Artikelbezeichnung', 'Serie nicht erkannt');
    }
  }

  final verweise = {
    for (final spalte in verweisSpalten) spalte: _nummern(text(spalte)),
  };
  final angaben = <String, int>{
    for (final spalte in angabenSpalten)
      if (zahl(spalte) case final n?) spalte: n.round(),
    for (final spalte in schalterSpalten)
      if (text(spalte).isNotEmpty)
        spalte: text(spalte).toLowerCase() == 'true' ? 1 : 0,
  };
  final benoetigt = <Artikelnummer, int>{};
  final zubehoer = _nummern(text('benoetigtesZubehoer'));
  final anzahlen = text('benoetigtesZubehoer_anzahl').split(RegExp('[;,]'));
  for (final (i, n) in zubehoer.indexed) {
    final anzahl = i < anzahlen.length
        ? int.tryParse(anzahlen[i].trim())
        : null;
    if (anzahl == null) {
      fehler('benoetigtesZubehoer_anzahl', 'Anzahl fehlt für ${n.wert}');
    } else {
      benoetigt[n] = anzahl;
    }
  }

  if (kritische() > kritischVorher) return null;
  try {
    return Artikeleintrag(
      artikel: Artikel(
        nummer: Artikelnummer(nummer),
        titel: titel,
        art: art!,
        einheit: Verkaufseinheit(einheit!, inhalt: inhalt),
        abmessungen: Abmessungen(
          breite: breite,
          staerke: staerke,
          laengen: [?laenge],
        ),
        preisBrutto: preis == null ? null : Cent.ausEuro(preis),
        holzart: holzart,
        serie: serie,
        profil: art.istHolz && art != Artikelart.unterkonstruktion
            ? _profil(titel, text('Materialobergruppe'))
            : null,
        oberseite: art == Artikelart.diele || art == Artikelart.systemdiele
            ? (titel.contains('bombiert')
                  ? Oberseite.bombiert
                  : Oberseite.glatt)
            : null,
        bilder: [
          for (final spalte in ['Abbildung_1', 'Abbildung_2', 'Abbildung_3'])
            if (text(spalte).isNotEmpty) text(spalte),
        ],
      ),
      verweise: verweise,
      angaben: angaben,
      benoetigt: benoetigt,
    );
  } on ArgumentError catch (e) {
    fehler(e.name ?? 'Artikel', '${e.message}');
    return null;
  }
}

/// Artikelart aus den Typ-Texten des alten Planers (M2-02); `null` =
/// unbekannt.
Artikelart? artikelartFuer(String typ, String titel, String gruppe) {
  final t = titel.toLowerCase();
  return switch (typ.replaceFirst(RegExp('^_'), '')) {
    'Deckbelag' =>
      t.contains('systemdiele') ? Artikelart.systemdiele : Artikelart.diele,
    'Deckbelag,Zubehoer' => Artikelart.holzfliese,
    'Unterkonstruktion' =>
      t.contains('robinie')
          ? Artikelart.unterkonstruktion
          : Artikelart.aluUnterkonstruktion,
    'BefestigungDeck' || 'BefestigungDeck,Zubehoer' =>
      t.contains('schraube') ? Artikelart.schraube : Artikelart.clip,
    'Stellfuss,Zubehoer' => Artikelart.stellfuss,
    'Unterlegpads,Zubehoer' => Artikelart.pad,
    'PadUnterStelzfuss,Zubehoer' => Artikelart.padUnterStellfuss,
    'Bodenanker' => Artikelart.bodenanker,
    'Laengsverbinder' => Artikelart.laengsverbinder,
    'Querverbinder' => Artikelart.querverbinder,
    'Eckverbinder' => Artikelart.eckverbinder,
    'VariablerEckverbinder' => Artikelart.variablerVerbinder,
    'Blendenhalter' => Artikelart.blendenhalter,
    'Verblendung' => Artikelart.verblendung,
    'Drainage' => Artikelart.rinne,
    'Unterrinne' ||
    'HalterEntwässerungsrinne' ||
    'DrainageZubehoer' => Artikelart.rinnenzubehoer,
    'EPDM-Band,Zubehoer' => Artikelart.gummiband,
    'Zubehoer' => _zubehoer(t, gruppe),
    _ => null,
  };
}

Artikelart _zubehoer(String titel, String gruppe) => switch (gruppe) {
  'Terrassenöl RIBOL' => Artikelart.pflege,
  'Anlieferung' => Artikelart.dienstleistung,
  'Höhenausgleich' => Artikelart.stellfuss,
  'Pads & EPDM Bänder' => Artikelart.pad,
  'Clips & Schrauben' =>
    titel.contains('schraube') ? Artikelart.schraube : Artikelart.clip,
  _ =>
    RegExp(r'\bbit\b|tx\d|bohr|handschuh|montage|abstandshalter')
            .hasMatch(titel)
        ? Artikelart.werkzeug
        : Artikelart.sonstiges,
};

Profil _profil(String titel, String obergruppe) =>
    titel.contains('glattkant') || obergruppe == 'Sichtbar befestigt'
    ? Profil.glattkant
    : Profil.genutet;

/// Artikelnummern aus einer Liste („a,b;c“); leere Einträge und „0“ entfallen.
List<Artikelnummer> _nummern(String liste) => [
  for (final teil in liste.split(RegExp('[;,]')))
    if (teil.trim().isNotEmpty && teil.trim() != '0')
      Artikelnummer(teil.trim()),
];

/// FNV-1a (64 Bit) als Versionskennung des Inhalts (16 Hex-Zeichen).
String _pruefsumme(String text) {
  var hash = 0xcbf29ce484222325;
  for (final b in utf8.encode(text)) {
    hash = (hash ^ b) * 0x100000001b3;
  }
  String haelfte(int wert) => wert.toRadixString(16).padLeft(8, '0');
  return haelfte(hash >>> 32) + haelfte(hash & 0xFFFFFFFF);
}
