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

  test('Stand: Kennung, Version ab 1, Gleichheit, Text', () {
    const nummer = Konfigurationsnummer('2026-10-08-1511');
    const kennung = Konfigurationskennung(nummer, Pruefcode('K7QXM'));
    final stand = KonfigurationsStand(kennung, 2);
    expect([stand.kennung, stand.nummer, stand.version], [kennung, nummer, 2]);
    expect(stand, KonfigurationsStand(kennung, 2));
    expect(stand.hashCode, KonfigurationsStand(kennung, 2).hashCode);
    expect(stand.hashCode, Object.hash(kennung, 2));
    expect(stand == KonfigurationsStand(kennung, 3), isFalse);
    expect(
      stand ==
          KonfigurationsStand(
            const Konfigurationskennung(nummer, Pruefcode('K7QXN')),
            2,
          ),
      isFalse,
    );
    expect(stand == Object(), isFalse);
    expect('$stand', '2026-10-08-1511-K7QXM v2');
    expect(KonfigurationsStand(kennung, 1).version, 1);
    expect(
      () => KonfigurationsStand(kennung, 0),
      wirftArgumentFehler('version', 0, 'ab 1'),
    );
  });

  test('vergeben: Tag und laufende Nummer (M9-05)', () {
    final nummer = Konfigurationsnummer.vergib(DateTime(2026, 3, 7, 23, 59), 7);
    expect(nummer.wert, '2026-03-07-0007');
    expect(nummer.tag, '2026-03-07');
    expect(nummer.laufend, 7);
    expect(
      Konfigurationsnummer.vergib(DateTime(812, 11, 30), 1).wert,
      '0812-11-30-0001',
    );
    expect(Konfigurationsnummer.vergib(DateTime(2026), 9999).laufend, 9999);
    expect(Konfigurationsnummer.vergib(DateTime(2026), 1510).laufend, 1510);
    expect(Konfigurationsnummer.hoechsteLaufende, 9999);
    expect(Konfigurationsnummer.tagAus(DateTime(2026, 12, 1)), '2026-12-01');
    expect(
      Konfigurationsnummer.pruefe('2026-10-08-1511'),
      Konfigurationsnummer.vergib(DateTime(2026, 10, 8), 1511),
    );
    for (final falsch in [0, 10000]) {
      expect(
        () => Konfigurationsnummer.vergib(DateTime(2026), falsch),
        throwsA(
          isA<RangeError>()
              .having((e) => e.name, 'name', 'laufend')
              .having((e) => e.start, 'start', 1)
              .having((e) => e.end, 'end', 9999),
        ),
      );
    }
  });
}
