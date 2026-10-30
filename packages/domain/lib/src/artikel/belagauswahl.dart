import '../holzart/holzart.dart';
import '../regeln/planungsregeln.dart' as regeln;
import 'artikel.dart';
import 'artikel_json.dart';
import 'einheiten.dart';

/// Kategorien im Dialog „Terrassenbelag auswählen“ (Fachkonzept 2.1).
enum Belagkategorie {
  /// Genutete Dielen, verdeckt mit Clips befestigt.
  unsichtbar,

  /// Glattkantige Dielen, von oben verschraubt.
  sichtbar,
  holzfliese;

  static Belagkategorie von(Artikel a) => a.art == Artikelart.holzfliese
      ? holzfliese
      : a.profil == Profil.genutet
      ? unsichtbar
      : sichtbar;
}

/// Ein Belag mit den Preisen, die der Dialog anzeigt (M5-01). Die Preise
/// rechnet der Server; sie sind nur Anzeige (B-055).
final class Belagangebot {
  const Belagangebot(this.artikel, {this.preisJeLfm, this.preisJeM2});

  /// Rechnet die Preise je lfm und je m² aus dem Preis der Verkaufseinheit.
  /// Ein Meter Diele deckt Breite plus Fuge (R-B06, Alexander 29.10.2026).
  factory Belagangebot.aus(Artikel a) {
    final preis = a.preisBrutto;
    final breite = a.abmessungen.breite;
    if (preis == null || breite == null) return Belagangebot(a);
    final deckbreite = (breite + regeln.fuge).m;
    final inhalt = a.einheit.inhalt;
    final laengen = a.abmessungen.laengen;
    final einzeln = preis.cent / inhalt;
    if (a.art == Artikelart.holzfliese) {
      return Belagangebot(
        a,
        preisJeM2: laengen.length == 1
            ? Cent((einzeln / (breite.m * laengen.single.m)).round())
            : null,
      );
    }
    final jeLfm = switch (a.einheit.einheit) {
      Mengeneinheit.laufmeter => einzeln,
      Mengeneinheit.quadratmeter => einzeln * deckbreite,
      _ when laengen.length == 1 => einzeln / laengen.single.m,
      _ => null,
    };
    return Belagangebot(
      a,
      preisJeLfm: jeLfm == null ? null : Cent(jeLfm.round()),
      preisJeM2: jeLfm == null ? null : Cent((jeLfm / deckbreite).round()),
    );
  }

  factory Belagangebot.ausJson(
    Map<String, Object?> j,
    Map<String, Holzart> holzarten,
  ) => Belagangebot(
    artikelAusJson(j['artikel']! as Map<String, Object?>, holzarten),
    preisJeLfm: switch (j['preis_lfm_cent']) {
      final int c => Cent(c),
      _ => null,
    },
    preisJeM2: switch (j['preis_m2_cent']) {
      final int c => Cent(c),
      _ => null,
    },
  );

  final Artikel artikel;
  final Cent? preisJeLfm;
  final Cent? preisJeM2;

  Belagkategorie get kategorie => Belagkategorie.von(artikel);

  Map<String, Object?> alsJson() => {
    'artikel': artikelAlsJson(artikel),
    'preis_lfm_cent': preisJeLfm?.cent,
    'preis_m2_cent': preisJeM2?.cent,
  };
}

/// Filter im Dialog „Terrassenbelag auswählen“: Kategorie, Mehrfachauswahl
/// je Merkmal und freie Suche in Titel und Artikelnummer. Leere Felder
/// filtern nicht.
final class Belagfilter {
  const Belagfilter({
    this.kategorie,
    this.serien = const {},
    this.oberseiten = const {},
    this.breiten = const {},
    this.staerken = const {},
    this.laengen = const {},
    this.suche = '',
  });

  final Belagkategorie? kategorie;
  final Set<Serie> serien;
  final Set<Oberseite> oberseiten;
  final Set<Millimeter> breiten;
  final Set<Millimeter> staerken;

  /// Passt, wenn der Belag eine der Längen liefern kann.
  final Set<Millimeter> laengen;
  final String suche;

  bool passt(Belagangebot b) {
    final a = b.artikel;
    final text = suche.trim().toLowerCase();
    return (kategorie == null || b.kategorie == kategorie) &&
        _enthaelt(serien, a.serie) &&
        _enthaelt(oberseiten, a.oberseite) &&
        _enthaelt(breiten, a.abmessungen.breite) &&
        _enthaelt(staerken, a.abmessungen.staerke) &&
        (laengen.isEmpty || a.abmessungen.laengen.any(laengen.contains)) &&
        (a.titel.toLowerCase().contains(text) ||
            a.nummer.wert.toLowerCase().contains(text));
  }

  static bool _enthaelt<T>(Set<T> auswahl, T? wert) =>
      auswahl.isEmpty || auswahl.contains(wert);

  Belagfilter kopie({
    Belagkategorie? kategorie,
    bool ohneKategorie = false,
    Set<Serie>? serien,
    Set<Oberseite>? oberseiten,
    Set<Millimeter>? breiten,
    Set<Millimeter>? staerken,
    Set<Millimeter>? laengen,
    String? suche,
  }) => Belagfilter(
    kategorie: ohneKategorie ? null : kategorie ?? this.kategorie,
    serien: serien ?? this.serien,
    oberseiten: oberseiten ?? this.oberseiten,
    breiten: breiten ?? this.breiten,
    staerken: staerken ?? this.staerken,
    laengen: laengen ?? this.laengen,
    suche: suche ?? this.suche,
  );
}

/// Alle Beläge der Artikeldaten in Datenreihenfolge (M5-01). Der erste ist
/// die Vorgabe (Alexander 29.10.2026): die Reihenfolge steuert die
/// Upload-Datei.
final class Belagauswahl {
  Belagauswahl(this.version, Iterable<Belagangebot> belaege)
    : belaege = List.unmodifiable(belaege);

  factory Belagauswahl.ausJson(
    Map<String, Object?> j,
    Map<String, Holzart> holzarten,
  ) => Belagauswahl(j['version']! as String, [
    for (final b in j['belaege']! as List<Object?>)
      Belagangebot.ausJson(b! as Map<String, Object?>, holzarten),
  ]);

  final String version;
  final List<Belagangebot> belaege;

  /// Vorgabe-Belag; `null`, wenn die Artikeldaten keinen Belag enthalten.
  Belagangebot? get vorgabe => belaege.firstOrNull;

  /// Der gewählte Belag [nummer] oder – ohne Wahl oder wenn es ihn nicht
  /// mehr gibt – die Vorgabe.
  Belagangebot? gewaehlt(Artikelnummer? nummer) =>
      belaege.where((b) => b.artikel.nummer == nummer).firstOrNull ?? vorgabe;

  List<Belagangebot> gefiltert(Belagfilter filter) =>
      belaege.where(filter.passt).toList();

  /// Vorhandene Kategorien und Merkmalswerte für die Filter, sortiert.
  List<Belagkategorie> get kategorien => Belagkategorie.values
      .where((k) => belaege.any((b) => b.kategorie == k))
      .toList();
  List<Serie> get serien =>
      _werte((a) => [?a.serie], (x, y) => x.name.compareTo(y.name));
  List<Oberseite> get oberseiten =>
      _werte((a) => [?a.oberseite], (x, y) => x.index.compareTo(y.index));
  List<Millimeter> get breiten =>
      _werte((a) => [?a.abmessungen.breite], _nachMm);
  List<Millimeter> get staerken =>
      _werte((a) => [?a.abmessungen.staerke], _nachMm);
  List<Millimeter> get laengen => _werte((a) => a.abmessungen.laengen, _nachMm);

  List<T> _werte<T>(
    List<T> Function(Artikel) wert,
    int Function(T, T) vergleich,
  ) => {for (final b in belaege) ...wert(b.artikel)}.toList()..sort(vergleich);

  static int _nachMm(Millimeter x, Millimeter y) => x.mm.compareTo(y.mm);

  Map<String, Object?> alsJson() => {
    'version': version,
    'belaege': [for (final b in belaege) b.alsJson()],
  };
}
