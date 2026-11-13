import '../holzart/holzart.dart';
import 'artikel.dart';
import 'belagauswahl.dart';
import 'einheiten.dart';

/// Ob [uk] zum [belag] passt (M6-03, Abnahme „nur zum Belag passende UK“):
/// UK-Holz derselben Holzart und Serie, dessen Format zur Serie gehört –
/// Breite und Stärke tauschbar (R-A08, B-034), auch die nur ungetrocknet
/// lieferbaren Formate (B-212). Alu-UK nicht: im Planer nur Robinie (B-122).
/// Bestimmt die Serie des Belags eine andere UK-Serie
/// ([Serienregeln.ukSerie]), gilt diese: MASSIV auf ECO SELECT (B-232).
bool ukPasstZuBelag(Artikel uk, Artikel belag) {
  final (holzart, serie, breite, staerke) = (
    uk.holzart,
    uk.serie,
    uk.abmessungen.breite,
    uk.abmessungen.staerke,
  );
  return uk.art == Artikelart.unterkonstruktion &&
      holzart != null &&
      holzart.id == belag.holzart?.id &&
      serie == _ukSerie(holzart, belag.serie) &&
      breite != null &&
      staerke != null &&
      holzart.serie(serie!).ukFormat(breite, staerke) != UkFormat.ungueltig;
}

/// UK-Serie zur Belagserie [serie] der [holzart].
Serie? _ukSerie(Holzart holzart, Serie? serie) =>
    serie == null ? null : holzart.serie(serie).ukSerie ?? serie;

/// Lieferlängen einer UK (M6-03): die Längen der Artikeldaten und die
/// UK-Lieferlängen ihrer Serie (R-A06, B-035; ECO SELECT nur 4/5/6 m,
/// B-230), aufsteigend. Die Upload-Datei
/// führt je UK nur eine Länge (6000 mm), geliefert wird aber wie bei den
/// Dielen in allen Längen der Serie – der alte Planer bot nur 600 cm an,
/// rechnete aber mit anderen Längen (Fehler, Fachkonzept 09).
List<Millimeter> ukLieferlaengen(Artikel uk) {
  final serie = uk.serie;
  return {
    ...uk.abmessungen.laengen,
    if (serie != null) ...uk.holzart!.serie(serie).ukLieferlaengen,
  }.toList()..sort((a, b) => a.mm.compareTo(b.mm));
}

/// Unterkonstruktionen zum Belag für den Dialog „Unterkonstruktion
/// auswählen“ (M6-03) in Datenreihenfolge; die erste ist die Vorgabe. Die
/// Preise je lfm rechnet der Server; sie sind nur Anzeige (B-055).
final class Ukauswahl {
  Ukauswahl(this.version, Iterable<Belagangebot> angebote)
    : angebote = List.unmodifiable(angebote);

  /// Die passenden UK aus [artikel] für den [belag]; ohne Belag keine.
  factory Ukauswahl.fuer(
    String version,
    Artikel? belag,
    Iterable<Artikel> artikel,
  ) => Ukauswahl(version, [
    if (belag != null)
      for (final a in artikel)
        if (ukPasstZuBelag(a, belag)) Belagangebot.jeLfm(a),
  ]);

  factory Ukauswahl.ausJson(
    Map<String, Object?> j,
    Map<String, Holzart> holzarten,
  ) => Ukauswahl(j['version']! as String, [
    for (final a in j['unterkonstruktionen']! as List<Object?>)
      Belagangebot.ausJson(a! as Map<String, Object?>, holzarten),
  ]);

  final String version;
  final List<Belagangebot> angebote;

  /// Vorgabe; `null`, wenn keine UK zum Belag passt.
  Belagangebot? get vorgabe => angebote.firstOrNull;

  /// Die gewählte UK [nummer] oder – ohne Wahl oder wenn sie nicht (mehr)
  /// zum Belag passt – die Vorgabe.
  Belagangebot? gewaehlt(Artikelnummer? nummer) =>
      angebote.where((a) => a.artikel.nummer == nummer).firstOrNull ?? vorgabe;

  Map<String, Object?> alsJson() => {
    'version': version,
    'unterkonstruktionen': [for (final a in angebote) a.alsJson()],
  };
}
