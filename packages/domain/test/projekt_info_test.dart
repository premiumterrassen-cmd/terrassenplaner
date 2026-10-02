import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

void main() {
  test('Titel setzt sich aus Name und Firma zusammen', () {
    const info = ProjektInfo(name: 'Planer', firma: 'Firma');
    expect(info.titel, 'Planer – Firma');
  });

  test('Projektkonstante beschreibt den Terrassenplaner von ALTO HOLZ', () {
    expect(terrassenplaner.titel, 'Terrassenplaner – ALTO HOLZ');
  });
}
