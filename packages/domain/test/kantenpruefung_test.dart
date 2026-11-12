import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

void main() {
  group('Plausibilität der Kanten (Planungskern v7 Regel 9.6)', () {
    test('unter 10 cm und über 30 m Warnung, Grenzen selbst nicht', () {
      expect(kuerzesteKante, const Millimeter(100));
      expect(laengsteKante, const Millimeter(30000));
      expect(groesstesEingabemass, const Millimeter(50000));
      // Rechteck 480 × 309 cm: keine Warnung
      expect(
        pruefeKanten(const [
          Punkt(0, 0),
          Punkt(4800, 0),
          Punkt(4800, 3090),
          Punkt(0, 3090),
        ]),
        isEmpty,
      );
      // genau 10 cm und genau 30 m (C–A gerundet 30000 mm): ohne Warnung
      expect(
        pruefeKanten(const [Punkt(0, 0), Punkt(100, 0), Punkt(100, 30000)]),
        isEmpty,
      );
      final warnungen = pruefeKanten(const [
        Punkt(0, 0),
        Punkt(31000, 0),
        Punkt(31000, 99),
        Punkt(0, 3000),
      ]);
      expect(warnungen, [
        (
          kante: 'A–B',
          laenge: const Millimeter(31000),
          art: Kantenmeldung.zuLang,
        ),
        (kante: 'B–C', laenge: const Millimeter(99), art: Kantenmeldung.zuKurz),
        (
          kante: 'C–D',
          laenge: const Millimeter(31135),
          art: Kantenmeldung.zuLang,
        ),
      ]);
    });

    test('offener Linienzug ohne Schlusskante; Berechnung', () {
      const ecken = [Punkt(0, 0), Punkt(50, 0), Punkt(50, 3000)];
      expect(pruefeKanten(ecken, geschlossen: false), [
        (kante: 'A–B', laenge: const Millimeter(50), art: Kantenmeldung.zuKurz),
      ]);
      // geschlossen: auch C–A (3000,4 mm)
      expect(pruefeKanten(ecken), hasLength(1));
      expect(pruefeKanten(const []), isEmpty);
      // zwei Ecken: auch geschlossen nur eine Kante
      expect(pruefeKanten(const [Punkt(0, 0), Punkt(50, 0)]), [
        (kante: 'A–B', laenge: const Millimeter(50), art: Kantenmeldung.zuKurz),
      ]);
      expect(
        Berechnung(
          umriss: ecken,
          ecken: ecken,
          flaeche: 0,
          geschlossen: false,
        ).kantenwarnungen,
        hasLength(1),
      );
      expect(Berechnung(umriss: const [], flaeche: 0).kantenwarnungen, isEmpty);
    });
  });
}
