import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'datenbank.dart';

/// Die Probe-Wiederherstellung einer Sicherung ist fehlgeschlagen.
class SicherungUngueltig implements Exception {
  const SicherungUngueltig(this.meldung);

  final String meldung;

  @override
  String toString() => 'SicherungUngueltig: $meldung';
}

/// Sicherung der ObjectBox-Datenbank im laufenden Betrieb (M10-03).
///
/// ObjectBox erlaubt nur einen Prozess je Datenbank – das Sicherungsskript
/// auf dem Server (Rolle `sicherung`) kann die Datei also nicht selbst öffnen.
/// Es fordert die Kopie per Signal (SIGUSR1) beim laufenden Dienst an. Der
/// Dienst legt sie konsistent in einem Arbeitsordner an, öffnet sie dort zur
/// Probe als eigene Datenbank (Probe-Wiederherstellung), verschiebt sie dann
/// nach `<ziel>/data.mdb` und meldet sie zuletzt mit `<ziel>/stand` fertig
/// (`<unix-sekunden> <sequenz>`). Ablauf: docs/betrieb/sicherung.md.
class Sicherungsdienst {
  Sicherungsdienst._(this._abo);

  static const datei = 'data.mdb';
  static const standDatei = 'stand';
  static const arbeitsordner = '.entstehend';

  /// Sichert [datenbank] bei jedem Ereignis aus [anforderungen] nach [ziel].
  /// Fehler beenden den Dienst nicht, sie gehen an [protokoll] – das Skript
  /// wartet dann vergeblich auf `stand` und meldet den Fehler.
  static Sicherungsdienst starte(
    Datenbank datenbank,
    String ziel,
    Stream<Object?> anforderungen, {
    void Function(String meldung)? protokoll,
    DateTime Function() uhr = DateTime.now,
  }) {
    final melde = protokoll ?? (_) {};
    return Sicherungsdienst._(
      anforderungen.listen((_) {
        try {
          final sequenz = sichere(datenbank, ziel, uhr());
          melde('Sicherung $ziel (Sequenz $sequenz)');
        } on Exception catch (fehler) {
          melde('Sicherung fehlgeschlagen: $fehler');
        }
      }),
    );
  }

  /// Legt die geprüfte Sicherung von [datenbank] in [ziel] ab und liefert
  /// die enthaltene Sequenznummer.
  static int sichere(Datenbank datenbank, String ziel, DateTime zeit) {
    final arbeit = Directory(p.join(ziel, arbeitsordner));
    if (arbeit.existsSync()) arbeit.deleteSync(recursive: true);
    final sequenz = probeWiederherstellung(
      arbeit.path,
      datenbank.knoten,
      datenbank.sichere(arbeit.path),
    );
    File(p.join(arbeit.path, datei)).renameSync(p.join(ziel, datei));
    File(p.join(arbeit.path, standDatei))
      ..writeAsStringSync('${zeit.millisecondsSinceEpoch ~/ 1000} $sequenz\n')
      ..renameSync(p.join(ziel, standDatei));
    arbeit.deleteSync(recursive: true);
    return sequenz;
  }

  /// Probe-Wiederherstellung: Die Kopie muss sich öffnen lassen und dieselbe
  /// letzte Sequenznummer tragen wie das Original beim Kopieren. Liefert die
  /// in der Kopie gelesene Sequenznummer.
  static int probeWiederherstellung(
    String verzeichnis,
    String knoten,
    int sequenz,
  ) {
    final kopie = Datenbank.oeffne(verzeichnis, knoten: knoten);
    try {
      final gelesen = kopie.letzteSequenz;
      if (gelesen != sequenz) {
        throw SicherungUngueltig('Sequenz $gelesen statt $sequenz');
      }
      return gelesen;
    } finally {
      kopie.schliesse();
    }
  }

  final StreamSubscription<Object?> _abo;

  Future<void> stoppe() => _abo.cancel();
}
