import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;

import 'ausschnitt_leser.dart';

/// Mehrere Datensätze einer Entität in einer WAMP-Nachricht (#110).
///
/// Jeder Eintrag ist ein vollständiger FlatBuffer im ObjectBox-Speicherformat
/// (siehe `transport.g.dart`). Der Stapel selbst ist nur der Umschlag:
/// `{ 0: schema (String), 1: eintraege ([{ 0: daten ([ubyte]) }]) }`.
/// Gelesene Einträge sind Ausschnitte desselben Puffers – keine Kopie.
final class Stapel {
  /// Liest einen Stapel aus [bytes], ohne die Einträge zu kopieren.
  Stapel(Uint8List bytes) : _puffer = fb.BufferContext.fromBytes(bytes) {
    final wurzel = _puffer.derefObject(0);
    schema = const fb.StringReader().vTableGet(
      _puffer,
      wurzel,
      _versatz(_schemaPlatz),
      '',
    );
    _eintraege = const fb.ListReader<Uint8List>(
      _EintragLeser(),
      lazy: true,
    ).vTableGet(_puffer, wurzel, _versatz(_eintraegePlatz), const []);
  }

  /// Baut einen Stapel der Entität [schema] aus fertigen Datensätzen.
  static Uint8List baue(String schema, List<Uint8List> eintraege) {
    final fbb = fb.Builder();
    final orte = <int>[
      for (final daten in eintraege) _eintrag(fbb, fbb.writeListUint8(daten)),
    ];
    final schemaOrt = fbb.writeString(schema);
    final eintraegeOrt = fbb.writeList(orte);
    fbb
      ..startTable(2)
      ..addOffset(_schemaPlatz, schemaOrt)
      ..addOffset(_eintraegePlatz, eintraegeOrt);
    fbb.finish(fbb.endTable());
    return fbb.buffer;
  }

  static int _eintrag(fb.Builder fbb, int datenOrt) {
    fbb
      ..startTable(1)
      ..addOffset(0, datenOrt);
    return fbb.endTable();
  }

  final fb.BufferContext _puffer;

  /// Name der Entität aller Einträge (z. B. `Aenderung`).
  late final String schema;

  late final List<Uint8List> _eintraege;

  /// Anzahl der Einträge.
  int get laenge => _eintraege.length;

  /// Eintrag [index] als Ausschnitt des Stapel-Puffers.
  Uint8List operator [](int index) => _eintraege[index];

  /// Alle Einträge als Ausschnitte des Stapel-Puffers.
  Iterable<Uint8List> get eintraege => _eintraege;

  static const _schemaPlatz = 0;
  static const _eintraegePlatz = 1;
}

/// vtable-Versatz eines Feldplatzes (FlatBuffers: 4 Byte Kopf, 2 Byte je Feld).
int _versatz(int platz) => 4 + 2 * platz;

/// Liest einen Eintrag-Tisch und liefert seine Daten als Ausschnitt.
final class _EintragLeser extends fb.TableReader<Uint8List> {
  const _EintragLeser();

  @override
  Uint8List createObject(fb.BufferContext bc, int offset) =>
      const AusschnittLeser().vTableGet(bc, offset, _versatz(0), _leer);

  static final _leer = Uint8List(0);
}
