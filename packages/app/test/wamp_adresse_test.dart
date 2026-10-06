import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/verbindung/wamp_adresse.dart';

void main() {
  test('HTTPS-Seite → wss auf demselben Host, Pfad /ws', () {
    expect(
      wampAdresse(Uri.parse('https://alto.terrassenplaner.eu/planer?x=1')),
      Uri.parse('wss://alto.terrassenplaner.eu/ws'),
    );
  });

  test('HTTP-Seite mit Port → ws mit Port', () {
    expect(
      wampAdresse(Uri.parse('http://localhost:5000/')),
      Uri.parse('ws://localhost:5000/ws'),
    );
  });

  test('Vorgabe hat Vorrang', () {
    expect(
      wampAdresse(
        Uri.parse('https://alto.terrassenplaner.eu/'),
        vorgabe: 'ws://127.0.0.1:8099/ws',
      ),
      Uri.parse('ws://127.0.0.1:8099/ws'),
    );
  });
}
