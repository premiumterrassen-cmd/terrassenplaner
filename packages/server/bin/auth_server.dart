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
  await Future.any([
    ProcessSignal.sigint.watch().first,
    ProcessSignal.sigterm.watch().first,
  ]);
  await auth.stoppe();
  stdout.writeln('Auth-Server beendet');
  // Native Threads der Transportschicht halten den Prozess sonst offen.
  exit(0);
}
