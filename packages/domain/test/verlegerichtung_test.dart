import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

void main() {
  test('Nummern und Winkel der Verlegerichtungen', () {
    expect([for (final r in Verlegerichtung.values) r.nummer], [0, 1, 2, 3, 4]);
    expect(
      [for (final r in Verlegerichtung.values) r.winkel],
      [0, 90, 45, 135, null],
    );
    expect(Verlegerichtung.vorgabeWinkel, 30);
  });

  test('individueller Winkel: ganze Grad von 0 bis 179', () {
    for (final grad in [0, 1, 30, 179]) {
      expect(Verlegerichtung.winkelGueltig(grad), isTrue, reason: '$grad');
    }
    for (final grad in [-1, 180, 360]) {
      expect(Verlegerichtung.winkelGueltig(grad), isFalse, reason: '$grad');
    }
  });
}
