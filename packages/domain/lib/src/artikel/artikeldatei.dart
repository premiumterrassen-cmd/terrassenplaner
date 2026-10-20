import '../holzart/holzart.dart';
import 'artikel.dart';
import 'einheiten.dart';

/// Geprüfte Artikeldatei für den Server (M2-02): Artikel plus die Angaben
/// und Verweise des Planer-Blatts, aus denen M2-04 das Regelwerk baut.
/// Nur Verkaufsdaten (B-020); keine Herstellerangaben (B-023).
final class Artikeleintrag {
  Artikeleintrag({
    required this.artikel,
    Map<String, List<Artikelnummer>> verweise = const {},
    Map<String, int> angaben = const {},
    Map<Artikelnummer, int> benoetigt = const {},
  }) : verweise = Map.unmodifiable({
         for (final MapEntry(:key, :value) in verweise.entries)
           if (value.isNotEmpty) key: List<Artikelnummer>.unmodifiable(value),
       }),
       angaben = Map.unmodifiable(angaben),
       benoetigt = Map.unmodifiable(benoetigt);

  final Artikel artikel;

  /// Verweise auf andere Artikel je Beziehung, z. B.
  /// `moeglicheBefestigungDeck` → [CLIP-FIXX …].
  final Map<String, List<Artikelnummer>> verweise;

  /// Planer-Angaben in mm, z. B. `Abstand_UK` → 400.
  final Map<String, int> angaben;

  /// Benötigtes Zubehör mit Anzahl je Artikel.
  final Map<Artikelnummer, int> benoetigt;
}

/// Artikeldatei mit Herkunft und Versionskennung (M2-06 nutzt die Version).
final class Artikeldatei {
  Artikeldatei({
    required this.quelle,
    required this.version,
    required Iterable<Artikeleintrag> eintraege,
  }) : eintraege = List.unmodifiable(eintraege) {
    final doppelt = <Artikelnummer>{};
    final gesehen = <Artikelnummer>{};
    for (final e in this.eintraege) {
      if (!gesehen.add(e.artikel.nummer)) doppelt.add(e.artikel.nummer);
    }
    if (doppelt.isNotEmpty) {
      throw ArgumentError.value(
        doppelt.map((n) => n.wert).join(', '),
        'eintraege',
        'doppelte Artikelnummern',
      );
    }
  }

  /// Liest die JSON-Darstellung; [holzarten] löst die Holzart-Kennungen auf.
  factory Artikeldatei.ausJson(
    Map<String, Object?> json,
    Iterable<Holzart> holzarten,
  ) {
    final nachId = {for (final h in holzarten) h.id: h};
    return Artikeldatei(
      quelle: json['quelle']! as String,
      version: json['version']! as String,
      eintraege: [
        for (final e in json['artikel']! as List<Object?>)
          _eintragAusJson(e! as Map<String, Object?>, nachId),
      ],
    );
  }

  /// Dateiname oder Beschreibung der Quelle.
  final String quelle;

  /// Versionskennung des Inhalts (z. B. Prüfsumme).
  final String version;

  final List<Artikeleintrag> eintraege;

  /// Artikel zur Nummer oder `null`.
  Artikeleintrag? operator [](Artikelnummer nummer) {
    for (final e in eintraege) {
      if (e.artikel.nummer == nummer) return e;
    }
    return null;
  }

  Map<String, Object?> alsJson() => {
    'quelle': quelle,
    'version': version,
    'artikel': [for (final e in eintraege) _eintragAlsJson(e)],
  };
}

Map<String, Object?> _eintragAlsJson(Artikeleintrag e) {
  final a = e.artikel;
  return {
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
    'verweise': {
      for (final MapEntry(:key, :value) in e.verweise.entries)
        key: [for (final n in value) n.wert],
    },
    'angaben': e.angaben,
    'benoetigt': {
      for (final MapEntry(:key, :value) in e.benoetigt.entries) key.wert: value,
    },
  };
}

Artikeleintrag _eintragAusJson(
  Map<String, Object?> j,
  Map<String, Holzart> holzarten,
) {
  T? opt<T, R>(String feld, T Function(R) wandle) =>
      j[feld] == null ? null : wandle(j[feld] as R);
  final holzartId = j['holzart'] as String?;
  final holzart = holzartId == null
      ? null
      : holzarten[holzartId] ??
            (throw ArgumentError.value(holzartId, 'holzart', 'unbekannt'));
  return Artikeleintrag(
    artikel: Artikel(
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
    ),
    verweise: {
      for (final MapEntry(:key, :value)
          in (j['verweise']! as Map<String, Object?>).entries)
        key: [
          for (final n in value! as List<Object?>)
            Artikelnummer.pruefe(n! as String),
        ],
    },
    angaben: {
      for (final MapEntry(:key, :value)
          in (j['angaben']! as Map<String, Object?>).entries)
        key: value! as int,
    },
    benoetigt: {
      for (final MapEntry(:key, :value)
          in (j['benoetigt']! as Map<String, Object?>).entries)
        Artikelnummer.pruefe(key): value! as int,
    },
  );
}
