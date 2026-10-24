import '../holzart/holzart.dart';
import 'artikel.dart';
import 'artikel_json.dart';

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
    for (final e in this.eintraege) {
      final nummer = e.artikel.nummer;
      if (_nachNummer.containsKey(nummer)) {
        doppelt.add(nummer);
      } else {
        _nachNummer[nummer] = e;
      }
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

  final _nachNummer = <Artikelnummer, Artikeleintrag>{};

  /// Artikel zur Nummer oder `null`.
  Artikeleintrag? operator [](Artikelnummer nummer) => _nachNummer[nummer];

  Map<String, Object?> alsJson() => {
    'quelle': quelle,
    'version': version,
    'artikel': [for (final e in eintraege) _eintragAlsJson(e)],
  };
}

Map<String, Object?> _eintragAlsJson(Artikeleintrag e) => {
  ...artikelAlsJson(e.artikel),
  'verweise': {
    for (final MapEntry(:key, :value) in e.verweise.entries)
      key: [for (final n in value) n.wert],
  },
  'angaben': e.angaben,
  'benoetigt': {
    for (final MapEntry(:key, :value) in e.benoetigt.entries) key.wert: value,
  },
};

Artikeleintrag _eintragAusJson(
  Map<String, Object?> j,
  Map<String, Holzart> holzarten,
) => Artikeleintrag(
  artikel: artikelAusJson(j, holzarten),
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
