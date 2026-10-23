import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

void main() {
  test('Abstände (R-C03, R-B06, R-C10)', () {
    expect(querstrebenAbstand, const Millimeter(600));
    expect(fuge, const Millimeter(5));
    expect(wandabstand, const Millimeter(20));
  });

  test('Freidielen-Staffel (R-B09): ab 25 eine, ab 50 zwei, ab 100 je 50', () {
    expect(freidielenAbDielen, 25);
    final faelle = {
      0: 0,
      24: 0,
      25: 1,
      49: 1,
      50: 2,
      99: 2,
      100: 3,
      149: 3,
      150: 4,
      199: 4,
      200: 5,
      586: 12,
    };
    for (final MapEntry(:key, :value) in faelle.entries) {
      expect(freidielen(key), value, reason: '$key Dielen');
    }
  });

  test('22 mm aus Altdaten wird 21 mm (R-A04)', () {
    expect(normierteStaerke(const Millimeter(22)), const Millimeter(21));
    for (final mm in [21, 23, 25, 26]) {
      expect(normierteStaerke(Millimeter(mm)), Millimeter(mm));
    }
  });
}
