import 'dart:async';
import 'dart:io';

import 'package:terrassenplaner_server/terrassenplaner_server.dart';

/// Auth-Server (connectanum_auth_server) als eigener Prozess.
/// Mitarbeiter-Konten liegen in ObjectBox (`PLANER_DATENVERZEICHNIS`) und
/// werden mit `bin/mitarbeiter.dart` verwaltet (M9-10); ohne Verzeichnis
/// (Entwicklung, Smoke-Tests) nur im Arbeitsspeicher.
Future<void> main() async {
  final umgebung = Platform.environment;
  final einstellungen = AuthServerEinstellungen.ausUmgebung(umgebung);
  final verzeichnis = umgebung['PLANER_DATENVERZEICHNIS'];
  if (verzeichnis == null) {
    stderr.writeln('WARNUNG: Mitarbeiter-Konten nur im Arbeitsspeicher');
  }
  final datenbank = Datenbank.oeffne(
    verzeichnis ?? 'memory:planer-auth',
    knoten: umgebung['PLANER_KNOTEN'] ?? Platform.localHostname,
  );
  // Datenbank-Kennzahlen für Prometheus (M0-14), nur lokal.
  final metriken = verzeichnis == null
      ? null
      : await MetrikServer.starte(
          umgebung['PLANER_DATENBANK_METRIKEN'] ?? '127.0.0.1:8084',
          () =>
              datenbankMetriken(datenbank.kennzahlen(), dienst: 'planer-auth'),
        );
  final auth = await AuthServerProzess.starte(
    einstellungen,
    konten: Mitarbeiterkonten(datenbank),
  );
  stdout.writeln(
    'Auth-Server bereit – ${einstellungen.listen}, '
    'Datenbank ${verzeichnis ?? '(keine)'}, Health ${einstellungen.healthListen}',
  );
  await _warteAufStoppsignal();
  await auth.stoppe();
  await metriken?.stoppe();
  datenbank.schliesse();
  stdout.writeln('Auth-Server beendet');
}

/// Wartet auf SIGINT oder SIGTERM und meldet beide Signale wieder ab, damit
/// sich der Prozess danach von selbst beendet.
Future<void> _warteAufStoppsignal() async {
  final signal = Completer<void>();
  final abos = [
    for (final s in [ProcessSignal.sigint, ProcessSignal.sigterm])
      s.watch().listen((_) {
        if (!signal.isCompleted) signal.complete();
      }),
  ];
  await signal.future;
  for (final abo in abos) {
    await abo.cancel();
  }
}
