import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';

/// Die Berechnung lief länger als [Rechenwerk.hoechstdauer] und wurde
/// abgebrochen.
final class RechenzeitUeberschritten implements Exception {
  const RechenzeitUeberschritten(this.hoechstdauer);

  final Duration hoechstdauer;

  @override
  String toString() =>
      'Berechnung nach ${hoechstdauer.inSeconds} s abgebrochen – '
      'die Planung ist zu aufwendig';
}

/// Fehler einer Berechnung im Rechen-Isolate; [toString] ist der Text des
/// ursprünglichen Fehlers.
final class Rechenfehler implements Exception {
  const Rechenfehler(this.text);

  final String text;

  @override
  String toString() => text;
}

/// Rechenwerk (M10-02): führt aufwendige Berechnungen in eigenen Isolates
/// aus. Im Router-Isolate laufen alle Dienste; rechnete er selbst, hielte
/// eine große Planung (Sekunden, mit Verschnittoptimierung bei extremen
/// Eingaben Minuten) Speichern, Laden und alle anderen Berechnungen an.
///
/// Höchstens [parallel] Berechnungen laufen gleichzeitig (Standard: Zahl
/// der Kerne), weitere warten der Reihe nach. Jede bekommt ein frisches
/// Isolate derselben Gruppe (Start unter einer Millisekunde), das nach
/// [hoechstdauer] beendet wird ([RechenzeitUeberschritten]).
final class Rechenwerk {
  Rechenwerk({int? parallel, this.hoechstdauer = standardHoechstdauer})
    : parallel = parallel ?? Platform.numberOfProcessors {
    if (this.parallel < 1) {
      throw ArgumentError.value(this.parallel, 'parallel', 'mindestens 1');
    }
  }

  /// Obergrenze je Berechnung; das große Projekt des Lasttests braucht auf
  /// dem Zielserver rund 2 s.
  static const standardHoechstdauer = Duration(seconds: 20);

  final int parallel;
  final Duration hoechstdauer;

  var _laufend = 0;
  final _wartend = Queue<Completer<void>>();

  /// Laufende Berechnungen.
  int get laufend => _laufend;

  /// Wartende Berechnungen.
  int get wartend => _wartend.length;

  /// Führt [arbeit] in einem eigenen Isolate aus und liefert ihr Ergebnis.
  /// [arbeit] darf nur versendbare Werte einschließen (keine Ports,
  /// Sitzungen oder Sockets); ihr Ergebnis muss versendbar sein.
  Future<R> rechne<R>(R Function() arbeit) async {
    await _platz();
    try {
      return await _imIsolate(arbeit);
    } finally {
      _gibFrei();
    }
  }

  Future<void> _platz() {
    if (_laufend < parallel) {
      _laufend++;
      return Future.value();
    }
    final platz = Completer<void>();
    _wartend.add(platz);
    return platz.future;
  }

  /// Den Platz übernimmt direkt die nächste wartende Berechnung.
  void _gibFrei() {
    if (_wartend.isEmpty) {
      _laufend--;
    } else {
      _wartend.removeFirst().complete();
    }
  }

  Future<R> _imIsolate<R>(R Function() arbeit) async {
    final antwort = ReceivePort();
    try {
      final isolate = await Isolate.spawn(
        _lauf<R>,
        (arbeit, antwort.sendPort),
        onExit: antwort.sendPort,
        debugName: 'rechenwerk',
      );
      final nachricht = await antwort.first.timeout(
        hoechstdauer,
        onTimeout: () {
          isolate.kill(priority: Isolate.immediate);
          throw RechenzeitUeberschritten(hoechstdauer);
        },
      );
      return switch (nachricht) {
        (true, final R ergebnis) => ergebnis,
        (false, final String text) => throw Rechenfehler(text),
        _ => throw const Rechenfehler('Rechen-Isolate unerwartet beendet'),
      };
    } finally {
      antwort.close();
    }
  }

  static void _lauf<R>((R Function(), SendPort) auftrag) {
    final (arbeit, antwort) = auftrag;
    try {
      antwort.send((true, arbeit()));
    } on Object catch (fehler) {
      antwort.send((false, '$fehler'));
    }
  }
}
