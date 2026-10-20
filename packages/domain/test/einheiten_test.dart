import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

void main() {
  group('Millimeter', () {
    test('aus cm und m, gerundet', () {
      expect(Millimeter.ausCm(48.04).mm, 480);
      expect(Millimeter.ausCm(8.66).mm, 87);
      expect(Millimeter.ausM(4.8).mm, 4800);
      expect(Millimeter.ausM(0.0004).mm, 0);
    });
    test('Umrechnung und Rechnen', () {
      const a = Millimeter(4800);
      const b = Millimeter(200);
      expect([a.cm, a.m], [480.0, 4.8]);
      expect((a + b).mm, 5000);
      expect((a - b).mm, 4600);
      expect((b * 3).mm, 600);
    });
    test('Vergleiche', () {
      const a = Millimeter(400);
      const b = Millimeter(450);
      expect([a < b, b < a, a < a], [true, false, false]);
      expect([a <= b, b <= a, a <= a], [true, false, true]);
      expect([a > b, b > a, a > a], [false, true, false]);
      expect([a >= b, b >= a, a >= a], [false, true, true]);
    });
  });

  group('Gramm', () {
    test('aus kg, Rechnen', () {
      expect(Gramm.ausKg(7.5).g, 7500);
      expect(const Gramm(1250).kg, 1.25);
      expect((const Gramm(100) + const Gramm(50)).g, 150);
      expect((const Gramm(100) * 2.5).g, 250);
      expect((const Gramm(3) * 0.5).g, 2, reason: 'gerundet');
    });
  });

  group('Cent', () {
    test('aus Euro, Rechnen', () {
      expect(Cent.ausEuro(4.49).cent, 449);
      expect(Cent.ausEuro(0.125).cent, 13);
      expect(const Cent(2066).euro, 20.66);
      expect((const Cent(100) + const Cent(49)).cent, 149);
      expect((const Cent(449) * 46).cent, 20654);
      expect((const Cent(3) * 0.5).cent, 2);
    });
    test('Anzeige deutsch mit Tausenderpunkt', () {
      expect(const Cent(206657).anzeige, '2.066,57 €');
      expect(const Cent(5).anzeige, '0,05 €');
      expect(const Cent(100).anzeige, '1,00 €');
      expect(const Cent(99900).anzeige, '999,00 €');
      expect(const Cent(100000).anzeige, '1.000,00 €');
      expect(const Cent(123456789).anzeige, '1.234.567,89 €');
      expect(const Cent(-1050).anzeige, '-10,50 €');
    });
  });

  group('Mengeneinheit', () {
    test('Anzeige', () {
      expect(Mengeneinheit.values.map((e) => e.anzeige), [
        'Stück',
        'lfm',
        'm²',
        'VPE',
        'Karton',
        'Set',
        'Kiste',
        'l',
      ]);
    });
    test('liest die Schreibweisen der Quellen', () {
      final faelle = {
        'Stück': Mengeneinheit.stueck,
        ' St. ': Mengeneinheit.stueck,
        'ST': Mengeneinheit.stueck,
        'Stk.': Mengeneinheit.stueck,
        'stk': Mengeneinheit.stueck,
        'lfm': Mengeneinheit.laufmeter,
        'm²': Mengeneinheit.quadratmeter,
        'm2': Mengeneinheit.quadratmeter,
        'qm': Mengeneinheit.quadratmeter,
        'VPE': Mengeneinheit.verpackungseinheit,
        'VE': Mengeneinheit.verpackungseinheit,
        'Karton': Mengeneinheit.karton,
        'SET': Mengeneinheit.set,
        'Kiste': Mengeneinheit.kiste,
        'l': Mengeneinheit.liter,
        'Liter': Mengeneinheit.liter,
      };
      for (final MapEntry(:key, :value) in faelle.entries) {
        expect(Mengeneinheit.lies(key), value, reason: key);
      }
      expect(Mengeneinheit.lies('Palette'), isNull);
    });
  });

  group('Verkaufseinheit', () {
    test('Inhalt muss größer als 0 sein', () {
      expect(
        () => Verkaufseinheit(Mengeneinheit.karton, inhalt: 0),
        throwsArgumentError,
      );
      expect(Verkaufseinheit(Mengeneinheit.stueck).inhalt, 1);
    });
    test('Bedarf wird auf ganze Verkaufseinheiten aufgerundet', () {
      final karton = Verkaufseinheit(
        Mengeneinheit.karton,
        inhalt: 100,
        inhaltEinheit: Mengeneinheit.stueck,
      );
      expect([0, -5, 1, 100, 101, 806].map(karton.fuerBedarf), [
        0,
        0,
        1,
        1,
        2,
        9,
      ]);
      expect(Verkaufseinheit(Mengeneinheit.laufmeter).fuerBedarf(2.2), 3);
    });
    test('Gleichheit und Anzeige', () {
      final a = Verkaufseinheit(
        Mengeneinheit.karton,
        inhalt: 100,
        inhaltEinheit: Mengeneinheit.stueck,
      );
      final b = Verkaufseinheit(
        Mengeneinheit.karton,
        inhalt: 100,
        inhaltEinheit: Mengeneinheit.stueck,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(
          Verkaufseinheit(
            Mengeneinheit.karton,
            inhalt: 50,
            inhaltEinheit: Mengeneinheit.stueck,
          ),
        ),
      );
      expect(
        a,
        isNot(
          Verkaufseinheit(
            Mengeneinheit.kiste,
            inhalt: 100,
            inhaltEinheit: Mengeneinheit.stueck,
          ),
        ),
      );
      expect(a, isNot(Verkaufseinheit(Mengeneinheit.karton, inhalt: 100)));
      expect(a, isNot(Object()));
      expect('$a', 'Karton zu 100 Stück');
      expect('${Verkaufseinheit(Mengeneinheit.laufmeter)}', 'lfm');
      expect(
        '${Verkaufseinheit(Mengeneinheit.set, inhalt: 3)}',
        'Set zu 3 Set',
      );
      expect(
        '${Verkaufseinheit(Mengeneinheit.stueck, inhaltEinheit: Mengeneinheit.liter)}',
        'Stück zu 1 l',
      );
    });
  });
}
