import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

int _summe(int n) {
  var s = 0;
  for (var i = 1; i <= n; i++) {
    s += i;
  }
  return s;
}

/// Rechnet, bis das Isolate beendet wird.
int _endlos() {
  var i = 0;
  while (i >= 0) {
    i = (i + 1) % 1000;
  }
  return i;
}

void main() {
  test('rechnet in einem eigenen Isolate und liefert das Ergebnis', () async {
    final werk = Rechenwerk(parallel: 1);
    final hauptIsolate = Isolate.current.debugName;
    expect(await werk.rechne(() => _summe(100)), 5050);
    expect(
      await werk.rechne(() => Isolate.current.debugName),
      allOf(isNot(hauptIsolate), 'rechenwerk'),
    );
    expect(werk.laufend, 0);
    expect(werk.wartend, 0);
  });

  test('Standard: so viele parallel wie Kerne, 20 s je Berechnung', () {
    final werk = Rechenwerk();
    expect(werk.parallel, Platform.numberOfProcessors);
    expect(werk.hoechstdauer, const Duration(seconds: 20));
    expect(Rechenwerk.standardHoechstdauer, const Duration(seconds: 20));
    expect(Rechenwerk(parallel: 1).parallel, 1);
    expect(
      () => Rechenwerk(parallel: 0),
      throwsA(
        isA<ArgumentError>().having((e) => e.message, 'text', 'mindestens 1'),
      ),
    );
  });

  test('Fehler der Berechnung kommen mit ihrem Text zurück', () async {
    final werk = Rechenwerk(parallel: 1);
    await expectLater(
      werk.rechne<int>(() => throw const FormatException('kaputt')),
      throwsA(
        isA<Rechenfehler>()
            .having((f) => f.text, 'text', 'FormatException: kaputt')
            .having((f) => '$f', 'toString', 'FormatException: kaputt'),
      ),
    );
    // nicht versendbares Ergebnis: Fehler statt Hänger
    await expectLater(
      werk.rechne<Object>(ReceivePort.new),
      throwsA(isA<Rechenfehler>()),
    );
    expect(werk.laufend, 0);
  });

  test('ein unerwartet beendetes Isolate ist ein Fehler', () async {
    final werk = Rechenwerk(parallel: 1);
    await expectLater(
      werk.rechne<int>(Isolate.exit),
      throwsA(
        isA<Rechenfehler>().having(
          (f) => f.text,
          'text',
          'Rechen-Isolate unerwartet beendet',
        ),
      ),
    );
  });

  test('zu lange Berechnungen werden abgebrochen, der Platz wird frei', () async {
    final werk = Rechenwerk(
      parallel: 1,
      hoechstdauer: const Duration(milliseconds: 200),
    );
    final uhr = Stopwatch()..start();
    await expectLater(
      werk.rechne(_endlos),
      throwsA(
        isA<RechenzeitUeberschritten>()
            .having((f) => f.hoechstdauer, 'hoechstdauer', werk.hoechstdauer)
            .having(
              (f) => '$f',
              'toString',
              'Berechnung nach 0 s abgebrochen – die Planung ist zu aufwendig',
            ),
      ),
    );
    expect(uhr.elapsed, lessThan(const Duration(seconds: 5)));
    expect(await werk.rechne(() => _summe(3)), 6);
    expect(
      '${const RechenzeitUeberschritten(Duration(seconds: 20))}',
      'Berechnung nach 20 s abgebrochen – die Planung ist zu aufwendig',
    );
  });

  test('das abgebrochene Isolate rechnet nicht weiter', () async {
    final ordner = Directory.systemTemp.createTempSync('rechenwerk-');
    final datei = File('${ordner.path}/takt');
    final pfad = datei.path;
    final werk = Rechenwerk(
      parallel: 1,
      hoechstdauer: const Duration(milliseconds: 200),
    );
    await expectLater(
      werk.rechne(() {
        for (var i = 0; ; i++) {
          File(pfad).writeAsStringSync('$i');
          sleep(const Duration(milliseconds: 5));
        }
      }),
      throwsA(isA<RechenzeitUeberschritten>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final stand = datei.readAsStringSync();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(datei.readAsStringSync(), stand);
    ordner.deleteSync(recursive: true);
  });

  test(
    'höchstens [parallel] gleichzeitig, weitere warten der Reihe nach',
    () async {
      final werk = Rechenwerk(parallel: 2);
      final ergebnisse = <int>[];
      final auftraege = [
        for (var i = 1; i <= 5; i++)
          werk
              .rechne(() {
                sleep(const Duration(milliseconds: 100));
                return i;
              })
              .then(ergebnisse.add),
      ];
      await Future<void>.delayed(Duration.zero);
      expect(werk.laufend, 2);
      expect(werk.wartend, 3);
      await Future.wait(auftraege);
      expect(ergebnisse, unorderedEquals([1, 2, 3, 4, 5]));
      // die zuerst wartende kommt zuerst dran
      expect(ergebnisse.indexOf(3), lessThan(ergebnisse.indexOf(5)));
      expect(werk.laufend, 0);
      expect(werk.wartend, 0);
    },
  );
}
