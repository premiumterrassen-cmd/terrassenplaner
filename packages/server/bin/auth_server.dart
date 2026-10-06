import 'dart:async';
import 'dart:io';

import 'package:terrassenplaner_server/terrassenplaner_server.dart';

/// Auth-Server (connectanum_auth_server) als eigener Prozess.
/// Mitarbeiter-Zugänge aus `PLANER_MITARBEITER_DATEI` (JSON), sonst keine.
Future<void> main() async {
  final umgebung = Platform.environment;
  final einstellungen = AuthServerEinstellungen.ausUmgebung(umgebung);
  final datei = umgebung['PLANER_MITARBEITER_DATEI'];
  final mitarbeiter = datei == null
      ? MitarbeiterVerzeichnis.leer()
      : MitarbeiterVerzeichnis.ausDatei(datei);
  final auth = await AuthServerProzess.starte(
    einstellungen,
    mitarbeiter: mitarbeiter,
  );
  stdout.writeln(
    'Auth-Server bereit – ${einstellungen.listen}, '
    '${mitarbeiter.anzahl} Mitarbeiter, Health ${einstellungen.healthListen}',
  );
  await _warteAufStoppsignal();
  await auth.stoppe();
  stdout.writeln('Auth-Server beendet');
  // Native Threads der Transportschicht halten den Prozess sonst offen.
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
