import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;

import '../geometrie/punkt.dart';

/// Was der Server aus einem Planungsstand berechnet und die App nur anzeigt
/// (M4-02): Umriss und Ausschnitte (M4-06) für die Zeichnung und Kennzahlen.
/// Bauteile, Volumen und Materialliste folgen mit M4-13 und M5.
final class Berechnung {
  Berechnung({
    required List<Punkt> umriss,
    required this.flaeche,
    List<List<Punkt>> ausschnitte = const [],
    List<Punkt>? ecken,
    this.geschlossen = true,
  }) : umriss = List.unmodifiable(umriss),
       ecken = List.unmodifiable(ecken ?? umriss),
       ausschnitte = List.unmodifiable([
         for (final a in ausschnitte) List<Punkt>.unmodifiable(a),
       ]);

  /// Liest eine Berechnung aus dem Transportformat ([zuBytes]).
  factory Berechnung.ausBytes(Uint8List bytes) {
    final puffer = fb.BufferContext.fromBytes(bytes);
    final wurzel = puffer.derefObject(0);
    return Berechnung(
      umriss: _punkte(puffer, wurzel, _umrissPlatz),
      ecken: _punkte(puffer, wurzel, _eckenPlatz),
      geschlossen: const fb.BoolReader().vTableGet(
        puffer,
        wurzel,
        _versatz(_geschlossenPlatz),
        true,
      ),
      ausschnitte: [
        for (final ort in const fb.ListReader<int>(
          _Tabellenort(),
        ).vTableGet(puffer, wurzel, _versatz(_ausschnittePlatz), const []))
          _punkte(puffer, ort, 0),
      ],
      flaeche: const fb.Float64Reader().vTableGet(
        puffer,
        wurzel,
        _versatz(_flaechePlatz),
        0,
      ),
    );
  }

  /// Rand des Grundrisses in mm als Linienzug ab A; Bögen als Sehnenzug
  /// (Kreis, M4-07).
  final List<Punkt> umriss;

  /// Benannte Eckpunkte A, B … für Beschriftungen; ohne Bögen gleich dem
  /// [umriss], beim Kreis leer.
  final List<Punkt> ecken;

  /// Ob der Umriss eine Fläche umschließt; eine offene Freiform (M4-08) hat
  /// keine Fläche.
  final bool geschlossen;

  /// Ausschnitte (Eckpunkte in mm), in der Reihenfolge des Planungsstands.
  final List<List<Punkt>> ausschnitte;

  /// Terrassenfläche in mm² – wie im alten Planer die Außenfläche, leere
  /// Ausschnitte zählen mit (Fachkonzept 1.4).
  final double flaeche;

  /// Terrassenfläche in m² für die Anzeige.
  double get flaecheQuadratmeter => flaeche / 1e6;

  /// FlatBuffer für den Weg zur App (#110):
  /// `{ 0: umriss ([float64] x, y je Punkt), 1: flaeche (float64 mm²),
  /// 2: ausschnitte ([{ 0: punkte ([float64]) }]), 3: ecken ([float64]),
  /// 4: geschlossen (bool) }`.
  Uint8List zuBytes() {
    final fbb = fb.Builder();
    final umrissOrt = _schreibe(fbb, umriss);
    final ausschnitteOrt = fbb.writeList([
      for (final a in ausschnitte) _ausschnitt(fbb, a),
    ]);
    final eckenOrt = _schreibe(fbb, ecken);
    fbb
      ..startTable(5)
      ..addOffset(_umrissPlatz, umrissOrt)
      ..addFloat64(_flaechePlatz, flaeche)
      ..addOffset(_ausschnittePlatz, ausschnitteOrt)
      ..addOffset(_eckenPlatz, eckenOrt)
      ..addBool(_geschlossenPlatz, geschlossen);
    fbb.finish(fbb.endTable());
    return fbb.buffer;
  }

  static int _schreibe(fb.Builder fbb, List<Punkt> punkte) =>
      fbb.writeListFloat64([
        for (final p in punkte) ...[p.x, p.y],
      ]);

  static int _ausschnitt(fb.Builder fbb, List<Punkt> punkte) {
    final ort = _schreibe(fbb, punkte);
    fbb
      ..startTable(1)
      ..addOffset(0, ort);
    return fbb.endTable();
  }

  static List<Punkt> _punkte(fb.BufferContext puffer, int ort, int platz) {
    final k = const fb.ListReader<double>(fb.Float64Reader())
        .vTableGet(puffer, ort, _versatz(platz), const []);
    // Zählschleife mit i++: ein Mutant „i += 2 → i = 2“ liefe endlos und
    // sprengte den Speicher des Runners (docs/erkenntnisse/mutation-tests.md)
    return [
      for (var i = 0; i < k.length ~/ 2; i++) Punkt(k[2 * i], k[2 * i + 1]),
    ];
  }

  static const _umrissPlatz = 0;
  static const _flaechePlatz = 1;
  static const _ausschnittePlatz = 2;
  static const _eckenPlatz = 3;
  static const _geschlossenPlatz = 4;

  static int _versatz(int platz) => 4 + 2 * platz;
}

/// Liest nur den Ort einer Tabelle – die Felder liest der Aufrufer.
final class _Tabellenort extends fb.TableReader<int> {
  const _Tabellenort();

  @override
  int createObject(fb.BufferContext puffer, int ort) => ort;
}
