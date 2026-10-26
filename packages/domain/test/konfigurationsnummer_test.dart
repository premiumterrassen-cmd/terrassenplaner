import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

import 'argument_fehler.dart';

void main() {
  test('gültige Nummern', () {
    expect(
      Konfigurationsnummer.pruefe('2026-10-08-1511').wert,
      '2026-10-08-1511',
    );
    expect(
      Konfigurationsnummer.pruefe(' 2024-02-29-0001 ').wert,
      '2024-02-29-0001',
    );
    expect(
      Konfigurationsnummer.pruefe('2026-12-31-9999').wert,
      '2026-12-31-9999',
    );
  });

  test('falsches Format', () {
    for (final text in [
      '',
      '2026-10-08',
      '2026-10-08-151',
      '2026-10-08-15111',
      '26-10-08-1511',
      '2026-1-08-1511',
      '2026/10/08/1511',
      'x2026-10-08-1511',
      '2026-10-08-1511x',
    ]) {
      expect(
        () => Konfigurationsnummer.pruefe(text),
        wirftArgumentFehler('text', text, 'Format JJJJ-MM-TT-NNNN'),
        reason: text,
      );
    }
  });

  test('ungültiges Datum', () {
    for (final text in [
      '2026-02-29-0001',
      '2026-13-01-0001',
      '2026-00-10-0001',
      '2026-04-31-0001',
      '2026-01-00-0001',
    ]) {
      expect(
        () => Konfigurationsnummer.pruefe(text),
        wirftArgumentFehler('text', text, 'kein gültiges Datum'),
        reason: text,
      );
    }
  });

  test('Stand: Version ab 1, Gleichheit, Text', () {
    const nummer = Konfigurationsnummer('2026-10-08-1511');
    final stand = KonfigurationsStand(nummer, 2);
    expect([stand.nummer, stand.version], [nummer, 2]);
    expect(stand, KonfigurationsStand(nummer, 2));
    expect(stand.hashCode, KonfigurationsStand(nummer, 2).hashCode);
    expect(stand.hashCode, Object.hash(nummer, 2));
    expect(stand == KonfigurationsStand(nummer, 3), isFalse);
    expect(
      stand ==
          KonfigurationsStand(const Konfigurationsnummer('2026-10-08-1512'), 2),
      isFalse,
    );
    expect(stand == Object(), isFalse);
    expect('$stand', '2026-10-08-1511 v2');
    expect(KonfigurationsStand(nummer, 1).version, 1);
    expect(
      () => KonfigurationsStand(nummer, 0),
      wirftArgumentFehler('version', 0, 'ab 1'),
    );
  });
}
