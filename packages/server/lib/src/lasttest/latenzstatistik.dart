/// Kennzahlen einer Reihe gemessener Antwortzeiten (M10-02): Anzahl,
/// Mittel, Median (p50), p95, p99 und Höchstwert.
///
/// Perzentile nach dem Nearest-Rank-Verfahren: p95 ist der kleinste
/// Messwert, unter oder auf dem mindestens 95 % aller Werte liegen.
final class Latenzstatistik {
  const Latenzstatistik._({
    required this.anzahl,
    required this.mittel,
    required this.p50,
    required this.p95,
    required this.p99,
    required this.hoechst,
  });

  /// Kennzahlen der [werte]; ohne Werte alle null.
  factory Latenzstatistik.aus(Iterable<Duration> werte) {
    final sortiert = werte.toList()..sort();
    if (sortiert.isEmpty) return leer;
    final summe = sortiert.fold(0, (s, d) => s + d.inMicroseconds);
    return Latenzstatistik._(
      anzahl: sortiert.length,
      mittel: Duration(microseconds: summe ~/ sortiert.length),
      p50: perzentil(sortiert, 50),
      p95: perzentil(sortiert, 95),
      p99: perzentil(sortiert, 99),
      hoechst: sortiert.last,
    );
  }

  static const leer = Latenzstatistik._(
    anzahl: 0,
    mittel: Duration.zero,
    p50: Duration.zero,
    p95: Duration.zero,
    p99: Duration.zero,
    hoechst: Duration.zero,
  );

  /// Perzentil [prozent] (0 < prozent ≤ 100) der aufsteigend [sortiert]en,
  /// nicht leeren Werte nach dem Nearest-Rank-Verfahren.
  static Duration perzentil(List<Duration> sortiert, num prozent) {
    if (sortiert.isEmpty) throw ArgumentError.value(sortiert, 'sortiert');
    if (prozent <= 0 || prozent > 100) {
      throw RangeError.range(prozent, 0, 100, 'prozent');
    }
    final rang = (prozent / 100 * sortiert.length).ceil();
    return sortiert[rang - 1];
  }

  final int anzahl;
  final Duration mittel;
  final Duration p50;
  final Duration p95;
  final Duration p99;
  final Duration hoechst;

  /// Darstellung für den Bericht, Zeiten in Millisekunden (eine
  /// Nachkommastelle).
  Map<String, Object> alsJson() => {
    'anzahl': anzahl,
    'mittel_ms': ms(mittel),
    'p50_ms': ms(p50),
    'p95_ms': ms(p95),
    'p99_ms': ms(p99),
    'max_ms': ms(hoechst),
  };

  /// [dauer] in Millisekunden, auf eine Nachkommastelle gerundet.
  static double ms(Duration dauer) => (dauer.inMicroseconds / 100).round() / 10;
}
