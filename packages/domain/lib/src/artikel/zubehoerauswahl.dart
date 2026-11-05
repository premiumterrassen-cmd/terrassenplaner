import '../holzart/holzart.dart';
import 'artikel.dart';
import 'artikel_json.dart';
import 'zubehoergruppe.dart';

/// Zubehör der Artikeldaten in den acht Gruppen (M8-01, Fachkonzept 06):
/// Gruppen in der Reihenfolge des alten Planers, darin die Artikel in
/// Datenreihenfolge (die Upload-Datei steuert sie, B-122). Gruppen ohne
/// Artikel bleiben leer stehen (Rhombusleisten, Fachkonzept 09).
final class Zubehoerauswahl {
  Zubehoerauswahl(this.version, Map<Zubehoergruppe, List<Artikel>> gruppen)
    : gruppen = Map.unmodifiable({
        for (final g in Zubehoergruppe.values)
          g: List<Artikel>.unmodifiable(gruppen[g] ?? const <Artikel>[]),
      });

  /// Sortiert [artikel] nach ihrer Zubehörgruppe; Artikel ohne Gruppe
  /// fehlen.
  factory Zubehoerauswahl.aus(String version, Iterable<Artikel> artikel) =>
      Zubehoerauswahl(version, {
        for (final g in Zubehoergruppe.values)
          g: [
            for (final a in artikel)
              if (a.zubehoergruppe == g) a,
          ],
      });

  factory Zubehoerauswahl.ausJson(
    Map<String, Object?> j,
    Map<String, Holzart> holzarten,
  ) => Zubehoerauswahl(j['version']! as String, {
    for (final MapEntry(:key, :value)
        in (j['gruppen']! as Map<String, Object?>).entries)
      Zubehoergruppe.values.byName(key): [
        for (final a in value! as List<Object?>)
          artikelAusJson(a! as Map<String, Object?>, holzarten),
      ],
  });

  /// Versionskennung der Artikeldaten.
  final String version;

  /// Alle acht Gruppen in fester Reihenfolge mit ihren Artikeln.
  final Map<Zubehoergruppe, List<Artikel>> gruppen;

  /// Artikel zur [nummer] in einer der Gruppen oder `null`.
  Artikel? artikel(Artikelnummer nummer) => gruppen.values
      .expand((l) => l)
      .where((a) => a.nummer == nummer)
      .firstOrNull;

  Map<String, Object?> alsJson() => {
    'version': version,
    'gruppen': {
      for (final MapEntry(:key, :value) in gruppen.entries)
        key.name: [for (final a in value) artikelAlsJson(a)],
    },
  };
}
