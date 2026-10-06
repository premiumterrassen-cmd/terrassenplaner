import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

void main() {
  test('WAMP-Namen des Planers', () {
    expect(WampNamen.realm, 'de.robinienwelt.terrassenplaner');
    expect(WampNamen.basis, 'de.robinienwelt.terrassenplaner.');
    expect(WampNamen.kunde, 'de.robinienwelt.terrassenplaner.kunde.');
    expect(
      WampNamen.mitarbeiter,
      'de.robinienwelt.terrassenplaner.mitarbeiter.',
    );
    expect(WampNamen.hallo, 'de.robinienwelt.terrassenplaner.kunde.hallo');
  });

  test('Begrüßung nennt den Projekttitel', () {
    expect(begruessung(), 'Verbunden mit Terrassenplaner – ALTO HOLZ');
    expect(
      begruessung(
        info: const ProjektInfo(name: 'A', firma: 'B'),
      ),
      'Verbunden mit A – B',
    );
  });
}
