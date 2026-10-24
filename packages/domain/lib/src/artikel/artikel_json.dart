import '../holzart/holzart.dart';
import 'artikel.dart';
import 'einheiten.dart';

/// JSON-Darstellung eines Artikels – gleich in Artikeldatei und WAMP-Antworten
/// (M2-06). Nur Verkaufsdaten (B-020).
Map<String, Object?> artikelAlsJson(Artikel a) => {
  'nummer': a.nummer.wert,
  'titel': a.titel,
  'art': a.art.name,
  'einheit': a.einheit.einheit.name,
  'inhalt': a.einheit.inhalt,
  'inhalt_einheit': a.einheit.inhaltEinheit?.name,
  'breite_mm': a.abmessungen.breite?.mm,
  'staerke_mm': a.abmessungen.staerke?.mm,
  'laengen_mm': [for (final l in a.abmessungen.laengen) l.mm],
  'preis_brutto_cent': a.preisBrutto?.cent,
  'gewicht_g': a.gewicht?.g,
  'holzart': a.holzart?.id,
  'serie': a.serie?.name,
  'profil': a.profil?.name,
  'oberseite': a.oberseite?.name,
  'bilder': a.bilder,
};

/// Liest [artikelAlsJson]; [holzarten] löst die Holzart-Kennungen auf.
Artikel artikelAusJson(Map<String, Object?> j, Map<String, Holzart> holzarten) {
  T? opt<T, R>(String feld, T Function(R) wandle) =>
      j[feld] == null ? null : wandle(j[feld] as R);
  final holzartId = j['holzart'] as String?;
  final holzart = holzartId == null
      ? null
      : holzarten[holzartId] ??
            (throw ArgumentError.value(holzartId, 'holzart', 'unbekannt'));
  return Artikel(
    nummer: Artikelnummer.pruefe(j['nummer']! as String),
    titel: j['titel']! as String,
    art: Artikelart.values.byName(j['art']! as String),
    einheit: Verkaufseinheit(
      Mengeneinheit.values.byName(j['einheit']! as String),
      inhalt: j['inhalt']! as num,
      inhaltEinheit: opt('inhalt_einheit', Mengeneinheit.values.byName),
    ),
    abmessungen: Abmessungen(
      breite: opt('breite_mm', Millimeter.new),
      staerke: opt('staerke_mm', Millimeter.new),
      laengen: [
        for (final l in j['laengen_mm']! as List<Object?>)
          Millimeter(l! as int),
      ],
    ),
    preisBrutto: opt('preis_brutto_cent', Cent.new),
    gewicht: opt('gewicht_g', Gramm.new),
    holzart: holzart,
    serie: opt('serie', Serie.new),
    profil: opt('profil', Profil.values.byName),
    oberseite: opt('oberseite', Oberseite.values.byName),
    bilder: [for (final b in j['bilder']! as List<Object?>) b! as String],
  );
}
