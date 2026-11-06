import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

/// Planungsstand im Transportformat vor M6-07 (bzw. nur mit Nutzung).
Uint8List _alt({bool? gewerblich}) {
  final fbb = fb.Builder();
  final masseOrt = fbb.writeListInt32([4800, 3090]);
  fbb
    ..startTable(2)
    ..addUint8(0, 0)
    ..addOffset(1, masseOrt);
  final ort = fbb.endTable();
  fbb
    ..startTable(85)
    ..addOffset(1, ort)
    ..addBool(84, gewerblich);
  fbb.finish(fbb.endTable());
  return fbb.buffer;
}

void main() {
  const f01 = Planungsstand.start;

  group('Planungsstand mit Nutzung privat oder gewerblich (M6-07)', () {
    test('Vorgabe privat (F01)', () {
      expect(f01.gewerblich, isFalse);
    });

    test('ändern; Gleichheit und Hash; bleibt bei anderen Eingaben', () {
      final gewerblich = f01.mitGewerblich(true);
      expect(gewerblich.gewerblich, isTrue);
      expect(gewerblich == f01, isFalse);
      expect(gewerblich.hashCode == f01.hashCode, isFalse);
      expect(gewerblich.mitGewerblich(false), f01);
      expect(
        gewerblich.mitTerrassenart(Terrassenart.hochterrasse).gewerblich,
        isTrue,
      );
    });

    test('Transportformat: hin und zurück, abwärtskompatibel', () {
      final gewerblich = f01.mitGewerblich(true);
      expect(Planungsstand.ausBytes(gewerblich.zuBytes()), gewerblich);
      expect(Planungsstand.ausBytes(_alt()).gewerblich, isFalse);
      expect(Planungsstand.ausBytes(_alt(gewerblich: true)).gewerblich, isTrue);
    });
  });

  group('Berechnung mit Stellfüßen (M6-07)', () {
    test('Transportformat: Nummer und Titel in Datenreihenfolge, '
        'abwärtskompatibel', () {
      final b = Berechnung(
        umriss: const [],
        flaeche: 0,
        stellfuesse: const [
          (nummer: Artikelnummer('70-10-002'), titel: 'Stellfuß B'),
          (nummer: Artikelnummer('70-10-001'), titel: 'Stellfuß A'),
        ],
      );
      final zurueck = Berechnung.ausBytes(b.zuBytes());
      expect(zurueck.stellfuesse, b.stellfuesse);
      expect(b.stellfuesse.clear, throwsUnsupportedError);
      expect(b.mitPlanung(0).stellfuesse, b.stellfuesse);
      expect(
        Berechnung.ausBytes(Berechnung(umriss: const [], flaeche: 0).zuBytes())
            .stellfuesse,
        isEmpty,
      );
    });
  });
}
