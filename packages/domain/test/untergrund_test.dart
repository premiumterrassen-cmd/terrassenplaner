import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

/// Planungsstand im Transportformat vor M6-04 (bzw. nur mit Untergrund).
Uint8List _alt({int? untergrund}) {
  final fbb = fb.Builder();
  final masseOrt = fbb.writeListInt32([4800, 3090]);
  fbb
    ..startTable(2)
    ..addUint8(0, 0)
    ..addOffset(1, masseOrt);
  final ort = fbb.endTable();
  fbb
    ..startTable(81)
    ..addOffset(1, ort)
    ..addUint8(80, untergrund);
  fbb.finish(fbb.endTable());
  return fbb.buffer;
}

void main() {
  group('Untergrund (M6-04, R-C07)', () {
    test('drei Untergründe wie im alten Planer, Nummern 0 bis 2', () {
      expect(Untergrund.values, [
        Untergrund.schotter,
        Untergrund.beton,
        Untergrund.bitumen,
      ]);
      expect([for (final u in Untergrund.values) u.nummer], [0, 1, 2]);
    });

    test('Nummer aus dem Transportformat', () {
      for (final u in Untergrund.values) {
        expect(Untergrund.ausNummer(u.nummer), u);
      }
      expect(
        () => Untergrund.ausNummer(3),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'unbekannter Untergrund 3',
          ),
        ),
      );
    });
  });

  group('Planungsstand mit Untergrund (M6-04)', () {
    const start = Planungsstand.start;

    test('Vorgabe Schotter (F01)', () {
      expect(start.untergrund, Untergrund.schotter);
    });

    test('ändern; Gleichheit und Hash; die übrigen Eingaben bleiben', () {
      final beton = start
          .mitTerrassenart(Terrassenart.hochterrasse)
          .mitUntergrund(Untergrund.beton);
      expect(beton.untergrund, Untergrund.beton);
      expect(beton.terrassenart, Terrassenart.hochterrasse);
      final schotter = start.mitTerrassenart(Terrassenart.hochterrasse);
      expect(beton == schotter, isFalse);
      expect(beton.hashCode == schotter.hashCode, isFalse);
      expect(beton.mitUntergrund(Untergrund.schotter), schotter);
      // der Untergrund bleibt bei anderen Eingaben erhalten
      expect(
        beton.mitTerrassenart(Terrassenart.normal).untergrund,
        Untergrund.beton,
      );
    });

    test('Transportformat: hin und zurück, abwärtskompatibel', () {
      for (final u in Untergrund.values) {
        final stand = start.mitUntergrund(u);
        expect(Planungsstand.ausBytes(stand.zuBytes()), stand);
      }
      // ältere Stände ohne Platz 80: Schotter
      expect(Planungsstand.ausBytes(_alt()).untergrund, Untergrund.schotter);
      expect(
        Planungsstand.ausBytes(_alt(untergrund: 2)).untergrund,
        Untergrund.bitumen,
      );
      expect(
        () => Planungsstand.ausBytes(_alt(untergrund: 9)),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
