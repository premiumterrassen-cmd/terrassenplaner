import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;

/// Liest einen `[ubyte]`-Vektor als Ausschnitt des Puffers – ohne Kopie und
/// ohne Byte-für-Byte-Zugriff (anders als `fb.Uint8ListReader`).
final class AusschnittLeser extends fb.Reader<Uint8List> {
  const AusschnittLeser();

  @override
  int get size => 4;

  @override
  Uint8List read(fb.BufferContext bc, int offset) {
    final vektor = bc.derefObject(offset);
    final daten = bc.buffer;
    return daten.buffer.asUint8List(
      daten.offsetInBytes + vektor + 4,
      daten.getUint32(vektor, Endian.little),
    );
  }
}
