import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;

import '../geometrie/punkt.dart';

/// Was der Server aus einem Planungsstand berechnet und die App nur anzeigt
/// (M4-02): Umriss, Ausschnitte (M4-06) und Dielenstücke (M5-05) für die
/// Zeichnung und Kennzahlen. Volumen und Materialliste folgen mit M5 und M6.
final class Berechnung {
  Berechnung({
    required List<Punkt> umriss,
    required this.flaeche,
    List<List<Punkt>> ausschnitte = const [],
    List<Punkt>? ecken,
    this.geschlossen = true,
    double? gesamtflaeche,
    List<List<Punkt>> dielen = const [],
  }) : gesamtflaeche = gesamtflaeche ?? flaeche,
       dielen = List.unmodifiable([
         for (final d in dielen) List<Punkt>.unmodifiable(d),
       ]),
       umriss = List.unmodifiable(umriss),
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
      ausschnitte: _umrisse(puffer, wurzel, _ausschnittePlatz),
      flaeche: const fb.Float64Reader().vTableGet(
        puffer,
        wurzel,
        _versatz(_flaechePlatz),
        0,
      ),
      gesamtflaeche: const fb.Float64Reader().vTableGetNullable(
        puffer,
        wurzel,
        _versatz(_gesamtflaechePlatz),
      ),
      dielen: _umrisse(puffer, wurzel, _dielenPlatz),
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

  /// Summe aller Flächen der Planung in mm², jede mal ihrer Häufigkeit
  /// (M4-14); bei nur einer Fläche gleich [flaeche].
  final double gesamtflaeche;

  /// Gesamtfläche in m² für die Anzeige.
  double get gesamtflaecheQuadratmeter => gesamtflaeche / 1e6;

  /// Umrisse der Dielenstücke (M5-05) in mm für die Zeichnung; leer, solange
  /// kein Belag bekannt ist.
  final List<List<Punkt>> dielen;

  /// FlatBuffer für den Weg zur App (#110):
  /// `{ 0: umriss ([float64] x, y je Punkt), 1: flaeche (float64 mm²),
  /// 2: ausschnitte ([{ 0: punkte ([float64]) }]), 3: ecken ([float64]),
  /// 4: geschlossen (bool), 5: gesamtflaeche (float64 mm², M4-14),
  /// 6: dielen ([{ 0: punkte ([float64]) }], M5-05) }`.
  Uint8List zuBytes() {
    final fbb = fb.Builder();
    final umrissOrt = _schreibe(fbb, umriss);
    final ausschnitteOrt = fbb.writeList([
      for (final a in ausschnitte) _ausschnitt(fbb, a),
    ]);
    final eckenOrt = _schreibe(fbb, ecken);
    final dielenOrt = fbb.writeList([
      for (final d in dielen) _ausschnitt(fbb, d),
    ]);
    fbb
      ..startTable(7)
      ..addOffset(_umrissPlatz, umrissOrt)
      ..addFloat64(_flaechePlatz, flaeche)
      ..addOffset(_ausschnittePlatz, ausschnitteOrt)
      ..addOffset(_eckenPlatz, eckenOrt)
      ..addBool(_geschlossenPlatz, geschlossen)
      ..addFloat64(_gesamtflaechePlatz, gesamtflaeche)
      ..addOffset(_dielenPlatz, dielenOrt);
    fbb.finish(fbb.endTable());
    return fbb.buffer;
  }

  static int _schreibe(fb.Builder fbb, List<Punkt> punkte) =>
      fbb.writeListFloat64([
        for (final p in punkte) ...[p.x, p.y],
      ]);

  /// Linienzug als Tabelle `{ 0: punkte }` (Ausschnitte, Dielen).
  static int _ausschnitt(fb.Builder fbb, List<Punkt> punkte) {
    final ort = _schreibe(fbb, punkte);
    fbb
      ..startTable(1)
      ..addOffset(0, ort);
    return fbb.endTable();
  }

  static List<List<Punkt>> _umrisse(
    fb.BufferContext puffer,
    int wurzel,
    int platz,
  ) => [
    for (final ort in const fb.ListReader<int>(
      _Tabellenort(),
    ).vTableGet(puffer, wurzel, _versatz(platz), const []))
      _punkte(puffer, ort, 0),
  ];

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
  static const _gesamtflaechePlatz = 5;
  static const _dielenPlatz = 6;

  static int _versatz(int platz) => 4 + 2 * platz;
}

/// Liest nur den Ort einer Tabelle – die Felder liest der Aufrufer.
final class _Tabellenort extends fb.TableReader<int> {
  const _Tabellenort();

  @override
  int createObject(fb.BufferContext puffer, int ort) => ort;
}
