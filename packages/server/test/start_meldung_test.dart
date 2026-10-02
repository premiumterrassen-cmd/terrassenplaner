import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

void main() {
  test('Startmeldung nennt den Projekttitel', () {
    expect(startMeldung(), 'Terrassenplaner – ALTO HOLZ: Server gestartet');
  });

  test('Startmeldung verwendet die übergebenen Projektdaten', () {
    const info = ProjektInfo(name: 'Test', firma: 'X');
    expect(startMeldung(info: info), 'Test – X: Server gestartet');
  });
}
