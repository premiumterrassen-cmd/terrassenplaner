import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;

import '../geometrie/punkt.dart';

/// Was der Server aus einem Planungsstand berechnet und die App nur anzeigt
/// (M4-02): Umriss für die Zeichnung und Kennzahlen. Bauteile, Volumen und
/// Materialliste folgen mit M4-13 und M5.
final class Berechnung {
  Berechnung({required List<Punkt> umriss, required this.flaeche})
    : umriss = List.unmodifiable(umriss);

  /// Liest eine Berechnung aus dem Transportformat ([zuBytes]).
  factory Berechnung.ausBytes(Uint8List bytes) {
    final puffer = fb.BufferContext.fromBytes(bytes);
    final wurzel = puffer.derefObject(0);
    final koordinaten = const fb.ListReader<double>(fb.Float64Reader())
        .vTableGet(puffer, wurzel, _versatz(_umrissPlatz), const []);
    return Berechnung(
      umriss: [
        for (var i = 1; i < koordinaten.length; i += 2)
          Punkt(koordinaten[i - 1], koordinaten[i]),
      ],
      flaeche: const fb.Float64Reader().vTableGet(
        puffer,
        wurzel,
        _versatz(_flaechePlatz),
        0,
      ),
    );
  }

  /// Eckpunkte des Grundrisses in mm, beginnend bei A.
  final List<Punkt> umriss;

  /// Terrassenfläche in mm².
  final double flaeche;

  /// Terrassenfläche in m² für die Anzeige.
  double get flaecheQuadratmeter => flaeche / 1e6;

  /// FlatBuffer für den Weg zur App (#110):
  /// `{ 0: umriss ([float64] x, y je Punkt), 1: flaeche (float64 mm²) }`.
  Uint8List zuBytes() {
    final fbb = fb.Builder();
    final umrissOrt = fbb.writeListFloat64([
      for (final p in umriss) ...[p.x, p.y],
    ]);
    fbb
      ..startTable(2)
      ..addOffset(_umrissPlatz, umrissOrt)
      ..addFloat64(_flaechePlatz, flaeche);
    fbb.finish(fbb.endTable());
    return fbb.buffer;
  }

  static const _umrissPlatz = 0;
  static const _flaechePlatz = 1;

  static int _versatz(int platz) => 4 + 2 * platz;
}
