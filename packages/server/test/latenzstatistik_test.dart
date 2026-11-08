import 'dart:io';

import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

Duration _ms(int ms) => Duration(milliseconds: ms);

void main() {
  group('Latenzstatistik (M10-02)', () {
    test('Kennzahlen aus unsortierten Werten (Nearest-Rank)', () {
      final werte = [for (var i = 100; i >= 1; i--) _ms(i)];
      final s = Latenzstatistik.aus(werte);
      expect(s.anzahl, 100);
      expect(s.mittel, const Duration(microseconds: 50500));
      expect(s.p50, _ms(50));
      expect(s.p95, _ms(95));
      expect(s.p99, _ms(99));
      expect(s.hoechst, _ms(100));
      expect(s.alsJson(), {
        'anzahl': 100,
        'mittel_ms': 50.5,
        'p50_ms': 50.0,
        'p95_ms': 95.0,
        'p99_ms': 99.0,
        'max_ms': 100.0,
      });
    });

    test('wenige Werte: Perzentile runden auf den nächsten Rang auf', () {
      final s = Latenzstatistik.aus([_ms(3), _ms(1), _ms(2)]);
      expect(s.p50, _ms(2));
      expect(s.p95, _ms(3));
      expect(s.mittel, _ms(2));
      final eins = Latenzstatistik.aus([_ms(7)]);
      expect([
        eins.p50,
        eins.p95,
        eins.p99,
        eins.hoechst,
      ], everyElement(_ms(7)));
    });

    test('ohne Werte alles null', () {
      final s = Latenzstatistik.aus(const []);
      expect(s, same(Latenzstatistik.leer));
      expect(s.anzahl, 0);
      expect([
        s.mittel,
        s.p50,
        s.p95,
        s.p99,
        s.hoechst,
      ], everyElement(Duration.zero));
    });

    test('perzentil prüft Eingaben', () {
      final werte = [_ms(1), _ms(2)];
      expect(Latenzstatistik.perzentil(werte, 100), _ms(2));
      expect(Latenzstatistik.perzentil(werte, 50), _ms(1));
      expect(Latenzstatistik.perzentil(werte, 50.1), _ms(2));
      expect(Latenzstatistik.perzentil(werte, 0.1), _ms(1));
      Matcher bereich(num wert) => throwsA(
        isA<RangeError>()
            .having((e) => e.name, 'name', 'prozent')
            .having((e) => e.start, 'start', 0)
            .having((e) => e.end, 'end', 100)
            .having((e) => e.invalidValue, 'wert', wert),
      );
      expect(() => Latenzstatistik.perzentil(werte, 0), bereich(0));
      expect(() => Latenzstatistik.perzentil(werte, -1), bereich(-1));
      expect(() => Latenzstatistik.perzentil(werte, 100.5), bereich(100.5));
      expect(
        () => Latenzstatistik.perzentil(const [], 50),
        throwsArgumentError,
      );
    });

    test('Millisekunden mit einer Nachkommastelle', () {
      expect(Latenzstatistik.ms(const Duration(microseconds: 1249)), 1.2);
      expect(Latenzstatistik.ms(const Duration(microseconds: 1250)), 1.3);
      expect(Latenzstatistik.ms(Duration.zero), 0);
    });
  });

  group('Prozessmessung (M10-02)', () {
    test('CPU-Zeit in den Formaten von ps', () {
      expect(Prozessmessung.liesCpuZeit('1:02.50'), _ms(62500));
      expect(Prozessmessung.liesCpuZeit('00:01:02'), _ms(62000));
      expect(
        Prozessmessung.liesCpuZeit('2-01:00:00'),
        const Duration(days: 2, hours: 1),
      );
      expect(Prozessmessung.liesCpuZeit('0:00.01'), _ms(10));
    });

    test('liest RSS und CPU-Zeit aus der Ausgabe von ps', () async {
      late List<String> argumente;
      final m = await Prozessmessung.lies(
        42,
        ps: (befehl, args) async {
          expect(befehl, 'ps');
          argumente = args;
          return ProcessResult(1, 0, '  20480   0:01.50\n', '');
        },
      );
      expect(argumente, ['-o', 'rss=,cputime=', '-p', '42']);
      expect(m!.speicherKb, 20480);
      expect(m.speicherMb, 20.0);
      expect(m.cpuZeit, _ms(1500));
      expect(
        const Prozessmessung(
          speicherKb: 1500,
          cpuZeit: Duration.zero,
        ).speicherMb,
        1.5,
      );
    });

    test('ohne Prozess oder mit fremder Ausgabe: null', () async {
      expect(
        await Prozessmessung.lies(
          1,
          ps: (_, _) async => ProcessResult(1, 1, '', ''),
        ),
        isNull,
      );
      expect(
        await Prozessmessung.lies(
          1,
          ps: (_, _) async => ProcessResult(1, 0, '20480 0:01 x', ''),
        ),
        isNull,
      );
      expect(
        await Prozessmessung.lies(
          1,
          ps: (_, _) async => ProcessResult(1, 1, '20480 0:01', ''),
        ),
        isNull,
      );
    });

    test('der eigene Prozess ist messbar', () async {
      final m = await Prozessmessung.lies(pid);
      expect(m!.speicherKb, greaterThan(1000));
      expect(m.cpuZeit, greaterThan(Duration.zero));
    });
  });
}
