import 'dart:math';

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

void main() {
  final zeit = DateTime.utc(2026, 10, 6, 12);

  test('Aufbau: Länge, Bindestriche, Version 7, Variante 10', () {
    final uuid = UuidV7(uhr: () => zeit, zufall: Random(1)).neu();
    expect(
      uuid,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });

  test('enthält den Zeitstempel in Millisekunden', () {
    final uuid = UuidV7(uhr: () => zeit, zufall: Random(1)).neu();
    expect(UuidV7.zeitstempel(uuid), zeit.millisecondsSinceEpoch);
    expect(uuid.substring(0, 13), '01a11115-be00');
  });

  test('zeitlich sortierbar', () {
    var t = zeit;
    final erzeuger = UuidV7(uhr: () => t, zufall: Random(2));
    final ids = <String>[];
    for (var i = 0; i < 20; i++) {
      t = t.add(const Duration(milliseconds: 1));
      ids.add(erzeuger.neu());
    }
    expect([...ids]..sort(), ids);
  });

  test('ohne Angaben: aktuelle Zeit und sichere Zufallsquelle, eindeutig', () {
    final erzeuger = UuidV7();
    final vorher = DateTime.now().millisecondsSinceEpoch;
    final ids = {for (var i = 0; i < 1000; i++) erzeuger.neu()};
    expect(ids, hasLength(1000));
    expect(UuidV7.zeitstempel(ids.first), greaterThanOrEqualTo(vorher));
  });
}
