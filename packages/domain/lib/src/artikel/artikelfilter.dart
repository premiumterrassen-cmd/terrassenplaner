import '../holzart/holzart.dart';
import 'artikel.dart';

/// Filter für die Artikelauswahl (M2-06), z. B. alle genuteten Beläge der
/// Serie PREMIUM SELECT. Leere Felder filtern nicht.
final class Artikelfilter {
  const Artikelfilter({
    this.bereich,
    this.art,
    this.holzart,
    this.serie,
    this.profil,
    this.oberseite,
  });

  /// Liest [alsJson]; unbekannte Werte sind ein Fehler.
  factory Artikelfilter.ausJson(Map<String, Object?> j) {
    T? opt<T>(String feld, T Function(String) wandle) =>
        j[feld] == null ? null : wandle(j[feld]! as String);
    return Artikelfilter(
      bereich: opt('bereich', Bereich.values.byName),
      art: opt('art', Artikelart.values.byName),
      holzart: opt('holzart', (id) => id),
      serie: opt('serie', Serie.new),
      profil: opt('profil', Profil.values.byName),
      oberseite: opt('oberseite', Oberseite.values.byName),
    );
  }

  final Bereich? bereich;
  final Artikelart? art;

  /// Kennung der Holzart (`Holzart.id`).
  final String? holzart;
  final Serie? serie;
  final Profil? profil;
  final Oberseite? oberseite;

  bool passt(Artikel a) =>
      (bereich == null || a.art.bereich == bereich) &&
      (art == null || a.art == art) &&
      (holzart == null || a.holzart?.id == holzart) &&
      (serie == null || a.serie == serie) &&
      (profil == null || a.profil == profil) &&
      (oberseite == null || a.oberseite == oberseite);

  Map<String, Object?> alsJson() => {
    'bereich': ?bereich?.name,
    'art': ?art?.name,
    'holzart': ?holzart,
    'serie': ?serie?.name,
    'profil': ?profil?.name,
    'oberseite': ?oberseite?.name,
  };
}
