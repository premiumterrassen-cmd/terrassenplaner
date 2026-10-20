/// Holzart als Fachmodell (M2-08): alle Planungseigenschaften sind Daten,
/// damit eine weitere Holzart (z. B. Kastanie) ohne Code-Änderung ergänzt
/// werden kann. Regelkatalog: `docs/fachkonzept/14-planungsregeln.md`.
library;

import '../artikel/einheiten.dart';

/// Serie einer Holzart, z. B. „PREMIUM SELECT“ – nur der Name, keine Werke
/// oder Herkunft (B-020).
extension type const Serie(String name) implements Object {}

/// Kantenprofil der Diele.
enum Profil {
  /// Beidseitig genutet für die verdeckte Befestigung.
  genutet,

  /// Ohne Nut, sichtbar von oben verschraubt.
  glattkant,
}

/// Befestigungsart der Diele auf der Unterkonstruktion (R-B01, R-B02).
enum Befestigung { clipFixx, duoClipFixx, verschraubungVonOben }

/// Ob ein UK-Format zur Serie gehört (R-A08).
enum UkFormat {
  /// Technisch getrocknet (KD), regulär im Sortiment.
  gueltig,

  /// Nur ungetrocknet lieferbar (B-212).
  ungetrocknet,

  /// Nicht im Sortiment.
  ungueltig,
}

/// Breiten und Stärken einer Serie für ein Profil (R-A04, R-A05).
final class Dielenformate {
  Dielenformate({
    required Iterable<Millimeter> breiten,
    required Iterable<Millimeter> staerken,
  }) : breiten = Set.unmodifiable(breiten),
       staerken = Set.unmodifiable(staerken);

  final Set<Millimeter> breiten;
  final Set<Millimeter> staerken;

  bool enthaelt(Millimeter breite, Millimeter staerke) =>
      breiten.contains(breite) && staerken.contains(staerke);
}

/// UK-Format aus zwei Seiten; Breite und Stärke sind tauschbar (B-034).
typedef UkMasse = ({Millimeter a, Millimeter b});

/// Planungsregeln einer Serie.
final class Serienregeln {
  Serienregeln({
    required this.serie,
    required Map<Profil, Dielenformate> dielen,
    required Iterable<Millimeter> lieferlaengen,
    required Iterable<(Set<Millimeter>, Set<Millimeter>)> ukSeiten,
    Iterable<UkMasse> ukUngetrocknet = const [],
    this.duoClipAb,
  }) : dielen = Map.unmodifiable(dielen),
       lieferlaengen = List.unmodifiable(
         lieferlaengen.toList()..sort((x, y) => x.mm - y.mm),
       ),
       ukSeiten = List.unmodifiable(ukSeiten),
       ukUngetrocknet = Set.unmodifiable(ukUngetrocknet.map(_sortiert));

  final Serie serie;
  final Map<Profil, Dielenformate> dielen;

  /// Lieferlängen aufsteigend (R-A06).
  final List<Millimeter> lieferlaengen;

  /// Gültige UK-Formate: eine Seite aus der ersten, die andere aus der
  /// zweiten Menge (R-A08).
  final List<(Set<Millimeter>, Set<Millimeter>)> ukSeiten;

  /// UK-Formate, die nur ungetrocknet lieferbar sind (B-212).
  final Set<UkMasse> ukUngetrocknet;

  /// Ab dieser Breite genutet mit DUO-CLIP-FIXX; `null` = nie (R-B01, B-094).
  final Millimeter? duoClipAb;

  /// Ob Breite × Stärke mit diesem Profil existiert (R-A03).
  bool dielenformatGueltig(
    Profil profil,
    Millimeter breite,
    Millimeter staerke,
  ) => dielen[profil]?.enthaelt(breite, staerke) ?? false;

  /// Befestigung einer Diele (R-B01: B-094, B-150; R-B02: B-090).
  Befestigung befestigung(Profil profil, Millimeter breite) {
    if (profil == Profil.glattkant) return Befestigung.verschraubungVonOben;
    final duo = duoClipAb;
    return duo != null && breite >= duo
        ? Befestigung.duoClipFixx
        : Befestigung.clipFixx;
  }

  /// Prüft ein UK-Format; Breite und Stärke sind tauschbar (R-A08).
  UkFormat ukFormat(Millimeter a, Millimeter b) {
    for (final (x, y) in ukSeiten) {
      if ((x.contains(a) && y.contains(b)) ||
          (x.contains(b) && y.contains(a))) {
        return UkFormat.gueltig;
      }
    }
    return ukUngetrocknet.contains(_sortiert((a: a, b: b)))
        ? UkFormat.ungetrocknet
        : UkFormat.ungueltig;
  }
}

UkMasse _sortiert(UkMasse m) => m.a <= m.b ? m : (a: m.b, b: m.a);

/// Holzart mit ihren Planungseigenschaften (M2-08).
final class Holzart {
  Holzart({
    required this.id,
    required this.name,
    required this.rohdichteKgProM3,
    required this.ukAchsabstandMax,
    required this.ukAchsabstandEmpfohlen,
    required this.zweiSchraubenAb,
    required Iterable<Serienregeln> serien,
  }) : serien = Map.unmodifiable({for (final s in serien) s.serie: s}) {
    if (this.serien.isEmpty) {
      throw ArgumentError.value(id, 'serien', 'Holzart ohne Serie');
    }
    if (ukAchsabstandEmpfohlen > ukAchsabstandMax) {
      throw ArgumentError.value(
        ukAchsabstandEmpfohlen.mm,
        'ukAchsabstandEmpfohlen',
        'größer als der höchste Achsabstand',
      );
    }
  }

  /// Liest eine Holzart aus ihrer JSON-Darstellung (Maße in mm).
  factory Holzart.ausJson(Map<String, Object?> json) => Holzart(
    id: json['id']! as String,
    name: json['name']! as String,
    rohdichteKgProM3: json['rohdichte_kg_m3']! as int,
    ukAchsabstandMax: Millimeter(json['uk_achsabstand_max_mm']! as int),
    ukAchsabstandEmpfohlen: Millimeter(
      json['uk_achsabstand_empfohlen_mm']! as int,
    ),
    zweiSchraubenAb: Millimeter(json['zwei_schrauben_ab_mm']! as int),
    serien: [
      for (final s in json['serien']! as List<Object?>)
        _serieAusJson(s! as Map<String, Object?>),
    ],
  );

  /// Kennung, z. B. `robinie`.
  final String id;
  final String name;

  /// Rechengewicht für Gewicht und Fracht (R-A12).
  final int rohdichteKgProM3;

  /// Höchster UK-Achsabstand (R-C01).
  final Millimeter ukAchsabstandMax;

  /// Empfohlener UK-Achsabstand (R-C01).
  final Millimeter ukAchsabstandEmpfohlen;

  /// Ab dieser Breite zwei Schrauben je Befestigungspunkt (R-B02).
  final Millimeter zweiSchraubenAb;

  final Map<Serie, Serienregeln> serien;

  /// Regeln einer Serie; wirft, wenn die Serie zu dieser Holzart nicht gehört.
  Serienregeln serie(Serie serie) =>
      serien[serie] ??
      (throw ArgumentError.value(serie.name, 'serie', 'keine Serie von $name'));

  /// Schrauben je Befestigungspunkt (R-B01, R-B02).
  int schraubenJePunkt(Serie serie, Profil profil, Millimeter breite) =>
      switch (this.serie(serie).befestigung(profil, breite)) {
        Befestigung.clipFixx => 1,
        Befestigung.duoClipFixx => 2,
        Befestigung.verschraubungVonOben => breite >= zweiSchraubenAb ? 2 : 1,
      };

  /// Gewicht einer Diele oder eines UK-Holzes (R-A12).
  Gramm gewicht(Millimeter breite, Millimeter staerke, Millimeter laenge) =>
      Gramm(
        (breite.mm * staerke.mm * laenge.mm * rohdichteKgProM3 / 1e6).round(),
      );
}

Serienregeln _serieAusJson(Map<String, Object?> json) {
  Set<Millimeter> mm(Object? liste) => {
    for (final w in liste! as List<Object?>) Millimeter(w! as int),
  };
  final dielen = json['dielen']! as Map<String, Object?>;
  final duo = json['duo_clip_ab_mm'] as int?;
  return Serienregeln(
    serie: Serie(json['name']! as String),
    dielen: {
      for (final MapEntry(:key, :value) in dielen.entries)
        Profil.values.byName(key): _formate(value! as Map<String, Object?>, mm),
    },
    lieferlaengen: mm(json['lieferlaengen_mm']),
    ukSeiten: [
      for (final paar in json['uk_seiten']! as List<Object?>) _paar(paar, mm),
    ],
    ukUngetrocknet: [
      for (final paar in (json['uk_ungetrocknet'] as List<Object?>?) ?? [])
        _ukMasse(paar),
    ],
    duoClipAb: duo == null ? null : Millimeter(duo),
  );
}

Dielenformate _formate(
  Map<String, Object?> json,
  Set<Millimeter> Function(Object?) mm,
) => Dielenformate(
  breiten: mm(json['breiten_mm']),
  staerken: mm(json['staerken_mm']),
);

(Set<Millimeter>, Set<Millimeter>) _paar(
  Object? paar,
  Set<Millimeter> Function(Object?) mm,
) {
  final liste = paar! as List<Object?>;
  return (mm(liste[0]), mm(liste[1]));
}

UkMasse _ukMasse(Object? paar) {
  final liste = paar! as List<Object?>;
  return (a: Millimeter(liste[0]! as int), b: Millimeter(liste[1]! as int));
}
