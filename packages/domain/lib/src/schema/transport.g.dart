// ERZEUGT von packages/server/bin/schema_erzeugen.dart aus objectbox-model.json – nicht von Hand ändern.

import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;

/// Baut einen Aenderung-Datensatz im ObjectBox-Speicherformat.
Uint8List baueAenderung({
  required String schluessel,
  required String knoten,
  required int seq,
  required String entitaet,
  required String uid,
  required String partition,
  required String hlc,
  required String art,
}) {
  final fbb = fb.Builder(initialSize: 256);
  final schluesselOrt = fbb.writeString(schluessel);
  final knotenOrt = fbb.writeString(knoten);
  final entitaetOrt = fbb.writeString(entitaet);
  final uidOrt = fbb.writeString(uid);
  final partitionOrt = fbb.writeString(partition);
  final hlcOrt = fbb.writeString(hlc);
  final artOrt = fbb.writeString(art);
  fbb.startTable(10);
  fbb.addOffset(1, schluesselOrt);
  fbb.addOffset(2, knotenOrt);
  fbb.addInt64(3, seq);
  fbb.addOffset(4, entitaetOrt);
  fbb.addOffset(5, uidOrt);
  fbb.addOffset(6, partitionOrt);
  fbb.addOffset(7, hlcOrt);
  fbb.addOffset(8, artOrt);
  fbb.finish(fbb.endTable());
  return fbb.buffer;
}

/// Sicht auf einen Aenderung-Datensatz im ObjectBox-Speicherformat;
/// liest Felder erst beim Zugriff und ohne Kopie des Puffers.
class AenderungSicht {
  AenderungSicht(Uint8List bytes)
    : _puffer = fb.BufferContext.fromBytes(bytes) {
    _wurzel = _puffer.derefObject(0);
  }

  static const schemaName = 'Aenderung';

  final fb.BufferContext _puffer;
  late final int _wurzel;

  String get schluessel =>
      const fb.StringReader(asciiOptimization: true)
          .vTableGet(_puffer, _wurzel, 6, '');

  String get knoten =>
      const fb.StringReader(asciiOptimization: true)
          .vTableGet(_puffer, _wurzel, 8, '');

  int get seq => const fb.Int64Reader().vTableGet(_puffer, _wurzel, 10, 0);

  String get entitaet =>
      const fb.StringReader(asciiOptimization: true)
          .vTableGet(_puffer, _wurzel, 12, '');

  String get uid =>
      const fb.StringReader(asciiOptimization: true)
          .vTableGet(_puffer, _wurzel, 14, '');

  String get partition =>
      const fb.StringReader(asciiOptimization: true)
          .vTableGet(_puffer, _wurzel, 16, '');

  String get hlc =>
      const fb.StringReader(asciiOptimization: true)
          .vTableGet(_puffer, _wurzel, 18, '');

  String get art =>
      const fb.StringReader(asciiOptimization: true)
          .vTableGet(_puffer, _wurzel, 20, '');
}
