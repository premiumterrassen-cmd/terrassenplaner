import '../artikel/artikel.dart';
import '../artikel/artikel_json.dart';
import '../artikel/artikeldatei.dart';
import '../artikel/artikelfilter.dart';
import '../artikel/einheiten.dart';
import '../holzart/holzart.dart';

/// Beziehung „was passt zu was“ – je eine Spalte der Upload-Datei (M2-04).
enum Beziehung {
  befestigung('moeglicheBefestigungDeck'),
  zubehoer('moeglichesZubehoer'),
  stellfussPrivat('moeglicherStellfussPrivat'),
  stellfussGewerblich('moeglicherStellfussGewerblich'),
  unterlegpads('moeglicheUnterlegpads'),
  laengsverbinder('moeglicheLaengsverbinder'),
  querverbinder('moeglicheQuerverbinder'),
  verblendung('moeglicheVerblendung'),
  drainage('moeglicheDrainage'),
  startEndClip('moeglicheStartEndClip'),
  eckverbinder('moeglicheEckverbinder'),
  variablerVerbinder('moeglicheVariableverbinder');

  const Beziehung(this.spalte);

  /// Spalte der Upload-Datei bzw. Schlüssel in [Artikeleintrag.verweise].
  final String spalte;
}

/// Abstände und Höhen eines Artikels laut Artikeldaten (M2-04).
final class Abstaende {
  const Abstaende({
    this.stelzfuesse,
    this.uk,
    this.ukVomRand,
    this.minHoehe,
    this.maxHoehe,
    this.reichweite = false,
  });

  /// Liest [alsJson].
  factory Abstaende.ausJson(Map<String, Object?> j) {
    Millimeter? mm(String feld) =>
        j[feld] == null ? null : Millimeter(j[feld]! as int);
    return Abstaende(
      stelzfuesse: mm('stelzfuesse_mm'),
      uk: mm('uk_mm'),
      ukVomRand: mm('uk_vom_rand_mm'),
      minHoehe: mm('min_hoehe_mm'),
      maxHoehe: mm('max_hoehe_mm'),
      reichweite: j['reichweite']! as bool,
    );
  }

  /// Höchster Abstand der Stelzfüße.
  final Millimeter? stelzfuesse;

  /// Höchster UK-Achsabstand laut Artikel (die Holzart kann strenger sein).
  final Millimeter? uk;

  /// Abstand der äußeren UK vom Rand.
  final Millimeter? ukVomRand;
  final Millimeter? minHoehe;
  final Millimeter? maxHoehe;

  /// Schalter „Reichweite“ der Artikeldaten.
  final bool reichweite;

  Map<String, Object?> alsJson() => {
    'stelzfuesse_mm': stelzfuesse?.mm,
    'uk_mm': uk?.mm,
    'uk_vom_rand_mm': ukVomRand?.mm,
    'min_hoehe_mm': minHoehe?.mm,
    'max_hoehe_mm': maxHoehe?.mm,
    'reichweite': reichweite,
  };
}

/// Alle Regeln zu einem Artikel in einer Antwort (M2-06): die App fragt sie
/// beim Server ab und rechnet selbst nichts aus (Frontend bleibt „doof“).
final class Artikelregeln {
  Artikelregeln({
    required this.version,
    required Map<Beziehung, List<Artikel>> moeglich,
    required Map<Artikel, int> pflichtzubehoer,
    required this.abstaende,
  }) : moeglich = Map.unmodifiable(moeglich),
       pflichtzubehoer = Map.unmodifiable(pflichtzubehoer);

  /// Liest [alsJson]; [holzarten] löst die Holzart-Kennungen auf.
  factory Artikelregeln.ausJson(
    Map<String, Object?> j,
    Map<String, Holzart> holzarten,
  ) {
    Artikel artikel(Object? a) =>
        artikelAusJson(a! as Map<String, Object?>, holzarten);
    return Artikelregeln(
      version: j['version']! as String,
      moeglich: {
        for (final MapEntry(:key, :value)
            in (j['moeglich']! as Map<String, Object?>).entries)
          Beziehung.values.byName(key): [
            for (final a in value! as List<Object?>) artikel(a),
          ],
      },
      pflichtzubehoer: {
        for (final p
            in (j['pflichtzubehoer']! as List<Object?>)
                .cast<Map<String, Object?>>())
          artikel(p['artikel']): p['anzahl']! as int,
      },
      abstaende: Abstaende.ausJson(j['abstaende']! as Map<String, Object?>),
    );
  }

  /// Versionskennung der Artikeldaten, aus denen die Regeln stammen.
  final String version;

  /// Auswahl je Beziehung; Beziehungen ohne Auswahl fehlen.
  final Map<Beziehung, List<Artikel>> moeglich;
  final Map<Artikel, int> pflichtzubehoer;
  final Abstaende abstaende;

  Map<String, Object?> alsJson() => {
    'version': version,
    'moeglich': {
      for (final MapEntry(:key, :value) in moeglich.entries)
        key.name: [for (final a in value) artikelAlsJson(a)],
    },
    'pflichtzubehoer': [
      for (final MapEntry(:key, :value) in pflichtzubehoer.entries)
        {'artikel': artikelAlsJson(key), 'anzahl': value},
    ],
    'abstaende': abstaende.alsJson(),
  };
}

/// Regelwerk „was passt zu was“ (M2-04) – vollständig aus der Artikeldatei,
/// nichts fest verdrahtet. Reihenfolge der Auswahl wie in den Daten.
final class Regelwerk {
  Regelwerk(this.datei);

  final Artikeldatei datei;

  Artikeleintrag _eintrag(Artikelnummer nummer) =>
      datei[nummer] ??
      (throw ArgumentError.value(nummer.wert, 'nummer', 'Artikel unbekannt'));

  /// Mögliche Artikel einer Beziehung für einen Artikel (z. B. Befestigung je
  /// Belag); leer, wenn die Daten nichts angeben.
  List<Artikel> moeglich(Artikelnummer nummer, Beziehung beziehung) {
    final ziele =
        _eintrag(nummer).verweise[beziehung.spalte] ?? const <Artikelnummer>[];
    return [for (final ziel in ziele) _eintrag(ziel).artikel];
  }

  /// Stellfüße je Nutzung (privat/gewerblich).
  List<Artikel> stellfuesse(Artikelnummer nummer, {required bool gewerblich}) =>
      moeglich(
        nummer,
        gewerblich ? Beziehung.stellfussGewerblich : Beziehung.stellfussPrivat,
      );

  /// Pflichtzubehör mit Anzahl je Artikel.
  Map<Artikel, int> pflichtzubehoer(Artikelnummer nummer) => {
    for (final MapEntry(:key, :value) in _eintrag(nummer).benoetigt.entries)
      _eintrag(key).artikel: value,
  };

  /// Abstände und Höhen laut Artikeldaten.
  Abstaende abstaende(Artikelnummer nummer) {
    final g = _eintrag(nummer).angaben;
    Millimeter? mm(String spalte) =>
        g[spalte] == null ? null : Millimeter(g[spalte]!);
    return Abstaende(
      stelzfuesse: mm('Abstand_Stelzfuesse'),
      uk: mm('Abstand_UK'),
      ukVomRand: mm('UK_Abstand_vom_Rand'),
      minHoehe: mm('MinHoehe'),
      maxHoehe: mm('MaxHoehe'),
      reichweite: g['Reichweite'] == 1,
    );
  }

  /// Alle Regeln zu einem Artikel – Antwort des Artikeldienstes (M2-06).
  Artikelregeln regeln(Artikelnummer nummer) => Artikelregeln(
    version: datei.version,
    moeglich: {
      for (final b in Beziehung.values)
        if (moeglich(nummer, b) case final auswahl when auswahl.isNotEmpty)
          b: auswahl,
    },
    pflichtzubehoer: pflichtzubehoer(nummer),
    abstaende: abstaende(nummer),
  );

  /// Artikel, auf die [filter] passt, in Datenreihenfolge.
  List<Artikel> finde(Artikelfilter filter) => [
    for (final e in datei.eintraege)
      if (filter.passt(e.artikel)) e.artikel,
  ];

  /// Alle Artikel eines Bereichs, z. B. die Beläge zur Auswahl.
  List<Artikel> imBereich(Bereich bereich) => [
    for (final e in datei.eintraege)
      if (e.artikel.art.bereich == bereich) e.artikel,
  ];

  /// Widerspruch der Befestigungsverweise zur Firmenregel der Holzart
  /// (B-094, B-090): genutet nur Clips, glattkant nur Schrauben. `null`, wenn
  /// alles passt oder der Artikel kein Holzbelag mit Profil ist.
  String? befestigungWiderspruch(Artikelnummer nummer) {
    final a = _eintrag(nummer).artikel;
    final (holzart, serie, profil, breite) = (
      a.holzart,
      a.serie,
      a.profil,
      a.abmessungen.breite,
    );
    if (holzart == null || serie == null || profil == null || breite == null) {
      return null;
    }
    final regel = holzart.serie(serie).befestigung(profil, breite);
    final erlaubt = regel == Befestigung.verschraubungVonOben
        ? Artikelart.schraube
        : Artikelart.clip;
    final falsch = [
      for (final ziel in moeglich(nummer, Beziehung.befestigung))
        if (ziel.art != erlaubt) ziel.nummer.wert,
    ];
    return falsch.isEmpty
        ? null
        : '${regel.name} verlangt ${erlaubt.name}, verweist aber auf '
              '${falsch.join(', ')}';
  }
}
