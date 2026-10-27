import 'dart:math' as math;

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

Matcher _punkt(double x, double y) => isA<Punkt>()
    .having((p) => p.x, 'x', closeTo(x, 1e-9))
    .having((p) => p.y, 'y', closeTo(y, 1e-9));

void main() {
  group('Punkt', () {
    const a = Punkt(3, 4), b = Punkt(-1, 2);

    test('Rechenarten', () {
      expect(a + b, _punkt(2, 6));
      expect(a - b, _punkt(4, 2));
      expect(a * 2, _punkt(6, 8));
      expect(a.punktprodukt(b), 5);
      expect(a.kreuz(b), 10);
      expect(b.kreuz(a), -10);
      expect(a.laenge, 5);
      expect(a.abstand(b), math.sqrt(20));
      expect(Punkt.ursprung, _punkt(0, 0));
    });

    test('Richtung, Drehung, Senkrechte, Einheit', () {
      expect(const Punkt(0, 2).richtung, closeTo(math.pi / 2, 1e-12));
      expect(const Punkt(-1, -1).richtung, closeTo(-3 * math.pi / 4, 1e-12));
      expect(a.gedreht(math.pi / 2), _punkt(-4, 3));
      expect(a.gedreht(math.pi / 2, const Punkt(1, 1)), _punkt(-2, 3));
      expect(a.links, _punkt(-4, 3));
      expect(a.einheit, _punkt(0.6, 0.8));
    });

    test('gleich mit Toleranz', () {
      expect(a.gleich(const Punkt(3, 4 + 1e-7)), isTrue);
      expect(a.gleich(const Punkt(3, 4 + 2e-6)), isFalse);
      expect(a.gleich(const Punkt(3, 4.5), 0.6), isTrue);
      expect(a.gleich(const Punkt(3, 4.5), 0.5), isFalse);
    });

    test('Gleichheit, Hashcode, Text', () {
      expect(a, const Punkt(3, 4));
      expect(a == const Punkt(3, 5), isFalse);
      expect(a == const Punkt(2, 4), isFalse);
      expect(a.hashCode, const Punkt(3, 4).hashCode);
      expect(a.toString(), '(3.0|4.0)');
    });
  });

  group('Huellrechteck', () {
    final u = Huellrechteck.um(const [Punkt(1, 5), Punkt(-2, 3), Punkt(4, -1)]);

    test('umschließt alle Punkte', () {
      expect(u.min, _punkt(-2, -1));
      expect(u.max, _punkt(4, 5));
      expect(u.breite, 6);
      expect(u.hoehe, 6);
      expect(u.mitte, _punkt(1, 2));
    });

    test('Berührung zählt, Abstand in jede Richtung nicht', () {
      Huellrechteck bei(double x, double y) =>
          Huellrechteck(Punkt(x, y), Punkt(x + 1, y + 1));
      expect(u.beruehrt(bei(4, 5)), isTrue);
      expect(u.beruehrt(bei(-3, -2)), isTrue);
      expect(u.beruehrt(bei(4.1, 0)), isFalse);
      expect(u.beruehrt(bei(-3.1, 0)), isFalse);
      expect(u.beruehrt(bei(0, 5.1)), isFalse);
      expect(u.beruehrt(bei(0, -2.1)), isFalse);
    });
  });
}
