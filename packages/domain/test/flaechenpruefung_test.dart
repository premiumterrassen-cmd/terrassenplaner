import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

void main() {
  group('Plausibilität der Fläche (Planungskern v6 Regel 1.7)', () {
    test('bis 0,05 m² Fehler, über 1.000 m² Fehler, außerhalb 1–300 m² '
        'Hinweis', () {
      final faelle = {
        0.0: Flaechenmeldung.masseFalsch,
        0.05: Flaechenmeldung.masseFalsch,
        0.051: Flaechenmeldung.ungewoehnlich,
        0.99: Flaechenmeldung.ungewoehnlich,
        1.0: null,
        14.832: null,
        300.0: null,
        300.01: Flaechenmeldung.ungewoehnlich,
        1000.0: Flaechenmeldung.ungewoehnlich,
        1000.01: Flaechenmeldung.unplausibelGross,
      };
      for (final MapEntry(key: m2, value: meldung) in faelle.entries) {
        expect(pruefeFlaeche(m2), meldung, reason: '$m2 m²');
      }
      expect(
        [for (final m in Flaechenmeldung.values) m.fehler],
        [true, true, false],
      );
    });

    test('Berechnung: Meldung zur Fläche, offene Freiform ohne', () {
      expect(
        Berechnung(umriss: const [], flaeche: 2000 * 1000).flaechenmeldung,
        isNull,
      );
      expect(
        Berechnung(umriss: const [], flaeche: 40000).flaechenmeldung,
        Flaechenmeldung.masseFalsch,
      );
      expect(
        Berechnung(
          umriss: const [],
          flaeche: 0,
          geschlossen: false,
        ).flaechenmeldung,
        isNull,
      );
    });
  });
}
