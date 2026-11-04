import 'dart:math';

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

import 'argument_fehler.dart';

/// Liefert die Zahlen aus [werte] der Reihe nach und merkt sich die Grenzen.
final class _Folge implements Random {
  _Folge(this.werte);

  final List<int> werte;
  final grenzen = <int>[];
  var _i = 0;

  @override
  int nextInt(int max) {
    grenzen.add(max);
    return werte[_i++];
  }

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  double nextDouble() => throw UnimplementedError();
}

void main() {
  group('Prüfcode (M9-05b)', () {
    test('Alphabet ohne verwechselbare Zeichen, Länge 5', () {
      expect(Pruefcode.alphabet, 'ABCDEFGHJKMNPQRSTUVWXYZ23456789');
      expect(Pruefcode.alphabet.length, 31);
      for (final zeichen in ['0', 'O', '1', 'I', 'L']) {
        expect(Pruefcode.alphabet, isNot(contains(zeichen)));
      }
      expect(Pruefcode.laenge, 5);
    });

    test('prüfen: Großschreibung, Leerraum am Rand', () {
      expect(Pruefcode.pruefe('K7QXM').wert, 'K7QXM');
      expect(Pruefcode.pruefe(' k7qxm ').wert, 'K7QXM');
      expect(Pruefcode.pruefe('AZ299').wert, 'AZ299');
      for (final text in [
        '',
        'K7QX',
        'K7QXMM',
        'K7Q0M',
        'K7QOM',
        'K7Q1M',
        'K7QIM',
        'K7QLM',
        'K7-XM',
        'xK7QXM',
        'K7QXMx',
      ]) {
        expect(
          () => Pruefcode.pruefe(text),
          wirftArgumentFehler('pruefcode', text, 'kein Prüfcode'),
          reason: text,
        );
      }
    });

    test('zufällig: fünf Zeichen aus dem Alphabet', () {
      final zufall = _Folge([0, 30, 7, 22, 23]);
      expect(Pruefcode.zufaellig(zufall).wert, 'A9HZ2');
      expect(zufall.grenzen, [31, 31, 31, 31, 31]);
      final code = Pruefcode.zufaellig(Random(1));
      expect(Pruefcode.pruefe(code.wert), code);
    });

    test('gleicht: nur bei identischem Code', () {
      const code = Pruefcode('K7QXM');
      expect(code.gleicht(const Pruefcode('K7QXM')), isTrue);
      for (final anders in ['A7QXM', 'K7QXA', 'K7AXM', 'K7QX', 'K7QXMA', '']) {
        expect(code.gleicht(Pruefcode(anders)), isFalse, reason: anders);
      }
      expect(const Pruefcode('').gleicht(const Pruefcode('')), isTrue);
    });
  });

  group('Konfigurationskennung (M9-05b)', () {
    const kennung = Konfigurationskennung(
      Konfigurationsnummer('2026-11-04-0001'),
      Pruefcode('K7QXM'),
    );

    test('Text, Gleichheit', () {
      expect(kennung.wert, '2026-11-04-0001-K7QXM');
      expect('$kennung', '2026-11-04-0001-K7QXM');
      expect(kennung.nummer, const Konfigurationsnummer('2026-11-04-0001'));
      expect(kennung.pruefcode, const Pruefcode('K7QXM'));
      expect(
        kennung,
        const Konfigurationskennung(
          Konfigurationsnummer('2026-11-04-0001'),
          Pruefcode('K7QXM'),
        ),
      );
      expect(
        kennung.hashCode,
        Object.hash(
          const Konfigurationsnummer('2026-11-04-0001'),
          const Pruefcode('K7QXM'),
        ),
      );
      expect(
        kennung ==
            const Konfigurationskennung(
              Konfigurationsnummer('2026-11-04-0002'),
              Pruefcode('K7QXM'),
            ),
        isFalse,
      );
      expect(
        kennung ==
            const Konfigurationskennung(
              Konfigurationsnummer('2026-11-04-0001'),
              Pruefcode('K7QXN'),
            ),
        isFalse,
      );
      expect(kennung == Object(), isFalse);
    });

    test('lesen: tolerant bei Schreibweise, Leerzeichen und Trennern', () {
      for (final text in [
        '2026-11-04-0001-K7QXM',
        '2026-11-04-0001-k7qxm',
        ' 2026 11 04 0001 K7QXM ',
        '202611040001K7QXM',
        '2026-11-04-0001 K7QXM',
        '2026.11.04/0001_K7QXM',
        '2026–11–04—0001-K7 QXM',
        '2026\t11\n04-0001-K7QXM',
      ]) {
        expect(Konfigurationskennung.lies(text), kennung, reason: text);
      }
    });

    test('lesen: Nummer falsch', () {
      for (final text in [
        '',
        'K7QXM',
        '2026-11-04-001-K7QXM',
        '26-11-04-0001-K7QXM',
        'x2026-11-04-0001-K7QXM',
        '2026,11-04-0001-K7QXM',
      ]) {
        expect(
          () => Konfigurationskennung.lies(text),
          wirftArgumentFehler('text', text, 'Format JJJJ-MM-TT-NNNN-XXXXX'),
          reason: text,
        );
      }
      expect(
        () => Konfigurationskennung.lies('2026-02-30-0001-K7QXM'),
        wirftArgumentFehler('text', '2026-02-30-0001', 'kein gültiges Datum'),
      );
    });

    test('lesen: Prüfcode fehlt oder ist falsch geschrieben', () {
      const nummer = Konfigurationsnummer('2026-11-04-0001');
      final mitNummer = throwsA(
        isA<PruefcodeUngueltig>().having((e) => e.nummer, 'nummer', nummer),
      );
      for (final text in ['2026-11-04-0001', '2026-11-04-0001- ']) {
        expect(
          () => Konfigurationskennung.lies(text),
          wirftArgumentFehler('pruefcode', text, 'Prüfcode fehlt'),
          reason: text,
        );
        expect(() => Konfigurationskennung.lies(text), mitNummer);
      }
      for (final (text, code) in [
        ('2026-11-04-0001-K7QX', 'K7QX'),
        ('2026-11-04-0001-K7QXMA', 'K7QXMA'),
        ('2026-11-04-0001-K7Q0M', 'K7Q0M'),
        ('2026-11-04-00011-K7QXM', '1K7QXM'),
      ]) {
        expect(
          () => Konfigurationskennung.lies(text),
          wirftArgumentFehler('pruefcode', code, 'kein Prüfcode'),
          reason: text,
        );
        expect(() => Konfigurationskennung.lies(text), mitNummer);
      }
    });
  });
}
